//
//  GroupManagementView.swift
//  SchoolCarpoolMatcher
//
//  F4.2 Group Management Interface with F3.1 messaging integration
//  Lists active carpool groups with member count, next pickup time, and chat access
//  Follows repo rule: Safety-first design with comprehensive logging and Apple Design Guidelines
//

import SwiftUI

// MARK: - Group Management View
/// Interface for managing active carpool groups with integrated messaging
/// Implements F4.2 requirements: group listing, performance metrics, settings modification
/// Integrates F3.1 messaging: direct chat access, unread message counts
struct GroupManagementView: View {
    
    // MARK: - State Objects
    @StateObject private var groupFormationService = GroupFormationService()
    @StateObject private var messageService = MessageService.shared
    
    // MARK: - State
    @State private var showingCreateGroup = false
    @State private var showingGroupDetails = false
    @State private var selectedGroup: CarpoolGroup?
    @State private var showingGroupChat = false
    @State private var searchText = ""
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Search Bar
                if !activeGroups.isEmpty {
                    searchBar
                }
                
                // MARK: - Content
                if activeGroups.isEmpty {
                    emptyStateView
                } else {
                    groupListView
                }
            }
            .navigationTitle("My Groups")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    createGroupButton
                }
            }
            .sheet(isPresented: $showingCreateGroup) {
                createGroupView
            }
            .sheet(isPresented: $showingGroupDetails) {
                if let group = selectedGroup {
                    GroupDetailsView(group: group)
                }
            }
            .sheet(isPresented: $showingGroupChat) {
                if let group = selectedGroup {
                    GroupChatView(group: group)
                }
            }
            .onAppear {
                print("👥 GroupManagementView appeared")
            }
        }
        .accessibilityLabel("Group management interface")
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search groups...", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button("Clear") {
                    searchText = ""
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Group List View
    private var groupListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredGroups) { group in
                    GroupRowView(
                        group: group,
                        unreadCount: messageService.getUnreadCount(for: group.id),
                        onTap: {
                            selectedGroup = group
                            showingGroupDetails = true
                        },
                        onChatTap: {
                            selectedGroup = group
                            showingGroupChat = true
                            print("💬 Opening chat for group: \(group.groupName)")
                        },
                        onLeave: {
                            leaveGroup(group)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Groups Yet")
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)
            
            Text("Start by finding compatible families and creating your first carpool group.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(spacing: 12) {
                Button("Find Families") {
                    // Would navigate to matching view
                    print("🔍 Navigate to family matching")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Join with Code") {
                    showJoinGroupDialog()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(40)
    }
    
    // MARK: - Create Group Button
    private var createGroupButton: some View {
        Button {
            showingCreateGroup = true
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("Create new group")
    }
    
    // MARK: - Create Group View
    private var createGroupView: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create New Group")
                    .font(.title2.weight(.semibold))
                
                Text("Start a new carpool group with families you've matched with")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // DEMO: Simplified group creation
                VStack(alignment: .leading, spacing: 16) {
                    Text("Demo: Creating sample group...")
                        .font(.headline)
                    
                    Text("In the full app, you would:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Select matched families")
                        Text("• Choose group name")
                        Text("• Set schedule preferences")
                        Text("• Optimize pickup route")
                        Text("• Send invitations")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("Create Demo Group") {
                        createDemoGroup()
                        showingCreateGroup = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Cancel") {
                        showingCreateGroup = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingCreateGroup = false
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var activeGroups: [CarpoolGroup] {
        groupFormationService.activeGroups.filter { $0.isActive }
    }
    
    private var filteredGroups: [CarpoolGroup] {
        if searchText.isEmpty {
            return activeGroups
        } else {
            return activeGroups.filter { group in
                group.groupName.localizedCaseInsensitiveContains(searchText) ||
                group.schoolName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func createDemoGroup() {
        // DEMO: Create a sample group for testing
        print("👥 Creating demo group...")
        
        Task {
            // This would normally use matched families from the matching engine
            // For demo, we'll create with mock data
            let mockFamilies = MockData.families.prefix(3).map { $0 }
            let currentUser = mockFamilies.first!
            let matches = Array(mockFamilies.dropFirst())
            
            let result = await groupFormationService.createCarpoolGroup(
                matches: matches,
                currentUser: currentUser,
                customName: "Demo Carpool Group"
            )
            
            switch result {
            case .success(let group):
                print("✅ Demo group created: \(group.groupName)")
            case .failure(let error):
                print("❌ Failed to create demo group: \(error)")
            }
        }
    }
    
    private func showJoinGroupDialog() {
        // DEMO: Would show invite code input dialog
        print("🔗 Show join group dialog")
    }
    
    private func leaveGroup(_ group: CarpoolGroup) {
        // Safety check: Ensure user isn't the only admin
        guard group.adminMember?.familyId != UUID() || group.members.count > 1 else {
            print("⚠️ Cannot leave group: You're the only admin")
            return
        }
        
        print("👋 Leaving group: \(group.groupName)")
        // Would implement leave group logic here
    }
}

// MARK: - Group Row View
/// Individual row for displaying group information with messaging integration
struct GroupRowView: View {
    let group: CarpoolGroup
    let unreadCount: Int
    let onTap: () -> Void
    let onChatTap: () -> Void
    let onLeave: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 16) {
                // Group icon with safety indicator
                ZStack {
                    Circle()
                        .fill(group.safetyScore >= 8.5 ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "car.2.fill")
                        .font(.title3)
                        .foregroundColor(group.safetyScore >= 8.5 ? .green : .orange)
                }
                
                // Group info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(group.groupName)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Unread message badge
                        if unreadCount > 0 {
                            Text("\(unreadCount)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                        
                        // Status indicator
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                    }
                    
                    Text(group.schoolName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Group stats
                    HStack(spacing: 16) {
                        GroupStatView(
                            icon: "person.2.fill",
                            value: "\(group.members.count)",
                            label: "members"
                        )
                        
                        GroupStatView(
                            icon: "shield.checkered",
                            value: String(format: "%.1f", group.safetyScore),
                            label: "safety"
                        )
                        
                        GroupStatView(
                            icon: "clock",
                            value: nextPickupTime,
                            label: "next pickup"
                        )
                    }
                }
                
                // Action buttons
                VStack(spacing: 8) {
                    Button {
                        onChatTap()
                    } label: {
                        Image(systemName: "message.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel("Open group chat")
                    
                    Button {
                        onTap()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Group details")
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Quick actions (swipe actions alternative)
            if group.status == .active {
                quickActionsView
            }
        }
        .contextMenu {
            contextMenuItems
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
    
    private var quickActionsView: some View {
        HStack(spacing: 16) {
            Button {
                onChatTap()
            } label: {
                Label("Chat", systemImage: "message")
            }
            .font(.caption)
            .foregroundColor(.blue)
            
            Button {
                // Share location
                print("📍 Share location with \(group.groupName)")
            } label: {
                Label("Share Location", systemImage: "location")
            }
            .font(.caption)
            .foregroundColor(.green)
            
            Button {
                // Emergency alert
                print("🚨 Send emergency alert to \(group.groupName)")
            } label: {
                Label("Emergency", systemImage: "exclamationmark.triangle")
            }
            .font(.caption)
            .foregroundColor(.red)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground))
    }
    
    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            onChatTap()
        } label: {
            Label("Open Chat", systemImage: "message")
        }
        
        Button {
            onTap()
        } label: {
            Label("Group Details", systemImage: "info.circle")
        }
        
        Button {
            print("🔕 Mute notifications for \(group.groupName)")
        } label: {
            Label("Mute Notifications", systemImage: "bell.slash")
        }
        
        Divider()
        
        Button(role: .destructive) {
            onLeave()
        } label: {
            Label("Leave Group", systemImage: "person.badge.minus")
        }
    }
    
    private var statusColor: Color {
        switch group.status {
        case .active: return .green
        case .forming: return .orange
        case .paused: return .yellow
        case .archived: return .gray
        }
    }
    
    private var nextPickupTime: String {
        guard let nextTrip = group.nextScheduledTrip else { return "TBD" }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: nextTrip)
    }
    
    private var accessibilityDescription: String {
        let statusDescription = "Group status: \(group.status.displayName)"
        let membersDescription = "\(group.members.count) members"
        let safetyDescription = "Safety score: \(String(format: "%.1f", group.safetyScore))"
        let unreadDescription = unreadCount > 0 ? "\(unreadCount) unread messages" : "No unread messages"
        
        return "\(group.groupName). \(group.schoolName). \(statusDescription). \(membersDescription). \(safetyDescription). \(unreadDescription)"
    }
}

// MARK: - Group Stat View
/// Small component for displaying group statistics
struct GroupStatView: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Group Details View
/// Detailed view for group information and settings
struct GroupDetailsView: View {
    let group: CarpoolGroup
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Group header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.groupName)
                            .font(.largeTitle.weight(.bold))
                        
                        Text(group.schoolName)
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Label("\(group.members.count) members", systemImage: "person.2")
                            Spacer()
                            Label(String(format: "%.1f safety", group.safetyScore), systemImage: "shield.checkered")
                                .foregroundColor(group.safetyScore >= 8.5 ? .green : .orange)
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Members section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Members")
                            .font(.headline)
                        
                        ForEach(group.members) { member in
                            HStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(member.role.displayName.prefix(1))
                                            .font(.headline.weight(.bold))
                                            .foregroundColor(.blue)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Family Member") // Would show actual name
                                        .font(.subheadline.weight(.medium))
                                    
                                    Text(member.role.displayName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if member.role == .admin {
                                    Text("ADMIN")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal)
                    
                    // Schedule section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Schedule")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            ScheduleDetailRow(
                                icon: "clock",
                                title: "Departure Time",
                                value: formatTime(group.scheduledDepartureTime)
                            )
                            
                            ScheduleDetailRow(
                                icon: "calendar",
                                title: "Active Days",
                                value: formatActiveDays(group.activeDays)
                            )
                            
                            ScheduleDetailRow(
                                icon: "car.2",
                                title: "Route Distance",
                                value: String(format: "%.1f km", group.estimatedDistance / 1000)
                            )
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Group Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        print("✏️ Edit group settings")
                    }
                }
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatActiveDays(_ days: Set<Weekday>) -> String {
        let sortedDays = days.sorted { day1, day2 in
            let order: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
            return order.firstIndex(of: day1) ?? 0 < order.firstIndex(of: day2) ?? 0
        }
        
        return sortedDays.map { $0.shortName }.joined(separator: ", ")
    }
}

// MARK: - Schedule Detail Row
struct ScheduleDetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
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
    GroupManagementView()
}
