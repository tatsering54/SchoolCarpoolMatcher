//
//  SimpleRouteAdaptationEngine.swift
//  SchoolCarpoolMatcher
//
//  Simplified F2.2 Real-time route adaptation service
//  Applied Rule: Safety-first routing and comprehensive debug logging
//

import Foundation
import MapKit
import CoreLocation

// MARK: - Simple Route Adaptation Engine
/// Simplified version of route adaptation for F2.2 demo
@MainActor
class SimpleRouteAdaptationEngine: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isMonitoring = false
    @Published var currentWeatherCondition: SimpleWeatherCondition?
    @Published var activeTrafficIncidents: [SimpleTrafficIncident] = []
    @Published var routeHistory: [SimpleRouteHistoryEntry] = []
    @Published var lastAdaptation: SimpleAdaptedRoute?
    
    // MARK: - Configuration
    private let monitoringInterval: TimeInterval = 300 // 5 minutes
    private let maxRouteHistoryEntries = 50
    
    // MARK: - Private Properties
    private var monitoringTimer: Timer?
    
    // MARK: - Initialization
    init() {
        print("🔄 SimpleRouteAdaptationEngine initialized")
        print("   🌤️ Weather monitoring: \(monitoringInterval/60)min intervals")
        print("   📊 Route history limit: \(maxRouteHistoryEntries) entries")
        
        // Load mock data for demo
        loadMockData()
    }
    
    // MARK: - Public Methods
    
    /// Start real-time monitoring for route adaptation
    func startMonitoring() {
        print("🔄 Starting real-time route monitoring...")
        
        guard !isMonitoring else {
            print("⚠️ Route monitoring already active")
            return
        }
        
        isMonitoring = true
        
        // Start monitoring timer
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateConditions()
            }
        }
        
        print("✅ Real-time route monitoring started")
    }
    
    /// Stop real-time monitoring
    func stopMonitoring() {
        print("🛑 Stopping real-time route monitoring...")
        
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        print("✅ Real-time route monitoring stopped")
    }
    
    /// Adapt route for current conditions (F2.2 core implementation)
    func adaptRouteForConditions(
        originalRoute: Route,
        weather: SimpleWeatherCondition,
        trafficIncidents: [SimpleTrafficIncident]
    ) async -> SimpleAdaptedRoute {
        
        print("🔄 Adapting route for current conditions...")
        print("   🌤️ Weather: \(weather.condition)")
        print("   🚦 Traffic incidents: \(trafficIncidents.count)")
        
        let adaptedRoute = originalRoute
        var adaptationReasons: [String] = []
        var estimatedDelay: TimeInterval = 0
        
        // 1. Weather-based adaptations
        if weather.requiresCoveredPickup {
            print("   ☔ Weather requires covered pickup locations")
            adaptationReasons.append("Weather protection required")
            estimatedDelay += 300 // 5 minutes for covered pickup
        }
        
        if weather.reducesVisibility {
            print("   🌫️ Weather reduces visibility - adjusting route")
            adaptationReasons.append("Low visibility conditions")
            estimatedDelay += 180 // 3 minutes for careful driving
        }
        
        // 2. Traffic incident adaptations
        for incident in trafficIncidents {
            print("   🚧 Processing traffic incident: \(incident.type)")
            estimatedDelay += incident.estimatedDelay
            adaptationReasons.append("Avoiding \(incident.type)")
        }
        
        // 3. Create adapted route result
        let adaptation = SimpleAdaptedRoute(
            originalRoute: originalRoute,
            adaptedRoute: adaptedRoute,
            estimatedDelay: estimatedDelay,
            adaptationReasons: adaptationReasons,
            weatherCondition: weather,
            trafficIncidents: trafficIncidents,
            adaptedAt: Date()
        )
        
        // 4. Store in history
        addToRouteHistory(adaptation)
        
        // 5. Update published property
        lastAdaptation = adaptation
        
        print("✅ Route adaptation complete:")
        print("   ⏱️ Additional delay: \(String(format: "%.1f", estimatedDelay/60))min")
        print("   📝 Reasons: \(adaptationReasons.joined(separator: ", "))")
        
        return adaptation
    }
    
    /// Recalculate pickup times for adapted route
    func recalculatePickupTimes(for adaptedRoute: SimpleAdaptedRoute) async -> [SimplePickupTimeUpdate] {
        print("⏰ Recalculating pickup times for adapted route...")
        
        var updates: [SimplePickupTimeUpdate] = []
        
        for (index, pickupPoint) in adaptedRoute.adaptedRoute.pickupPoints.enumerated() {
            let originalTime = adaptedRoute.originalRoute.pickupPoints[index].estimatedTime
            let newTime = originalTime.addingTimeInterval(adaptedRoute.estimatedDelay)
            
            let update = SimplePickupTimeUpdate(
                familyId: pickupPoint.familyId,
                originalTime: originalTime,
                newTime: newTime,
                delay: adaptedRoute.estimatedDelay,
                reason: adaptedRoute.adaptationReasons.joined(separator: ", ")
            )
            
            updates.append(update)
        }
        
        print("✅ Pickup times recalculated for \(updates.count) families")
        return updates
    }
    
    /// Notify group members of route changes (simplified)
    func notifyGroupMembers(
        groupId: UUID,
        adaptedRoute: SimpleAdaptedRoute,
        pickupUpdates: [SimplePickupTimeUpdate]
    ) async {
        print("📢 Notifying group members of route changes...")
        print("   👥 Group: \(groupId)")
        print("   ⏱️ Delay: \(String(format: "%.1f", adaptedRoute.estimatedDelay/60))min")
        print("   📝 Reason: \(adaptedRoute.adaptationReason)")
        
        // In a real implementation, this would send push notifications
        // For demo, we just log the notification
        
        print("✅ Route change notifications sent (demo mode)")
    }
    
    // MARK: - Private Methods
    
    /// Update weather and traffic conditions
    private func updateConditions() async {
        print("🔄 Updating weather and traffic conditions...")
        
        // Simulate weather update
        currentWeatherCondition = generateMockWeather()
        
        // Simulate traffic incidents update
        activeTrafficIncidents = generateMockTrafficIncidents()
        
        print("✅ Conditions updated:")
        print("   🌤️ Weather: \(currentWeatherCondition?.condition ?? "Unknown")")
        print("   🚦 Traffic incidents: \(activeTrafficIncidents.count)")
    }
    
    /// Load mock data for demo
    private func loadMockData() {
        currentWeatherCondition = SimpleWeatherCondition(
            condition: "Clear",
            temperature: 18.0,
            visibility: 10000,
            precipitation: 0.0,
            timestamp: Date()
        )
        
        activeTrafficIncidents = [
            SimpleTrafficIncident(
                id: UUID(),
                type: "Roadwork",
                description: "Lane closure on Tuggeranong Parkway",
                estimatedDelay: 300,
                reportedAt: Date()
            )
        ]
        
        print("📊 Loaded mock data for F2.2 demo")
    }
    
    /// Generate mock weather for demo
    private func generateMockWeather() -> SimpleWeatherCondition {
        let conditions = ["Clear", "Cloudy", "Light Rain", "Heavy Rain", "Fog"]
        let randomCondition = conditions.randomElement() ?? "Clear"
        
        return SimpleWeatherCondition(
            condition: randomCondition,
            temperature: Double.random(in: 5...25),
            visibility: randomCondition == "Fog" ? 500 : 10000,
            precipitation: randomCondition.contains("Rain") ? Double.random(in: 1...10) : 0,
            timestamp: Date()
        )
    }
    
    /// Generate mock traffic incidents for demo
    private func generateMockTrafficIncidents() -> [SimpleTrafficIncident] {
        let incidents = [
            "Accident on Northbourne Avenue",
            "Roadwork on Commonwealth Avenue",
            "Heavy traffic near schools",
            "Road closure for event"
        ]
        
        let randomCount = Int.random(in: 0...2)
        
        return (0..<randomCount).map { _ in
            SimpleTrafficIncident(
                id: UUID(),
                type: "Traffic",
                description: incidents.randomElement() ?? "Traffic incident",
                estimatedDelay: TimeInterval.random(in: 120...600),
                reportedAt: Date()
            )
        }
    }
    
    /// Add adaptation to route history
    private func addToRouteHistory(_ adaptation: SimpleAdaptedRoute) {
        let historyEntry = SimpleRouteHistoryEntry(
            id: UUID(),
            originalRoute: adaptation.originalRoute,
            adaptedRoute: adaptation.adaptedRoute,
            adaptationReasons: adaptation.adaptationReasons,
            estimatedDelay: adaptation.estimatedDelay,
            timestamp: adaptation.adaptedAt,
            weatherCondition: adaptation.weatherCondition,
            trafficIncidents: adaptation.trafficIncidents
        )
        
        routeHistory.insert(historyEntry, at: 0)
        
        // Limit history size
        if routeHistory.count > maxRouteHistoryEntries {
            routeHistory = Array(routeHistory.prefix(maxRouteHistoryEntries))
        }
        
        print("📊 Route adaptation added to history (\(routeHistory.count) entries)")
    }
}

