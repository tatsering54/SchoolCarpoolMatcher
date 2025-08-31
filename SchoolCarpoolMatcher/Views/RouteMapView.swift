//
//  RouteMapView.swift
//  SchoolCarpoolMatcher
//
//  Map view component for displaying route safety analysis
//  Shows route polylines, safety annotations, and interactive controls
//  Applied Rule: iOS native patterns and comprehensive debug logging
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Route Map View
/// SwiftUI component for displaying routes with safety analysis on Apple Maps
/// Integrates with F2.1 safety scoring and route visualization
struct RouteMapView: View {
    
    // MARK: - Properties
    let analysis: RouteRiskAnalysis
    let sourceCoordinate: CLLocationCoordinate2D?
    let destinationCoordinate: CLLocationCoordinate2D?
    
    @State private var region: MKCoordinateRegion
    @State private var showingRouteDetails = false
    @State private var selectedAnnotation: RouteAnnotation?
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Initialization
    init(analysis: RouteRiskAnalysis, sourceCoordinate: CLLocationCoordinate2D? = nil, destinationCoordinate: CLLocationCoordinate2D? = nil) {
        self.analysis = analysis
        self.sourceCoordinate = sourceCoordinate
        self.destinationCoordinate = destinationCoordinate
        
        // Initialize region based on route or default to Canberra
        let defaultCenter = CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300)
        let center = sourceCoordinate ?? defaultCenter
        
        self._region = State(initialValue: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
        
        print("🗺️ RouteMapView initialized")
        print("   📍 Source: \(sourceCoordinate.map { "(\(String(format: "%.4f", $0.latitude)), \(String(format: "%.4f", $0.longitude)))" } ?? "nil")")
        print("   📍 Destination: \(destinationCoordinate.map { "(\(String(format: "%.4f", $0.latitude)), \(String(format: "%.4f", $0.longitude)))" } ?? "nil")")
        print("   🛡️ Safety Score: \(String(format: "%.2f", analysis.overallScore))/10")
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                // Map View (using modern MapKit API with backward compatibility)
                if #available(iOS 17.0, *) {
                    Map(position: .constant(.region(region))) {
                        ForEach(mapAnnotations) { annotation in
                            Annotation(annotation.title, coordinate: annotation.coordinate) {
                                annotationView(for: annotation)
                            }
                        }
                    }
                    .onMapCameraChange { context in
                        region = context.region
                    }
                    .onAppear {
                        updateRegionForRoute()
                    }
                } else {
                    Map(coordinateRegion: $region, annotationItems: mapAnnotations) { annotation in
                        MapAnnotation(coordinate: annotation.coordinate) {
                            annotationView(for: annotation)
                        }
                    }
                    .onAppear {
                        updateRegionForRoute()
                    }
                }
                
