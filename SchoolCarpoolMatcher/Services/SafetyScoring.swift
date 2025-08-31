//
//  SafetyScoring.swift
//  SchoolCarpoolMatcher
//
//  Route risk scoring algorithm for F2.1
//  Implements school zone prioritization and accident data analysis
//  Applied Rule: Safety-first messaging and comprehensive debug logging
//  Note: Lower risk scores indicate safer routes
//

import Foundation
import MapKit
import CoreLocation

// MARK: - Route Risk Scoring Engine
/// Core algorithm for calculating route risk scores based on F2.1 requirements
/// Prioritizes school zones, residential streets, and traffic light intersections
/// Note: Lower risk scores indicate safer routes
class RouteRiskScoring: ObservableObject {
    
    // MARK: - Risk Multipliers (F2.1 Requirements)
    private struct RiskMultipliers {
        static let schoolZoneBonus: Double = -2.0      // -2.0 risk reduction for school zones
        static let residentialStreetBonus: Double = -1.5  // -1.5 risk reduction for residential vs arterial
        static let trafficLightsBonus: Double = -1.3   // -1.3 risk reduction for traffic light intersections
        static let accidentRiskPenalty: Double = 3.0 // +3.0 risk increase for accident-prone areas
    }
    
    // MARK: - Constants
    private let baseRiskScore: Double = 5.0 // Base risk score out of 10 (lower is better)
    private let maximumAcceptableRisk: Double = 3.0 // F2.1 requirement (routes above 3.0 risk need warning)
    private let schoolZoneRadius: Double = 500.0 // meters
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var lastAnalysisDate: Date?
    @Published var cachedSchoolLocations: [SchoolLocation] = []
    @Published var cachedAccidentData: [AccidentLocation] = []
    
    // MARK: - Services
    private let schoolDataService = SchoolDataService()
    private let accidentDataService = AccidentDataService()
    
    // MARK: - Initialization
    init() {
        print("🛡️ RouteRiskScoring engine initialized")
        print("   📏 School zone radius: \(schoolZoneRadius)m")
        print("   ⚖️ Maximum acceptable risk: \(maximumAcceptableRisk)/10")
        
        Task {
            await loadSafetyData()
        }
    }
    
    // MARK: - Core Safety Calculation
    
    /// Calculate comprehensive risk score for a route (F2.1 implementation)
    /// Lower scores indicate safer routes
    func calculateRouteRiskScore(
        route: MKRoute,
        userLocation: CLLocation
    ) async -> RouteRiskAnalysis {
        print("🔍 Calculating risk score for route (lower = safer)...")
        print("   📍 Route distance: \(String(format: "%.2f", route.distance/1000))km")
        print("   ⏱️ Estimated time: \(String(format: "%.1f", route.expectedTravelTime/60))min")
        
        isLoading = true
        defer { isLoading = false }
        
        // Ensure safety data is loaded
        await loadSafetyDataIfNeeded()
        
        var riskFactors = RiskFactors()
        
        // 1. Analyze school zone coverage (reduces risk)
        riskFactors.schoolZoneRiskReduction = await analyzeSchoolZoneCoverage(route: route)
        
        // 2. Analyze road type composition (affects risk)
        riskFactors.roadTypeRiskScore = analyzeRoadTypes(route: route)
        
        // 3. Analyze traffic light intersections (reduces risk)
        riskFactors.trafficLightRiskReduction = await analyzeTrafficLights(route: route)
        
        // 4. Analyze accident history (increases risk)
        riskFactors.accidentRiskIncrease = analyzeAccidentHistory(route: route)
        
        // 5. Calculate overall risk score using F2.1 formula
        let overallRiskScore = calculateOverallRiskScore(factors: riskFactors)
        
        let analysis = RouteRiskAnalysis(
            route: route,
            overallRiskScore: overallRiskScore,
            riskFactors: riskFactors,
            isAcceptableRisk: overallRiskScore <= maximumAcceptableRisk,
            recommendations: generateRiskRecommendations(factors: riskFactors, riskScore: overallRiskScore),
            lastAnalyzed: Date()
        )
        
        print("🎯 Risk analysis complete:")
        print("   📊 Overall risk score: \(String(format: "%.2f", overallRiskScore))/10 (lower = safer)")
        print("   ✅ Acceptable risk: \(analysis.isAcceptableRisk)")
        print("   🏫 School zone coverage: \(String(format: "%.1f", riskFactors.schoolZoneRiskReduction))%")
        print("   🛣️ Road type risk: \(String(format: "%.2f", riskFactors.roadTypeRiskScore))")
        print("   ⚠️ Accident risk increase: \(String(format: "%.2f", riskFactors.accidentRiskIncrease))")
        
        return analysis
    }
    
