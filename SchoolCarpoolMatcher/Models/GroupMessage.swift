//
//  GroupMessage.swift
//  SchoolCarpoolMatcher
//
//  F3.1 In-Group Messaging System models
//  Implements real-time chat with typing indicators and message persistence
//  Follows repo rule: Safety-first design with comprehensive comments and debug logging
//

import Foundation
import CoreLocation

// MARK: - Group Message Model
/// Core data model for group messaging functionality
/// Supports text, location sharing, schedule updates, and media attachments
/// Implements F3.1 requirements: real-time chat, typing indicators, read receipts
struct GroupMessage: Identifiable, Codable {
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case id, groupId, senderId, senderName, content, messageType, timestamp
        case isEdited, editedAt, replyToMessageId, readReceipts, priority
        case mediaUrls, locationLatitude, locationLongitude, sharedSchedule
    }
    // MARK: - Primary Identifiers
    let id: UUID
    let groupId: UUID
    let senderId: UUID
    let senderName: String
    
    // MARK: - Message Content
    let content: String
    let messageType: MessageType
    let timestamp: Date
    let isEdited: Bool
    let editedAt: Date?
    let replyToMessageId: UUID?
    
    // MARK: - Engagement Tracking
    let readReceipts: [ReadReceipt]
    let priority: MessagePriority
    
    // MARK: - Rich Content (Optional)
    let mediaUrls: [String]?
    let locationLatitude: Double?
    let locationLongitude: Double?
    let sharedSchedule: ScheduleShare?
    
    // MARK: - Computed Properties for Location
    var locationCoordinate: CLLocationCoordinate2D? {
        guard let lat = locationLatitude, let lon = locationLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    // MARK: - Computed Properties
    var isFromCurrentUser: Bool {
        // In a real app, would compare with current user ID
        // For demo, using a simple check
        return senderId.uuidString.hasPrefix("current")
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: timestamp)
    }
    
    var hasBeenRead: Bool {
        !readReceipts.isEmpty
    }
    
    var canBeEdited: Bool {
        let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)
        return timestamp > fiveMinutesAgo && !isEdited && isFromCurrentUser
    }
    
    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        groupId: UUID,
        senderId: UUID,
        senderName: String,
        content: String,
        messageType: MessageType = .text,
        priority: MessagePriority = .normal,
        replyToMessageId: UUID? = nil,
        mediaUrls: [String]? = nil,
        locationCoordinate: CLLocationCoordinate2D? = nil,
        sharedSchedule: ScheduleShare? = nil
    ) {
        self.id = id
        self.groupId = groupId
        self.senderId = senderId
        self.senderName = senderName
        self.content = content
        self.messageType = messageType
        self.timestamp = Date()
        self.isEdited = false
        self.editedAt = nil
        self.replyToMessageId = replyToMessageId
        self.readReceipts = []
        self.priority = priority
        self.mediaUrls = mediaUrls
        self.locationLatitude = locationCoordinate?.latitude
        self.locationLongitude = locationCoordinate?.longitude
        self.sharedSchedule = sharedSchedule
        
        // Debug logging for message creation
        print("💬 Created message from \(senderName): \(messageType.rawValue)")
        if let coordinate = locationCoordinate {
            print("   📍 Location shared: \(coordinate.latitude), \(coordinate.longitude)")
        }
        if let schedule = sharedSchedule {
            print("   📅 Schedule shared: \(schedule.departureTime)")
        }
    }
}

// MARK: - Read Receipt Model
/// Tracks when group members have read messages
struct ReadReceipt: Codable {
    let userId: UUID
    let userName: String
    let readAt: Date
    
    init(userId: UUID, userName: String) {
        self.userId = userId
        self.userName = userName
        self.readAt = Date()
        
        print("👀 Read receipt created for \(userName)")
    }
}

// MARK: - Schedule Share Model
/// Model for sharing schedule updates within group messages
struct ScheduleShare: Codable {
    let departureTime: Date
    let pickupLocation: String
    let estimatedArrival: Date
    let driverName: String
    let message: String?
    let scheduleId: UUID
    
    init(
        departureTime: Date,
        pickupLocation: String,
        estimatedArrival: Date,
        driverName: String,
        message: String? = nil
    ) {
        self.departureTime = departureTime
        self.pickupLocation = pickupLocation
        self.estimatedArrival = estimatedArrival
        self.driverName = driverName
        self.message = message
        self.scheduleId = UUID()
        
        print("📅 Schedule share created by \(driverName) for \(departureTime)")
    }
    
    var formattedDepartureTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: departureTime)
    }
    
    var formattedArrivalTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: estimatedArrival)
    }
}

// MARK: - Message Type Enum
/// Defines different types of messages supported in group chat
enum MessageType: String, CaseIterable, Codable {
    case text = "text"
    case location = "location"
    case schedule = "schedule"
    case announcement = "announcement"
    case emergency = "emergency"
    case media = "media"
    case systemGenerated = "system"
    
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .location: return "Location"
        case .schedule: return "Schedule"
        case .announcement: return "Announcement"
        case .emergency: return "Emergency"
        case .media: return "Media"
        case .systemGenerated: return "System"
        }
    }
    
    var icon: String {
        switch self {
        case .text: return "message"
        case .location: return "location"
        case .schedule: return "calendar"
        case .announcement: return "megaphone"
        case .emergency: return "exclamationmark.triangle"
        case .media: return "photo"
        case .systemGenerated: return "gear"
        }
    }
    
    var priority: MessagePriority {
        switch self {
        case .emergency: return .urgent
        case .announcement, .schedule: return .high
        case .location: return .normal
        case .text, .media: return .normal
        case .systemGenerated: return .low
        }
    }
}