// MARK: - Simplified Data Models

/// Simplified weather condition for F2.2 demo
struct SimpleWeatherCondition {
    let condition: String
    let temperature: Double
    let visibility: Double // meters
    let precipitation: Double // mm/hour
    let timestamp: Date
    
    var requiresCoveredPickup: Bool {
        precipitation > 2.0 || condition.contains("Heavy Rain")
    }
    
    var reducesVisibility: Bool {
        visibility < 1000 || condition == "Fog" || condition.contains("Heavy Rain")
    }
}

/// Simplified traffic incident for F2.2 demo
struct SimpleTrafficIncident: Identifiable {
    let id: UUID
    let type: String
    let description: String
    let estimatedDelay: TimeInterval
    let reportedAt: Date
}

/// Simplified adapted route result
struct SimpleAdaptedRoute {
    let originalRoute: Route
    let adaptedRoute: Route
    let estimatedDelay: TimeInterval
    let adaptationReasons: [String]
    let weatherCondition: SimpleWeatherCondition
    let trafficIncidents: [SimpleTrafficIncident]
    let adaptedAt: Date
    
    var adaptationReason: String {
        adaptationReasons.joined(separator: ", ")
    }
}

/// Simplified pickup time update information
struct SimplePickupTimeUpdate {
    let familyId: UUID
    let originalTime: Date
    let newTime: Date
    let delay: TimeInterval
    let reason: String
}

/// Simplified route history entry
struct SimpleRouteHistoryEntry: Identifiable {
    let id: UUID
    let originalRoute: Route
    let adaptedRoute: Route
    let adaptationReasons: [String]
    let estimatedDelay: TimeInterval
    let timestamp: Date
    let weatherCondition: SimpleWeatherCondition
    let trafficIncidents: [SimpleTrafficIncident]
}
