//
//  GroupChatView.swift
//  SchoolCarpoolMatcher
//
//  F3.1 In-Group Messaging System UI implementation
//  Native iOS messaging interface with real-time chat, typing indicators, and safety-first design
//  Follows repo rule: Apple Design Guidelines with accessibility support and comprehensive logging
//

import SwiftUI
import CoreLocation

// MARK: - Group Chat View
/// Main chat interface for carpool group messaging
/// Implements F3.1 requirements: real-time chat, typing indicators, message editing, safety-first design
struct GroupChatView: View {
    
    // MARK: - Properties
    let group: CarpoolGroup
    @StateObject private var messageService = MessageService.shared
    @State private var messageText = ""
    @State private var isTyping = false
    @State private var showingLocationPicker = false
    @State private var showingScheduleShare = false
    @State private var showingMessageOptions = false
    @State private var selectedMessage: GroupMessage?
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isTextFieldFocused: Bool
    
    // MARK: - Computed Properties
    private var messages: [GroupMessage] {
        messageService.getMessages(for: group.id, limit: 100)
    }
    
    private var typingUsers: [TypingIndicator] {
        messageService.getTypingUsers(for: group.id)
    }
    
    private var unreadCount: Int {
        messageService.getUnreadCount(for: group.id)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Message List
                messageListView
                
                // MARK: - Typing Indicators
                if !typingUsers.isEmpty {
                    typingIndicatorView
                }
                
                // MARK: - Message Input
                messageInputView
            }
            .navigationTitle(group.groupName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        locationSharingButton
                        groupInfoButton
                    }
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                locationPickerView
            }
            .sheet(isPresented: $showingScheduleShare) {
                scheduleShareView
            }
            .actionSheet(isPresented: $showingMessageOptions) {
                messageOptionsActionSheet
            }
            .onAppear {
                markAllMessagesAsRead()
                print("💬 GroupChatView appeared for group: \(group.groupName)")
            }
            .onDisappear {
                stopTypingIndicator()
            }
        }
        .accessibilityLabel("Group chat for \(group.groupName)")
    }
    
    // MARK: - Message List View
    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(messages) { message in
                        MessageBubbleView(
                            message: message,
                            isFromCurrentUser: message.isFromCurrentUser,
                            onLongPress: {
                                selectedMessage = message
                                showingMessageOptions = true
                            }
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onAppear {
                scrollProxy = proxy
                scrollToBottom()
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom()
            }
        }
    }
    
    // MARK: - Typing Indicator View
    private var typingIndicatorView: some View {
        HStack(spacing: 8) {
            Image(systemName: "ellipsis")
                .foregroundColor(.secondary)
                .symbolEffect(.pulse)
            
            Text(typingIndicatorText)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Color(.systemGroupedBackground))
        .accessibilityLabel(typingIndicatorText)
    }
    
    private var typingIndicatorText: String {
        let names = typingUsers.map { $0.userName }
        switch names.count {
        case 1:
            return "\(names[0]) is typing..."
        case 2:
            return "\(names[0]) and \(names[1]) are typing..."
        default:
            return "Several people are typing..."
        }
    }
    
    // MARK: - Message Input View
    private var messageInputView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .bottom, spacing: 12) {
                // Additional options button
                Menu {
                    Button {
                        showingLocationPicker = true
                    } label: {
                        Label("Share Location", systemImage: "location")
                    }
                    
                    Button {
                        showingScheduleShare = true
                    } label: {
                        Label("Share Schedule", systemImage: "calendar")
                    }
                    
                    Button {
                        // DEMO: Emergency alert functionality would go here
                        sendEmergencyMessage()
                    } label: {
                        Label("Emergency Alert", systemImage: "exclamationmark.triangle")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Message options")
                
                // Text input field
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Message", text: $messageText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            sendMessage()
                        }
                        .onChange(of: messageText) { _, newValue in
                            handleTypingChange(newValue)
                        }
                        .accessibilityLabel("Message input field")
                    
                    // Send button
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "arrow.up.circle" : "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .blue)
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || messageService.isSendingMessage)
                    .accessibilityLabel("Send message")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Location Sharing Button
    private var locationSharingButton: some View {
        Button {
            // Navigate to location sharing view
            print("📍 Location sharing button tapped for group: \(group.groupName)")
            // For now, just show a demo alert
            // In a real app, this would navigate to LocationSharingView
        } label: {
            Image(systemName: "location.fill")
                .foregroundColor(.blue)
        }
        .accessibilityLabel("Live location sharing")
    }
    
    // MARK: - Group Info Button
    private var groupInfoButton: some View {
        Button {
            // DEMO: Would navigate to group details
            print("🔍 Group info tapped for: \(group.groupName)")
        } label: {
            Image(systemName: "info.circle")
        }
        .accessibilityLabel("Group information")
    }
    
    // MARK: - Location Picker View
    private var locationPickerView: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Share Your Location")
                    .font(.title2.weight(.semibold))
                
                Text("Let group members know where you are for pickup coordination")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // DEMO: Mock current location
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                        Text("Current Location")
                            .font(.headline)
                        Spacer()
                    }
                    
                    Text("123 Canberra Street, Forrest ACT 2603")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("Share Location") {
                        shareCurrentLocation()
                        showingLocationPicker = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Cancel") {
                        showingLocationPicker = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Share Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingLocationPicker = false
                    }
                }
            }
        }
        .accessibilityLabel("Share location with group")
    }
    
    // MARK: - Schedule Share View
    private var scheduleShareView: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Share Schedule Update")
                    .font(.title2.weight(.semibold))
                
                Text("Keep your group informed about pickup times and changes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // DEMO: Mock schedule information
                VStack(alignment: .leading, spacing: 16) {
                    ScheduleInfoRow(
                        icon: "clock",
                        title: "Departure Time",
                        value: "8:15 AM",
                        color: .blue
                    )
                    
                    ScheduleInfoRow(
                        icon: "location",
                        title: "Pickup Location",
                        value: "123 Canberra Street",
                        color: .green
                    )
                    
                    ScheduleInfoRow(
                        icon: "car",
                        title: "Driver",
                        value: "Current User",
                        color: .orange
                    )
                    
                    ScheduleInfoRow(
                        icon: "clock.arrow.circlepath",
                        title: "Estimated Arrival",
                        value: "8:45 AM",
                        color: .purple
                    )
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("Share Schedule") {
                        shareScheduleUpdate()
                        showingScheduleShare = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Cancel") {
                        showingScheduleShare = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Schedule Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingScheduleShare = false
                    }
                }
            }
        }
        .accessibilityLabel("Share schedule update with group")
    }
    
    // MARK: - Message Options Action Sheet
    private var messageOptionsActionSheet: ActionSheet {
        guard let message = selectedMessage else {
            return ActionSheet(title: Text("Message Options"))
        }
        
        var buttons: [ActionSheet.Button] = []
        
        // Reply option
        buttons.append(.default(Text("Reply")) {
            // DEMO: Reply functionality
            messageText = "Re: \(message.content.prefix(20))... "
            isTextFieldFocused = true
        })
        
        // Edit option (only for own messages within 5 minutes)
        if message.canBeEdited {
            buttons.append(.default(Text("Edit")) {
                messageText = message.content
                isTextFieldFocused = true
            })
        }
        
        // Copy option
        buttons.append(.default(Text("Copy")) {
            UIPasteboard.general.string = message.content
        })
        
        // Report option (safety-first design)
        if !message.isFromCurrentUser {
            buttons.append(.destructive(Text("Report")) {
                // DEMO: Safety reporting functionality
                print("🚨 Message reported for review: \(message.id)")
            })
        }
        
        buttons.append(.cancel())
        
        return ActionSheet(
            title: Text("Message Options"),
            message: Text("Choose an action for this message"),
            buttons: buttons
        )
    }
    
    // MARK: - Helper Methods
    
    private func sendMessage() {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        Task {
            do {
                try await messageService.sendMessage(
                    to: group.id,
                    content: content,
                    type: .text,
                    priority: .normal
                )
                
                await MainActor.run {
                    messageText = ""
                    stopTypingIndicator()
                    scrollToBottom()
                }
                
            } catch {
                print("❌ Failed to send message: \(error)")
                // DEMO: In real app, would show error alert
            }
        }
    }
    
    private func handleTypingChange(_ newValue: String) {
        if !newValue.isEmpty && !isTyping {
            isTyping = true
            messageService.startTypingIndicator(for: group.id)
        } else if newValue.isEmpty && isTyping {
            isTyping = false
            stopTypingIndicator()
        }
    }
    
    private func stopTypingIndicator() {
        if isTyping {
            isTyping = false
            messageService.stopTypingIndicator(for: group.id, userId: UUID()) // Mock user ID
        }
    }
    
    private func scrollToBottom() {
        guard let lastMessage = messages.last else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            scrollProxy?.scrollTo(lastMessage.id, anchor: UnitPoint.bottom)
        }
    }
    
    private func markAllMessagesAsRead() {
        Task {
            await messageService.markAllMessagesAsRead(in: group.id)
        }
    }
    
    private func shareCurrentLocation() {
        // DEMO: Mock location sharing
        let mockLocation = CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300) // Canberra
        
        Task {
            do {
                try await messageService.sendMessage(
                    to: group.id,
                    content: "📍 Current location shared",
                    type: .location,
                    priority: .normal,
                    locationCoordinate: mockLocation
                )
            } catch {
                print("❌ Failed to share location: \(error)")
            }
        }
    }
    
    private func shareScheduleUpdate() {
        // DEMO: Mock schedule sharing
        _ = ScheduleShare(
            departureTime: Date().addingTimeInterval(15 * 60), // 15 minutes from now
            pickupLocation: "123 Canberra Street, Forrest ACT",
            estimatedArrival: Date().addingTimeInterval(45 * 60), // 45 minutes from now
            driverName: "Current User",
            message: "Updated pickup time - see you at 8:15!"
        )
        
        Task {
            do {
                try await messageService.sendMessage(
                    to: group.id,
                    content: "📅 Schedule updated",
                    type: .schedule,
                    priority: .high
                )
            } catch {
                print("❌ Failed to share schedule: \(error)")
            }
        }
    }
    
    private func sendEmergencyMessage() {
        Task {
            do {
                try await messageService.sendMessage(
                    to: group.id,
                    content: "🚨 EMERGENCY: Need immediate assistance with pickup",
                    type: .emergency,
                    priority: .urgent
                )
            } catch {
                print("❌ Failed to send emergency message: \(error)")
            }
        }
    }
}

