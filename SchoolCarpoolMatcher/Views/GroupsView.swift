//
//  GroupsView.swift
//  SchoolCarpoolMatcher
//
//  Groups management interface with active groups, chat previews, and multi-modal transport
//  Follows Apple Design Guidelines for iOS native feel and accessibility
//  Applied Rule: iOS native patterns with comprehensive accessibility support
//

import SwiftUI
import CoreLocation
import MapKit

// MARK: - Groups View
/// Groups management interface showing active carpool groups and multi-modal transport options
/// Implements F4.2 requirements: group management interface and F2.3: multi-modal transport
struct GroupsView: View {
    
    // MARK: - Properties
    @StateObject private var groupsViewModel = GroupsViewModel()
    @StateObject private var groupFormationService = GroupFormationService()
    
    // Removed multi-modal transport state - moved to Route tab
    
    // Group management state
    @State private var showingCreateGroup = false
    @State private var showingGroupSettings = false
    @State private var selectedGroup: CarpoolGroupDisplay?
    @State private var showingGroupChat = false
    @State private var showingRouteMap = false
    @State private var showingInviteMembers = false
    
    // F3 Real-Time Coordination features
    @State private var showingLocationSharing = false
    @State private var showingScheduleCoordination = false
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            List {
                // Header
                groupsHeader
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                
                // Active Groups
                if !groupsViewModel.activeGroups.isEmpty {
                    ForEach(groupsViewModel.activeGroups) { group in
                        GroupCard(
                            group: group,
                            onChatTap: {
                                selectedGroup = group
                                showingGroupChat = true
                            },
                            onRouteTap: {
                                selectedGroup = group
                                showingRouteMap = true
                            },
                            onLocationTap: {
                                selectedGroup = group
                                showingLocationSharing = true
                            },
                            onScheduleTap: {
                                selectedGroup = group
                                showingScheduleCoordination = true
                            },
                            onSettingsTap: {
                                selectedGroup = group
                                showingGroupSettings = true
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    noGroupsPlaceholder
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                
                // Multi-modal transport moved to Route tab
            }
            .listStyle(.plain)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Active Groups")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(false)
            .navigationBarItems(
                leading: Button("Safety Center", systemImage: "shield.checkered") {
                    // Navigate to safety center
                    print("🛡️ Navigate to Safety Center")
                }
                .foregroundColor(.green)
                .accessibilityLabel("Safety Center"),
                
                trailing: Menu {
                    Button("Create New Group", systemImage: "plus.circle") {
                        showingCreateGroup = true
                    }
                    
                    Button("Invite Friends", systemImage: "person.badge.plus") {
                        showingInviteMembers = true
                    }
                    
                    Button("Group Settings", systemImage: "gearshape") {
                        showingGroupSettings = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                }
                .accessibilityLabel("Group Actions")
            )
            .refreshable {
                await groupsViewModel.loadGroups()
            }
        }
        .onAppear {
            Task {
                await groupsViewModel.loadGroups()
            }
        }
        // Transport details sheet moved to Route tab
        .sheet(isPresented: $showingCreateGroup) {
            CreateGroupSheet(groupFormationService: groupFormationService) { newGroup in
                // Handle successful group creation
                Task {
                    await groupsViewModel.loadGroups()
                }
            }
        }
        .sheet(isPresented: $showingGroupChat) {
            if let group = selectedGroup {
                GroupChatView(group: convertToFullGroup(group))
            }
        }
        .sheet(isPresented: $showingRouteMap) {
            if selectedGroup != nil {
                // Create a mock MKRoute for demo purposes
                let mockRoute = MKRoute()
                
                // Create mock risk factors
                let mockRiskFactors = RiskFactors(
                    schoolZoneRiskReduction: 0.2,
                    roadTypeRiskScore: 0.1,
                    trafficLightRiskReduction: 0.15,
                    accidentRiskIncrease: 0.05
                )
                
                // Create mock recommendations
                let mockRecommendations = [
                    RiskRecommendation(
                        priority: .medium,
                        title: "School Zone Route",
                        description: "Follow designated school routes for enhanced safety",
                        actionRequired: false
                    ),
                    RiskRecommendation(
                        priority: .low,
                        title: "Safe Following Distance",
                        description: "Maintain safe following distance during carpool",
                        actionRequired: false
                    )
                ]
                
                // Create a mock RouteRiskAnalysis for demo purposes
                let mockAnalysis = RouteRiskAnalysis(
                    route: mockRoute,
                    overallRiskScore: 0.3,
                    riskFactors: mockRiskFactors,
                    isAcceptableRisk: true,
                    recommendations: mockRecommendations,
                    lastAnalyzed: Date()
                )
                RouteMapView(analysis: mockAnalysis)
            }
        }
        .sheet(isPresented: $showingGroupSettings) {
            GroupSettingsSheet()
        }
        .sheet(isPresented: $showingInviteMembers) {
            InviteMembersSheet()
        }
        .sheet(isPresented: $showingLocationSharing) {
            if let group = selectedGroup {
                LocationSharingView(group: convertToFullGroup(group))
            }
        }
        .sheet(isPresented: $showingScheduleCoordination) {
            if let group = selectedGroup {
                ScheduleCoordinationView(group: convertToFullGroup(group))
            }
        }
    }
    
    // MARK: - Groups Header
    // Applied Rule: Apple Design Guidelines - clear hierarchy and messaging
    private var groupsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !groupsViewModel.activeGroups.isEmpty {
                Text("Active Groups")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.primary)
                
                Text("\(groupsViewModel.activeGroups.count) active • \(groupsViewModel.activeGroups.reduce(0) { $0 + $1.members.count }) families")
                    .font(.title3)
                    .foregroundColor(.secondary)
            } else {
                Text("My Active Groups")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.primary)
                
                Text("Create or join groups to get started")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - No Groups Placeholder
    private var noGroupsPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.sequence")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Active Groups")
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)
            