                // Overlay Controls
                VStack {
                    Spacer()
                    
                    // Route Info Card
                    routeInfoCard
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle("Route Safety Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Details") {
                        showingRouteDetails = true
                    }
                }
            }
            .sheet(isPresented: $showingRouteDetails) {
                RouteDetailsSheet(analysis: analysis)
            }
        }
    }
    
    // MARK: - Map Annotations
    private var mapAnnotations: [RouteAnnotation] {
        var annotations: [RouteAnnotation] = []
        
        // Source annotation
        if let source = sourceCoordinate {
            annotations.append(RouteAnnotation(
                id: "source",
                coordinate: source,
                type: .source,
                title: "Start Location",
                subtitle: "Pickup Point"
            ))
        }
        
        // Destination annotation
        if let destination = destinationCoordinate {
            annotations.append(RouteAnnotation(
                id: "destination",
                coordinate: destination,
                type: .destination,
                title: "School",
                subtitle: "Drop-off Point"
            ))
        }
        
        // Safety concern annotations (mock data for demonstration)
        if !analysis.meetsMinimumSafety {
            // Add safety warning annotations along the route
            let midpoint = calculateMidpoint()
            annotations.append(RouteAnnotation(
                id: "safety_warning",
                coordinate: midpoint,
                type: .safetyWarning,
                title: "Safety Concern",
                subtitle: "Score: \(String(format: "%.1f", analysis.overallScore))/10"
            ))
        }
        
        return annotations
    }
    
    // MARK: - Annotation Views
    private func annotationView(for annotation: RouteAnnotation) -> some View {
        Button(action: {
            selectedAnnotation = annotation
        }) {
            VStack(spacing: 4) {
                // Icon
                Image(systemName: annotation.type.iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(annotation.type.color)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                // Label (for important annotations)
                if annotation.type == .safetyWarning {
                    Text(annotation.title)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(4)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Route Info Card
    private var routeInfoCard: some View {
        VStack(spacing: 12) {
            // Safety Score Header
            HStack {
                Image(systemName: analysis.riskLevel.iconName)
                    .foregroundColor(riskLevelColor(analysis.riskLevel))
                
                Text("Safety Score: \(String(format: "%.1f", analysis.overallScore))/10")
                    .font(.headline.weight(.semibold))
                
                Spacer()
                
                Text(analysis.riskLevel.rawValue.capitalized)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(riskLevelColor(analysis.riskLevel))
            }
            
            // Route Stats
            HStack(spacing: 20) {
                routeStatItem(
                    icon: "clock",
                    title: "Duration",
                    value: formatDuration(analysis.route.expectedTravelTime)
                )
                
                routeStatItem(
                    icon: "road.lanes",
                    title: "Distance",
                    value: formatDistance(analysis.route.distance)
                )
                
                routeStatItem(
                    icon: "shield.checkered",
                    title: "Safety",
                    value: analysis.meetsMinimumSafety ? "✓ Pass" : "⚠ Fail"
                )
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Open in Maps") {
                    openInAppleMaps()
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue)
                .cornerRadius(8)
                
                Button("Share Route") {
                    shareRoute()
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private func routeStatItem(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func updateRegionForRoute() {
        print("🗺️ Updating map region for route visualization")
        
        guard let source = sourceCoordinate,
              let destination = destinationCoordinate else {
            print("   ⚠️ Missing coordinates, using default region")
            return
        }
        
        // Calculate region that encompasses both points
        let minLat = min(source.latitude, destination.latitude)
        let maxLat = max(source.latitude, destination.latitude)
        let minLon = min(source.longitude, destination.longitude)
        let maxLon = max(source.longitude, destination.longitude)
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLat - minLat, 0.01) * 1.5, // Add 50% padding
            longitudeDelta: max(maxLon - minLon, 0.01) * 1.5
        )
        
        // Note: In iOS 17+, we'd use MapCameraPosition for animation
        // For now, we'll update the region directly
        region = MKCoordinateRegion(center: center, span: span)
        
        print("   ✅ Region updated to center: (\(String(format: "%.4f", center.latitude)), \(String(format: "%.4f", center.longitude)))")
    }
    
    private func calculateMidpoint() -> CLLocationCoordinate2D {
        guard let source = sourceCoordinate,
              let destination = destinationCoordinate else {
            return CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300)
        }
        
        return CLLocationCoordinate2D(
            latitude: (source.latitude + destination.latitude) / 2,
            longitude: (source.longitude + destination.longitude) / 2
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }
    
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let kilometers = distance / 1000
        return String(format: "%.1f km", kilometers)
    }
    
    private func openInAppleMaps() {
        print("📱 Opening route in Apple Maps")
        
        guard let source = sourceCoordinate,
              let destination = destinationCoordinate else {
            print("   ❌ Missing coordinates for Apple Maps")
            return
        }
        
        let sourcePlacemark = MKPlacemark(coordinate: source)
        let destinationPlacemark = MKPlacemark(coordinate: destination)
        
        let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
        let destinationMapItem = MKMapItem(placemark: destinationPlacemark)
        
        sourceMapItem.name = "Pickup Location"
        destinationMapItem.name = "School"
        
        MKMapItem.openMaps(
            with: [sourceMapItem, destinationMapItem],
            launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ]
        )
    }
    
    private func shareRoute() {
        print("📤 Sharing route information")
        // Implementation for sharing route details
        // Could integrate with iOS share sheet
    }
    
    private func riskLevelColor(_ riskLevel: RiskLevel) -> Color {
        switch riskLevel {
        case .low:
            return .green
        case .medium:
            return .yellow
        case .high:
            return .orange
        case .critical:
            return .red
        }
    }
}

// MARK: - Route Annotation Model
struct RouteAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let type: AnnotationType
    let title: String
    let subtitle: String
    
    enum AnnotationType {
        case source
        case destination
        case safetyWarning
        case pickupPoint
        
        var iconName: String {
            switch self {
            case .source:
                return "figure.walk.circle"
            case .destination:
                return "graduationcap.circle"
            case .safetyWarning:
                return "exclamationmark.triangle"
            case .pickupPoint:
                return "person.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .source:
                return .green
            case .destination:
                return .blue
            case .safetyWarning:
                return .red
            case .pickupPoint:
                return .orange
            }
        }
    }
}

// MARK: - Route Details Sheet
struct RouteDetailsSheet: View {
    let analysis: RouteRiskAnalysis
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            SafetyWarningView(
                analysis: analysis, 
                showDetailedBreakdown: true,
                sourceCoordinate: nil,
                destinationCoordinate: nil
            )
            .navigationTitle("Route Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Extensions for Risk Level Icon Names
extension RiskLevel {
    var iconName: String {
        switch self {
        case .low:
            return "shield.checkered"
        case .medium:
            return "shield"
        case .high:
            return "exclamationmark.shield"
        case .critical:
            return "xmark.shield"
        }
    }
}

// MARK: - Preview Provider
struct RouteMapView_Previews: PreviewProvider {
    static var previews: some View {
        RouteMapView(
            analysis: RouteRiskAnalysis(
                route: MockRoute(distance: 5000, expectedTravelTime: 600, polyline: MKPolyline()),
                overallRiskScore: 3.5, // Moderate risk
                riskFactors: RiskFactors(
                    schoolZoneRiskReduction: 45.0,
                    roadTypeRiskScore: 1.2,
                    trafficLightRiskReduction: -0.8,
                    accidentRiskIncrease: 0.5
                ),
                isAcceptableRisk: false,
                recommendations: [
                    RiskRecommendation(
                        priority: .high,
                        title: "High Risk Route Warning",
                        description: "This route has risk concerns that exceed acceptable levels.",
                        actionRequired: true
                    )
                ],
                lastAnalyzed: Date()
            ),
            sourceCoordinate: CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300),
            destinationCoordinate: CLLocationCoordinate2D(latitude: -35.2500, longitude: 149.1500)
        )
    }
}

// MARK: - Mock Route for Preview
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