// MARK: - Message Priority Enum
/// Defines message priority levels for notifications and display
enum MessagePriority: String, CaseIterable, Codable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
    
    var notificationSound: String {
        switch self {
        case .urgent: return "emergency_alert"
        case .high: return "high_priority"
        case .normal: return "default"
        case .low: return "subtle"
        }
    }
    
    var badgeColor: String {
        switch self {
        case .urgent: return "red"
        case .high: return "orange"
        case .normal: return "blue"
        case .low: return "gray"
        }
    }
}

// MARK: - Typing Indicator Model
/// Model for showing when users are typing in group chat
struct TypingIndicator: Identifiable {
    let id: UUID
    let groupId: UUID
    let userId: UUID
    let userName: String
    let startedAt: Date
    let expiresAt: Date
    
    init(groupId: UUID, userId: UUID, userName: String) {
        self.id = UUID()
        self.groupId = groupId
        self.userId = userId
        self.userName = userName
        self.startedAt = Date()
        self.expiresAt = Date().addingTimeInterval(5) // 5 seconds timeout
        
        print("⌨️ \(userName) started typing in group \(groupId)")
    }
    
    var isExpired: Bool {
        Date() > expiresAt
    }
}

// MARK: - Message Delivery Status
/// Tracks delivery and read status for messages
struct MessageDelivery: Codable {
    let messageId: UUID
    let recipientId: UUID
    let recipientName: String
    let status: DeliveryStatus
    let deliveredAt: Date?
    let readAt: Date?
    
    init(messageId: UUID, recipientId: UUID, recipientName: String) {
        self.messageId = messageId
        self.recipientId = recipientId
        self.recipientName = recipientName
        self.status = .pending
        self.deliveredAt = nil
        self.readAt = nil
        
        print("📨 Message delivery tracking created for \(recipientName)")
    }
    
    mutating func markAsDelivered() {
        // In a real app, this would be handled by the message service
        print("✅ Message delivered to \(recipientName)")
    }
    
    mutating func markAsRead() {
        // In a real app, this would be handled by the message service
        print("👀 Message read by \(recipientName)")
    }
}

// MARK: - Delivery Status Enum
/// Defines message delivery states
enum DeliveryStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case delivered = "delivered"
    case read = "read"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .pending: return "Sending"
        case .delivered: return "Delivered"
        case .read: return "Read"
        case .failed: return "Failed"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .delivered: return "checkmark"
        case .read: return "checkmark.circle"
        case .failed: return "exclamationmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "orange"
        case .delivered: return "blue"
        case .read: return "green"
        case .failed: return "red"
        }
    }
}

// MARK: - Message Thread Model
/// Groups related messages together (for replies and conversations)
struct MessageThread: Identifiable {
    let id: UUID
    let parentMessageId: UUID
    let replies: [GroupMessage]
    let createdAt: Date
    let lastActivity: Date
    
    init(parentMessage: GroupMessage) {
        self.id = UUID()
        self.parentMessageId = parentMessage.id
        self.replies = []
        self.createdAt = Date()
        self.lastActivity = Date()
        
        print("🧵 Message thread created for message: \(parentMessage.content.prefix(50))")
    }
    
    var replyCount: Int {
        replies.count
    }
    
    var hasNewReplies: Bool {
        // Check if there are unread replies (simplified for demo)
        let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)
        return replies.contains { $0.timestamp > fiveMinutesAgo }
    }
}

// MARK: - Message Search Model
/// Model for searching through message history
struct MessageSearch {
    let query: String
    let groupId: UUID?
    let messageType: MessageType?
    let senderId: UUID?
    let dateRange: DateInterval?
    let includeSystemMessages: Bool
    
    init(
        query: String,
        groupId: UUID? = nil,
        messageType: MessageType? = nil,
        senderId: UUID? = nil,
        dateRange: DateInterval? = nil,
        includeSystemMessages: Bool = true
    ) {
        self.query = query
        self.groupId = groupId
        self.messageType = messageType
        self.senderId = senderId
        self.dateRange = dateRange
        self.includeSystemMessages = includeSystemMessages
        
        print("🔍 Message search created: '\(query)'")
        if let group = groupId {
            print("   📊 Scoped to group: \(group)")
        }
        if let type = messageType {
            print("   📝 Message type filter: \(type.rawValue)")
        }
    }
}

// MARK: - Message Statistics
/// Analytics for group messaging activity
struct MessageStatistics {
    let groupId: UUID
    let totalMessages: Int
    let messagesThisWeek: Int
    let mostActiveUser: String?
    let averageResponseTime: TimeInterval
    let messageTypeBreakdown: [MessageType: Int]
    let lastCalculated: Date
    
    init(groupId: UUID, messages: [GroupMessage]) {
        self.groupId = groupId
        self.totalMessages = messages.count
        
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        self.messagesThisWeek = messages.filter { $0.timestamp > weekAgo }.count
        
        // Calculate most active user
        let userMessageCounts = Dictionary(grouping: messages, by: { $0.senderId })
            .mapValues { $0.count }
        let mostActiveUserId = userMessageCounts.max(by: { $0.value < $1.value })?.key
        self.mostActiveUser = mostActiveUserId != nil ? 
            messages.first { $0.senderId == mostActiveUserId }?.senderName : nil
        
        // Calculate average response time (simplified)
        self.averageResponseTime = 15 * 60 // 15 minutes default
        
        // Message type breakdown
        self.messageTypeBreakdown = Dictionary(grouping: messages, by: { $0.messageType })
            .mapValues { $0.count }
        
        self.lastCalculated = Date()
        
        print("📊 Message statistics calculated for group \(groupId)")
        print("   📈 Total messages: \(totalMessages)")
        print("   📅 This week: \(messagesThisWeek)")
        print("   👤 Most active: \(mostActiveUser ?? "None")")
    }
}
