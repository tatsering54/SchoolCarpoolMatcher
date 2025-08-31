//
//  ScheduleChangeProposal.swift
//  SchoolCarpoolMatcher
//
//  Data models for schedule change proposals and coordination
//  Implements F3.3 requirements: schedule changes, conflict detection, voting
//  Follows repo rule: Comprehensive comments and debug logging
//

import Foundation
import SwiftUI

// MARK: - Schedule Change Proposal Model
/// Core data model for proposing and managing schedule changes in carpool groups
/// Prioritizes child safety and parent coordination with clear conflict detection
struct ScheduleChangeProposal: Identifiable, Codable {
    // MARK: - Primary Identifiers
    let id: UUID
    let groupId: UUID
    let proposedBy: UUID
    let proposerName: String
    
    // MARK: - Schedule Change Details
    let currentDepartureTime: Date
    let proposedDepartureTime: Date
    let reason: String
    let priority: ScheduleChangePriority
    
    // MARK: - Conflict Analysis
    let detectedConflicts: [ScheduleConflict]
    let suggestedAlternatives: [Date]
    let conflictSeverity: ConflictSeverity
    
    // MARK: - Voting & Approval
    let votesRequired: Int
    var currentVotes: [ScheduleVote]
    var status: ProposalStatus
    let expiresAt: Date
    
    // MARK: - Metadata
    let createdAt: Date
    var lastUpdated: Date
    let requiresImmediateAction: Bool
    
    // MARK: - Computed Properties
    var isApproved: Bool {
        let approvedVotes = currentVotes.filter { $0.vote == .approve }.count
        return approvedVotes >= votesRequired
    }
    
    var isRejected: Bool {
        let rejectedVotes = currentVotes.filter { $0.vote == .reject }.count
        let remainingVotes = votesRequired - currentVotes.count
        return rejectedVotes > remainingVotes
    }
    
    var approvalPercentage: Double {
        guard votesRequired > 0 else { return 0.0 }
        let approvedVotes = currentVotes.filter { $0.vote == .approve }.count
        return Double(approvedVotes) / Double(votesRequired) * 100.0
    }
    
    var timeUntilExpiry: TimeInterval {
        expiresAt.timeIntervalSinceNow
    }
    
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    var hasHighPriorityConflicts: Bool {
        conflictSeverity == .high || conflictSeverity == .critical
    }
    
    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        groupId: UUID,
        proposedBy: UUID,
        proposerName: String,
        currentDepartureTime: Date,
        proposedDepartureTime: Date,
        reason: String,
        priority: ScheduleChangePriority = .normal,
        detectedConflicts: [ScheduleConflict] = [],
        suggestedAlternatives: [Date] = [],
        votesRequired: Int,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.groupId = groupId
        self.proposedBy = proposedBy
        self.proposerName = proposerName
        self.currentDepartureTime = currentDepartureTime
        self.proposedDepartureTime = proposedDepartureTime
        self.reason = reason
        self.priority = priority
        self.detectedConflicts = detectedConflicts
        self.suggestedAlternatives = suggestedAlternatives
        self.votesRequired = votesRequired
        self.currentVotes = []
        self.status = .pending
        self.expiresAt = expiresAt ?? Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date()
        self.createdAt = Date()
        self.lastUpdated = Date()
        
        // Calculate conflict severity based on detected conflicts
        self.conflictSeverity = ScheduleChangeProposal.calculateConflictSeverity(detectedConflicts)
        self.requiresImmediateAction = priority == .urgent || conflictSeverity == .critical
    }
    
    // MARK: - Helper Methods
    /// Calculate overall conflict severity based on individual conflicts
    private static func calculateConflictSeverity(_ conflicts: [ScheduleConflict]) -> ConflictSeverity {
        guard !conflicts.isEmpty else { return .none }
        
        let maxSeverity = conflicts.map { $0.severity }.max() ?? .low
        let criticalCount = conflicts.filter { $0.severity == .critical }.count
        let highCount = conflicts.filter { $0.severity == .high }.count
        
        // If any critical conflicts or multiple high conflicts, escalate severity
        if criticalCount > 0 || highCount >= 2 {
            return .critical
        } else if highCount > 0 {
            return .high
        } else {
            return maxSeverity
        }
    }
    
    /// Add a vote to the proposal
    mutating func addVote(_ vote: ScheduleVote) {
        // Remove existing vote from same user if exists
        currentVotes.removeAll { $0.userId == vote.userId }
        currentVotes.append(vote)
        lastUpdated = Date()
        
        print("📅 Schedule proposal \(id.uuidString.prefix(8)): Vote added by \(vote.userId.uuidString.prefix(8)) - \(vote.vote.rawValue)")
    }
    
    /// Update proposal status based on current votes
    mutating func updateStatus() {
        if isApproved {
            status = .approved
            print("✅ Schedule proposal \(id.uuidString.prefix(8)): Approved with \(String(format: "%.1f", approvalPercentage))% approval")
        } else if isRejected {
            status = .rejected
            print("❌ Schedule proposal \(id.uuidString.prefix(8)): Rejected")
        } else if isExpired {
            status = .expired
            print("⏰ Schedule proposal \(id.uuidString.prefix(8)): Expired")
        }
    }
}