// MARK: - Message Bubble View
/// Individual message bubble component with native iOS styling
struct MessageBubbleView: View {
    let message: GroupMessage
    let isFromCurrentUser: Bool
    let onLongPress: () -> Void
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender name (only for other users)
                if !isFromCurrentUser {
                    Text(message.senderName)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                }
                
                // Message content
                messageContentView
                
                // Timestamp and status
                HStack(spacing: 4) {
                    Text(message.formattedTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if isFromCurrentUser {
                        messageStatusIcon
                    }
                }
                .padding(.horizontal, 12)
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
        .onLongPressGesture {
            onLongPress()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
    
    private var messageContentView: some View {
        Group {
            switch message.messageType {
            case .text:
                textMessageView
            case .location:
                locationMessageView
            case .schedule:
                scheduleMessageView
            case .emergency:
                emergencyMessageView
            default:
                textMessageView
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(messageBubbleColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var textMessageView: some View {
        Text(message.content)
            .font(.body)
            .foregroundColor(isFromCurrentUser ? .white : .primary)
            .multilineTextAlignment(.leading)
    }
    
    private var locationMessageView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(isFromCurrentUser ? .white : .blue)
                Text("Location Shared")
                    .font(.headline)
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
            }
            
            if let coordinate = message.locationCoordinate {
                Text("Lat: \(String(format: "%.4f", coordinate.latitude)), Long: \(String(format: "%.4f", coordinate.longitude))")
                    .font(.caption)
                    .foregroundColor(isFromCurrentUser ? .white.opacity(0.8) : .secondary)
            }
        }
    }
    
    private var scheduleMessageView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(isFromCurrentUser ? .white : .blue)
                Text("Schedule Update")
                    .font(.headline)
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
            }
            
            if let schedule = message.sharedSchedule {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Departure: \(schedule.formattedDepartureTime)")
                    Text("Driver: \(schedule.driverName)")
                    Text("ETA: \(schedule.formattedArrivalTime)")
                }
                .font(.caption)
                .foregroundColor(isFromCurrentUser ? .white.opacity(0.8) : .secondary)
            }
        }
    }
    
    private var emergencyMessageView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("EMERGENCY")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.red)
            }
            
            Text(message.content)
                .font(.body.weight(.medium))
                .foregroundColor(isFromCurrentUser ? .white : .primary)
        }
    }
    
    private var messageBubbleColor: Color {
        switch message.messageType {
        case .emergency:
            return Color.red.opacity(0.1)
        default:
            return isFromCurrentUser ? .blue : Color(.secondarySystemGroupedBackground)
        }
    }
    
    private var messageStatusIcon: some View {
        Image(systemName: message.hasBeenRead ? "checkmark.circle.fill" : "checkmark.circle")
            .font(.caption2)
            .foregroundColor(message.hasBeenRead ? .green : .secondary)
    }
    
    private var accessibilityDescription: String {
        let timeDescription = "sent at \(message.formattedTime)"
        let senderDescription = isFromCurrentUser ? "You" : message.senderName
        let typeDescription = message.messageType == .text ? "" : "\(message.messageType.displayName) message"
        
        return "\(typeDescription) from \(senderDescription) \(timeDescription): \(message.content)"
    }
}

// MARK: - Schedule Info Row
/// Helper component for displaying schedule information
struct ScheduleInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview
#Preview {
    let sampleGroup = CarpoolGroup(
        groupName: "Forrest Primary Squad",
        adminId: UUID(),
        members: [
            GroupMember(familyId: UUID(), role: .admin),
            GroupMember(familyId: UUID(), role: .driver),
            GroupMember(familyId: UUID(), role: .passenger)
        ],
        schoolName: "Forrest Primary School",
        schoolAddress: "6 Vasey Crescent, Forrest ACT 2603",
        scheduledDepartureTime: Date(),
        pickupSequence: [],
        optimizedRoute: Route(groupId: UUID(), pickupPoints: [])
    )
    
    GroupChatView(group: sampleGroup)
}
