import SwiftUI

struct CommunityRatingView: View {
    @ObservedObject var verificationService: VerificationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedUser: UUID = UUID()
    @State private var ratings: [UserRating.RatingCategory: Int] = [:]
    @State private var feedback = ""
    @State private var showingRatingForm = false
    @State private var errorMessage = ""
    @State private var isSuccess = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    
                    Text("Community Rating")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.primary)
                    
                    Text("Rate other families to build trust in the community")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                if !showingRatingForm {
                    // Rating Overview
                    ratingOverview
                } else {
                    // Rating Form
                    ratingForm
                }
                
                Spacer()
                
                // Action Button
                actionButton
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .navigationTitle("Community Rating")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Rating Error", isPresented: .constant(!errorMessage.isEmpty)) {
                Button("OK") {
                    errorMessage = ""
                }
            } message: {
                Text(errorMessage)
            }
            .alert("Rating Submitted", isPresented: $isSuccess) {
                Button("Continue") {
                    dismiss()
                }
            } message: {
                Text("Your rating has been submitted successfully!")
            }
        }
    }
    
    // MARK: - Rating Overview
    private var ratingOverview: some View {
        VStack(spacing: 16) {
            Text("Recent Community Activity")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Average Community Rating: 4.7/5")
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.blue)
                    Text("Total Ratings Submitted: 156")
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.green)
                    Text("Trust Score Trend: Improving")
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Rating Form
    private var ratingForm: some View {
        VStack(spacing: 16) {
            Text("Rate Family Experience")
                .font(.headline)
                .foregroundColor(.primary)
            
            ForEach(UserRating.RatingCategory.allCases, id: \.self) { category in
                RatingCategoryRow(
                    category: category,
                    rating: ratings[category] ?? 0,
                    onRatingChanged: { rating in
                        ratings[category] = rating
                    }
                )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Additional Feedback (Optional)")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                TextField("Share your experience...", text: $feedback, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
        }
    }
    
    // MARK: - Action Button
    private var actionButton: some View {
        Button(action: handleAction) {
            HStack {
                if verificationService.isVerifying {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: showingRatingForm ? "paperplane.fill" : "plus.circle.fill")
                }
                
                Text(showingRatingForm ? "Submit Rating" : "Rate Family")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.yellow)
            .foregroundColor(.black)
            .cornerRadius(12)
            .font(.headline)
        }
        .disabled(verificationService.isVerifying || 
                 (showingRatingForm && ratings.values.allSatisfy { $0 == 0 }))
        .opacity(verificationService.isVerifying || 
                 (showingRatingForm && ratings.values.allSatisfy { $0 == 0 }) ? 0.6 : 1.0)
    }
    
    // MARK: - Actions
    private func handleAction() {
        if showingRatingForm {
            submitRating()
        } else {
            showingRatingForm = true
        }
    }
    
    private func submitRating() {
        let categoryRatings = ratings.compactMap { category, rating in
            rating > 0 ? RatingSubmission.CategoryRating(category: category, rating: rating) : nil
        }
        
        let submission = RatingSubmission(
            targetUserId: selectedUser,
            ratings: categoryRatings,
            feedback: feedback.isEmpty ? nil : feedback,
            tripId: nil
        )
        
        Task {
            let success = await verificationService.submitRating(for: selectedUser.uuidString, rating: submission)
            
            await MainActor.run {
                if success {
                    isSuccess = true
                } else {
                    errorMessage = "Failed to submit rating. Please try again."
                }
            }
        }
    }
}

// MARK: - Rating Category Row
struct RatingCategoryRow: View {
    let category: UserRating.RatingCategory
    let rating: Int
    let onRatingChanged: (Int) -> Void
    
    var body: some View {
        HStack {
            Text(category.icon)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { star in
                    Button(action: {
                        onRatingChanged(star)
                    }) {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .foregroundColor(star <= rating ? .yellow : .gray)
                            .font(.title3)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