    // MARK: - School Zone Analysis
    
    /// Analyze route coverage through school zones (F2.1 requirement)
    private func analyzeSchoolZoneCoverage(route: MKRoute) async -> Double {
        print("🏫 Analyzing school zone coverage...")
        
        let routeCoordinates = extractRouteCoordinates(from: route)
        var schoolZoneDistance: Double = 0
        let totalRouteDistance = route.distance
        
        for coordinate in routeCoordinates {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            // Check if this point is within any school zone
            for school in cachedSchoolLocations {
                let schoolLocation = CLLocation(latitude: school.latitude, longitude: school.longitude)
                let distance = location.distance(from: schoolLocation)
                
                if distance <= schoolZoneRadius {
                    schoolZoneDistance += 100 // Approximate 100m segments
                    break // Don't double-count for multiple schools
                }
            }
        }
        
        let coveragePercentage = min(100.0, (schoolZoneDistance / totalRouteDistance) * 100)
        print("   📏 School zone coverage: \(String(format: "%.1f", coveragePercentage))%")
        
        return coveragePercentage
    }
    
    // MARK: - Road Type Analysis
    
    /// Analyze road type composition (residential vs arterial)
    private func analyzeRoadTypes(route: MKRoute) -> Double {
        print("🛣️ Analyzing road type composition...")
        
        // For MVP, use heuristics based on route characteristics
        // In production, would query OpenStreetMap data
        
        let avgSpeed = route.distance / route.expectedTravelTime // m/s
        let avgSpeedKmh = avgSpeed * 3.6
        
        var roadTypeScore: Double
        
        switch avgSpeedKmh {
        case 0..<40:
            roadTypeScore = RiskMultipliers.residentialStreetBonus // Likely residential
            print("   🏘️ Route classified as: Residential streets")
        case 40..<60:
            roadTypeScore = 1.2 // Mixed residential/collector
            print("   🛣️ Route classified as: Mixed streets")
        default:
            roadTypeScore = 1.0 // Likely arterial roads
            print("   🚗 Route classified as: Arterial roads")
        }
        
        return roadTypeScore
    }
    
    // MARK: - Traffic Light Analysis
    
    /// Analyze traffic light intersection coverage
    private func analyzeTrafficLights(route: MKRoute) async -> Double {
        print("🚦 Analyzing traffic light coverage...")
        
        // For MVP, estimate based on route through urban areas
        // In production, would query traffic infrastructure APIs
        
        let routeCoordinates = extractRouteCoordinates(from: route)
        let urbanAreaCount = routeCoordinates.filter { coordinate in
            // Heuristic: points near schools likely have traffic infrastructure
            cachedSchoolLocations.contains { school in
                let schoolLocation = CLLocation(latitude: school.latitude, longitude: school.longitude)
                let pointLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                return pointLocation.distance(from: schoolLocation) <= 200 // 200m from schools
            }
        }.count
        
        let trafficLightScore = min(RiskMultipliers.trafficLightsBonus, 1.0 + Double(urbanAreaCount) / Double(routeCoordinates.count))
        print("   🚦 Traffic light score: \(String(format: "%.2f", trafficLightScore))")
        
        return trafficLightScore
    }
    
    // MARK: - Accident History Analysis
    
    /// Analyze historical accident data along route
    private func analyzeAccidentHistory(route: MKRoute) -> Double {
        print("📊 Analyzing accident history...")
        
        let routeCoordinates = extractRouteCoordinates(from: route)
        var accidentRiskScore: Double = 0
        
        for coordinate in routeCoordinates {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            // Check for nearby accidents
            let nearbyAccidents = cachedAccidentData.filter { accident in
                let accidentLocation = CLLocation(latitude: accident.latitude, longitude: accident.longitude)
                return location.distance(from: accidentLocation) <= 100 // 100m radius
            }
            
            if !nearbyAccidents.isEmpty {
                accidentRiskScore += Double(nearbyAccidents.count) * 0.1
            }
        }
        
        let finalAccidentScore = max(RiskMultipliers.accidentRiskPenalty, -accidentRiskScore)
        print("   ⚠️ Accident penalty: \(String(format: "%.2f", finalAccidentScore))")
        
        return finalAccidentScore
    }
    
    // MARK: - Overall Risk Score Calculation
    