// MARK: - Schedule Vote Model
/// Individual vote on a schedule change proposal
struct ScheduleVote: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let vote: VoteType
    let comment: String?
    let timestamp: Date
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        vote: VoteType,
        comment: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.vote = vote
        self.comment = comment
        self.timestamp = Date()
    }
}

// MARK: - Schedule Conflict Model
/// Represents a scheduling conflict detected during proposal analysis
struct ScheduleConflict: Identifiable, Codable {
    let id: UUID
    let conflictType: ConflictType
    let severity: ConflictSeverity
    let description: String
    let affectedMembers: [UUID]
    let suggestedResolution: String?
    let isResolvable: Bool
    
    init(
        id: UUID = UUID(),
        conflictType: ConflictType,
        severity: ConflictSeverity,
        description: String,
        affectedMembers: [UUID],
        suggestedResolution: String? = nil,
        isResolvable: Bool = true
    ) {
        self.id = id
        self.conflictType = conflictType
        self.severity = severity
        self.description = description
        self.affectedMembers = affectedMembers
        self.suggestedResolution = suggestedResolution
        self.isResolvable = isResolvable
    }
}

// MARK: - Enums

/// Priority levels for schedule change proposals
enum ScheduleChangePriority: String, CaseIterable, Codable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low: return "Low Priority"
        case .normal: return "Normal"
        case .high: return "High Priority"
        case .urgent: return "Urgent"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "green"
        case .normal: return "blue"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "clock.badge.checkmark"
        case .normal: return "clock"
        case .high: return "exclamationmark.triangle"
        case .urgent: return "exclamationmark.triangle.fill"
        }
    }
}

/// Status of a schedule change proposal
enum ProposalStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    case expired = "expired"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending Approval"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .expired: return "Expired"
        case .cancelled: return "Cancelled"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .approved: return "checkmark.circle"
        case .rejected: return "xmark.circle"
        case .expired: return "clock.badge.exclamationmark"
        case .cancelled: return "minus.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        case .expired: return .gray
        case .cancelled: return .secondary
        }
    }
}

/// Types of votes on proposals
enum VoteType: String, CaseIterable, Codable {
    case approve = "approve"
    case reject = "reject"
    case abstain = "abstain"
    
    var displayName: String {
        switch self {
        case .approve: return "Approve"
        case .reject: return "Reject"
        case .abstain: return "Abstain"
        }
    }
    
    var icon: String {
        switch self {
        case .approve: return "checkmark.circle"
        case .reject: return "xmark.circle"
        case .abstain: return "minus.circle"
        }
    }
}

/// Types of scheduling conflicts
enum ConflictType: String, CaseIterable, Codable {
    case calendarConflict = "calendar_conflict"
    case driverUnavailable = "driver_unavailable"
    case backupDriverConflict = "backup_driver_conflict"
    case schoolScheduleConflict = "school_schedule_conflict"
    case weatherConflict = "weather_conflict"
    case trafficConflict = "traffic_conflict"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .calendarConflict: return "Calendar Conflict"
        case .driverUnavailable: return "Driver Unavailable"
        case .backupDriverConflict: return "Backup Driver Conflict"
        case .schoolScheduleConflict: return "School Schedule Conflict"
        case .weatherConflict: return "Weather Conflict"
        case .trafficConflict: return "Traffic Conflict"
        case .other: return "Other Conflict"
        }
    }
    
    var icon: String {
        switch self {
        case .calendarConflict: return "calendar.badge.exclamationmark"
        case .driverUnavailable: return "person.crop.circle.badge.xmark"
        case .backupDriverConflict: return "person.2.circle.badge.xmark"
        case .schoolScheduleConflict: return "building.2.crop.circle.badge.exclamationmark"
        case .weatherConflict: return "cloud.rain"
        case .trafficConflict: return "car.circle.badge.exclamationmark"
        case .other: return "exclamationmark.triangle"
        }
    }
}

/// Severity levels for conflicts
enum ConflictSeverity: String, CaseIterable, Codable, Comparable {
    case none = "none"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .none: return "No Conflicts"
        case .low: return "Low Impact"
        case .medium: return "Medium Impact"
        case .high: return "High Impact"
        case .critical: return "Critical Impact"
        }
    }
    
    var color: String {
        switch self {
        case .none: return "green"
        case .low: return "blue"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
    
    var requiresImmediateAction: Bool {
        self == .high || self == .critical
    }
    
    // MARK: - Comparable Implementation
    static func < (lhs: ConflictSeverity, rhs: ConflictSeverity) -> Bool {
        let order: [ConflictSeverity] = [.none, .low, .medium, .high, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}
