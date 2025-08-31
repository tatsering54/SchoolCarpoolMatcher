//
//  NewScheduleProposalView.swift
//  SchoolCarpoolMatcher
//
//  View for creating new schedule change proposals
//  Implements F3.3 requirements: schedule change creation with conflict detection
//  Follows Apple Design Tips: Safety-first messaging, parent-focused design, iOS native feel
//

import SwiftUI

// MARK: - New Schedule Proposal View
/// Interface for creating new schedule change proposals with conflict detection
/// Prioritizes child safety with clear conflict warnings and alternative suggestions
struct NewScheduleProposalView: View {
    // MARK: - Environment & State
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var scheduleService: ScheduleCoordinationService
    
    @State private var selectedGroup: CarpoolGroup?
    @State private var currentDepartureTime = Date()
    @State private var proposedDepartureTime = Date()
    @State private var reason = ""
    @State private var priority: ScheduleChangePriority = .normal
    @State private var isCreating = false
    @State private var showingConflictAlert = false
    @State private var detectedConflicts: [ScheduleConflict] = []
    @State private var suggestedAlternatives: [Date] = []
    
    // MARK: - Mock Groups for Testing
    private let mockGroups = MockData.sampleGroups
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                groupSelectionSection
                
                if selectedGroup != nil {
                    scheduleChangeSection
                    detailsSection
                    
                    if !detectedConflicts.isEmpty {
                        conflictDetectionSection
                        safetyWarningSection
                    }
                }
            }
            .navigationTitle("New Schedule Proposal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            await createProposal()
                        }
                    }
                    .disabled(selectedGroup == nil || reason.isEmpty || isCreating)
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: proposedDepartureTime) { _, _ in
                Task {
                    await checkConflicts()
                }
            }
            .onChange(of: selectedGroup?.id) { _, _ in
                if let group = selectedGroup {
                    Task {
                        await checkConflicts()
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    /// Group selection section
    private var groupSelectionSection: some View {
        Section("Carpool Group") {
            if let selectedGroup = selectedGroup {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedGroup.groupName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(selectedGroup.schoolName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Change") {
                        self.selectedGroup = nil
                    }
                    .font(.caption)
                }
            } else {
                ForEach(mockGroups) { group in
                    Button {
                        self.selectedGroup = group
                        self.currentDepartureTime = group.scheduledDepartureTime
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.groupName)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text(group.schoolName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    /// Schedule change details section
    private var scheduleChangeSection: some View {
        Section("Schedule Change") {
            DatePicker(
                "Current Departure Time",
                selection: $currentDepartureTime,
                displayedComponents: [.hourAndMinute]
            )
            
            DatePicker(
                "Proposed Departure Time",
                selection: $proposedDepartureTime,
                displayedComponents: [.hourAndMinute]
            )
            
            timeDifferenceView
        }
    }
    
    /// Time difference display view
    private var timeDifferenceView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time Difference")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                Text(formatTime(currentDepartureTime))
                    .strikethrough()
                    .foregroundColor(.secondary)
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.blue)
                
                Text(formatTime(proposedDepartureTime))
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(timeDifferenceText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
    
    /// Details section (reason and priority)
    private var detailsSection: some View {
        Section("Details") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Reason for Change")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("e.g., Doctor appointment, earlier school start", text: $reason, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
            }
            
            Picker("Priority", selection: $priority) {
                ForEach(ScheduleChangePriority.allCases, id: \.self) { priority in
                    HStack {
                        Image(systemName: priority.icon)
                            .foregroundColor(Color(priority.color))
                        
                        Text(priority.displayName)
                    }
                    .tag(priority)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
    
    /// Conflict detection section
    private var conflictDetectionSection: some View {
        Section("⚠️ Conflicts Detected") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(detectedConflicts) { conflict in
                    ConflictRow(conflict: conflict)
                }
                
                if !suggestedAlternatives.isEmpty {
                    suggestedAlternativesView
                }
            }
        }
    }
    
    /// Suggested alternatives view
    private var suggestedAlternativesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("💡 Suggested Alternative Times")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
            
            ForEach(suggestedAlternatives, id: \.self) { alternative in
                Button {
                    proposedDepartureTime = alternative
                    // Re-check conflicts with new time
                    Task {
                        await checkConflicts()
                    }
                } label: {
                    HStack {
                        Text(formatTime(alternative))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("Use This Time")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.vertical, 4)
            }
        }
    }
    
    /// Safety warning section
    private var safetyWarningSection: some View {
        Section {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Safety Consideration")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    
                    Text("Schedule conflicts may impact carpool reliability and child safety. Please review alternatives carefully.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Calculates and formats the time difference between current and proposed times
    private var timeDifferenceText: String {
        let difference = proposedDepartureTime.timeIntervalSince(currentDepartureTime)
        let hours = Int(difference) / 3600
        let minutes = Int(difference) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(abs(minutes))m"
        } else {
            return "\(abs(minutes))m"
        }
    }
    
    // MARK: - Methods
    
    /// Check for conflicts with the proposed time
    private func checkConflicts() async {
        guard let group = selectedGroup else { return }
        
        print("🔍 Checking conflicts for proposed time: \(formatTime(proposedDepartureTime))")
        
        // Detect conflicts
        let conflicts = await scheduleService.detectCalendarConflicts(
            proposedTime: proposedDepartureTime,
            groupId: group.id
        )
        
        // Generate alternatives if conflicts exist
        let alternatives = await scheduleService.generateAlternativeTimes(
            originalTime: proposedDepartureTime,
            conflicts: conflicts
        )
        
        // Update state on main thread
        await MainActor.run {
            detectedConflicts = conflicts
            suggestedAlternatives = alternatives
            
            if !conflicts.isEmpty {
                print("⚠️ \(conflicts.count) conflicts detected")
                print("💡 \(alternatives.count) alternatives suggested")
            }
        }
    }
    
    /// Create the schedule change proposal
    private func createProposal() async {
        guard let group = selectedGroup else { return }
        
        print("📅 Creating schedule change proposal...")
        isCreating = true
        
        let proposal = await scheduleService.proposeScheduleChange(
            groupId: group.id,
            currentDepartureTime: currentDepartureTime,
            proposedDepartureTime: proposedDepartureTime,
            reason: reason,
            priority: priority
        )
        
        print("✅ Proposal created successfully: \(proposal.id.uuidString.prefix(8))")
        
        // Dismiss the view
        await MainActor.run {
            dismiss()
        }
        
        isCreating = false
    }
    
    /// Format time for display
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Conflict Row
/// Individual row displaying a detected conflict
struct ConflictRow: View {
    let conflict: ScheduleConflict
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: conflict.conflictType.icon)
                    .foregroundColor(severityColor)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(conflict.conflictType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(conflict.severity.displayName)
                        .font(.caption)
                        .foregroundColor(severityColor)
                }
                
                Spacer()
                
                Text(conflict.severity.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(severityColor.opacity(0.1))
                    .cornerRadius(8)
                    .foregroundColor(severityColor)
            }
            
            Text(conflict.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let resolution = conflict.suggestedResolution {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    
                    Text(resolution)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(severityColor.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(severityColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var severityColor: Color {
        switch conflict.severity {
        case .none: return .green
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Preview
struct NewScheduleProposalView_Previews: PreviewProvider {
    static var previews: some View {
        NewScheduleProposalView(scheduleService: ScheduleCoordinationService())
    }
}