    /// Calculate final risk score using F2.1 formula (lower = safer)
    private func calculateOverallRiskScore(factors: RiskFactors) -> Double {
        // F2.1 Formula: base_risk + road_type_risk - school_zone_reduction - traffic_light_reduction + accident_risk
        var riskScore = baseRiskScore
        
        // Apply road type risk
        riskScore += factors.roadTypeRiskScore
        
        // Apply school zone risk reduction (coverage-based)
        let schoolZoneReduction = (factors.schoolZoneRiskReduction / 100.0) * abs(RiskMultipliers.schoolZoneBonus)
        riskScore -= schoolZoneReduction
        
        // Apply traffic light risk reduction
        riskScore += factors.trafficLightRiskReduction
        
        // Apply accident risk increase
        riskScore += factors.accidentRiskIncrease
        
        // Clamp to 0-10 range (0 = safest, 10 = most risky)
        return max(0.0, min(10.0, riskScore))
    }
    
    // MARK: - Risk Recommendations
    
    /// Generate risk recommendations based on analysis
    private func generateRiskRecommendations(factors: RiskFactors, riskScore: Double) -> [RiskRecommendation] {
        var recommendations: [RiskRecommendation] = []
        
        if riskScore > maximumAcceptableRisk {
            recommendations.append(RiskRecommendation(
                priority: .critical,
                title: "High Risk Route Warning",
                description: "This route has a risk score of \(String(format: "%.1f", riskScore))/10, above the maximum acceptable risk of \(maximumAcceptableRisk)/10. Consider alternative routes.",
                actionRequired: true
            ))
        }
        
        if factors.schoolZoneRiskReduction < 30 {
            recommendations.append(RiskRecommendation(
                priority: .medium,
                title: "Limited School Zone Coverage",
                description: "Consider routes that pass through more school zones for reduced risk and enhanced safety.",
                actionRequired: false
            ))
        }
        
        if factors.accidentRiskIncrease > 1.0 {
            recommendations.append(RiskRecommendation(
                priority: .high,
                title: "Accident-Prone Areas Detected",
                description: "This route passes through areas with significant accident history (risk increase: +\(String(format: "%.1f", factors.accidentRiskIncrease))). Extra caution recommended.",
                actionRequired: true
            ))
        }
        
        if factors.roadTypeRiskScore > 2.0 {
            recommendations.append(RiskRecommendation(
                priority: .medium,
                title: "High-Speed Roads Detected",
                description: "This route uses high-speed arterial roads. Consider residential alternatives for safer school transport.",
                actionRequired: false
            ))
        }
        
        return recommendations
    }
    
    // MARK: - Overall Score Calculation (Legacy)
    
    /// Calculate final safety score using F2.1 formula
    private func calculateOverallSafetyScore(factors: SafetyFactors) -> Double {
        // F2.1 Formula: base_score * road_type_multiplier * school_zone_multiplier * accident_penalty
        let schoolZoneMultiplier = 1.0 + (factors.schoolZoneScore / 100.0) * (RiskMultipliers.schoolZoneBonus - 1.0)
        
        let rawScore = baseRiskScore * factors.roadTypeScore * schoolZoneMultiplier * factors.trafficLightScore
        let finalScore = rawScore + factors.accidentHistoryScore
        
        // Clamp to 0-10 range
        return max(0.0, min(10.0, finalScore))
    }
    
    // MARK: - Safety Recommendations
    
    /// Generate safety recommendations based on analysis
    private func generateSafetyRecommendations(factors: SafetyFactors, score: Double) -> [SafetyRecommendation] {
        var recommendations: [SafetyRecommendation] = []
        
        if score < (10.0 - maximumAcceptableRisk) {
            recommendations.append(SafetyRecommendation(
                priority: .critical,
                title: "Route Safety Warning",
                description: "This route has a safety score of \(String(format: "%.1f", score))/10, below the minimum required \(10.0 - maximumAcceptableRisk)/10.",
                actionRequired: true
            ))
        }
        
        if factors.schoolZoneScore < 50 {
            recommendations.append(SafetyRecommendation(
                priority: .medium,
                title: "Limited School Zone Coverage",
                description: "Consider routes that pass through more school zones for enhanced safety.",
                actionRequired: false
            ))
        }
        
        if factors.accidentHistoryScore < -0.5 {
            recommendations.append(SafetyRecommendation(
                priority: .high,
                title: "Accident-Prone Areas Detected",
                description: "This route passes through areas with historical accident data. Extra caution recommended.",
                actionRequired: true
            ))
        }
        
        return recommendations
    }
    
    // MARK: - Data Loading
    
    /// Load school and accident data from APIs
    private func loadSafetyData() async {
        print("📥 Loading safety data from ACT Government APIs...")
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadSchoolData()
            }
            
