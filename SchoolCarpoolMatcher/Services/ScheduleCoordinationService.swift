//
//  ScheduleCoordinationService.swift
//  SchoolCarpoolMatcher
//
//  Service for managing schedule coordination and conflict detection
//  Implements F3.3 requirements: schedule changes, calendar integration, voting
//  Follows repo rule: Comprehensive comments and debug logging
//

import Foundation
import EventKit
import Combine

// MARK: - Schedule Coordination Service
/// Core service for managing schedule changes, conflict detection, and group coordination
/// Prioritizes child safety with comprehensive conflict analysis and backup driver management
@MainActor
class ScheduleCoordinationService: ObservableObject {
    // MARK: - Singleton
    static let shared = ScheduleCoordinationService()
    
    // MARK: - Published Properties
    @Published var activeProposals: [ScheduleChangeProposal] = []
    @Published var pendingApprovals: [ScheduleChangeProposal] = []
    @Published var recentChanges: [ScheduleChangeProposal] = []
    @Published var isCalendarAccessGranted = false
    @Published var lastError: String?
    
    // MARK: - Private Properties
    private let eventStore = EKEventStore()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Mock Data for Testing
    private var mockProposals: [ScheduleChangeProposal] = []
    
    // MARK: - Initialization
    init() {
        print("📅 ScheduleCoordinationService: Initializing service...")
        setupMockData()
        checkCalendarPermission()
        startProposalExpiryTimer()
    }
    
    // MARK: - Public Methods
    
    /// Propose a schedule change for a carpool group
    /// - Parameters:
    ///   - groupId: The carpool group ID
    ///   - currentDepartureTime: Current departure time
    ///   - proposedDepartureTime: New proposed departure time
    ///   - reason: Reason for the change
    ///   - priority: Priority level of the change
    /// - Returns: The created proposal with conflict analysis
    func proposeScheduleChange(
        groupId: UUID,
        currentDepartureTime: Date,
        proposedDepartureTime: Date,
        reason: String,
        priority: ScheduleChangePriority = .normal
    ) async -> ScheduleChangeProposal {
        print("📅 Proposing schedule change for group \(groupId.uuidString.prefix(8))")
        print("   ⏰ Current: \(formatTime(currentDepartureTime)) → Proposed: \(formatTime(proposedDepartureTime))")
        print("   📝 Reason: \(reason)")
        print("   🚨 Priority: \(priority.displayName)")
        
        // Detect conflicts
        let conflicts = await detectCalendarConflicts(
            proposedTime: proposedDepartureTime,
            groupId: groupId
        )
        
        // Generate alternative times if conflicts exist
        let alternatives = await generateAlternativeTimes(
            originalTime: proposedDepartureTime,
            conflicts: conflicts
        )
        
        // Create proposal
        let proposal = ScheduleChangeProposal(
            groupId: groupId,
            proposedBy: UUID(), // TODO: Get current user ID
            proposerName: "Current User", // TODO: Get current user name
            currentDepartureTime: currentDepartureTime,
            proposedDepartureTime: proposedDepartureTime,
            reason: reason,
            priority: priority,
            detectedConflicts: conflicts,
            suggestedAlternatives: alternatives,
            votesRequired: 3 // TODO: Get from group member count
        )
        
        // Add to active proposals
        activeProposals.append(proposal)
        pendingApprovals.append(proposal)
        
        print("✅ Schedule change proposal created successfully")
        print("   🔍 Conflicts detected: \(conflicts.count)")
        print("   💡 Alternatives suggested: \(alternatives.count)")
        print("   📊 Votes required: \(proposal.votesRequired)")
        
        // Post notification for real-time updates
        NotificationCenter.default.post(
            name: .newScheduleProposal,
            object: proposal
        )
        
        return proposal
    }
    
