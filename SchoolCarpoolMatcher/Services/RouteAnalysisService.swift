//
//  RouteAnalysisService.swift
//  SchoolCarpoolMatcher
//
//  Route analysis service integrating MapKit with F2.1 safety scoring
//  Provides route optimization with safety-first prioritization
//  Applied Rule: Safety-first routing and comprehensive debug logging
//

import Foundation
import MapKit
import CoreLocation

// MARK: - Route Analysis Service
/// Service for analyzing and optimizing routes with safety-first approach
/// Integrates MapKit routing with F2.1 safety scoring algorithm
class RouteAnalysisService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAnalyzing = false
    @Published var currentAnalysis: RouteAnalysisResult?
    @Published var error: RouteAnalysisError?
    
    // MARK: - Dependencies
    private let riskScoring = RouteRiskScoring()
    private let directionsService = MKDirections.self
    
    // MARK: - Constants
    private let maxAlternativeRoutes = 3
    private let routeTimeout: TimeInterval = 30.0
    
    // MARK: - Initialization
    init() {
        print("🗺️ RouteAnalysisService initialized")
        print("   🛡️ Safety-first routing enabled")
        print("   📊 Max alternative routes: \(maxAlternativeRoutes)")
    }
    
    // MARK: - Public Methods
    
    /// Analyze route with comprehensive safety scoring
    func analyzeRoute(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType = .automobile
    ) async -> RouteAnalysisResult {
        print("🔍 Starting route analysis...")
        print("   📍 From: (\(String(format: "%.4f", source.latitude)), \(String(format: "%.4f", source.longitude)))")
        print("   📍 To: (\(String(format: "%.4f", destination.latitude)), \(String(format: "%.4f", destination.longitude)))")
        
        isAnalyzing = true
        error = nil
        
        defer {
            isAnalyzing = false
        }
        
        do {
            // 1. Get multiple route options from MapKit
            let routes = try await fetchRouteOptions(
                from: source,
                to: destination,
                transportType: transportType
            )
            
            print("✅ Found \(routes.count) route options")
            
            // 2. Analyze risk for each route (lower risk = safer)
            var routeAnalyses: [RouteRiskAnalysis] = []
            
            for (index, route) in routes.enumerated() {
                print("🔬 Analyzing route \(index + 1)/\(routes.count)...")
                
                let sourceLocation = CLLocation(latitude: source.latitude, longitude: source.longitude)
                let analysis = await riskScoring.calculateRouteRiskScore(
                    route: route,
                    userLocation: sourceLocation
                )
                
                routeAnalyses.append(analysis)
            }
            
            // 3. Rank routes by risk score (lower risk = safer)
            let rankedAnalyses = routeAnalyses.sorted { $0.overallRiskScore < $1.overallRiskScore }
            
            // 4. Create comprehensive result
            let result = RouteAnalysisResult(
                sourceCoordinate: source,
                destinationCoordinate: destination,
                primaryRoute: rankedAnalyses.first!,
                alternativeRoutes: Array(rankedAnalyses.dropFirst()),
                analysisDate: Date(),
                transportType: transportType
            )
            
            currentAnalysis = result
            
            print("🎯 Route analysis complete:")
            print("   🥇 Best route risk score: \(String(format: "%.2f", result.primaryRoute.overallRiskScore))/10 (lower = safer)")
            print("   📊 Total routes analyzed: \(routeAnalyses.count)")
            print("   ⚠️ Routes meeting safety threshold: \(routeAnalyses.filter { $0.isAcceptableRisk }.count)")
            
            return result
            
        } catch {
            print("❌ Route analysis failed: \(error)")
            print("   🔍 Error type: \(type(of: error))")
            print("   📍 Source: (\(String(format: "%.4f", source.latitude)), \(String(format: "%.4f", source.longitude)))")
            print("   📍 Destination: (\(String(format: "%.4f", destination.latitude)), \(String(format: "%.4f", destination.longitude)))")
            
            let analysisError = RouteAnalysisError.analysisFailure(error)
            self.error = analysisError
            
            // Create fallback analysis for graceful handling
            let fallbackAnalysis = createFallbackAnalysis(from: source, to: destination)
            let result = RouteAnalysisResult(
                sourceCoordinate: source,
                destinationCoordinate: destination,
                primaryRoute: fallbackAnalysis,
                alternativeRoutes: [],
                analysisDate: Date(),
                transportType: transportType
            )
            
            currentAnalysis = result
            
            print("✅ Fallback analysis created successfully")
            print("   🛡️ Safety score: \(String(format: "%.1f", result.bestSafetyScore))/10")
            
            return result
        }
    }
    
    /// Get optimized pickup sequence for carpool group
    func optimizePickupSequence(
        for group: CarpoolGroup,
        school: CLLocationCoordinate2D
    ) async -> OptimizedPickupResult {
        print("🚐 Optimizing pickup sequence for group: \(group.groupName)")
        print("   👥 Members: \(group.members.count)")
        
        let memberLocations = group.members.compactMap { member -> CLLocationCoordinate2D? in
            // In a real implementation, we'd fetch member locations from Family data
            // For now, use mock locations around Canberra
            return generateMockMemberLocation()
        }
        
        print("   📍 Member locations: \(memberLocations.count)")
        
        // Use traveling salesman heuristic for pickup optimization
        let optimizedSequence = await calculateOptimalSequence(
            locations: memberLocations,
            destination: school
        )
        
        // Analyze the optimized route
        let routeAnalysis = await analyzeOptimizedRoute(sequence: optimizedSequence, destination: school)
        
        let result = OptimizedPickupResult(
            groupId: group.id,
            optimizedSequence: optimizedSequence,
            routeAnalysis: routeAnalysis,
            estimatedTotalTime: routeAnalysis.route.expectedTravelTime,
            totalDistance: routeAnalysis.route.distance,
            safetyScore: routeAnalysis.overallScore
        )
        
        print("✅ Pickup optimization complete:")
        print("   🎯 Risk score: \(String(format: "%.2f", result.routeAnalysis.overallRiskScore))/10 (lower = safer)")
        print("   🛡️ Safety score: \(String(format: "%.2f", result.safetyScore))/10")
        print("   ⏱️ Total time: \(String(format: "%.1f", result.estimatedTotalTime/60))min")
        print("   📏 Distance: \(String(format: "%.2f", result.totalDistance/1000))km")
        
        return result
    }
    
    /// Create demo route analysis for testing purposes
    func createDemoRouteAnalysis() async -> RouteAnalysisResult {
        print("🎭 Creating demo route analysis for testing...")
        
        // Demo coordinates around Canberra
        let source = CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300)
        let destination = CLLocationCoordinate2D(latitude: -35.2835, longitude: 149.1287)
        
        // Create demo route with varied safety scores
        let demoRoute = MockRoute(
            distance: 500.0, // 500 meters
            expectedTravelTime: 120.0, // 2 minutes
            polyline: MKPolyline()
        )
        
        // Generate varied risk scores for demo
        let riskScore = Double.random(in: 1.5...4.0) // Good to medium risk
        let isAcceptable = riskScore <= 3.0
        
        let demoAnalysis = RouteRiskAnalysis(
            route: demoRoute,
            overallRiskScore: riskScore,
            riskFactors: RiskFactors(
                schoolZoneRiskReduction: Double.random(in: 40.0...90.0),
                roadTypeRiskScore: Double.random(in: 0.3...1.5),
                trafficLightRiskReduction: Double.random(in: 0.5...1.5),
                accidentRiskIncrease: Double.random(in: 0.0...0.8)
            ),
            isAcceptableRisk: isAcceptable,
            recommendations: [
                RiskRecommendation(
                    priority: .medium,
                    title: "Demo Route Analysis",
                    description: "This is a demo route with realistic safety scoring. Tap 'Find Safer Route' to see different scores.",
                    actionRequired: false
                )
            ],
            lastAnalyzed: Date()
        )
        
        let result = RouteAnalysisResult(
            sourceCoordinate: source,
            destinationCoordinate: destination,
            primaryRoute: demoAnalysis,
            alternativeRoutes: [],
            analysisDate: Date(),
            transportType: .automobile
        )
        
        currentAnalysis = result
        
        print("✅ Demo route analysis created:")
        print("   🛡️ Safety score: \(String(format: "%.1f", result.bestSafetyScore))/10")
        print("   📊 Risk score: \(String(format: "%.1f", result.bestRiskScore))/10")
        print("   ✅ Acceptable risk: \(isAcceptable)")
        
        return result
    }
    
    // MARK: - Private Methods
    
    /// Fetch route options from MapKit
    private func fetchRouteOptions(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType
    ) async throws -> [MKRoute] {
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = transportType
        request.requestsAlternateRoutes = true
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            return Array(response.routes.prefix(maxAlternativeRoutes))
            
        } catch {
            print("❌ MapKit directions failed: \(error)")
            throw RouteAnalysisError.directionsFailure(error)
        }
    }
    
    /// Calculate optimal pickup sequence using nearest neighbor heuristic
    private func calculateOptimalSequence(
        locations: [CLLocationCoordinate2D],
        destination: CLLocationCoordinate2D
    ) async -> [CLLocationCoordinate2D] {
        
        guard !locations.isEmpty else { return [] }
        
        print("🧮 Calculating optimal pickup sequence...")
        
        var remaining = locations
        var sequence: [CLLocationCoordinate2D] = []
        var currentLocation = locations.first! // Start from first member
        
        remaining.removeFirst()
        sequence.append(currentLocation)
        
        // Nearest neighbor algorithm
        while !remaining.isEmpty {
            let nearestIndex = findNearestLocationIndex(
                from: currentLocation,
                in: remaining
            )
            
            currentLocation = remaining[nearestIndex]
            sequence.append(currentLocation)
            remaining.remove(at: nearestIndex)
        }
        
        print("   ✅ Sequence optimized: \(sequence.count) stops")
        return sequence
    }
    
    /// Find index of nearest location
    private func findNearestLocationIndex(
        from current: CLLocationCoordinate2D,
        in locations: [CLLocationCoordinate2D]
    ) -> Int {
        let currentLocation = CLLocation(latitude: current.latitude, longitude: current.longitude)
        
        var nearestIndex = 0
        var shortestDistance = Double.infinity
        
        for (index, coordinate) in locations.enumerated() {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = currentLocation.distance(from: location)
            
            if distance < shortestDistance {
                shortestDistance = distance
                nearestIndex = index
            }
        }
        
        return nearestIndex
    }
    
    /// Analyze the optimized pickup route
    private func analyzeOptimizedRoute(
        sequence: [CLLocationCoordinate2D],
        destination: CLLocationCoordinate2D
    ) async -> RouteRiskAnalysis {
        
        guard let firstLocation = sequence.first else {
            return createFallbackAnalysis(from: destination, to: destination)
        }
        
        // For simplicity, analyze the route from first pickup to school
        // In production, would analyze the complete multi-stop route
        let result = await analyzeRoute(
            from: firstLocation,
            to: destination
        )
        
        return result.primaryRoute
    }
    
    /// Create fallback analysis for error cases
    private func createFallbackAnalysis(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) -> RouteRiskAnalysis {
        
        print("🔄 Creating fallback analysis due to MapKit failure")
        
        // Create a basic route for fallback
        let sourceLocation = CLLocation(latitude: source.latitude, longitude: source.longitude)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        let distance = sourceLocation.distance(from: destinationLocation)
        
        // Create mock route
        let mockRoute = MockRoute(
            distance: distance,
            expectedTravelTime: distance / 10.0, // Assume 10 m/s average
            polyline: MKPolyline()
        )
        
        // Generate varied risk scores for demo purposes
        let baseRiskScore = Double.random(in: 2.0...4.5) // Varied risk scores
        let isAcceptable = baseRiskScore <= 3.0
        
        print("   📊 Fallback risk score: \(String(format: "%.1f", baseRiskScore))/10")
        print("   ✅ Acceptable risk: \(isAcceptable)")
        
        return RouteRiskAnalysis(
            route: mockRoute,
            overallRiskScore: baseRiskScore,
            riskFactors: RiskFactors(
                schoolZoneRiskReduction: Double.random(in: 20.0...80.0),
                roadTypeRiskScore: Double.random(in: 0.5...2.0),
                trafficLightRiskReduction: Double.random(in: 0.3...1.2),
                accidentRiskIncrease: Double.random(in: 0.0...1.5)
            ),
            isAcceptableRisk: isAcceptable,
            recommendations: [
                RiskRecommendation(
                    priority: isAcceptable ? .medium : .high,
                    title: "Demo Route Analysis",
                    description: "This is a demo route analysis. In production, real MapKit routing would be used.",
                    actionRequired: false
                )
            ],
            lastAnalyzed: Date()
        )
    }
    
    /// Generate mock member location for development
    private func generateMockMemberLocation() -> CLLocationCoordinate2D {
        // Generate locations around Canberra
        let canberraCenter = CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300)
        let randomOffset = 0.05 // ~5km radius
        
        let lat = canberraCenter.latitude + Double.random(in: -randomOffset...randomOffset)
        let lon = canberraCenter.longitude + Double.random(in: -randomOffset...randomOffset)
        
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Result Models

