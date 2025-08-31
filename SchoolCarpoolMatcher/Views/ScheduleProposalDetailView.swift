//
//  ScheduleProposalDetailView.swift
//  SchoolCarpoolMatcher
//
//  Detailed view for schedule change proposals with voting functionality
//  Implements F3.3 requirements: proposal details, conflict analysis, voting
//  Follows Apple Design Tips: Safety-first messaging, parent-focused design, iOS native feel
//

import SwiftUI

// MARK: - Schedule Proposal Detail View
/// Detailed interface for viewing and voting on schedule change proposals
/// Prioritizes child safety with comprehensive conflict analysis and clear voting options
struct ScheduleProposalDetailView: View {
    // MARK: - Environment & State
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var scheduleService: ScheduleCoordinationService
    let proposal: ScheduleChangeProposal
    
    @State private var showingVoteSheet = false
    @State private var selectedVote: VoteType = .approve
    @State private var voteComment = ""
    @State private var isSubmittingVote = false
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header Card
                    headerCard
                    
                    // Schedule Change Details
                    scheduleChangeCard
                    
                    // Conflict Analysis
                    if !proposal.detectedConflicts.isEmpty {
                        conflictAnalysisCard
                    }
                    
                    // Alternative Times
                    if !proposal.suggestedAlternatives.isEmpty {
                        alternativesCard
                    }
                    
                    // Voting Progress
                    votingProgressCard
                    
                    // Vote History
                    if !proposal.currentVotes.isEmpty {
                        voteHistoryCard
                    }
                    