            Text("Start matching with families to create your first carpool group")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Find Families") {
                // TODO: Navigate to matching screen
                print("🔍 Navigate to matching screen")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
    // Multi-Modal Transport Section moved to Route tab
    
    // MARK: - Methods
    // Transport-related methods moved to Route tab
    
    // MARK: - Helper Methods
    
    /// Convert CarpoolGroupDisplay to full CarpoolGroup for services that need complete data
    private func convertToFullGroup(_ displayGroup: CarpoolGroupDisplay) -> CarpoolGroup {
        // Create a mock route for the group
        let mockRoute = Route(
            groupId: displayGroup.id,
            pickupPoints: [],
            safetyScore: displayGroup.safetyScore
        )
        
        // Convert display members to full group members
        let fullMembers = displayGroup.members.map { displayMember in
            GroupMember(
                familyId: displayMember.id, // Using same ID for demo
                role: .passenger,
                contributionScore: 0.8
            )
        }
        
        return CarpoolGroup(
            id: displayGroup.id,
            groupName: displayGroup.groupName,
            adminId: displayGroup.members.first?.id ?? UUID(),
            members: fullMembers,
            schoolName: "Demo School",
            schoolAddress: "Demo Address",
            scheduledDepartureTime: Date(),
            pickupSequence: [],
            optimizedRoute: mockRoute,
            safetyScore: displayGroup.safetyScore
        )
    }
}

// MARK: - Group Card Component
struct GroupCard: View {
    let group: CarpoolGroupDisplay
    let onChatTap: () -> Void
    let onRouteTap: () -> Void
    let onLocationTap: () -> Void
    let onScheduleTap: () -> Void
    let onSettingsTap: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text(group.status.displayName)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(group.status.badgeText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(group.status.badgeColor)
                    .clipShape(Capsule())
            }
            
            // Stats
            HStack {
                Text("\(Int(group.estimatedTotalTime / 60)) min")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(String(format: "%.1f", group.safetyScore))/10")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            // Members
            HStack(spacing: 15) {
                // Member Avatars
                HStack(spacing: -8) {
                    ForEach(group.members.prefix(4), id: \.id) { member in
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 32, height: 32)
                            .overlay {
                                Text(member.name.prefix(1))
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.white)
                            }
                            .overlay {
                                Circle()
                                    .stroke(Color(.systemBackground), lineWidth: 2)
                            }
                    }
                }
                
                // Member Names
                Text(group.memberNames.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
            }
            