            group.addTask {
                await self.loadAccidentData()
            }
        }
        
        lastAnalysisDate = Date()
        print("✅ Safety data loading complete")
    }
    
    /// Load safety data if not already cached or stale
    private func loadSafetyDataIfNeeded() async {
        guard cachedSchoolLocations.isEmpty || cachedAccidentData.isEmpty ||
              lastAnalysisDate?.timeIntervalSinceNow ?? -3600 < -3600 else {
            return // Data is fresh
        }
        
        await loadSafetyData()
    }
    
    /// Load school data from ACT API
    private func loadSchoolData() async {
        cachedSchoolLocations = (try? await schoolDataService.fetchSchoolLocations()) ?? MockSafetyData.canberraSchools
        print("🏫 Loaded \(cachedSchoolLocations.count) school locations")
    }
    
    /// Load accident data from ACT API
    private func loadAccidentData() async {
        cachedAccidentData = (try? await accidentDataService.fetchAccidentData()) ?? MockSafetyData.accidentLocations
        print("📊 Loaded \(cachedAccidentData.count) accident records")
    }
    
    // MARK: - Helper Methods
    
    /// Extract coordinate points from MKRoute for analysis
    private func extractRouteCoordinates(from route: MKRoute) -> [CLLocationCoordinate2D] {
        let polyline = route.polyline
        let pointCount = polyline.pointCount
        let coordinates = UnsafeMutablePointer<CLLocationCoordinate2D>.allocate(capacity: pointCount)
        defer { coordinates.deallocate() }
        
        polyline.getCoordinates(coordinates, range: NSRange(location: 0, length: pointCount))
        
        return Array(UnsafeBufferPointer(start: coordinates, count: pointCount))
    }
}

// MARK: - Data Models

/// Risk analysis result for a specific route
struct RouteRiskAnalysis {
    let route: MKRoute
    let overallRiskScore: Double
    let riskFactors: RiskFactors
    let isAcceptableRisk: Bool
    let recommendations: [RiskRecommendation]
    let lastAnalyzed: Date
    
    var riskLevel: RiskLevel {
        switch overallRiskScore {
        case 0.0...1.0: return .low
        case 1.0...3.0: return .medium
        case 3.0...6.0: return .high
        default: return .critical
        }
    }
    
    // Backwards compatibility properties
    var overallScore: Double {
        return 10.0 - overallRiskScore // Convert risk to safety score for compatibility
    }
    
    var safetyFactors: SafetyFactors {
        return SafetyFactors(
            schoolZoneScore: riskFactors.schoolZoneRiskReduction,
            roadTypeScore: 10.0 - riskFactors.roadTypeRiskScore,
            trafficLightScore: 10.0 + riskFactors.trafficLightRiskReduction,
            accidentHistoryScore: -riskFactors.accidentRiskIncrease
        )
    }
    
    var meetsMinimumSafety: Bool {
        return isAcceptableRisk
    }
}

/// Individual risk factors analyzed
struct RiskFactors {
    var schoolZoneRiskReduction: Double = 0.0      // Percentage coverage (reduces risk)
    var roadTypeRiskScore: Double = 0.0            // Risk contribution from road type
    var trafficLightRiskReduction: Double = 0.0    // Risk reduction from traffic lights
    var accidentRiskIncrease: Double = 0.0         // Risk increase from accident history
}

/// Individual safety factors analyzed (backwards compatibility)
struct SafetyFactors {
    var schoolZoneScore: Double = 0.0      // Percentage coverage
    var roadTypeScore: Double = 1.0        // Multiplier
    var trafficLightScore: Double = 1.0    // Multiplier
    var accidentHistoryScore: Double = 0.0 // Penalty/bonus
}

/// Risk recommendation for route improvement
struct RiskRecommendation {
    let priority: RecommendationPriority
    let title: String
    let description: String
    let actionRequired: Bool
}

/// Safety recommendation for route improvement (backwards compatibility)
struct SafetyRecommendation {
    let priority: RecommendationPriority
    let title: String
    let description: String
    let actionRequired: Bool
}

/// Recommendation priority levels
enum RecommendationPriority: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}



/// School location data model
struct SchoolLocation: Identifiable, Codable {
    let id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String
    let schoolType: String
    
    init(name: String, latitude: Double, longitude: Double, address: String, schoolType: String) {
        self.id = UUID()
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.schoolType = schoolType
    }
}

/// Accident location data model
struct AccidentLocation: Identifiable, Codable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let severity: String
    let date: Date
    let description: String
    
    init(latitude: Double, longitude: Double, severity: String, date: Date, description: String) {
        self.id = UUID()
        self.latitude = latitude
        self.longitude = longitude
        self.severity = severity
        self.date = date
        self.description = description
    }
}
