//
//  CarpoolGroup.swift
//  SchoolCarpoolMatcher
//
//  Data models for carpool group formation and management
//  Implements F1.4 requirements: group creation, route optimization, admin roles
//  Follows repo rule: Comprehensive comments and debug logging
//

import Foundation
import CoreLocation

// MARK: - Carpool Group Model
/// Core data model for carpool groups formed from successful matches
/// Includes membership, route optimization, and performance tracking
struct CarpoolGroup: Identifiable {
    // MARK: - Primary Identifiers
    let id: UUID
    let groupName: String
    let groupType: GroupType
    
    // MARK: - Membership
    let adminId: UUID
    let members: [GroupMember]
    let maxMembers: Int
    let inviteCode: String
    
    // MARK: - School & Schedule
    let schoolName: String
    let schoolAddress: String
    let scheduledDepartureTime: Date
    let scheduleFlexibility: TimeInterval
    let activeDays: Set<Weekday>
    
    // MARK: - Route & Logistics
    let pickupSequence: [PickupPoint] 
    let optimizedRoute: Route
    let estimatedTotalTime: TimeInterval
    let estimatedDistance: Double
    let currentDriverId: UUID?
    let backupDriverIds: [UUID]
    
    // MARK: - Performance & Safety
    let safetyScore: Double
    let reliabilityScore: Double
    let avgRating: Double
    let totalTrips: Int
    let onTimePercentage: Double
    
    // MARK: - Status & Dates
    let status: GroupStatus
    let createdDate: Date
    let lastActiveDate: Date
    let nextScheduledTrip: Date?
    
    // MARK: - Settings
    let isPrivate: Bool
    let allowsNewMembers: Bool
    let requiresApproval: Bool
    let emergencyContactsShared: Bool
    
    // MARK: - Computed Properties
    var isActive: Bool {
        status == .active && members.count >= 2
    }
    
    var needsDriver: Bool {
        currentDriverId == nil || !members.contains { $0.familyId == currentDriverId }
    }
    
    var adminMember: GroupMember? {
        members.first { $0.familyId == adminId }
    }
    
    var driverMembers: [GroupMember] {
        members.filter { $0.role == .driver || $0.role == .admin }
    }
    
    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        groupName: String,
        adminId: UUID,
        members: [GroupMember],
        schoolName: String,
        schoolAddress: String,
        scheduledDepartureTime: Date,
        pickupSequence: [PickupPoint],
        optimizedRoute: Route,
        safetyScore: Double = 8.5
    ) {
        self.id = id
        self.groupName = groupName
        self.groupType = .regular
        self.adminId = adminId
        self.members = members
        self.maxMembers = 6 // Reasonable limit for safety
        self.inviteCode = CarpoolGroup.generateInviteCode()
        
        self.schoolName = schoolName
        self.schoolAddress = schoolAddress
        self.scheduledDepartureTime = scheduledDepartureTime
        self.scheduleFlexibility = 15 * 60 // 15 minutes default
        self.activeDays = [.monday, .tuesday, .wednesday, .thursday, .friday]
        
        self.pickupSequence = pickupSequence
        self.optimizedRoute = optimizedRoute
        self.estimatedTotalTime = optimizedRoute.estimatedDuration
        self.estimatedDistance = optimizedRoute.totalDistance
        self.currentDriverId = members.first { $0.role == .driver }?.familyId
        self.backupDriverIds = members.filter { $0.role == .backup }.map { $0.familyId }
        
        self.safetyScore = safetyScore
        self.reliabilityScore = 9.0 // New groups start with high reliability
        self.avgRating = 4.5 // Default rating
        self.totalTrips = 0
        self.onTimePercentage = 100.0
        
        self.status = members.count >= 2 ? .active : .forming
        self.createdDate = Date()
        self.lastActiveDate = Date()
        self.nextScheduledTrip = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        
        self.isPrivate = false
        self.allowsNewMembers = members.count < maxMembers
        self.requiresApproval = true
        self.emergencyContactsShared = true
        
        print("👥 Created carpool group '\(groupName)' with \(members.count) members")
        print("   🏫 School: \(schoolName)")
        print("   🛡️ Safety Score: \(safetyScore)")
        print("   📍 Route Distance: \(String(format: "%.1f", estimatedDistance/1000))km")
    }
    
    // MARK: - Helper Methods
    static func generateInviteCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement() ?? "A" })
    }
}

