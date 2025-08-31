//
//  GroupFormationService.swift
//  SchoolCarpoolMatcher
//
//  Service for creating and managing carpool groups from successful matches
//  Implements F1.4 requirements: group creation, route optimization, admin assignment
//  Follows repo rule: ObservableObject pattern with comprehensive logging
//

import Foundation
import CoreLocation
import Combine

// MARK: - Group Formation Service
/// Service responsible for creating carpool groups from successful matches
/// Handles route optimization, pickup sequencing, and safety scoring
@MainActor
class GroupFormationService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var activeGroups: [CarpoolGroup] = []
    @Published var pendingInvitations: [GroupInvitation] = []
    @Published var isCreatingGroup = false
    @Published var lastCreatedGroup: CarpoolGroup?
    
    // MARK: - Private Properties
    private let routeOptimizer = RouteOptimizer()
    private let safetyCalculator = SafetyCalculator()
    
    // MARK: - Initialization
    init() {
        print("👥 GroupFormationService initialized")
        loadActiveGroups()
    }
    
    // MARK: - Public Methods
    
    /// Create carpool group from successful matches (F1.4 implementation)
    func createCarpoolGroup(
        matches: [Family],
        currentUser: Family,
        customName: String? = nil
    ) async -> Result<CarpoolGroup, GroupFormationError> {
        
        print("🔄 Creating carpool group with \(matches.count + 1) families...")
        isCreatingGroup = true
        
        do {
            // 1. Validate group composition
            let allMembers = [currentUser] + matches
            try validateGroupComposition(allMembers)
            
            // 2. Generate group name
            let groupName = customName ?? generateGroupName(for: allMembers)
            print("📝 Group name: '\(groupName)'")
            
            // 3. Create pickup points from family locations
            let pickupPoints = createPickupPoints(from: allMembers)
            print("📍 Created \(pickupPoints.count) pickup points")
            
            // 4. Optimize pickup sequence
            let optimizedSequence = await routeOptimizer.calculateOptimalPickupSequence(
                pickupPoints: pickupPoints,
                schoolLocation: CLLocation(
                    latitude: currentUser.schoolLatitude,
                    longitude: currentUser.schoolLongitude
                )
            )
            
            // 5. Create optimized route
            let route = Route(
                groupId: UUID(), // Will be updated with actual group ID
                pickupPoints: optimizedSequence,
                safetyScore: await calculateRouteSafetyScore(optimizedSequence)
            )
            
            // 6. Create group members
            let groupMembers = createGroupMembers(from: allMembers, adminId: currentUser.id)
            
            // 7. Create the carpool group
            let carpoolGroup = CarpoolGroup(
                groupName: groupName,
                adminId: currentUser.id,
                members: groupMembers,
                schoolName: currentUser.schoolName,
                schoolAddress: currentUser.schoolAddress,
                scheduledDepartureTime: currentUser.preferredDepartureTime,
                pickupSequence: optimizedSequence,
                optimizedRoute: route,
                safetyScore: route.safetyAnalysis.overallScore
            )
            
            // 8. Save and activate group
            activeGroups.append(carpoolGroup)
            lastCreatedGroup = carpoolGroup
            saveActiveGroups()
            
            // 9. Send invitations to other families
            await sendGroupInvitations(group: carpoolGroup, invitees: matches)
            
            print("✅ Successfully created carpool group: \(carpoolGroup.id)")
            print("   👥 Members: \(carpoolGroup.members.count)")
            print("   🛡️ Safety Score: \(String(format: "%.1f", carpoolGroup.safetyScore))")
            print("   📏 Route Distance: \(String(format: "%.1f", carpoolGroup.estimatedDistance/1000))km")
            
            isCreatingGroup = false
            return .success(carpoolGroup)
            
        } catch {
            print("❌ Failed to create carpool group: \(error)")
            isCreatingGroup = false
            return .failure(error as? GroupFormationError ?? .unknown)
        }
    }
    
    /// Join an existing group via invite code
    func joinGroup(inviteCode: String, family: Family) async -> Result<CarpoolGroup, GroupFormationError> {
        print("🔗 Attempting to join group with code: \(inviteCode)")
        
        guard let group = activeGroups.first(where: { $0.inviteCode == inviteCode }) else {
            return .failure(.invalidInviteCode)
        }
        
        guard group.allowsNewMembers && group.members.count < group.maxMembers else {
            return .failure(.groupFull)
        }
        
        // Add member to group (simplified for demo)
        let newMember = GroupMember(familyId: family.id, role: .passenger)
        var updatedMembers = group.members
        updatedMembers.append(newMember)
        
        print("✅ Successfully joined group: \(group.groupName)")
        return .success(group)
    }
    
    // MARK: - Private Methods
    
    private func validateGroupComposition(_ families: [Family]) throws {
        // Ensure all families go to the same school
        let schools = Set(families.map { $0.schoolName })
        guard schools.count == 1 else {
            throw GroupFormationError.differentSchools
        }
        
        // Ensure there's at least one driver
        let driversAvailable = families.contains { $0.isDriverAvailable }
        guard driversAvailable else {
            throw GroupFormationError.noDriverAvailable
        }
        
        // Check vehicle capacity
        let totalSeatsNeeded = families.count
        let totalSeatsAvailable = families.filter { $0.isDriverAvailable }.reduce(0) { $0 + $1.availableSeats }
        guard totalSeatsAvailable >= totalSeatsNeeded else {
            throw GroupFormationError.insufficientSeats
        }
        
        print("✅ Group composition validated")
    }
    
    private func generateGroupName(for families: [Family]) -> String {
        let school = families.first?.schoolName ?? "School"
        let schoolShort = school.components(separatedBy: " ").first ?? "School"
        
        // Generate creative group names
        let nameOptions = [
            "\(schoolShort) Squad",
            "\(schoolShort) Carpool Crew",
            "\(schoolShort) Transport Team",
            "\(schoolShort) School Run",
            "\(schoolShort) Family Express",
            "\(schoolShort) Morning Crew",
            "\(schoolShort) Eco Warriors"
        ]
        
        return nameOptions.randomElement() ?? "\(schoolShort) Carpool"
    }
    
    private func createPickupPoints(from families: [Family]) -> [PickupPoint] {
        return families.enumerated().map { index, family in
            PickupPoint(
                familyId: family.id,
                coordinate: family.coordinate,
                address: family.homeAddress,
                sequenceOrder: index,
                estimatedTime: family.preferredDepartureTime,
                specialInstructions: generatePickupInstructions(for: family)
            )
        }
    }
    
    private func generatePickupInstructions(for family: Family) -> String? {
        let instructions = [
            "Ring doorbell once",
            "Park in driveway if available",
            "Text on arrival",
            "Wait at front gate",
            nil // Some families don't need special instructions
        ]
        
        return instructions.randomElement() ?? nil
    }
    
    private func createGroupMembers(from families: [Family], adminId: UUID) -> [GroupMember] {
        return families.map { family in
            let role: MemberRole
            if family.id == adminId {
                role = .admin
            } else if family.isDriverAvailable {
                role = .driver
            } else {
                role = .passenger
            }
            
            return GroupMember(
                familyId: family.id,
                role: role,
                contributionScore: calculateContributionScore(for: family)
            )
        }
    }
    
    private func calculateContributionScore(for family: Family) -> Double {
        var score = 5.0 // Base score
        
        // Bonus for being a driver
        if family.isDriverAvailable {
            score += 2.0
        }
        
        // Bonus for high trust level
        if family.isHighTrust {
            score += 1.0
        }
        
        // Bonus for high ratings
        if family.averageRating >= 4.5 {
            score += 0.5
        }
        
        return min(score, 10.0)
    }
    
    private func calculateRouteSafetyScore(_ pickupPoints: [PickupPoint]) async -> Double {
        // Simplified safety calculation for demo
        let baseScore = 8.5
        let randomVariation = Double.random(in: -0.5...0.5)
        let finalScore = max(7.0, min(10.0, baseScore + randomVariation))
        
        print("🛡️ Calculated route safety score: \(String(format: "%.1f", finalScore))")
        return finalScore
    }
    
    private func sendGroupInvitations(group: CarpoolGroup, invitees: [Family]) async {
        print("📧 Sending invitations to \(invitees.count) families")
        
        for family in invitees {
            let invitation = GroupInvitation(
                groupId: group.id,
                groupName: group.groupName,
                inviteeId: family.id,
                inviteeName: family.parentName,
                inviterName: group.adminMember?.familyId.uuidString ?? "Admin", // Simplified
                expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            )
            
            pendingInvitations.append(invitation)
            print("   📨 Sent invitation to \(family.parentName)")
        }
        
        savePendingInvitations()
    }
    
    // MARK: - Persistence
    
    private func loadActiveGroups() {
        // In a real app, would load from Core Data or API
        // For demo, start with empty array
        activeGroups = []
        print("📁 Loaded \(activeGroups.count) active groups")
    }
    
    private func saveActiveGroups() {
        // In a real app, would save to Core Data or API
        print("💾 Saved \(activeGroups.count) active groups")
    }
    
    private func savePendingInvitations() {
        // In a real app, would save to Core Data or API
        print("💾 Saved \(pendingInvitations.count) pending invitations")
    }
}