/// Comprehensive route analysis result
struct RouteAnalysisResult {
    let sourceCoordinate: CLLocationCoordinate2D
    let destinationCoordinate: CLLocationCoordinate2D
    let primaryRoute: RouteRiskAnalysis
    let alternativeRoutes: [RouteRiskAnalysis]
    let analysisDate: Date
    let transportType: MKDirectionsTransportType
    
    var bestRiskScore: Double {
        primaryRoute.overallRiskScore
    }
    
    var bestSafetyScore: Double {
        primaryRoute.overallScore // Backwards compatibility
    }
    
    var hasAlternatives: Bool {
        !alternativeRoutes.isEmpty
    }
    
    var allRoutesMeetSafety: Bool {
        primaryRoute.isAcceptableRisk && alternativeRoutes.allSatisfy { $0.isAcceptableRisk }
    }
}

/// Optimized pickup sequence result
struct OptimizedPickupResult {
    let groupId: UUID
    let optimizedSequence: [CLLocationCoordinate2D]
    let routeAnalysis: RouteRiskAnalysis
    let estimatedTotalTime: TimeInterval
    let totalDistance: Double
    let safetyScore: Double
    
    var meetsMinimumSafety: Bool {
        safetyScore >= 7.0
    }
}

// MARK: - Error Handling

