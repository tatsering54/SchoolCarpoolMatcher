//
//  RouteAdaptationTestView.swift
//  SchoolCarpoolMatcher
//
//  Testing view for F2.2 Real-time route adaptation functionality
//  Applied Rule: iOS native patterns and comprehensive debug logging
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Route Adaptation Test View
/// SwiftUI view for testing F2.2 route adaptation features
struct RouteAdaptationTestView: View {
    
    // MARK: - State Objects
    @StateObject private var adaptationEngine = SimpleRouteAdaptationEngine()
    
    // MARK: - State Properties
    @State private var isMonitoring = false
    @State private var showingAdaptationResult = false
    @State private var testRoute: Route?
    @State private var adaptationResult: SimpleAdaptedRoute?
    @State private var pickupUpdates: [SimplePickupTimeUpdate] = []
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - Header
                    headerSection
                    
                    // MARK: - Monitoring Controls
                    monitoringControlsSection
                    
                    // MARK: - Current Conditions
                    currentConditionsSection
                    
                    // MARK: - Route Adaptation Testing
                    routeAdaptationSection
                    
                    // MARK: - Route History
                    routeHistorySection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("F2.2 Route Adaptation")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            setupTestRoute()
        }
        .sheet(isPresented: $showingAdaptationResult) {
            adaptationResultSheet
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🔄 Real-Time Route Adaptation")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text("F2.2: Monitor weather conditions and traffic incidents to adapt routes dynamically")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var monitoringControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🎛️ Monitoring Controls")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                Button(action: {
                    if adaptationEngine.isMonitoring {
                        adaptationEngine.stopMonitoring()
                    } else {
                        adaptationEngine.startMonitoring()
                    }
                }) {
                    HStack {
                        Image(systemName: adaptationEngine.isMonitoring ? "stop.circle.fill" : "play.circle.fill")
                        Text(adaptationEngine.isMonitoring ? "Stop Monitoring" : "Start Monitoring")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(adaptationEngine.isMonitoring ? Color.red : Color.green)
                    .cornerRadius(8)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(adaptationEngine.isMonitoring ? "🟢 Active" : "🔴 Inactive")
                        .font(.subheadline.bold())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var currentConditionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🌤️ Current Conditions")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Weather Condition
            if let weather = adaptationEngine.currentWeatherCondition {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Weather")
                            .font(.subheadline.bold())
                        Text(weather.condition)
                            .font(.title3)
                        Text("\(String(format: "%.1f", weather.temperature))°C")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        if weather.requiresCoveredPickup {
                            Label("Covered Pickup", systemImage: "umbrella.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        if weather.reducesVisibility {
                            Label("Low Visibility", systemImage: "eye.slash")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            // Traffic Incidents
            VStack(alignment: .leading, spacing: 8) {
                Text("🚦 Traffic Incidents (\(adaptationEngine.activeTrafficIncidents.count))")
                    .font(.subheadline.bold())
                
                if adaptationEngine.activeTrafficIncidents.isEmpty {
                    Text("No active incidents")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(adaptationEngine.activeTrafficIncidents) { incident in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(incident.type)
                                    .font(.subheadline.bold())
                                Text(incident.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("+\(String(format: "%.0f", incident.estimatedDelay/60))min")
                                .font(.caption.bold())
                                .foregroundColor(.red)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var routeAdaptationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🗺️ Route Adaptation Testing")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let route = testRoute {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Route")
                        .font(.subheadline.bold())
                    Text("\(route.pickupPoints.count) pickup points")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Distance: \(String(format: "%.1f", route.totalDistance/1000))km")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                Button(action: {
                    testRouteAdaptation()
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Test Route Adaptation")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                
                if let result = adaptationResult {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Adaptation Result")
                            .font(.subheadline.bold())
                        Text("Delay: +\(String(format: "%.1f", result.estimatedDelay/60))min")
                            .font(.subheadline)
                        Text("Reason: \(result.adaptationReason)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("View Details") {
                            showingAdaptationResult = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var routeHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📊 Route History (\(adaptationEngine.routeHistory.count))")
                .font(.headline)
                .foregroundColor(.primary)
            
            if adaptationEngine.routeHistory.isEmpty {
                Text("No route adaptations yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(adaptationEngine.routeHistory.prefix(5)) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.adaptationReasons.joined(separator: ", "))
                                    .font(.subheadline.bold())
                                    .lineLimit(1)
                                Text("+\(String(format: "%.1f", entry.estimatedDelay/60))min delay")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(entry.timestamp, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var adaptationResultSheet: some View {
        NavigationView {
            ScrollView {
                if let result = adaptationResult {
                    VStack(alignment: .leading, spacing: 16) {
                        
                        // Summary
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Route Adaptation Summary")
                                .font(.title2.bold())
                            
                            Text("Additional Delay: +\(String(format: "%.1f", result.estimatedDelay/60)) minutes")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            Text("Adapted at: \(result.adaptedAt, style: .time)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Reasons
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Adaptation Reasons")
                                .font(.headline)
                            
                            ForEach(result.adaptationReasons, id: \.self) { reason in
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(reason)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 2)
                        
                        // Pickup Updates
                        if !pickupUpdates.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Pickup Time Updates")
                                    .font(.headline)
                                
                                ForEach(pickupUpdates, id: \.familyId) { update in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Family: \(update.familyId.uuidString.prefix(8))...")
                                            .font(.subheadline.bold())
                                        Text("New time: \(update.newTime, style: .time)")
                                            .font(.subheadline)
                                        Text("Delay: +\(String(format: "%.0f", update.delay/60))min")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(radius: 2)
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding()
                }
            }
            .navigationTitle("Adaptation Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingAdaptationResult = false
                    }
                }
            }
        }
    }
    
    // MARK: - Methods
    
    private func setupTestRoute() {
        // Create a test route with mock pickup points
        let mockPickups = [
            PickupPoint(
                familyId: UUID(),
                coordinate: CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300),
                address: "123 Test Street, Canberra",
                sequenceOrder: 1,
                estimatedTime: Date().addingTimeInterval(1800) // 30 min from now
            ),
            PickupPoint(
                familyId: UUID(),
                coordinate: CLLocationCoordinate2D(latitude: -35.2500, longitude: 149.1200),
                address: "456 Demo Avenue, Canberra",
                sequenceOrder: 2,
                estimatedTime: Date().addingTimeInterval(2100) // 35 min from now
            )
        ]
        
        testRoute = Route(
            groupId: UUID(),
            pickupPoints: mockPickups,
            safetyScore: 8.5
        )
        
        print("🗺️ Test route created with \(mockPickups.count) pickup points")
    }
    
    private func testRouteAdaptation() {
        guard let route = testRoute,
              let weather = adaptationEngine.currentWeatherCondition else {
            print("❌ Cannot test adaptation: missing route or weather data")
            return
        }
        
        print("🧪 Testing route adaptation...")
        
        Task {
            let result = await adaptationEngine.adaptRouteForConditions(
                originalRoute: route,
                weather: weather,
                trafficIncidents: adaptationEngine.activeTrafficIncidents
            )
            
            adaptationResult = result
            
            // Calculate pickup updates
            pickupUpdates = await adaptationEngine.recalculatePickupTimes(for: result)
            
            // Simulate notification
            await adaptationEngine.notifyGroupMembers(
                groupId: route.groupId,
                adaptedRoute: result,
                pickupUpdates: pickupUpdates
            )
            
            print("✅ Route adaptation test completed")
        }
    }
}

// MARK: - Preview
struct RouteAdaptationTestView_Previews: PreviewProvider {
    static var previews: some View {
        RouteAdaptationTestView()
    }
}