    /// Vote on a schedule change proposal
    /// - Parameters:
    ///   - proposalId: The proposal ID to vote on
    ///   - userId: The user voting
    ///   - vote: The vote type (approve/reject/abstain)
    ///   - comment: Optional comment with the vote
    func voteOnProposal(
        proposalId: UUID,
        userId: UUID,
        vote: VoteType,
        comment: String? = nil
    ) {
        print("🗳️ User \(userId.uuidString.prefix(8)) voting on proposal \(proposalId.uuidString.prefix(8))")
        print("   ✅ Vote: \(vote.displayName)")
        if let comment = comment {
            print("   💬 Comment: \(comment)")
        }
        
        guard let proposalIndex = activeProposals.firstIndex(where: { $0.id == proposalId }) else {
            print("❌ Proposal not found: \(proposalId.uuidString.prefix(8))")
            lastError = "Proposal not found"
            return
        }
        
        // Create vote
        let scheduleVote = ScheduleVote(
            userId: userId,
            vote: vote,
            comment: comment
        )
        
        // Add vote to proposal
        activeProposals[proposalIndex].addVote(scheduleVote)
        
        // Update proposal status
        activeProposals[proposalIndex].updateStatus()
        
        // Check if proposal is resolved
        let proposal = activeProposals[proposalIndex]
        if proposal.status != .pending {
            handleProposalResolution(proposal)
        }
        
        print("✅ Vote recorded successfully")
        print("   📊 Current approval: \(String(format: "%.1f", proposal.approvalPercentage))%")
        print("   📋 Status: \(proposal.status.displayName)")
        
        // Post notification for real-time updates
        NotificationCenter.default.post(
            name: .scheduleProposalVoteUpdated,
            object: proposal
        )
    }
    
    /// Get all active proposals for a specific group
    /// - Parameter groupId: The carpool group ID
    /// - Returns: Array of active proposals
    func getActiveProposals(for groupId: UUID) -> [ScheduleChangeProposal] {
        return activeProposals.filter { $0.groupId == groupId && $0.status == .pending }
    }
    
    /// Get proposals requiring immediate action (urgent priority or critical conflicts)
    /// - Returns: Array of urgent proposals
    func getUrgentProposals() -> [ScheduleChangeProposal] {
        return activeProposals.filter { $0.requiresImmediateAction }
    }
    
    /// Cancel a schedule change proposal
    /// - Parameter proposalId: The proposal ID to cancel
    func cancelProposal(proposalId: UUID) {
        print("❌ Cancelling proposal \(proposalId.uuidString.prefix(8))")
        
        guard let proposalIndex = activeProposals.firstIndex(where: { $0.id == proposalId }) else {
            print("❌ Proposal not found for cancellation")
            lastError = "Proposal not found"
            return
        }
        
        // Update status
        activeProposals[proposalIndex].status = .cancelled
        
        // Remove from pending approvals
        pendingApprovals.removeAll { $0.id == proposalId }
        
        print("✅ Proposal cancelled successfully")
        
        // Post notification for real-time updates
        NotificationCenter.default.post(
            name: .scheduleProposalCancelled,
            object: activeProposals[proposalIndex]
        )
    }
    
