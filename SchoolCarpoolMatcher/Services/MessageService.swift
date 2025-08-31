//
//  MessageService.swift
//  SchoolCarpoolMatcher
//
//  F3.1 In-Group Messaging Service implementation
//  Handles real-time messaging, typing indicators, and message persistence
//  Follows repo rule: ObservableObject pattern with comprehensive logging and debug comments
//

import Foundation
import Combine
import CoreLocation

// MARK: - Message Service
/// Service responsible for managing group messaging functionality
/// Implements F3.1 requirements: real-time chat, typing indicators, read receipts, message editing
/// DEMO: Uses local storage and mock real-time updates for hackathon prototype
@MainActor
class MessageService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var groupMessages: [UUID: [GroupMessage]] = [:] // GroupID -> Messages
    @Published var typingIndicators: [TypingIndicator] = []
    @Published var unreadCounts: [UUID: Int] = [:] // GroupID -> Unread count
    @Published var isConnected = true // Mock connection status
    @Published var isSendingMessage = false
    @Published var lastError: MessageError?
    
    // MARK: - Private Properties
    private var messageStorage: [UUID: [GroupMessage]] = [:]
    private var typingTimers: [UUID: Timer] = [:]
    private var cancellables = Set<AnyCancellable>()
    private let maxMessagesPerGroup = 1000 // Limit for memory management
    private let messageRetentionDays = 30
    
    // MARK: - Singleton
    static let shared = MessageService()
    
    // MARK: - Initialization
    init() {
        print("💬 MessageService initialized")
        loadPersistedMessages()
        setupTypingCleanup()
        
        // DEMO: Simulate connection status changes
        simulateConnectionChanges()
    }
    
    // MARK: - Public Methods
    
    /// Send a message to a group (F3.1 core functionality)
    func sendMessage(
        to groupId: UUID,
        content: String,
        type: MessageType = .text,
        priority: MessagePriority = .normal,
        replyToMessageId: UUID? = nil,
        mediaUrls: [String]? = nil,
        locationCoordinate: CLLocationCoordinate2D? = nil,
        scheduleShare: ScheduleShare? = nil
    ) async throws {
        
        print("📤 Sending \(type.rawValue) message to group \(groupId)")
        isSendingMessage = true
        
        // Validate input
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || type != .text else {
            throw MessageError.emptyMessage
        }
        
        guard isConnected else {
            throw MessageError.connectionError
        }
        
        do {
            // Create message with current user info (mock)
            let message = GroupMessage(
                groupId: groupId,
                senderId: getCurrentUserId(),
                senderName: getCurrentUserName(),
                content: content,
                messageType: type,
                priority: priority,
                replyToMessageId: replyToMessageId,
                mediaUrls: mediaUrls,
                locationCoordinate: locationCoordinate,
                sharedSchedule: scheduleShare
            )
            
            // Add to local storage
            if groupMessages[groupId] == nil {
                groupMessages[groupId] = []
            }
            groupMessages[groupId]?.append(message)
            
            // Sort messages by timestamp
            groupMessages[groupId]?.sort { $0.timestamp < $1.timestamp }
            
            // Persist message
            persistMessage(message)
            
            // DEMO: Simulate message delivery delay
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Stop typing indicator for current user
            stopTypingIndicator(for: groupId, userId: getCurrentUserId())
            
            // Trigger notification for other group members
            await notifyGroupMembers(message: message)
            
            print("✅ Message sent successfully: \(message.id)")
            
            // DEMO: Simulate auto-reply for testing
            if type == .text && content.lowercased().contains("hello") {
                do {
                    try await simulateAutoReply(to: groupId, originalMessage: message)
                } catch {
                    print("⚠️ Auto-reply simulation failed: \(error)")
                }
            }
            
        } catch {
            print("❌ Failed to send message: \(error)")
            lastError = error as? MessageError ?? .unknown
            throw error
        }
        
        isSendingMessage = false
    }
    
    /// Edit an existing message (F3.1 requirement: editing within 5 minutes)
    func editMessage(
        messageId: UUID,
        newContent: String,
        in groupId: UUID
    ) async throws {
        
        print("✏️ Editing message \(messageId)")
        
        guard let messages = groupMessages[groupId],
              let messageIndex = messages.firstIndex(where: { $0.id == messageId }) else {
            throw MessageError.messageNotFound
        }
        
        let message = messages[messageIndex]
        
        // Validate edit permissions
        guard message.canBeEdited else {
            throw MessageError.editTimeExpired
        }
        
        guard message.isFromCurrentUser else {
            throw MessageError.unauthorized
        }
        
        // Create edited message
        let editedMessage = GroupMessage(
            id: message.id,
            groupId: message.groupId,
            senderId: message.senderId,
            senderName: message.senderName,
            content: newContent,
            messageType: message.messageType,
            priority: message.priority,
            replyToMessageId: message.replyToMessageId,
            mediaUrls: message.mediaUrls,
            locationCoordinate: message.locationCoordinate,
            sharedSchedule: message.sharedSchedule
        )
        
        // Update in storage
        groupMessages[groupId]?[messageIndex] = editedMessage
        persistMessage(editedMessage)
        
        print("✅ Message edited successfully")
    }
    
    /// Get messages for a specific group with pagination
    func getMessages(
        for groupId: UUID,
        limit: Int = 50,
        offset: Int = 0
    ) -> [GroupMessage] {
        
        guard let messages = groupMessages[groupId] else {
            print("📭 No messages found for group \(groupId)")
            return []
        }
        
        let sortedMessages = messages.sorted { $0.timestamp < $1.timestamp }
        let startIndex = max(0, sortedMessages.count - offset - limit)
        let endIndex = min(sortedMessages.count, sortedMessages.count - offset)
        
        guard startIndex < endIndex else {
            return []
        }
        
        let paginatedMessages = Array(sortedMessages[startIndex..<endIndex])
        print("📚 Retrieved \(paginatedMessages.count) messages for group \(groupId)")
        
        return paginatedMessages
    }
    
    /// Start typing indicator (F3.1 requirement)
    func startTypingIndicator(for groupId: UUID) {
        let userId = getCurrentUserId()
        let userName = getCurrentUserName()
        
        // Remove existing typing indicator for this user
        typingIndicators.removeAll { $0.userId == userId && $0.groupId == groupId }
        
        // Add new typing indicator
        let indicator = TypingIndicator(groupId: groupId, userId: userId, userName: userName)
        typingIndicators.append(indicator)
        
        // Set timer to auto-remove
        typingTimers[userId]?.invalidate()
        typingTimers[userId] = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            Task { @MainActor in
                self.stopTypingIndicator(for: groupId, userId: userId)
            }
        }
        
        print("⌨️ Started typing indicator for \(userName)")
    }
    
    /// Stop typing indicator
    func stopTypingIndicator(for groupId: UUID, userId: UUID) {
        typingIndicators.removeAll { $0.userId == userId && $0.groupId == groupId }
        typingTimers[userId]?.invalidate()
        typingTimers[userId] = nil
        
        print("⌨️ Stopped typing indicator for user \(userId)")
    }
    
    /// Mark message as read (F3.1 requirement: read receipts)
    func markMessageAsRead(messageId: UUID, in groupId: UUID) async {
        guard let messages = groupMessages[groupId],
              let messageIndex = messages.firstIndex(where: { $0.id == messageId }) else {
            return
        }
        
        let message = messages[messageIndex]
        
        // Don't mark own messages as read
        guard !message.isFromCurrentUser else { return }
        
        // Create read receipt
        _ = ReadReceipt(userId: getCurrentUserId(), userName: getCurrentUserName())
        
        // Update message with read receipt (in real app, would update server)
        print("👀 Marked message as read: \(messageId)")
        
        // Update unread count
        if let currentCount = unreadCounts[groupId], currentCount > 0 {
            unreadCounts[groupId] = currentCount - 1
        }
    }
    
    /// Mark all messages in group as read
    func markAllMessagesAsRead(in groupId: UUID) async {
        guard let messages = groupMessages[groupId] else { return }
        
        for message in messages where !message.isFromCurrentUser {
            await markMessageAsRead(messageId: message.id, in: groupId)
        }
        
        unreadCounts[groupId] = 0
        print("✅ Marked all messages as read in group \(groupId)")
    }
    
    /// Get unread message count for a group
    func getUnreadCount(for groupId: UUID) -> Int {
        return unreadCounts[groupId] ?? 0
    }
    
    /// Search messages across groups
    func searchMessages(query: String, in groupId: UUID? = nil) -> [GroupMessage] {
        let allMessages: [GroupMessage]
        
        if let groupId = groupId {
            allMessages = groupMessages[groupId] ?? []
        } else {
            allMessages = groupMessages.values.flatMap { $0 }
        }
        
        let results = allMessages.filter { message in
            message.content.localizedCaseInsensitiveContains(query) ||
            message.senderName.localizedCaseInsensitiveContains(query)
        }
        
        print("🔍 Found \(results.count) messages matching '\(query)'")
        return results.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// Get typing users for a group
    func getTypingUsers(for groupId: UUID) -> [TypingIndicator] {
        // Remove expired indicators
        typingIndicators.removeAll { $0.isExpired }
        
        // Return active indicators for group (excluding current user)
        let activeIndicators = typingIndicators.filter { 
            $0.groupId == groupId && 
            $0.userId != getCurrentUserId() && 
            !$0.isExpired 
        }
        
        return activeIndicators
    }
    
    // MARK: - Private Methods
    
    private func getCurrentUserId() -> UUID {
        // DEMO: Return mock current user ID
        // In real app, would get from authentication service
        return UUID(uuidString: "current-user-id") ?? UUID()
    }
    
    private func getCurrentUserName() -> String {
        // DEMO: Return mock current user name
        // In real app, would get from user profile service
        return "Current User"
    }
    
    private func loadPersistedMessages() {
        // DEMO: Load mock messages for testing
        // In real app, would load from Core Data or server
        print("📁 Loading persisted messages...")
        
        // Create some sample messages for demo
        createSampleMessages()
        
        print("✅ Loaded messages for \(groupMessages.count) groups")
    }
    
    private func persistMessage(_ message: GroupMessage) {
        // DEMO: In real app, would save to Core Data or send to server
        print("💾 Persisted message: \(message.id)")
        
        // Implement message retention policy
        cleanupOldMessages()
    }
    
    private func cleanupOldMessages() {
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(messageRetentionDays * 24 * 60 * 60))
        
        for groupId in groupMessages.keys {
            let originalCount = groupMessages[groupId]?.count ?? 0
            groupMessages[groupId]?.removeAll { $0.timestamp < cutoffDate }
            let newCount = groupMessages[groupId]?.count ?? 0
            
            if originalCount != newCount {
                print("🗑️ Cleaned up \(originalCount - newCount) old messages from group \(groupId)")
            }
        }
    }
    
    private func setupTypingCleanup() {
        // Clean up expired typing indicators every 5 seconds
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                let beforeCount = self.typingIndicators.count
                self.typingIndicators.removeAll { $0.isExpired }
                let afterCount = self.typingIndicators.count
                
                if beforeCount != afterCount {
                    print("🧹 Cleaned up \(beforeCount - afterCount) expired typing indicators")
                }
            }
        }
    }
    
    private func simulateConnectionChanges() {
        // DEMO: Simulate occasional connection issues for testing
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                if Bool.random() && self.isConnected {
                    self.isConnected = false
                    print("📡 Simulated connection loss")
                    
                    // Reconnect after 2-5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 2...5)) {
                        self.isConnected = true
                        print("📡 Simulated connection restored")
                    }
                }
            }
        }
    }
    
    private func notifyGroupMembers(message: GroupMessage) async {
        // DEMO: In real app, would send push notifications
        print("🔔 Notifying group members of new \(message.messageType.rawValue) message")
        
        // Update unread counts for other group members (mock)
        if !message.isFromCurrentUser {
            let currentCount = unreadCounts[message.groupId] ?? 0
            unreadCounts[message.groupId] = currentCount + 1
        }
    }
    
    private func simulateAutoReply(to groupId: UUID, originalMessage: GroupMessage) async throws {
        // DEMO: Simulate another user responding
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
        
        let replies = [
            "Hi there! 👋",
            "Hello! How are you?",
            "Hey! Ready for school pickup?",
            "Good morning! Traffic looks clear today 🚗"
        ]
        
        do {
            try await sendMessage(
                to: groupId,
                content: replies.randomElement() ?? "Hello!",
                type: .text,
                priority: .normal,
                replyToMessageId: originalMessage.id
            )
        } catch {
            print("❌ Failed to send auto-reply: \(error)")
        }
        
        print("🤖 Auto-reply sent")
    }
    
    private func createSampleMessages() {
        // Create sample group and messages for demo
        let sampleGroupId = UUID()
        let sampleMessages: [GroupMessage] = [
            GroupMessage(
                groupId: sampleGroupId,
                senderId: UUID(),
                senderName: "Sarah Johnson",
                content: "Good morning everyone! I'll be picking up at 8:15 AM today 🚗",
                messageType: .text,
                priority: .normal
            ),
            GroupMessage(
                groupId: sampleGroupId,
                senderId: UUID(),
                senderName: "Mike Chen",
                content: "Thanks Sarah! Emma will be ready",
                messageType: .text,
                priority: .normal
            ),
            GroupMessage(
                groupId: sampleGroupId,
                senderId: getCurrentUserId(),
                senderName: getCurrentUserName(),
                content: "Perfect! See you at 8:15 👍",
                messageType: .text,
                priority: .normal
            )
        ]
        
        groupMessages[sampleGroupId] = sampleMessages
        unreadCounts[sampleGroupId] = 0
        
        print("📝 Created \(sampleMessages.count) sample messages")
    }
}