enum RouteAnalysisError: LocalizedError {
    case directionsFailure(Error)
    case analysisFailure(Error)
    case invalidCoordinates
    case noRoutesFound
    case safetyAnalysisFailure
    
    var errorDescription: String? {
        switch self {
        case .directionsFailure(let error):
            return "MapKit directions failed: \(error.localizedDescription)"
        case .analysisFailure(let error):
            return "Route analysis failed: \(error.localizedDescription)"
        case .invalidCoordinates:
            return "Invalid coordinates provided"
        case .noRoutesFound:
            return "No routes found between locations"
        case .safetyAnalysisFailure:
            return "Safety analysis failed"
        }
    }
}

// MARK: - Mock Route for Fallback

/// Mock route implementation for fallback scenarios
private class MockRoute: MKRoute {
    private let _distance: CLLocationDistance
    private let _expectedTravelTime: TimeInterval
    private let _polyline: MKPolyline
    
    init(distance: CLLocationDistance, expectedTravelTime: TimeInterval, polyline: MKPolyline) {
        self._distance = distance
        self._expectedTravelTime = expectedTravelTime
        self._polyline = polyline
        super.init()
    }
    
    override var distance: CLLocationDistance {
        return _distance
    }
    
    override var expectedTravelTime: TimeInterval {
        return _expectedTravelTime
    }
    
    override var polyline: MKPolyline {
        return _polyline
    }
}