            // Chat Preview
            if let lastMessage = group.lastMessage {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(lastMessage.senderName): \(lastMessage.content)")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(lastMessage.timestamp.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Action Buttons - F3 Real-Time Coordination Features
            VStack(spacing: 8) {
                // Primary actions row
                HStack(spacing: 8) {
                    Button("💬 Chat") {
                        onChatTap()
                        print("💬 F3.1: Open chat for \(group.groupName)")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.regular)
                    
                    Button("📍 Location") {
                        onLocationTap()
                        print("📍 F3.2: Live location sharing for \(group.groupName)")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .foregroundColor(.blue)
                    
                    Button("📅 Schedule") {
                        onScheduleTap()
                        print("📅 F3.3: Schedule coordination for \(group.groupName)")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .foregroundColor(.purple)
                }
                
                // Secondary actions row
                HStack(spacing: 8) {
                    Button("🗺️ Route") {
                        onRouteTap()
                        print("🗺️ View route for \(group.groupName)")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Button("⚙️ Settings") {
                        onSettingsTap()
                        print("⚙️ Group settings for \(group.groupName)")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Groups View Model
class GroupsViewModel: ObservableObject {
    @Published var activeGroups: [CarpoolGroupDisplay] = []
    
    func loadGroups() async {
        // Load demo groups for demonstration - only showing active groups per user request
        // Applied Rule: Apple Design Guidelines - clean, focused interface
        await MainActor.run {
            // Create demo groups with realistic Canberra data - only active groups
            self.activeGroups = [
                CarpoolGroupDisplay(
                    id: UUID(),
                    groupName: "Red Hill Primary Squad",
                    status: .active,
                    estimatedTotalTime: 1800, // 30 minutes
                    safetyScore: 9.2,
                    members: [
                        GroupMemberDisplay(id: UUID(), name: "Sarah Chen"),
                        GroupMemberDisplay(id: UUID(), name: "Mike Johnson"),
                        GroupMemberDisplay(id: UUID(), name: "Lisa Wong")
                    ],
                    lastMessage: GroupMessagePreview(
                        senderName: "Sarah",
                        content: "Running 5 minutes late today, sorry!",
                        timestamp: Date().addingTimeInterval(-300)
                    )
                ),
                CarpoolGroupDisplay(
                    id: UUID(),
                    groupName: "Forrest Primary Crew",
                    status: .active, // Changed from .forming to .active
                    estimatedTotalTime: 1200, // 20 minutes
                    safetyScore: 8.8,
                    members: [
                        GroupMemberDisplay(id: UUID(), name: "David Smith"),
                        GroupMemberDisplay(id: UUID(), name: "Emma Taylor"),
                        GroupMemberDisplay(id: UUID(), name: "Rachel Brown") // Added third member to make it active
                    ],
                    lastMessage: GroupMessagePreview(
                        senderName: "David",
                        content: "Great carpool today everyone! See you tomorrow.",
                        timestamp: Date().addingTimeInterval(-1800) // 30 minutes ago
                    )
                )
            ]
            
            print("✅ Loaded \(self.activeGroups.count) active demo groups")
        }
    }
}

// MARK: - Data Models
struct CarpoolGroupDisplay: Identifiable {
    let id: UUID
    let groupName: String
    let status: GroupStatus
    let estimatedTotalTime: TimeInterval
    let safetyScore: Double
    let members: [GroupMemberDisplay]
    let lastMessage: GroupMessagePreview?
    
    var memberNames: [String] {
        members.map { $0.name }
    }
}

struct GroupMemberDisplay: Identifiable {
    let id: UUID
    let name: String
}

struct GroupMessagePreview {
    let senderName: String
    let content: String
    let timestamp: Date
}

// Extension to add UI-specific properties to existing GroupStatus
extension GroupStatus {
    var badgeText: String {
        switch self {
        case .active: return "Live"
        case .forming: return "Forming"
        case .paused: return "Paused"
        case .archived: return "Archived"
        }
    }
    
    var badgeColor: Color {
        switch self {
        case .active: return .green
        case .forming: return .orange
        case .paused: return .gray
        case .archived: return .secondary
        }
    }
}

// MARK: - Create Group Sheet
struct CreateGroupSheet: View {
    let groupFormationService: GroupFormationService
    let onGroupCreated: (CarpoolGroup) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var groupName = ""
    @State private var schoolName = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.3.sequence.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Create New Group")
                        .font(.title2.weight(.bold))
                    
                    Text("Start a carpool group with families in your area")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Form
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Group Name")
                            .font(.headline)
                        
                        TextField("Enter group name", text: $groupName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("School")
                            .font(.headline)
                        
                        TextField("Enter school name", text: $schoolName)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Spacer()
                
                // Create Button
                Button(action: createGroup) {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        Text(isCreating ? "Creating..." : "Create Group")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(groupName.isEmpty || schoolName.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(groupName.isEmpty || schoolName.isEmpty || isCreating)
            }
            .padding()
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createGroup() {
        isCreating = true
        
        Task {
            // Mock group creation for demo
            let mockCurrentUser = MockData.families.first!
            let result = await groupFormationService.createCarpoolGroup(
                matches: [],
                currentUser: mockCurrentUser,
                customName: groupName
            )
            
            await MainActor.run {
                isCreating = false
                
                switch result {
                case .success(let group):
                    onGroupCreated(group)
                    dismiss()
                case .failure(let error):
                    print("❌ Failed to create group: \(error)")
                }
            }
        }
    }
}

// MARK: - Group Settings Sheet
struct GroupSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Group Settings")
                    .font(.title2.weight(.bold))
                
                Text("Group settings and management options will be available here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Invite Members Sheet
struct InviteMembersSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Invite Members")
                    .font(.title2.weight(.bold))
                
                Text("Invite friends and family to join your carpool groups")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Invite")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Transport Option Detail Sheet moved to Route tab

// MARK: - Preview
#Preview {
    GroupsView()
}