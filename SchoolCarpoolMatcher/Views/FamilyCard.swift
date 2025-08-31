//
//  FamilyCard.swift
//  SchoolCarpoolMatcher
//
//  Swipeable family card component for matching interface
//  Implements F1.3 requirements: swipe gestures, animations, tap alternatives
//  Follows repo rule: iOS native design with accessibility support
//

import SwiftUI
import CoreLocation

// MARK: - Family Card View
/// Individual family card for swipe-to-match interface
/// Displays family info, compatibility score, and safety indicators
struct FamilyCard: View {
    
    // MARK: - Properties
    let family: Family
    let compatibilityScore: Double
    let onSwipe: (SwipeDirection) -> Void
    let onTap: () -> Void
    
    // MARK: - State
    @State private var dragAmount = CGSize.zero
    @State private var isShowingDetails = false
    @State private var rotationAngle: Double = 0
    @State private var cardScale: Double = 1.0
    
    // MARK: - Constants
    private let cardWidth: CGFloat = 340 // Increased from 320 for better visibility
    private let cardHeight: CGFloat = 520 // Increased from 480 for better content display
    private let swipeThreshold: CGFloat = 150 // F1.3 requirement: ±150 points
    private let maxRotation: Double = 20
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Main card content
            cardContent
                .frame(width: cardWidth, height: cardHeight)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8) // Enhanced shadow for better depth
                .scaleEffect(cardScale)
                .rotationEffect(.degrees(rotationAngle))
                .offset(dragAmount)
                .gesture(swipeGesture)
                .onTapGesture {
                    onTap()
                    print("👆 Tapped on \(family.parentName) card")
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragAmount)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: rotationAngle)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: cardScale)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Swipe right to match, left to skip, or tap for details")
    }
    
    // MARK: - Card Content
    private var cardContent: some View {
        VStack(spacing: 0) {
            // Header with compatibility score
            cardHeader
            
            // Family photo placeholder and info
            familyInfoSection
            
            // Transport details
            transportSection
            
            // Trust and safety indicators
            trustSection
            
            // Removed action buttons - users can still swipe or tap the card
        }
    }
    
    // MARK: - Header Section
    private var cardHeader: some View {
        HStack {
            // Compatibility score badge
            compatibilityBadge
            
            Spacer()
            
            // School indicator
            schoolBadge
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private var compatibilityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .foregroundColor(.pink)
                .font(.caption)
            
            Text("\(Int(compatibilityScore * 100))%")
                .font(.caption.weight(.semibold))
                .foregroundColor(.pink)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.pink.opacity(0.1))
        .clipShape(Capsule())
    }
    
    private var schoolBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "graduationcap.fill")
                .font(.caption2)
            
            Text(schoolShortName)
                .font(.caption2.weight(.medium))
        }
        .foregroundColor(.blue)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.blue.opacity(0.1))
        .clipShape(Capsule())
    }
    
    // MARK: - Family Info Section
    private var familyInfoSection: some View {
        VStack(spacing: 12) {
            // Profile photo placeholder
            Circle()
                .fill(LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 80, height: 80)
                .overlay {
                    Text(family.parentName.prefix(1))
                        .font(.title.weight(.semibold))
                        .foregroundColor(.white)
                }
            
            // Parent name and child info
            VStack(spacing: 4) {
                Text(family.parentName)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text("\(family.childName), \(family.childAge) years")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(family.suburb)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Transport Section
    private var transportSection: some View {
        VStack(spacing: 12) {
            // Departure time
            timeInfoRow
            
            // Vehicle info (if driver)
            if family.isDriverAvailable {
                vehicleInfoRow
            } else {
                passengerInfoRow
            }
            
            // Distance info
            distanceInfoRow
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
    }
    
    private var timeInfoRow: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(.orange)
                .frame(width: 20)
            
            Text("Departs")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(family.preferredDepartureTime.formatted(date: .omitted, time: .shortened))
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            Text("±\(Int(family.departureTimeWindow / 60))min")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var vehicleInfoRow: some View {
        HStack {
            Image(systemName: vehicleIcon)
                .foregroundColor(.green)
                .frame(width: 20)
            
            Text(family.vehicleType.displayName)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("\(family.availableSeats) seats")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.green)
        }
    }
    
    private var passengerInfoRow: some View {
        HStack {
            Image(systemName: "figure.walk")
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text("Looking for rides")
                .font(.subheadline)
                .foregroundColor(.blue)
            
            Spacer()
        }
    }
    
    private var distanceInfoRow: some View {
        HStack {
            Image(systemName: "location")
                .foregroundColor(.purple)
                .frame(width: 20)
            
            Text("Distance")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(distanceText)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Trust Section
    private var trustSection: some View {
        HStack(spacing: 16) {
            // Rating
            ratingIndicator
            
            // Verification status
            verificationIndicator
            
            // Background check (if available)
            if family.backgroundCheckStatus == .cleared {
                backgroundCheckIndicator
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    private var ratingIndicator: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                ForEach(0..<5) { index in
                    Image(systemName: index < Int(family.averageRating) ? "star.fill" : "star")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
            }
            
            Text("\(family.totalRatings) reviews")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var verificationIndicator: some View {
        VStack(spacing: 2) {
            Image(systemName: verificationIcon)
                .font(.caption)
                .foregroundColor(verificationColor)
            
            Text(family.verificationLevel.displayName)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var backgroundCheckIndicator: some View {
        VStack(spacing: 2) {
            Image(systemName: "checkmark.shield.fill")
                .font(.caption)
                .foregroundColor(.green)
            
            Text("Background\nCleared")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Swipe Gesture
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragAmount = value.translation
                
                // Calculate rotation based on drag (F1.3 requirement)
                let dragRatio = value.translation.width / swipeThreshold
                rotationAngle = Double(dragRatio) * maxRotation
                
                // Subtle scale effect
                cardScale = 1.0 - abs(dragRatio) * 0.05
                
                print("📱 Dragging \(family.parentName): \(Int(value.translation.width))px")
            }
            .onEnded { value in
                let dragDistance = value.translation.width
                
                if abs(dragDistance) > swipeThreshold {
                    // Swipe detected (F1.3 requirement)
                    let direction: SwipeDirection = dragDistance > 0 ? .right : .left
                    handleSwipeAction(direction)
                } else {
                    // Return to center
                    resetCardPosition()
                }
            }
    }
    
    // MARK: - Actions
    private func handleSwipeAction(_ direction: SwipeDirection) {
        print("👆 Swiped \(direction.rawValue) on \(family.parentName)")
        
        // Animate card off screen (F1.3 requirement)
        let exitOffset: CGFloat = direction == .right ? 400 : -400
        dragAmount = CGSize(width: exitOffset, height: 0)
        rotationAngle = direction == .right ? maxRotation : -maxRotation
        cardScale = 0.8
        
        // Trigger callback after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSwipe(direction)
            resetCardPosition()
        }
    }
    
    private func resetCardPosition() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            dragAmount = .zero
            rotationAngle = 0
            cardScale = 1.0
        }
    }
    
    // MARK: - Computed Properties
    private var cardBackground: some View {
        // Enhanced gradient background for better contrast and visual appeal
        LinearGradient(
            colors: [
                Color.white,
                Color(.systemGray6)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            // Subtle border for definition
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private var schoolShortName: String {
        // Extract first word of school name for compact display
        family.schoolName.components(separatedBy: " ").first ?? "School"
    }
    
    private var vehicleIcon: String {
        switch family.vehicleType {
        case .sedan: return "car.fill"
        case .suv: return "car.2.fill"
        case .hatchback: return "car.fill"
        case .minivan: return "bus.fill"
        case .ute: return "truck.pickup.fill"
        case .none: return "figure.walk"
        }
    }
    
    private var verificationIcon: String {
        switch family.verificationLevel {
        case .unverified: return "questionmark.circle"
        case .phoneVerified: return "phone.badge.checkmark"
        case .documentsVerified: return "doc.badge.checkmark"
        case .verified: return "checkmark.seal.fill"
        }
    }
    
    private var verificationColor: Color {
        switch family.verificationLevel {
        case .unverified: return .gray
        case .phoneVerified: return .orange
        case .documentsVerified: return .blue
        case .verified: return .green
        }
    }
    
    private var distanceText: String {
        // This would be calculated from user's location in real app
        let distance = Int.random(in: 500...2500) // Mock distance for demo
        if distance < 1000 {
            return "\(distance)m away"
        } else {
            return "\(String(format: "%.1f", Double(distance) / 1000))km away"
        }
    }
    
    private var accessibilityDescription: String {
        let rating = String(format: "%.1f", family.averageRating)
        return """
        \(family.parentName), parent of \(family.childName), age \(family.childAge).
        Lives in \(family.suburb), goes to \(family.schoolName).
        \(family.isDriverAvailable ? "Available as driver with \(family.availableSeats) seats" : "Looking for rides").
        Departs at \(family.preferredDepartureTime.formatted(date: .omitted, time: .shortened)).
        Rating: \(rating) stars from \(family.totalRatings) reviews.
        Verification: \(family.verificationLevel.displayName).
        Compatibility: \(Int(compatibilityScore * 100)) percent.
        """
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        FamilyCard(
            family: MockData.families[0],
            compatibilityScore: 0.85,
            onSwipe: { direction in
                print("Swiped \(direction.rawValue)")
            },
            onTap: {
                print("Tapped card")
            }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
