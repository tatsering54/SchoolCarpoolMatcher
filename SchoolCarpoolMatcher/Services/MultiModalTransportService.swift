//
//  MultiModalTransportService.swift
//  SchoolCarpoolMatcher
//
//  Multi-modal transport integration service for F2.3
//  Combines carpool routes with ACT public transport for optimal journey planning
//  Applied Rule: Safety-first multi-modal transport with comprehensive debug logging
//

import Foundation
import MapKit
import CoreLocation

// MARK: - Multi-Modal Transport Service
/// Service for integrating carpool routes with ACT public transport
/// Implements F2.3 requirements: Park & Ride integration, hybrid journeys, real-time updates
class MultiModalTransportService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAnalyzing = false
    @Published var hybridOptions: [HybridJourneyOption] = []
    @Published var recommendedOption: HybridJourneyOption?
    @Published var serviceStatus: TransportServiceStatus?
    @Published var error: MultiModalError?
    @Published var analysisResult: MultiModalAnalysisResult?
    
    // MARK: - Dependencies
    private let actTransportService = ACTTransportService()
    private let routeAnalysisService = RouteAnalysisService()
    
    // MARK: - Constants
    private let maxParkRideRadius: Double = 2.0 // km
    private let maxWalkingDistance: Double = 800.0 // meters
    private let transferTime: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    init() {
        print("🚗🚌 MultiModalTransportService initialized")
        print("   🅿️ Max Park & Ride radius: \(maxParkRideRadius)km")
        print("   🚶‍♂️ Max walking distance: \(maxWalkingDistance)m")
        print("   ⏱️ Transfer time allowance: \(transferTime/60)min")
        
        Task {
            await loadTransportData()
        }
    }
    
    // MARK: - Public Methods
    
    /// Analyze multi-modal transport options for a carpool group
    func analyzeMultiModalOptions(
        for group: CarpoolGroup,
        members: [CLLocationCoordinate2D],
        school: CLLocationCoordinate2D
    ) async -> MultiModalAnalysisResult {
        print("🔍 Analyzing multi-modal transport options for group: \(group.groupName)")
        print("   👥 Members: \(members.count)")
        print("   🏫 School: (\(String(format: "%.4f", school.latitude)), \(String(format: "%.4f", school.longitude)))")
        
        isAnalyzing = true
        error = nil
        
        defer {
            isAnalyzing = false
        }
        
        // 1. Analyze traditional carpool route
        let carpoolAnalysis = await analyzeCarpoolRoute(members: members, school: school)
        
        // 2. Find hybrid options for each member
        var allHybridOptions: [MemberHybridOptions] = []
        
        for (index, memberLocation) in members.enumerated() {
            print("🔬 Analyzing hybrid options for member \(index + 1)...")
            
            let memberOptions = await actTransportService.calculateHybridJourneys(
                from: memberLocation,
                to: school
            )
            
            allHybridOptions.append(MemberHybridOptions(
                memberIndex: index,
                homeLocation: memberLocation,
                hybridOptions: memberOptions
            ))
        }
        
        // 3. Calculate group-wide recommendations
        let groupRecommendations = calculateGroupRecommendations(
            carpoolAnalysis: carpoolAnalysis,
            memberOptions: allHybridOptions,
            groupSize: members.count
        )
        
        // 4. Get current service status
        let currentServiceStatus = await actTransportService.getServiceStatus()
        serviceStatus = currentServiceStatus
        
        let result = MultiModalAnalysisResult(
            groupId: group.id,
            carpoolOnlyOption: carpoolAnalysis,
            memberHybridOptions: allHybridOptions,
            groupRecommendations: groupRecommendations,
            serviceStatus: currentServiceStatus,
            analysisDate: Date(),
            co2ComparisonData: calculateCO2Comparison(
                carpoolAnalysis: carpoolAnalysis,
                hybridOptions: allHybridOptions
            )
        )
        
        // Update published properties
        hybridOptions = allHybridOptions.flatMap { $0.hybridOptions }
        recommendedOption = groupRecommendations.first
        analysisResult = result
        
        print("✅ Multi-modal analysis complete:")
        print("   🚗 Carpool-only time: \(String(format: "%.1f", carpoolAnalysis.totalTime/60))min")
        print("   🚌 Hybrid options found: \(hybridOptions.count)")
        print("   💰 Best hybrid savings: $\(String(format: "%.2f", groupRecommendations.first?.totalCost ?? 0))")
        
        return result
    }
    
    /// Find optimal Park & Ride locations for a specific location
    func findOptimalParkRideLocations(
        near coordinate: CLLocationCoordinate2D,
        destinationSchool: CLLocationCoordinate2D
    ) async -> [ParkRideRecommendation] {
        print("🅿️ Finding optimal Park & Ride locations...")
        
        let nearbyParkRides = actTransportService.findNearbyParkRideLocations(
            near: coordinate,
            radiusKm: maxParkRideRadius
        )
        
        var recommendations: [ParkRideRecommendation] = []
        
        for parkRide in nearbyParkRides {
            let homeLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let parkRideLocation = CLLocation(latitude: parkRide.latitude, longitude: parkRide.longitude)
            let schoolLocation = CLLocation(latitude: destinationSchool.latitude, longitude: destinationSchool.longitude)
            
            // Calculate route segments
            let driveDistance = homeLocation.distance(from: parkRideLocation)
            let transitDistance = parkRideLocation.distance(from: schoolLocation)
            
            // Calculate times
            let driveTime = calculateDriveTime(distance: driveDistance)
            let transitTime = calculateTransitTime(distance: transitDistance, mode: parkRide.primaryTransportType)
            let totalTime = driveTime + transferTime + transitTime
            
            // Calculate costs
            let driveCost = calculateDriveCost(distance: driveDistance)
            let transitCost = parkRide.averageFare
            let totalCost = driveCost + transitCost
            
            // Calculate recommendation score
            let score = calculateParkRideScore(
                parkRide: parkRide,
                driveTime: driveTime,
                transitTime: transitTime,
                totalCost: totalCost
            )
            
            let recommendation = ParkRideRecommendation(
                parkRideLocation: parkRide,
                driveDistance: driveDistance,
                driveTime: driveTime,
                transitDistance: transitDistance,
                transitTime: transitTime,
                totalTime: totalTime,
                totalCost: totalCost,
                recommendationScore: score,
                benefits: generateParkRideBenefits(
                    parkRide: parkRide,
                    totalTime: totalTime,
                    totalCost: totalCost
                )
            )
            
            recommendations.append(recommendation)
        }
        
        // Sort by recommendation score
        recommendations.sort { $0.recommendationScore > $1.recommendationScore }
        
        print("   📊 Generated \(recommendations.count) Park & Ride recommendations")
        if let best = recommendations.first {
            print("   🥇 Best: \(best.parkRideLocation.name) (score: \(String(format: "%.1f", best.recommendationScore)))")
        }
        
        return recommendations
    }
    
    /// Update transport options with real-time service data
    func updateWithRealTimeData() async {
        print("🔄 Updating with real-time transport data...")
        
        do {
            // Fetch latest transport usage data
            let _ = try await actTransportService.fetchTransportData()
            
            // Update service status
            serviceStatus = await actTransportService.getServiceStatus()
            
            // Recalculate hybrid options if we have existing analysis
            if !hybridOptions.isEmpty {
                print("   🔄 Recalculating hybrid options with updated data...")
                // In a real implementation, would recalculate based on service delays
            }
            
            print("✅ Real-time data update complete")
            
        } catch {
            print("⚠️ Failed to update real-time data: \(error)")
            self.error = MultiModalError.realTimeUpdateFailed(error)
        }
    }
    
    // MARK: - Private Methods
    
    /// Load initial transport data
    private func loadTransportData() async {
        print("📥 Loading initial transport data...")
        
        do {
            let _ = try await actTransportService.fetchTransportData()
            serviceStatus = await actTransportService.getServiceStatus()
            print("✅ Initial transport data loaded")
        } catch {
            print("⚠️ Failed to load initial transport data: \(error)")
            self.error = MultiModalError.dataLoadingFailed(error)
        }
    }
    
    /// Analyze traditional carpool route
    private func analyzeCarpoolRoute(
        members: [CLLocationCoordinate2D],
        school: CLLocationCoordinate2D
    ) async -> CarpoolRouteOption {
        print("🚗 Analyzing traditional carpool route...")
        
        guard let firstMember = members.first else {
            return CarpoolRouteOption(
                totalTime: 1800,
                totalDistance: 15000,
                estimatedCost: 12.0,
                safetyScore: 7.0,
                route: []
            )
        }
        
        // For MVP, use simple route from first member to school
        // In production, would use RouteAnalysisService for optimal pickup sequence
        let result = await routeAnalysisService.analyzeRoute(
            from: firstMember,
            to: school
        )
        
        let totalDistance = result.primaryRoute.route.distance
        let totalTime = result.primaryRoute.route.expectedTravelTime
        let costPerKm = 0.85 // AUD per km
        let estimatedCost = (totalDistance / 1000.0) * costPerKm
        
        return CarpoolRouteOption(
            totalTime: totalTime,
            totalDistance: totalDistance,
            estimatedCost: estimatedCost,
            safetyScore: result.primaryRoute.overallScore,
            route: [firstMember, school]
        )
    }
    
    /// Calculate group-wide recommendations
    private func calculateGroupRecommendations(
        carpoolAnalysis: CarpoolRouteOption,
        memberOptions: [MemberHybridOptions],
        groupSize: Int
    ) -> [HybridJourneyOption] {
        print("📊 Calculating group recommendations...")
        
        // Find the best hybrid option that works for the group
        var groupRecommendations: [HybridJourneyOption] = []
        
        // Strategy 1: Find common Park & Ride locations
        let allParkRides = memberOptions.flatMap { $0.hybridOptions.map { $0.parkRideLocation } }
        let parkRideFrequency = Dictionary(grouping: allParkRides) { $0.id }
        
        for (parkRideId, instances) in parkRideFrequency {
            if instances.count >= max(2, groupSize / 2) { // At least half the group can use it
                if let representativeOption = memberOptions.first?.hybridOptions.first(where: { $0.parkRideLocation.id == parkRideId }) {
                    groupRecommendations.append(representativeOption)
                }
            }
        }
        
        // Strategy 2: Best individual options for comparison
        let bestIndividualOptions = memberOptions.compactMap { $0.hybridOptions.first }
        groupRecommendations.append(contentsOf: bestIndividualOptions.prefix(2))
        
        // Sort by total time and cost efficiency
        groupRecommendations.sort { option1, option2 in
            let efficiency1 = option1.totalTime + (option1.totalCost * 60) // Weight cost as time
            let efficiency2 = option2.totalTime + (option2.totalCost * 60)
            return efficiency1 < efficiency2
        }
        
        print("   🎯 Generated \(groupRecommendations.count) group recommendations")
        
        return Array(groupRecommendations.prefix(3)) // Top 3 recommendations
    }
    
    /// Calculate CO2 comparison data
    private func calculateCO2Comparison(
        carpoolAnalysis: CarpoolRouteOption,
        hybridOptions: [MemberHybridOptions]
    ) -> CO2ComparisonData {
        let carpoolCO2 = (carpoolAnalysis.totalDistance / 1000.0) * 0.251 // kg CO2 per km
        
        let bestHybridCO2 = hybridOptions.compactMap { memberOption in
            memberOption.hybridOptions.first?.co2Savings
        }.min() ?? carpoolCO2
        
        let potentialSavings = max(0, carpoolCO2 - bestHybridCO2)
        
        return CO2ComparisonData(
            carpoolOnlyCO2: carpoolCO2,
            bestHybridCO2: bestHybridCO2,
            potentialSavings: potentialSavings
        )
    }
    
    /// Calculate Park & Ride recommendation score
    private func calculateParkRideScore(
        parkRide: ParkRideLocation,
        driveTime: TimeInterval,
        transitTime: TimeInterval,
        totalCost: Double
    ) -> Double {
        var score = 100.0
        
        // Time efficiency (40% weight)
        let totalTime = driveTime + transferTime + transitTime
        let timeScore = max(0, 100 - (totalTime / 60.0)) // Penalty for longer times
        score += timeScore * 0.4
        
        // Cost efficiency (25% weight)
        let costScore = max(0, 100 - (totalCost * 10)) // Penalty for higher cost
        score += costScore * 0.25
        
        // Reliability (20% weight)
        score += parkRide.reliabilityScore * 0.2
        
        // Availability (15% weight)
        let availabilityScore = Double(parkRide.availableSpaces) / Double(parkRide.parkingSpaces) * 100
        score += availabilityScore * 0.15
        
        return max(0, min(100, score))
    }
    
    /// Generate Park & Ride benefits list
    private func generateParkRideBenefits(
        parkRide: ParkRideLocation,
        totalTime: TimeInterval,
        totalCost: Double
    ) -> [String] {
        var benefits: [String] = []
        
        if totalCost < 15.0 {
            benefits.append("Cost-effective option under $15")
        }
        
        if totalTime < 2700 { // Under 45 minutes
            benefits.append("Quick journey under 45 minutes")
        }
        
        if parkRide.reliabilityScore > 8.5 {
            benefits.append("Highly reliable transport service")
        }
        
        if parkRide.availabilityStatus == .available {
            benefits.append("Ample parking spaces available")
        }
        
        if parkRide.amenities.contains("Free Parking") {
            benefits.append("Free parking included")
        }
        
        if parkRide.amenities.contains("Shopping Centre") || parkRide.amenities.contains("Food Court") {
            benefits.append("Convenient shopping and dining nearby")
        }
        
        return benefits
    }
    
    // MARK: - Helper Methods
    
    private func calculateDriveTime(distance: Double) -> TimeInterval {
        let averageSpeedKmh = 40.0
        let distanceKm = distance / 1000.0
        let timeHours = distanceKm / averageSpeedKmh
        return timeHours * 3600
    }
    
    private func calculateTransitTime(distance: Double, mode: TransportMode) -> TimeInterval {
        let averageSpeed: Double
        switch mode {
        case .lightRail: averageSpeed = 25.0
        case .rapidBus: averageSpeed = 30.0
        case .bus: averageSpeed = 20.0
        default: averageSpeed = 15.0
        }
        
        let distanceKm = distance / 1000.0
        let timeHours = distanceKm / averageSpeed
        return timeHours * 3600
    }
    
    private func calculateDriveCost(distance: Double) -> Double {
        let costPerKm = 0.85
        let distanceKm = distance / 1000.0
        return distanceKm * costPerKm
    }
}

