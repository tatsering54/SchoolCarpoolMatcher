//
//  ScheduleCoordinationView.swift
//  SchoolCarpoolMatcher
//
//  F3.3 Schedule Coordination Tools implementation
//  Schedule change proposals, availability conflicts, calendar integration, and backup driver assignments
//  Applied Rule: Apple Design Guidelines with comprehensive accessibility and debug logging
//

import SwiftUI
import EventKit

// MARK: - Supporting Enums
enum TripStatus: String, CaseIterable, Codable {
    case scheduled = "scheduled"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
    case delayed = "delayed"
    
    var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .delayed: return "Delayed"
        }
    }
    
    var color: Color {
        switch self {
        case .scheduled: return .blue
        case .inProgress: return .green
        case .completed: return .gray
        case .cancelled: return .red
        case .delayed: return .orange
        }
    }
}

// MARK: - Schedule Coordination View
/// Schedule coordination interface for carpool group management
/// Implements F3.3 requirements: schedule proposals, conflict detection, calendar integration, backup assignments
struct ScheduleCoordinationView: View {
    
    // MARK: - Properties
    let group: CarpoolGroup
    @StateObject private var scheduleCoordinator = ScheduleCoordinationService.shared
    @State private var showingNewProposal = false
    @State private var showingCalendarIntegration = false
    @State private var showingBackupDrivers = false
    @State private var selectedProposal: ScheduleChangeProposal?
    @State private var showingProposalDetails = false
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Computed Properties
    private var pendingProposals: [ScheduleChangeProposal] {
        scheduleCoordinator.getPendingProposals(for: group.id)
    }
    
    private var upcomingSchedule: [ScheduledTrip] {
        scheduleCoordinator.getUpcomingTrips(for: group.id, limit: 7)
    }
    