// MARK: - Message Error Types
enum MessageError: Error, LocalizedError {
    case emptyMessage
    case connectionError
    case messageNotFound
    case editTimeExpired
    case unauthorized
    case groupNotFound
    case rateLimitExceeded
    case messageTooLong
    case invalidContent
    case networkTimeout
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .emptyMessage:
            return "Message cannot be empty"
        case .connectionError:
            return "No internet connection"
        case .messageNotFound:
            return "Message not found"
        case .editTimeExpired:
            return "Message can only be edited within 5 minutes"
        case .unauthorized:
            return "You can only edit your own messages"
        case .groupNotFound:
            return "Group not found"
        case .rateLimitExceeded:
            return "Too many messages sent. Please wait."
        case .messageTooLong:
            return "Message is too long"
        case .invalidContent:
            return "Message contains invalid content"
        case .networkTimeout:
            return "Request timed out"
        case .unknown:
            return "An unknown error occurred"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .emptyMessage:
            return "Please enter a message before sending"
        case .connectionError:
            return "Check your internet connection and try again"
        case .editTimeExpired:
            return "Send a new message instead"
        case .rateLimitExceeded:
            return "Wait a few seconds before sending another message"
        case .messageTooLong:
            return "Shorten your message and try again"
        default:
            return "Please try again"
        }
    }
}

// MARK: - Message Service Extensions
extension MessageService {
    
    /// Get message statistics for analytics
    func getMessageStatistics(for groupId: UUID) -> MessageStatistics? {
        guard let messages = groupMessages[groupId] else { return nil }
        return MessageStatistics(groupId: groupId, messages: messages)
    }
    
    /// Export messages for backup or sharing
    func exportMessages(for groupId: UUID, format: ExportFormat = .json) -> Data? {
        guard let messages = groupMessages[groupId] else { return nil }
        
        switch format {
        case .json:
            do {
                return try JSONEncoder().encode(messages)
            } catch {
                print("❌ Failed to export messages as JSON: \(error)")
                return nil
            }
        case .text:
            let textContent = messages.map { message in
                "[\(message.formattedTime)] \(message.senderName): \(message.content)"
            }.joined(separator: "\n")
            
            return textContent.data(using: .utf8)
        }
    }
    
    /// Clear all messages for a group (admin function)
    func clearAllMessages(for groupId: UUID) {
        groupMessages[groupId] = []
        unreadCounts[groupId] = 0
        print("🗑️ Cleared all messages for group \(groupId)")
    }
}

// MARK: - Export Format
enum ExportFormat {
    case json
    case text
}