// MARK: - Route Optimizer
/// Utility class for optimizing pickup sequences and routes
class RouteOptimizer {
    
    func calculateOptimalPickupSequence(
        pickupPoints: [PickupPoint],
        schoolLocation: CLLocation
    ) async -> [PickupPoint] {
        print("🗺️ Optimizing pickup sequence for \(pickupPoints.count) points...")
        
        // Simplified optimization: sort by distance from school (closest first)
        let optimized = pickupPoints.sorted { point1, point2 in
            let location1 = CLLocation(latitude: point1.coordinate.latitude, longitude: point1.coordinate.longitude)
            let location2 = CLLocation(latitude: point2.coordinate.latitude, longitude: point2.coordinate.longitude)
            
            return schoolLocation.distance(from: location1) < schoolLocation.distance(from: location2)
        }
        
        // Update sequence order
        let reorderedPoints = optimized.enumerated().map { index, point in
            PickupPoint(
                familyId: point.familyId,
                coordinate: point.coordinate,
                address: point.address,
                sequenceOrder: index,
                estimatedTime: calculateEstimatedTime(for: index, baseTime: point.estimatedTime),
                specialInstructions: point.specialInstructions
            )
        }
        
        print("✅ Optimized pickup sequence")
        return reorderedPoints
    }
    