                    // Action Buttons
                    actionButtonsCard
                }
                .padding()
            }
            .navigationTitle("Proposal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingVoteSheet) {
                VoteSheetView(
                    proposal: proposal,
                    selectedVote: $selectedVote,
                    voteComment: $voteComment,
                    isSubmitting: $isSubmittingVote,
                    onSubmit: submitVote
                )
            }
        }
    }
    
    // MARK: - Header Card
    /// Shows proposal priority, status, and basic information
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Priority and Status
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: proposal.priority.icon)
                        .foregroundColor(Color(proposal.priority.color))
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(proposal.priority.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(proposal.priority.color))
                        
                        Text("Priority Level")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(proposal.status.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                    
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Urgent Action Required
            if proposal.requiresImmediateAction {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Immediate Action Required")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                        
                        Text("This proposal requires urgent attention due to high priority or critical conflicts.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Expiry Information
            if proposal.status == .pending {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Expires \(formatTimeRemaining(proposal.timeUntilExpiry))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                        
                        Text("Proposal expires on \(formatDate(proposal.expiresAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Schedule Change Card
    /// Shows the current vs proposed schedule change
    private var scheduleChangeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Schedule Change")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                // Current Schedule
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Departure")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text(formatTime(proposal.currentDepartureTime))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.blue)
                        .font(.title2)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Proposed Departure")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Text(formatTime(proposal.proposedDepartureTime))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
                
                // Time Difference
                HStack {
                    Spacer()
                    
                    Text("Change: \(timeDifferenceText)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(.blue)
                    
                    Spacer()
                }
            }
            
            // Reason
            if !proposal.reason.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reason for Change")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(proposal.reason)
                        .font(.body)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Conflict Analysis Card
    /// Shows detected conflicts and their severity
    private var conflictAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                Text("Conflicts Detected")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(proposal.detectedConflicts.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 12) {
                ForEach(proposal.detectedConflicts) { conflict in
                    DetailedConflictRow(conflict: conflict)
                }
            }
            
            // Overall Conflict Severity
            HStack {
                Text("Overall Severity:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(proposal.conflictSeverity.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(conflictSeverityColor.opacity(0.1))
                    .cornerRadius(8)
                    .foregroundColor(conflictSeverityColor)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Alternatives Card
    /// Shows suggested alternative times
    private var alternativesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("Suggested Alternatives")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(proposal.suggestedAlternatives.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                ForEach(proposal.suggestedAlternatives, id: \.self) { alternative in
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatTime(alternative))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Conflict-free alternative")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("+\(formatTimeDifference(from: proposal.currentDepartureTime, to: alternative))")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Voting Progress Card
    /// Shows current voting progress and approval status
    private var votingProgressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Voting Progress")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Progress Bar
                VStack(spacing: 8) {
                    ProgressView(value: proposal.approvalPercentage, total: 100)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    
                    HStack {
                        Text("\(Int(proposal.approvalPercentage))% approved")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text("\(proposal.currentVotes.count)/\(proposal.votesRequired) votes")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Vote Breakdown
                HStack(spacing: 20) {
                    VoteStatView(
                        icon: "checkmark.circle.fill",
                        color: .green,
                        count: proposal.currentVotes.filter { $0.vote == .approve }.count,
                        label: "Approve"
                    )
                    
                    VoteStatView(
                        icon: "xmark.circle.fill",
                        color: .red,
                        count: proposal.currentVotes.filter { $0.vote == .reject }.count,
                        label: "Reject"
                    )
                    
                    VoteStatView(
                        icon: "minus.circle.fill",
                        color: .gray,
                        count: proposal.currentVotes.filter { $0.vote == .abstain }.count,
                        label: "Abstain"
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Vote History Card
    /// Shows detailed voting history
    private var voteHistoryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Vote History")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(proposal.currentVotes) { vote in
                    HStack {
                        Image(systemName: vote.vote.icon)
                            .foregroundColor(voteColor(for: vote.vote))
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("User \(vote.userId.uuidString.prefix(8))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if let comment = vote.comment {
                                Text(comment)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(vote.vote.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(voteColor(for: vote.vote))
                            
                            Text(formatTimeAgo(vote.timestamp))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Action Buttons Card
    /// Shows action buttons for the proposal
    private var actionButtonsCard: some View {
        VStack(spacing: 12) {
            if proposal.status == .pending {
                Button {
                    showingVoteSheet = true
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Vote on Proposal")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .disabled(proposal.isExpired)
            }
            
            if proposal.status == .pending && proposal.requiresImmediateAction {
                Button {
                    // TODO: Implement urgent action
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Take Urgent Action")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
            
            if proposal.status == .pending {
                Button {
                    // TODO: Implement proposal cancellation
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Cancel Proposal")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Helper Methods
    
    /// Submit a vote on the proposal
    private func submitVote() {
        print("🗳️ Submitting vote: \(selectedVote.displayName)")
        isSubmittingVote = true
        
        // Submit vote to service
        scheduleService.voteOnProposal(
            proposalId: proposal.id,
            userId: UUID(), // TODO: Get actual user ID
            vote: selectedVote,
            comment: voteComment.isEmpty ? nil : voteComment
        )
        
        isSubmittingVote = false
        showingVoteSheet = false
        
        // Reset form
        selectedVote = .approve
        voteComment = ""
    }
    
    /// Get color for proposal status
    private var statusColor: Color {
        switch proposal.status {
        case .approved: return .green
        case .rejected: return .red
        case .expired: return .orange
        case .cancelled: return .gray
        default: return .blue
        }
    }
    
    /// Get color for conflict severity
    private var conflictSeverityColor: Color {
        switch proposal.conflictSeverity {
        case .none: return .green
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    /// Get color for vote type
    private func voteColor(for vote: VoteType) -> Color {
        switch vote {
        case .approve: return .green
        case .reject: return .red
        case .abstain: return .gray
        }
    }
    
    /// Format time for display
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Format date for display
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Format time remaining until expiry
    private func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Calculate time difference text
    private var timeDifferenceText: String {
        let difference = proposal.proposedDepartureTime.timeIntervalSince(proposal.currentDepartureTime)
        let hours = Int(difference) / 3600
        let minutes = Int(difference) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(abs(minutes))m"
        } else {
            return "\(abs(minutes))m"
        }
    }
    
    /// Format time difference between two dates
    private func formatTimeDifference(from: Date, to: Date) -> String {
        let difference = to.timeIntervalSince(from)
        let hours = Int(difference) / 3600
        let minutes = Int(difference) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(abs(minutes))m"
        } else {
            return "\(abs(minutes))m"
        }
    }
    
    /// Format relative time ago
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Detailed Conflict Row
/// Detailed view of a single conflict
struct DetailedConflictRow: View {
    let conflict: ScheduleConflict
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: conflict.conflictType.icon)
                    .foregroundColor(severityColor)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(conflict.conflictType.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
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
            
            if !conflict.affectedMembers.isEmpty {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text("Affects \(conflict.affectedMembers.count) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(severityColor.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
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

// MARK: - Vote Stat View
/// Shows individual vote statistics
struct VoteStatView: View {
    let icon: String
    let color: Color
    let count: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Vote Sheet View
/// Sheet for submitting votes on proposals
struct VoteSheetView: View {
    let proposal: ScheduleChangeProposal
    @Binding var selectedVote: VoteType
    @Binding var voteComment: String
    @Binding var isSubmitting: Bool
    let onSubmit: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Your Vote") {
                    Picker("Vote", selection: $selectedVote) {
                        ForEach(VoteType.allCases, id: \.self) { vote in
                            HStack {
                                Image(systemName: vote.icon)
                                    .foregroundColor(voteColor(for: vote))
                                Text(vote.displayName)
                            }
                            .tag(vote)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Comment (Optional)") {
                    TextField("Add a comment about your vote...", text: $voteComment, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                
                Section("Proposal Summary") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Current Time:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatTime(proposal.currentDepartureTime))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Proposed Time:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatTime(proposal.proposedDepartureTime))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                        
                        if !proposal.reason.isEmpty {
                            HStack {
                                Text("Reason:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(proposal.reason)
                                    .font(.subheadline)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Submit Vote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        onSubmit()
                    }
                    .disabled(isSubmitting)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func voteColor(for vote: VoteType) -> Color {
        switch vote {
        case .approve: return .green
        case .reject: return .red
        case .abstain: return .gray
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview
struct ScheduleProposalDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let mockProposal = ScheduleChangeProposal(
            groupId: UUID(),
            proposedBy: UUID(),
            proposerName: "Sarah Chen",
            currentDepartureTime: Date(),
            proposedDepartureTime: Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date(),
            reason: "Doctor appointment for child",
            priority: .high,
            votesRequired: 3
        )
        
        ScheduleProposalDetailView(
            scheduleService: ScheduleCoordinationService(),
            proposal: mockProposal
        )
    }
}