// MARK: - Group Member Model
struct GroupMember: Identifiable, Codable {
    let id: UUID
    let familyId: UUID
    let role: MemberRole
    let joinedDate: Date
    let isActive: Bool
    let notificationPreferences: NotificationPreferences
    let contributionScore: Double // Based on driving frequency, reliability
    
    init(
        familyId: UUID,
        role: MemberRole = .passenger,
        contributionScore: Double = 5.0
    ) {
        self.id = UUID()
        self.familyId = familyId
        self.role = role
        self.joinedDate = Date()
        self.isActive = true
        self.notificationPreferences = NotificationPreferences()
        self.contributionScore = contributionScore
        
        print("👤 Added group member with role: \(role.rawValue)")
    }
}

// MARK: - Notification Preferences
struct NotificationPreferences: Codable {
    let enablePushNotifications: Bool
    let enableScheduleChanges: Bool
    let enableEmergencyAlerts: Bool
    let enableGroupMessages: Bool
    let quietHoursStart: Date
    let quietHoursEnd: Date
    
    init() {
        self.enablePushNotifications = true
        self.enableScheduleChanges = true
        self.enableEmergencyAlerts = true
        self.enableGroupMessages = true
        
        // Default quiet hours: 9 PM to 7 AM
        let calendar = Calendar.current
        self.quietHoursStart = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
        self.quietHoursEnd = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    }
}

// MARK: - Supporting Enums

enum GroupType: String, CaseIterable, Codable {
    case regular = "regular" // Daily school run
    case occasional = "occasional" // Events, activities
    case emergency = "emergency" // Backup arrangements
    
    var displayName: String {
        switch self {
        case .regular: return "Regular Carpool"
        case .occasional: return "Occasional Events"
        case .emergency: return "Emergency Backup"
        }
    }
}

enum GroupStatus: String, CaseIterable, Codable {
    case forming = "forming" // Less than minimum members
    case active = "active"
    case paused = "paused" // Temporarily inactive
    case archived = "archived" // Permanently inactive
    
    var displayName: String {
        switch self {
        case .forming: return "Forming"
        case .active: return "Active"
        case .paused: return "Paused"
        case .archived: return "Archived"
        }
    }
    
    var color: String {
        switch self {
        case .forming: return "orange"
        case .active: return "green"
        case .paused: return "yellow"
        case .archived: return "gray"
        }
    }
}

enum MemberRole: String, CaseIterable, Codable {
    case admin = "admin"
    case driver = "driver"
    case passenger = "passenger"
    case backup = "backup"
    
    var displayName: String {
        switch self {
        case .admin: return "Admin"
        case .driver: return "Driver"
        case .passenger: return "Passenger"
        case .backup: return "Backup Driver"
        }
    }
    
    var permissions: [Permission] {
        switch self {
        case .admin:
            return [.manageMembers, .editSchedule, .editRoute, .viewReports, .sendAnnouncements]
        case .driver:
            return [.editSchedule, .shareLocation, .sendUpdates]
        case .passenger:
            return [.shareLocation, .sendMessages]
        case .backup:
            return [.editSchedule, .shareLocation, .sendUpdates]
        }
    }
}

enum Permission: String, CaseIterable, Codable {
    case manageMembers = "manage_members"
    case editSchedule = "edit_schedule"
    case editRoute = "edit_route"
    case viewReports = "view_reports"
    case sendAnnouncements = "send_announcements"
    case shareLocation = "share_location"
    case sendUpdates = "send_updates"
    case sendMessages = "send_messages"
}

enum Weekday: String, CaseIterable, Codable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
    
    var shortName: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }
}

// MARK: - Route Models