    private func calculateEstimatedTime(for sequenceIndex: Int, baseTime: Date) -> Date {
        // Add 3 minutes per pickup point for travel time
        let additionalMinutes = sequenceIndex * 3
        return Calendar.current.date(byAdding: .minute, value: additionalMinutes, to: baseTime) ?? baseTime
    }
}

// MARK: - Safety Calculator
/// Utility class for calculating route safety scores
class SafetyCalculator {
    
    func evaluateRoute(_ pickupPoints: [PickupPoint]) async -> Double {
        // Simplified safety evaluation for demo
        let baseScore = 8.5
        let safetyFactors = calculateSafetyFactors(pickupPoints)
        
        let finalScore = baseScore * safetyFactors.average
        print("🛡️ Route safety evaluation: \(String(format: "%.1f", finalScore))")
        
        return finalScore
    }
    
    private func calculateSafetyFactors(_ pickupPoints: [PickupPoint]) -> (school: Double, traffic: Double, residential: Double, average: Double) {
        // Mock safety factors for demo
        let schoolZoneFactor = Double.random(in: 0.9...1.1)
        let trafficLightFactor = Double.random(in: 0.85...1.05)
        let residentialFactor = Double.random(in: 0.95...1.1)
        
        let average = (schoolZoneFactor + trafficLightFactor + residentialFactor) / 3.0
        
        return (schoolZoneFactor, trafficLightFactor, residentialFactor, average)
    }
}

// MARK: - Supporting Models

struct GroupInvitation: Identifiable, Codable {
    let id: UUID
    let groupId: UUID
    let groupName: String
    let inviteeId: UUID
    let inviteeName: String
    let inviterName: String
    let sentAt: Date
    let expiresAt: Date
    let status: InvitationStatus
    
    init(
        groupId: UUID,
        groupName: String,
        inviteeId: UUID,
        inviteeName: String,
        inviterName: String,
        expiresAt: Date
    ) {
        self.id = UUID()
        self.groupId = groupId
        self.groupName = groupName
        self.inviteeId = inviteeId
        self.inviteeName = inviteeName
        self.inviterName = inviterName
        self.sentAt = Date()
        self.expiresAt = expiresAt
        self.status = .pending
    }
    
    var isExpired: Bool {
        Date() > expiresAt
    }
}

enum InvitationStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case expired = "expired"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        case .expired: return "Expired"
        }
    }
}

// MARK: - Error Types

enum GroupFormationError: Error, LocalizedError {
    case differentSchools
    case noDriverAvailable
    case insufficientSeats
    case invalidInviteCode
    case groupFull
    case networkError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .differentSchools:
            return "All families must attend the same school"
        case .noDriverAvailable:
            return "At least one family must be available to drive"
        case .insufficientSeats:
            return "Not enough vehicle seats for all families"
        case .invalidInviteCode:
            return "Invalid or expired invite code"
        case .groupFull:
            return "This group is already full"
        case .networkError:
            return "Network error occurred"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
