//
//  MatchingEngine.swift
//  SchoolCarpoolMatcher
//
//  AI-powered family compatibility scoring and matching engine
//  Implements F1.2 algorithm with weighted factors and safety prioritization
//  Follows repo rule: ObservableObject pattern with debug logging
//

import Foundation
import CoreLocation
import Combine

// MARK: - Matching Engine
/// Core business logic for family compatibility scoring and matching
/// Uses weighted algorithm: Distance(40%) + Schedule(30%) + Trust(20%) + Capacity(10%)
@MainActor
class MatchingEngine: ObservableObject {
    
    // MARK: - Published Properties
    @Published var availableFamilies: [Family] = []
    @Published var currentMatches: [Family] = []
    @Published var compatibilityScores: [UUID: Double] = [:]
    @Published var isLoading: Bool = false
    @Published var lastUpdateTime: Date?
    
    // MARK: - Private Properties
    private let locationManager: LocationManager
    private let maxSearchRadius: Double = 5000 // 5km maximum as per F1.2
    private let minCompatibilityScore: Double = 0.3 // Minimum viable match
    private var swipedFamilyIds: Set<UUID> = []
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        setupLocationObserver()
        loadSwipedFamilies()
        print("🤖 MatchingEngine initialized with max radius: \(Int(maxSearchRadius))m")
    }
    
    // MARK: - Setup
    private func setupLocationObserver() {
        // Observe location changes to update available families (F1.1 requirement)
        locationManager.$currentLocation
            .compactMap { $0 }
            .removeDuplicates { old, new in
                old.distance(from: new) < 500 // F1.1: Update when moved >500m
            }
            .sink { [weak self] location in
                print("📍 Location changed, updating family matches...")
                Task {
                    await self?.updateAvailableFamilies(userLocation: location)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Core Matching Logic
    
    /// Calculate compatibility score using F1.2 weighted algorithm
    func calculateCompatibilityScore(
        family: Family, 
        userLocation: CLLocation, 
        userPreferences: UserPreferences
    ) -> Double {
        print("🔍 Calculating compatibility for \(family.parentName)...")
        
        // 1. Geographic proximity (40% weight)
        let distance = userLocation.distance(from: family.location)
        let distanceScore = max(0.0, 1.0 - (distance / maxSearchRadius))
        print("   📍 Distance: \(Int(distance))m, Score: \(String(format: "%.2f", distanceScore))")
        
        // 2. Schedule alignment (30% weight) 
        let timeScore = calculateTimeCompatibility(
            userTime: userPreferences.departureTime,
            familyTime: family.preferredDepartureTime,
            userFlexibility: userPreferences.timeFlexibility,
            familyFlexibility: family.departureTimeWindow
        )
        print("   ⏰ Time compatibility: \(String(format: "%.2f", timeScore))")
        
        // 3. Trust/verification status (20% weight)
        let trustScore = calculateTrustScore(family: family)
        print("   🛡️ Trust score: \(String(format: "%.2f", trustScore))")
        
        // 4. Vehicle capacity match (10% weight)
        let capacityScore = calculateCapacityScore(
            family: family, 
            requiredSeats: userPreferences.requiredSeats
        )
        print("   🚗 Capacity score: \(String(format: "%.2f", capacityScore))")
        
        // Apply safety prioritization multiplier if enabled
        let safetyMultiplier = userPreferences.prioritizeSafety ? 
            calculateSafetyMultiplier(family: family) : 1.0
        
        // Calculate final weighted score
        let baseScore = (distanceScore * 0.4) + 
                       (timeScore * 0.3) + 
                       (trustScore * 0.2) + 
                       (capacityScore * 0.1)
        
        let finalScore = baseScore * safetyMultiplier
        
        print("   🎯 Final compatibility: \(String(format: "%.3f", finalScore)) (safety multiplier: \(String(format: "%.2f", safetyMultiplier)))")
        
        return finalScore
    }
    
    /// Calculate time compatibility between two departure preferences
    private func calculateTimeCompatibility(
        userTime: Date,
        familyTime: Date,
        userFlexibility: TimeInterval,
        familyFlexibility: TimeInterval
    ) -> Double {
        let timeDifference = abs(userTime.timeIntervalSince(familyTime))
        let combinedFlexibility = userFlexibility + familyFlexibility
        
        if timeDifference <= combinedFlexibility {
            // Perfect or good match within flexibility windows
            let score = max(0.0, 1.0 - (timeDifference / combinedFlexibility))
            return score
        } else {
            // Outside flexibility window
            return 0.0
        }
    }
    
    /// Calculate trust score based on verification and ratings
    private func calculateTrustScore(family: Family) -> Double {
        // Base verification score (0.0 - 1.0)
        let verificationScore = family.verificationLevel.trustMultiplier
        
        // Rating score (0.0 - 1.0, normalized from 0-5 star rating)
        let ratingScore = family.totalRatings > 0 ? 
            (family.averageRating / 5.0) : 0.5 // Default 0.5 for no ratings
        
        // Background check bonus
        let backgroundBonus: Double = family.backgroundCheckStatus == .cleared ? 0.2 : 0.0
        
        // Combine scores (capped at 1.0)
        let trustScore = min(1.0, (verificationScore + ratingScore) / 2.0 + backgroundBonus)
        
        return trustScore
    }
    
    /// Calculate vehicle capacity compatibility
    private func calculateCapacityScore(family: Family, requiredSeats: Int) -> Double {
        if !family.isDriverAvailable {
            return 0.0 // Can't provide rides
        }
        
        if family.availableSeats >= requiredSeats {
            // Has enough seats, bonus for extra capacity
            let extraSeats = family.availableSeats - requiredSeats
            return min(1.0, 0.8 + (Double(extraSeats) * 0.1))
        } else {
            // Not enough seats
            return 0.0
        }
    }
    
    /// Calculate safety multiplier for high-priority safety families
    private func calculateSafetyMultiplier(family: Family) -> Double {
        var multiplier: Double = 1.0
        
        // High trust families get bonus
        if family.isHighTrust {
            multiplier += 0.3
        }
        
        // Verified families get bonus
        if family.verificationLevel == .verified {
            multiplier += 0.2
        }
        
        // Background check cleared bonus
        if family.backgroundCheckStatus == .cleared {
            multiplier += 0.1
        }
        
        // High rating bonus
        if family.averageRating >= 4.5 && family.totalRatings >= 10 {
            multiplier += 0.1
        }
        
        return multiplier
    }
    
    // MARK: - Public Methods
    
    /// Update available families based on current location and preferences
    func updateAvailableFamilies(
        userLocation: CLLocation,
        userPreferences: UserPreferences = UserPreferences()
    ) async {
        isLoading = true
        print("🔄 Updating available families...")
        print("📍 User location: \(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude)")
        print("🔍 Search radius: \(Int(userPreferences.searchRadius))m")
        
        // Get all families from mock data
        let allFamilies = MockData.families
        print("🏠 Total families in mock data: \(allFamilies.count)")
        
        // Filter by search radius
        let nearbyFamilies = allFamilies.filter { family in
            let distance = userLocation.distance(from: family.location)
            let isNearby = distance <= userPreferences.searchRadius
            if !isNearby {
                print("   ❌ \(family.parentName) too far: \(Int(distance))m > \(Int(userPreferences.searchRadius))m")
            }
            return isNearby
        }
        print("📍 Families within radius: \(nearbyFamilies.count)/\(allFamilies.count)")
        
        // Exclude already swiped families
        let unswipedFamilies = nearbyFamilies.filter { family in
            !swipedFamilyIds.contains(family.id)
        }
        print("👆 Unswiped families: \(unswipedFamilies.count)/\(nearbyFamilies.count)")
        
        // Calculate compatibility scores
        var scoredFamilies: [(Family, Double)] = []
        var newCompatibilityScores: [UUID: Double] = [:]
        
        for family in unswipedFamilies {
            let score = calculateCompatibilityScore(
                family: family,
                userLocation: userLocation,
                userPreferences: userPreferences
            )
            
            if score >= minCompatibilityScore {
                scoredFamilies.append((family, score))
                newCompatibilityScores[family.id] = score
            } else {
                print("   ❌ \(family.parentName) below minimum score: \(String(format: "%.3f", score)) < \(minCompatibilityScore)")
            }
        }
        
        // Sort by compatibility score (F1.2 requirement)
        scoredFamilies.sort { $0.1 > $1.1 }
        
        // Update published properties
        availableFamilies = scoredFamilies.map { $0.0 }
        compatibilityScores = newCompatibilityScores
        lastUpdateTime = Date()
        isLoading = false
        
        print("✅ Found \(availableFamilies.count) compatible families")
        print("🏆 Top matches:")
        for (index, family) in availableFamilies.prefix(3).enumerated() {
            let score = compatibilityScores[family.id] ?? 0.0
            print("   \(index + 1). \(family.parentName) - \(String(format: "%.3f", score))")
        }
    }
    
    /// Handle swipe action (F1.3 requirement) with memory safety checks
    func handleSwipe(family: Family, direction: SwipeDirection) {
        // Memory safety: Validate family object
        guard !family.id.uuidString.isEmpty else {
            print("⚠️ Invalid family object in handleSwipe")
            return
        }
        
        // Memory safety: Check if family exists in available families
        guard availableFamilies.contains(where: { $0.id == family.id }) else {
            print("⚠️ Family \(family.parentName) not found in available families")
            return
        }
        
        print("👆 Swipe \(direction.rawValue) on \(family.parentName)")
        
        // Record swipe to prevent showing again
        swipedFamilyIds.insert(family.id)
        saveSwipedFamilies()
        
        // Remove from available families with safety check
        let originalCount = availableFamilies.count
        availableFamilies.removeAll { $0.id == family.id }
        compatibilityScores.removeValue(forKey: family.id)
        
        // Verify removal was successful
        if availableFamilies.count == originalCount {
            print("⚠️ Failed to remove family from available families")
        }
        
        switch direction {
        case .right: // Match/Like
            handleMatchAttempt(family: family)
        case .left: // Skip/Pass
            print("⏭️ Skipped \(family.parentName)")
        }
    }
    
    /// Handle match attempt and check for mutual interest
    private func handleMatchAttempt(family: Family) {
        print("❤️ Attempting to match with \(family.parentName)")
        
        // Add to current matches (in real app, would check mutual interest)
        currentMatches.append(family)
        
        // Simulate mutual interest for demo (80% chance)
        let hasMutualInterest = Double.random(in: 0...1) < 0.8
        
        if hasMutualInterest {
            print("🎉 It's a Match with \(family.parentName)!")
            // Trigger match confirmation flow (F1.4)
            handleSuccessfulMatch(family: family)
        } else {
            print("💔 No mutual interest from \(family.parentName)")
        }
    }
    
    /// Handle successful mutual match (F1.4 implementation)
    private func handleSuccessfulMatch(family: Family) {
        print("✨ Creating carpool group with \(family.parentName)")
        
        // In real implementation, would call F1.4 group formation logic
        // For now, just log the successful match
        
        // Calculate potential savings and impact
        let distance = locationManager.currentLocation?.distance(from: family.schoolLocation) ?? 0
        let dailySavings = calculateDailySavings(distance: distance)
        
        print("💰 Estimated daily savings: $\(String(format: "%.2f", dailySavings))")
        print("🌱 CO2 reduction: \(String(format: "%.1f", dailySavings * 0.25))kg per week")
    }
    
    /// Calculate estimated daily savings from carpooling
    private func calculateDailySavings(distance: Double) -> Double {
        let fuelCostPerKm = 0.15 // AUD per km (Australian average)
        let dailyDistance = distance * 2 / 1000 // Round trip in km
        return dailyDistance * fuelCostPerKm * 0.5 // 50% savings from sharing
    }
    
    // MARK: - Persistence
    
    /// Load previously swiped families from UserDefaults
    private func loadSwipedFamilies() {
        let today = DateFormatter().string(from: Date())
        let key = "swiped_families_\(today)"
        
        if let data = UserDefaults.standard.data(forKey: key),
           let swipedIds = try? JSONDecoder().decode([UUID].self, from: data) {
            swipedFamilyIds = Set(swipedIds)
            print("📱 Loaded \(swipedFamilyIds.count) swiped families for today")
        }
    }
    
    /// Save swiped families to UserDefaults (F1.3 requirement)
    private func saveSwipedFamilies() {
        let today = DateFormatter().string(from: Date())
        let key = "swiped_families_\(today)"
        
        if let data = try? JSONEncoder().encode(Array(swipedFamilyIds)) {
            UserDefaults.standard.set(data, forKey: key)
            print("💾 Saved \(swipedFamilyIds.count) swiped families")
        }
    }
    
    /// Reset daily swipes (for testing/demo)
    func resetDailySwipes() {
        swipedFamilyIds.removeAll()
        let today = DateFormatter().string(from: Date())
        let key = "swiped_families_\(today)"
        UserDefaults.standard.removeObject(forKey: key)
        print("🔄 Reset daily swipes")
    }
    
    // MARK: - Debug Helpers
    
    /// Print detailed compatibility analysis for debugging
    func debugCompatibilityAnalysis(
        family: Family,
        userLocation: CLLocation,
        userPreferences: UserPreferences
    ) {
        print("\n🔍 DETAILED COMPATIBILITY ANALYSIS")
        print("Family: \(family.parentName) (\(family.suburb))")
        print("Child: \(family.childName), \(family.childAge) years old")
        print("School: \(family.schoolName)")
        print("Vehicle: \(family.vehicleType.displayName) (\(family.availableSeats) seats)")
        print("Rating: ⭐ \(family.averageRating) (\(family.totalRatings) reviews)")
        print("Verification: \(family.verificationLevel.displayName)")
        print("Background: \(family.backgroundCheckStatus.displayName)")
        
        let score = calculateCompatibilityScore(
            family: family,
            userLocation: userLocation,
            userPreferences: userPreferences
        )
        
        print("Final Score: \(String(format: "%.3f", score))")
        print("Match Quality: \(getMatchQuality(score: score))")
        print("---")
    }
    
    private func getMatchQuality(score: Double) -> String {
        switch score {
        case 0.8...1.0: return "🔥 Excellent Match"
        case 0.6..<0.8: return "✅ Good Match"
        case 0.4..<0.6: return "👍 Fair Match"
        case 0.3..<0.4: return "⚠️ Marginal Match"
        default: return "❌ Poor Match"
        }
    }
}

// MARK: - Supporting Types

/// Swipe direction for user interface
enum SwipeDirection: String, CaseIterable {
    case left = "left"   // Skip/Pass
    case right = "right" // Like/Match
    
    var emoji: String {
        switch self {
        case .left: return "❌"
        case .right: return "❤️"
        }
    }
}

/// Match result for UI feedback
struct MatchResult {
    let family: Family
    let isMutualMatch: Bool
    let compatibilityScore: Double
    let estimatedSavings: Double
    let co2Reduction: Double
    let timestamp: Date
    
    var isSuccessful: Bool {
        return isMutualMatch
    }
}

// MARK: - Extensions

extension UserPreferences {
    /// Create demo preferences for testing
    static func demoPreferences(
        location: CLLocation = CLLocation(latitude: -35.3089, longitude: 149.0981)
    ) -> UserPreferences {
        return UserPreferences(
            searchRadius: 3000,
            departureTime: Calendar.current.date(bySettingHour: 8, minute: 15, second: 0, of: Date()) ?? Date(),
            timeFlexibility: 15 * 60, // 15 minutes
            requiredSeats: 1,
            maxDetourTime: 10 * 60, // 10 minutes
            prioritizeSafety: true,
            requireVerification: false,
            allowBackgroundCheck: true
        )
    }
}