struct Route: Identifiable {
    let id: UUID
    let groupId: UUID
    let coordinates: [CLLocationCoordinate2D]
    let pickupPoints: [PickupPoint]
    let safetyAnalysis: SafetyAnalysis
    let estimatedDuration: TimeInterval
    let totalDistance: Double
    let lastUpdated: Date
    
    init(
        groupId: UUID,
        pickupPoints: [PickupPoint],
        safetyScore: Double = 8.5
    ) {
        self.id = UUID()
        self.groupId = groupId
        self.pickupPoints = pickupPoints
        
        // Calculate route coordinates (simplified for demo)
        self.coordinates = pickupPoints.map { $0.coordinate }
        
        // Calculate total distance
        var totalDist = 0.0
        if pickupPoints.count >= 2 {
            for i in 1..<pickupPoints.count {
                let prev = CLLocation(
                    latitude: pickupPoints[i-1].coordinate.latitude,
                    longitude: pickupPoints[i-1].coordinate.longitude
                )
                let curr = CLLocation(
                    latitude: pickupPoints[i].coordinate.latitude,
                    longitude: pickupPoints[i].coordinate.longitude
                )
                totalDist += prev.distance(from: curr)
            }
        }
        self.totalDistance = totalDist
        
        // Estimate duration (assuming 30 km/h average speed)
        self.estimatedDuration = (totalDist / 1000) * (60 * 60 / 30) // seconds
        
        self.safetyAnalysis = SafetyAnalysis(overallScore: safetyScore)
        self.lastUpdated = Date()
        
        print("🗺️ Created route with \(pickupPoints.count) pickup points")
        print("   📏 Total distance: \(String(format: "%.1f", totalDist/1000))km")
        print("   ⏱️ Estimated time: \(Int(estimatedDuration/60)) minutes")
    }
}

struct PickupPoint: Identifiable {
    let id: UUID
    let familyId: UUID
    let coordinate: CLLocationCoordinate2D
    let address: String
    let estimatedTime: Date
    let specialInstructions: String?
    let sequenceOrder: Int
    let isCoveredArea: Bool // For weather protection
    
    init(
        familyId: UUID,
        coordinate: CLLocationCoordinate2D,
        address: String,
        sequenceOrder: Int,
        estimatedTime: Date = Date(),
        specialInstructions: String? = nil
    ) {
        self.id = UUID()
        self.familyId = familyId
        self.coordinate = coordinate
        self.address = address
        self.sequenceOrder = sequenceOrder
        self.estimatedTime = estimatedTime
        self.specialInstructions = specialInstructions
        self.isCoveredArea = Bool.random() // Random for demo
    }
}

struct SafetyAnalysis {
    let overallScore: Double // 0.0 - 10.0
    let schoolZoneScore: Double
    let trafficLightScore: Double
    let residentialStreetScore: Double
    let accidentHistoryScore: Double
    let visibilityScore: Double
    let speedLimitCompliance: Double
    let weatherVulnerability: Double
    let lastAnalyzed: Date
    
    init(overallScore: Double) {
        self.overallScore = overallScore
        self.schoolZoneScore = overallScore + Double.random(in: -0.5...0.5)
        self.trafficLightScore = overallScore + Double.random(in: -0.5...0.5)
        self.residentialStreetScore = overallScore + Double.random(in: -0.5...0.5)
        self.accidentHistoryScore = overallScore + Double.random(in: -1.0...0.5)
        self.visibilityScore = overallScore + Double.random(in: -0.5...0.5)
        self.speedLimitCompliance = overallScore + Double.random(in: -0.5...0.5)
        self.weatherVulnerability = overallScore + Double.random(in: -1.0...0.5)
        self.lastAnalyzed = Date()
    }
    
    var riskLevel: RiskLevel {
        switch overallScore {
        case 8.5...10.0: return .low
        case 6.5..<8.5: return .medium  
        case 4.0..<6.5: return .high
        default: return .critical
        }
    }
}

enum RiskLevel: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "Low Risk"
        case .medium: return "Medium Risk"
        case .high: return "High Risk"
        case .critical: return "Critical Risk"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}