    /// Check calendar permission and request if needed
    func checkCalendarPermission() {
        print("📅 Checking calendar permission status...")
        
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            print("   ⏳ Permission not determined, requesting access...")
            requestCalendarPermission()
        case .authorized, .fullAccess:
            print("   ✅ Calendar access granted")
            isCalendarAccessGranted = true
        case .denied, .restricted, .writeOnly:
            print("   ❌ Calendar access denied or restricted")
            isCalendarAccessGranted = false
            lastError = "Calendar access is required for conflict detection"
        @unknown default:
            print("   ❓ Unknown calendar permission status")
            isCalendarAccessGranted = false
        }
    }
    
    // MARK: - Public Methods for F3.3 Features
    
    /// Get pending proposals for a group
    func getPendingProposals(for groupId: UUID) -> [ScheduleChangeProposal] {
        print("📋 Getting pending proposals for group: \(groupId)")
        return activeProposals.filter { $0.groupId == groupId && $0.status == .pending }
    }
    
    /// Get upcoming trips for a group
    func getUpcomingTrips(for groupId: UUID, limit: Int = 10) -> [ScheduledTrip] {
        print("🚗 Getting upcoming trips for group: \(groupId)")
        // Return mock trips for demo
        return mockUpcomingTrips.prefix(limit).map { $0 }
    }
    
    /// Get backup drivers for a group
    func getBackupDrivers(for groupId: UUID) -> [BackupDriverAssignment] {
        print("👥 Getting backup drivers for group: \(groupId)")
        // Return all mock backup drivers for demo (filtering by groupId would require adding groupId to struct)
        return mockBackupDrivers
    }
    
    /// Load schedule data for a group
    func loadScheduleData(for groupId: UUID) async {
        print("📊 Loading schedule data for group: \(groupId)")
        // Simulate loading data
        try? await Task.sleep(nanoseconds: 500_000_000)
        setupMockData()
    }
    
    /// Enable calendar integration for a group
    func enableCalendarIntegration(for groupId: UUID) async throws {
        print("📅 Enabling calendar integration for group: \(groupId)")
        // Simulate calendar integration
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isCalendarAccessGranted = true
    }
    
    /// Assign backup driver
    func assignBackupDriver(
        groupId: UUID,
        driverId: UUID,
        priority: BackupPriority,
        availableDays: [String]
    ) async throws {
        print("🚗 Assigning backup driver for group: \(groupId)")
        // Create new backup assignment
        let assignment = BackupDriverAssignment(
            id: UUID(),
            driverId: driverId,
            driverName: "Backup Driver", // TODO: Get actual driver name
            priority: priority,
            availability: .available,
            assignedDate: Date()
        )
        mockBackupDrivers.append(assignment)
    }
    
    // MARK: - Mock Data Properties
    private var mockUpcomingTrips: [ScheduledTrip] = []
    private var mockBackupDrivers: [BackupDriverAssignment] = []
    
    // MARK: - Private Methods
    
    /// Request calendar permission from user
    private func requestCalendarPermission() {
        print("🔐 Requesting calendar permission...")
        
        eventStore.requestAccess(to: .event) { [weak self] granted, error in
            Task { @MainActor in
                if granted {
                    print("✅ Calendar permission granted")
                    self?.isCalendarAccessGranted = true
                } else {
                    print("❌ Calendar permission denied")
                    self?.isCalendarAccessGranted = false
                    if let error = error {
                        print("   🔍 Error: \(error.localizedDescription)")
                        self?.lastError = "Calendar permission denied: \(error.localizedDescription)"
                    } else {
                        self?.lastError = "Calendar access is required for conflict detection"
                    }
                }
            }
        }
    }
    
    /// Detect calendar conflicts for a proposed time
    /// - Parameters:
    ///   - proposedTime: The proposed departure time
    ///   - groupId: The carpool group ID
    /// - Returns: Array of detected conflicts
    func detectCalendarConflicts(
        proposedTime: Date,
        groupId: UUID
    ) async -> [ScheduleConflict] {
        print("🔍 Detecting calendar conflicts for \(formatTime(proposedTime))")
        
        guard isCalendarAccessGranted else {
            print("   ⚠️ Calendar access not available, using mock conflict detection")
            return await detectMockConflicts(proposedTime: proposedTime, groupId: groupId)
        }
        
        var conflicts: [ScheduleConflict] = []
        
        // Create time window for conflict detection (±2 hours)
        let startDate = Calendar.current.date(byAdding: .hour, value: -2, to: proposedTime) ?? proposedTime
        let endDate = Calendar.current.date(byAdding: .hour, value: 2, to: proposedTime) ?? proposedTime
        
        // Create predicate for calendar events
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        
        // Fetch events
        let events = eventStore.events(matching: predicate)
        
        print("   📅 Found \(events.count) calendar events in time window")
        
        // Analyze each event for conflicts
        for event in events {
            if isEventConflicting(event, with: proposedTime) {
                let conflict = ScheduleConflict(
                    conflictType: .calendarConflict,
                    severity: determineConflictSeverity(for: event),
                    description: "Calendar conflict with: \(event.title ?? "Untitled Event")",
                    affectedMembers: [UUID()], // TODO: Get actual affected members
                    suggestedResolution: "Reschedule event or adjust carpool time"
                )
                conflicts.append(conflict)
                
                print("   ⚠️ Conflict detected: \(event.title ?? "Untitled")")
                print("      🕐 Event time: \(formatTime(event.startDate)) - \(formatTime(event.endDate))")
                print("      🚨 Severity: \(conflict.severity.displayName)")
            }
        }
        
        print("   📊 Total conflicts detected: \(conflicts.count)")
        return conflicts
    }
    
    /// Check if a calendar event conflicts with proposed carpool time
    /// - Parameters:
    ///   - event: The calendar event to check
    ///   - proposedTime: The proposed carpool departure time
    /// - Returns: True if there's a conflict
    private func isEventConflicting(_ event: EKEvent, with proposedTime: Date) -> Bool {
        // Check if event overlaps with proposed time (±30 minutes)
        let bufferTime: TimeInterval = 30 * 60 // 30 minutes
        let eventStart = event.startDate.timeIntervalSince1970
        let eventEnd = event.endDate.timeIntervalSince1970
        let proposedTimeInterval = proposedTime.timeIntervalSince1970
        
        let proposedStart = proposedTimeInterval - bufferTime
        let proposedEnd = proposedTimeInterval + bufferTime
        
        // Check for overlap
        return (eventStart < proposedEnd && eventEnd > proposedStart)
    }
    
    /// Determine conflict severity based on event details
    /// - Parameter event: The conflicting calendar event
    /// - Returns: Conflict severity level
    private func determineConflictSeverity(for event: EKEvent) -> ConflictSeverity {
        // Check if event is all-day (lower severity)
        if event.isAllDay {
            return .low
        }
        
        // Check event duration (longer events = higher severity)
        let duration = event.endDate.timeIntervalSince(event.startDate)
        if duration > 4 * 60 * 60 { // 4+ hours
            return .high
        } else if duration > 2 * 60 * 60 { // 2+ hours
            return .medium
        } else {
            return .low
        }
    }
    
    /// Generate alternative departure times when conflicts are detected
    /// - Parameters:
    ///   - originalTime: The originally proposed time
    ///   - conflicts: The detected conflicts
    /// - Returns: Array of alternative times
    func generateAlternativeTimes(
        originalTime: Date,
        conflicts: [ScheduleConflict]
    ) async -> [Date] {
        print("💡 Generating alternative departure times...")
        
        guard !conflicts.isEmpty else {
            print("   ✅ No conflicts, no alternatives needed")
            return []
        }
        
        var alternatives: [Date] = []
        let calendar = Calendar.current
        
        // Generate times ±15, ±30, ±45, ±60 minutes from original
        let timeOffsets: [Int] = [-60, -45, -30, -15, 15, 30, 45, 60]
        
        for offset in timeOffsets {
            if let alternativeTime = calendar.date(byAdding: .minute, value: offset, to: originalTime) {
                // Check if this alternative time avoids conflicts
                let alternativeConflicts = await detectCalendarConflicts(
                    proposedTime: alternativeTime,
                    groupId: UUID() // TODO: Get actual group ID
                )
                
                if alternativeConflicts.isEmpty {
                    alternatives.append(alternativeTime)
                    print("   ⏰ Alternative \(offset > 0 ? "+" : "")\(offset)min: \(formatTime(alternativeTime))")
                }
            }
        }
        
        print("   📋 Generated \(alternatives.count) conflict-free alternatives")
        return alternatives
    }
    
    /// Handle proposal resolution (approved/rejected/expired)
    /// - Parameter proposal: The resolved proposal
    private func handleProposalResolution(_ proposal: ScheduleChangeProposal) {
        print("📋 Handling proposal resolution: \(proposal.id.uuidString.prefix(8))")
        print("   📊 Final status: \(proposal.status.displayName)")
        print("   🗳️ Approval rate: \(String(format: "%.1f", proposal.approvalPercentage))%")
        
        // Remove from pending approvals
        pendingApprovals.removeAll { $0.id == proposal.id }
        
        // Add to recent changes
        recentChanges.insert(proposal, at: 0)
        
        // Keep only last 10 recent changes
        if recentChanges.count > 10 {
            recentChanges = Array(recentChanges.prefix(10))
        }
        
        // Post notification for real-time updates
        NotificationCenter.default.post(
            name: .scheduleProposalResolved,
            object: proposal
        )
        
        // TODO: Send push notifications to group members
        // TODO: Update group schedule if approved
        // TODO: Notify backup drivers if needed
    }
    
    /// Start timer to check for expired proposals
    private func startProposalExpiryTimer() {
        print("⏰ Starting proposal expiry timer...")
        
        Timer.publish(every: 300, on: .main, in: .common) // Check every 5 minutes
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkProposalExpiry()
            }
            .store(in: &cancellables)
    }
    
    /// Check for expired proposals and update their status
    private func checkProposalExpiry() {
        print("⏰ Checking for expired proposals...")
        
        var expiredCount = 0
        
        for i in 0..<activeProposals.count {
            if activeProposals[i].isExpired && activeProposals[i].status == .pending {
                activeProposals[i].status = .expired
                expiredCount += 1
                
                print("   ⏰ Proposal expired: \(activeProposals[i].id.uuidString.prefix(8))")
            }
        }
        
        if expiredCount > 0 {
            print("   📊 \(expiredCount) proposals marked as expired")
            
            // Remove expired proposals from pending approvals
            pendingApprovals.removeAll { $0.status == .expired }
            
            // Post notification for real-time updates
            NotificationCenter.default.post(
                name: .scheduleProposalsExpired,
                object: expiredCount
            )
        }
    }
    
    // MARK: - Mock Data Methods (for testing when calendar not available)
    
    /// Setup mock data for testing
    private func setupMockData() {
        print("🧪 Setting up mock schedule coordination data...")
        
        let mockProposal1 = ScheduleChangeProposal(
            groupId: UUID(),
            proposedBy: UUID(),
            proposerName: "Sarah Chen",
            currentDepartureTime: Date(),
            proposedDepartureTime: Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date(),
            reason: "Doctor appointment for child",
            priority: .high,
            votesRequired: 3
        )
        
        let mockProposal2 = ScheduleChangeProposal(
            groupId: UUID(),
            proposedBy: UUID(),
            proposerName: "Mike Johnson",
            currentDepartureTime: Date(),
            proposedDepartureTime: Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date(),
            reason: "Earlier school start time",
            priority: .normal,
            votesRequired: 3
        )
        
        mockProposals = [mockProposal1, mockProposal2]
        activeProposals = mockProposals
        pendingApprovals = mockProposals
        
        print("   ✅ Mock data setup complete: \(mockProposals.count) proposals")
    }
    
    /// Detect mock conflicts for testing
    /// - Parameters:
    ///   - proposedTime: The proposed time
    ///   - groupId: The group ID
    /// - Returns: Mock conflicts
    private func detectMockConflicts(
        proposedTime: Date,
        groupId: UUID
    ) async -> [ScheduleConflict] {
        print("🧪 Detecting mock conflicts for testing...")
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Randomly generate some conflicts for testing
        let randomConflicts = Int.random(in: 0...2)
        var conflicts: [ScheduleConflict] = []
        
        for i in 0..<randomConflicts {
            let conflictTypes: [ConflictType] = [.calendarConflict, .driverUnavailable, .weatherConflict]
            let conflictType = conflictTypes.randomElement() ?? .other
            
            let conflict = ScheduleConflict(
                conflictType: conflictType,
                severity: ConflictSeverity.allCases.randomElement() ?? .low,
                description: "Mock conflict \(i + 1) for testing",
                affectedMembers: [UUID()],
                suggestedResolution: "Mock resolution suggestion"
            )
            conflicts.append(conflict)
        }
        
        print("   🧪 Generated \(conflicts.count) mock conflicts")
        return conflicts
    }
    
    // MARK: - Helper Methods
    
    /// Format time for logging
    /// - Parameter date: The date to format
    /// - Returns: Formatted time string
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let newScheduleProposal = Notification.Name("newScheduleProposal")
    static let scheduleProposalVoteUpdated = Notification.Name("scheduleProposalVoteUpdated")
    static let scheduleProposalResolved = Notification.Name("scheduleProposalResolved")
    static let scheduleProposalCancelled = Notification.Name("scheduleProposalCancelled")
    static let scheduleProposalsExpired = Notification.Name("scheduleProposalsExpired")
}