// MARK: - Additional Data Models

/// Multi-modal analysis result for a carpool group
struct MultiModalAnalysisResult {
    let groupId: UUID
    let carpoolOnlyOption: CarpoolRouteOption
    let memberHybridOptions: [MemberHybridOptions]
    let groupRecommendations: [HybridJourneyOption]
    let serviceStatus: TransportServiceStatus
    let analysisDate: Date
    let co2ComparisonData: CO2ComparisonData
}

/// Carpool-only route option
struct CarpoolRouteOption {
    let totalTime: TimeInterval
    let totalDistance: Double
    let estimatedCost: Double
    let safetyScore: Double
    let route: [CLLocationCoordinate2D]
}

/// Hybrid options for a specific group member
struct MemberHybridOptions {
    let memberIndex: Int
    let homeLocation: CLLocationCoordinate2D
    let hybridOptions: [HybridJourneyOption]
}

/// Park & Ride recommendation with detailed analysis
struct ParkRideRecommendation: Identifiable {
    let id = UUID()
    let parkRideLocation: ParkRideLocation
    let driveDistance: Double
    let driveTime: TimeInterval
    let transitDistance: Double
    let transitTime: TimeInterval
    let totalTime: TimeInterval
    let totalCost: Double
    let recommendationScore: Double
    let benefits: [String]
}

/// CO2 emissions comparison data
struct CO2ComparisonData {
    let carpoolOnlyCO2: Double // kg CO2
    let bestHybridCO2: Double // kg CO2
    let potentialSavings: Double // kg CO2 saved
    
    var savingsPercentage: Double {
        guard carpoolOnlyCO2 > 0 else { return 0 }
        return (potentialSavings / carpoolOnlyCO2) * 100
    }
}

// MARK: - Error Handling

enum MultiModalError: LocalizedError {
    case analysisFailure(Error)
    case dataLoadingFailed(Error)
    case realTimeUpdateFailed(Error)
    case invalidInput
    case serviceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .analysisFailure(let error):
            return "Multi-modal analysis failed: \(error.localizedDescription)"
        case .dataLoadingFailed(let error):
            return "Failed to load transport data: \(error.localizedDescription)"
        case .realTimeUpdateFailed(let error):
            return "Real-time update failed: \(error.localizedDescription)"
        case .invalidInput:
            return "Invalid input parameters provided"
        case .serviceUnavailable:
            return "Multi-modal transport service temporarily unavailable"
        }
    }
}