    private var backupDrivers: [BackupDriverAssignment] {
        scheduleCoordinator.getBackupDrivers(for: group.id)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Current Schedule Card
                    currentScheduleCard
                    
                    // Pending Proposals
                    if !pendingProposals.isEmpty {
                        pendingProposalsSection
                    }
                    
                    // Upcoming Schedule
                    upcomingScheduleSection
                    
                    // Backup Drivers
                    backupDriversSection
                    
                    // Calendar Integration
                    calendarIntegrationCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Schedule Coordination")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New Proposal", systemImage: "plus.circle") {
                        showingNewProposal = true
                    }
                    .foregroundColor(.blue)
                }
            }
            .sheet(isPresented: $showingNewProposal) {
                NewScheduleProposalView(scheduleService: scheduleCoordinator)
            }
            .sheet(isPresented: $showingCalendarIntegration) {
                calendarIntegrationView
            }
            .sheet(isPresented: $showingBackupDrivers) {
                backupDriverManagementView
            }
            .sheet(isPresented: $showingProposalDetails) {
                if let proposal = selectedProposal {
                    ScheduleProposalDetailView(scheduleService: scheduleCoordinator, proposal: proposal)
                }
            }
            .onAppear {
                loadScheduleData()
                print("📅 ScheduleCoordinationView appeared for group: \(group.groupName)")
            }
        }
        .accessibilityLabel("Schedule coordination for \(group.groupName)")
    }
    
    // MARK: - Current Schedule Card
    private var currentScheduleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Schedule")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text("Daily departure at \(group.scheduledDepartureTime.formatted(.dateTime.hour().minute()))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Edit") {
                    showingNewProposal = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // Schedule details grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ScheduleDetailCard(
                    icon: "clock.fill",
                    title: "Departure",
                    value: group.scheduledDepartureTime.formatted(.dateTime.hour().minute()),
                    color: .blue
                )
                
                ScheduleDetailCard(
                    icon: "car.fill",
                    title: "Current Driver",
                    value: getCurrentDriverName(),
                    color: .green
                )
                
                ScheduleDetailCard(
                    icon: "timer",
                    title: "Total Time",
                    value: "\(Int(group.estimatedTotalTime / 60))min",
                    color: .orange
                )
                
                ScheduleDetailCard(
                    icon: "shield.checkered",
                    title: "Safety Score",
                    value: String(format: "%.1f/10", group.safetyScore),
                    color: .green
                )
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Pending Proposals Section
    private var pendingProposalsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Pending Proposals")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(pendingProposals.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
            
            ForEach(pendingProposals) { proposal in
                ProposalCard(
                    proposal: proposal,
                    onTap: {
                        selectedProposal = proposal
                        showingProposalDetails = true
                    },
                    onVote: { approve in
                        voteOnProposal(proposal, approve: approve)
                    }
                )
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Upcoming Schedule Section
    private var upcomingScheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Upcoming Trips")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            ForEach(upcomingSchedule) { trip in
                UpcomingTripCard(trip: trip)
            }
            
            if upcomingSchedule.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text("No upcoming trips scheduled")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Backup Drivers Section
    private var backupDriversSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Backup Drivers")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Manage") {
                    showingBackupDrivers = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            if !backupDrivers.isEmpty {
                ForEach(backupDrivers) { assignment in
                    BackupDriverRow(assignment: assignment)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text("No backup drivers assigned")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Add Backup Drivers") {
                        showingBackupDrivers = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Calendar Integration Card
    private var calendarIntegrationCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calendar Integration")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text("Sync carpool schedule with your device calendar")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button("Setup Integration") {
                    showingCalendarIntegration = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                
                Button("Detect Conflicts") {
                    detectCalendarConflicts()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Calendar Integration View
    private var calendarIntegrationView: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.purple)
                    
                    Text("Calendar Integration")
                        .font(.title2.weight(.bold))
                    
                    Text("Automatically sync carpool events with your device calendar and detect conflicts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Integration options
                VStack(spacing: 16) {
                    CalendarIntegrationOption(
                        icon: "calendar.badge.plus",
                        title: "Auto-Add Events",
                        description: "Automatically add carpool trips to your calendar",
                        isEnabled: true
                    )
                    
                    CalendarIntegrationOption(
                        icon: "exclamationmark.triangle",
                        title: "Conflict Detection",
                        description: "Check for scheduling conflicts with existing events",
                        isEnabled: true
                    )
                    
                    CalendarIntegrationOption(
                        icon: "bell",
                        title: "Reminder Notifications",
                        description: "Get notified 15 minutes before pickup time",
                        isEnabled: false
                    )
                    
                    CalendarIntegrationOption(
                        icon: "arrow.clockwise",
                        title: "Sync Changes",
                        description: "Update calendar when schedule changes occur",
                        isEnabled: true
                    )
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("Enable Integration") {
                        enableCalendarIntegration()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Cancel") {
                        showingCalendarIntegration = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding()
            .navigationTitle("Calendar Setup")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Backup Driver Management View
    private var backupDriverManagementView: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Available members
                VStack(alignment: .leading, spacing: 16) {
                    Text("Available Members")
                        .font(.headline.weight(.semibold))
                    
                    ForEach(getAvailableBackupDrivers()) { member in
                        BackupDriverCandidateRow(
                            member: member,
                            onAssign: {
                                assignBackupDriver(member)
                            }
                        )
                    }
                }
                
                Spacer()
                
                Button("Done") {
                    showingBackupDrivers = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .navigationTitle("Backup Drivers")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadScheduleData() {
        Task {
            await scheduleCoordinator.loadScheduleData(for: group.id)
        }
    }
    
    private func getCurrentDriverName() -> String {
        // Mock implementation - in real app would look up current driver
        return "Sarah Chen"
    }
    
    private func voteOnProposal(_ proposal: ScheduleChangeProposal, approve: Bool) {
        print("📅 Voting on proposal \(proposal.id): \(approve ? "Approve" : "Reject")")
        
        Task {
            do {
                try await scheduleCoordinator.voteOnProposal(
                    proposalId: proposal.id,
                    userId: UUID(), // Mock current user ID
                    vote: approve ? .approve : .reject,
                    comment: nil
                )
                
                await MainActor.run {
                    print("✅ Vote submitted successfully")
                }
            } catch {
                print("❌ Failed to submit vote: \(error)")
            }
        }
    }
    
    private func detectCalendarConflicts() {
        print("📅 Detecting calendar conflicts for group: \(group.groupName)")
        
        Task {
            let conflicts = await scheduleCoordinator.detectCalendarConflicts(
                proposedTime: Date().addingTimeInterval(24 * 3600), // Tomorrow
                groupId: group.id
            )
            
            await MainActor.run {
                print("📅 Found \(conflicts.count) potential conflicts")
                // In real app, would show conflicts in UI
            }
        }
    }
    
    private func enableCalendarIntegration() {
        print("📅 Enabling calendar integration for group: \(group.groupName)")
        
        Task {
            do {
                try await scheduleCoordinator.enableCalendarIntegration(for: group.id)
                
                await MainActor.run {
                    showingCalendarIntegration = false
                    print("✅ Calendar integration enabled")
                }
            } catch {
                print("❌ Failed to enable calendar integration: \(error)")
            }
        }
    }
    
    private func getAvailableBackupDrivers() -> [GroupMemberDetail] {
        // Mock implementation - return members who can be backup drivers
        return [
            GroupMemberDetail(
                id: UUID(),
                name: "Mike Johnson",
                role: .driver,
                availability: .available,
                lastActive: Date().addingTimeInterval(-3600)
            ),
            GroupMemberDetail(
                id: UUID(),
                name: "Lisa Wong",
                role: .passenger,
                availability: .available,
                lastActive: Date().addingTimeInterval(-1800)
            )
        ]
    }
    
    private func assignBackupDriver(_ member: GroupMemberDetail) {
        print("📅 Assigning backup driver: \(member.name)")
        
        Task {
            do {
                try await scheduleCoordinator.assignBackupDriver(
                    groupId: group.id,
                    driverId: member.id,
                    priority: .secondary,
                    availableDays: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
                )
                
                await MainActor.run {
                    print("✅ Backup driver assigned successfully")
                }
            } catch {
                print("❌ Failed to assign backup driver: \(error)")
            }
        }
    }
}

// MARK: - Schedule Detail Card
struct ScheduleDetailCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Proposal Card
struct ProposalCard: View {
    let proposal: ScheduleChangeProposal
    let onTap: () -> Void
    let onVote: (Bool) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Schedule Change Proposal")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Text("Proposed by \(proposal.proposerName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(proposal.status.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(proposal.status.color)
                    .clipShape(Capsule())
            }
            
            Text(proposal.reason)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            HStack {
                Text("New time: \(proposal.proposedDepartureTime.formatted(.dateTime.hour().minute()))")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("\(proposal.currentVotes.count)/\(proposal.votesRequired) votes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Voting buttons
            if proposal.status == .pending {
                HStack(spacing: 12) {
                    Button("Approve") {
                        onVote(true)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.green)
                    
                    Button("Reject") {
                        onVote(false)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                    
                    Spacer()
                    
                    Button("Details") {
                        onTap()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Upcoming Trip Card
struct UpcomingTripCard: View {
    let trip: ScheduledTrip
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(trip.scheduledDate.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                
                Text(trip.scheduledDate.formatted(.dateTime.day()))
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)
            }
            .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.scheduledDate.formatted(.dateTime.hour().minute()))
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Text("Driver: \(trip.driverName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(trip.status.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundColor(trip.status.color)
                
                Text("\(Int(trip.estimatedTotalTime / 60))min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Backup Driver Row
struct BackupDriverRow: View {
    let assignment: BackupDriverAssignment
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 32, height: 32)
                .overlay {
                    Text(assignment.driverName.prefix(1))
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.driverName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Text("Priority: \(assignment.priority.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(assignment.availability.displayName)
                .font(.caption.weight(.medium))
                .foregroundColor(assignment.availability.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(assignment.availability.color.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Calendar Integration Option
struct CalendarIntegrationOption: View {
    let icon: String
    let title: String
    let description: String
    @State var isEnabled: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.purple)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Backup Driver Candidate Row
struct BackupDriverCandidateRow: View {
    let member: GroupMemberDetail
    let onAssign: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 32, height: 32)
                .overlay {
                    Text(member.name.prefix(1))
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Text("Role: \(member.role.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Assign") {
                onAssign()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Data Models
struct GroupMemberDetail: Identifiable {
    let id: UUID
    let name: String
    let role: MemberRole
    let availability: MemberAvailability
    let lastActive: Date
}

struct BackupDriverAssignment: Identifiable {
    let id: UUID
    let driverId: UUID
    let driverName: String
    let priority: BackupPriority
    let availability: MemberAvailability
    let assignedDate: Date
}

struct ScheduledTrip: Identifiable {
    let id: UUID
    let scheduledDate: Date
    let driverId: UUID
    let driverName: String
    let status: TripStatus
    let estimatedTotalTime: TimeInterval
}

enum MemberAvailability: String, CaseIterable {
    case available = "available"
    case busy = "busy"
    case unavailable = "unavailable"
    
    var displayName: String {
        switch self {
        case .available: return "Available"
        case .busy: return "Busy"
        case .unavailable: return "Unavailable"
        }
    }
    
    var color: Color {
        switch self {
        case .available: return .green
        case .busy: return .orange
        case .unavailable: return .red
        }
    }
}

enum BackupPriority: String, CaseIterable {
    case primary = "primary"
    case secondary = "secondary"
    case emergency = "emergency"
    
    var displayName: String {
        switch self {
        case .primary: return "Primary"
        case .secondary: return "Secondary"
        case .emergency: return "Emergency"
        }
    }
}

// MARK: - Preview
#Preview {
    let sampleGroup = CarpoolGroup(
        id: UUID(),
        groupName: "Forrest Primary Squad",
        adminId: UUID(),
        members: [],
        schoolName: "Forrest Primary School",
        schoolAddress: "6 Vasey Crescent, Forrest ACT 2603",
        scheduledDepartureTime: Date(),
        pickupSequence: [],
        optimizedRoute: Route(groupId: UUID(), pickupPoints: [], safetyScore: 9.2),
        safetyScore: 9.2
    )
    
    ScheduleCoordinationView(group: sampleGroup)
}