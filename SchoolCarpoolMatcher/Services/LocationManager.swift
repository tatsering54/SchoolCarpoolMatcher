//
//  LocationManager.swift
//  SchoolCarpoolMatcher
//
//  Location services manager with CoreLocation integration
//  Handles permissions, location updates, and privacy compliance
//  Follows repo rule: Debug logs and safety-first approach
//

import Foundation
import CoreLocation
import Combine

// MARK: - Location Manager
/// Manages location services for family discovery and route optimization
/// Implements F1.1 requirements: permission handling, accuracy, updates
@MainActor
class LocationManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    static let shared = LocationManager()
    
    // MARK: - Published Properties
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var isLocationAvailable: Bool = false
    @Published var locationError: LocationError?
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private let searchRadiusKey = "search_radius_meters"
    private var lastLocationUpdate: Date?
    
    // MARK: - Configuration
    /// Search radius for family discovery (default: 3000m as per F1.1)
    var searchRadius: Double {
        get {
            let radius = UserDefaults.standard.double(forKey: searchRadiusKey)
            return radius > 0 ? radius : 3000.0 // Default 3km
        }
        set {
            UserDefaults.standard.set(newValue, forKey: searchRadiusKey)
            print("📍 Updated search radius to \(Int(newValue))m")
        }
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationManager()
        print("📍 LocationManager initialized with search radius: \(Int(searchRadius))m")
    }
    
    // MARK: - Setup
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest // F1.1 requirement
        locationManager.distanceFilter = 500 // Update when moved >500m (F1.1)
        
        // Check current authorization status
        authorizationStatus = locationManager.authorizationStatus
        updateLocationAvailability()
        
        print("🔧 LocationManager configured with accuracy: \(locationManager.desiredAccuracy)m")
    }
    
    // MARK: - Public Methods
    
    /// Request location permission (F1.1 requirement)
    func requestLocationPermission() {
        print("🔐 Requesting location permission...")
        
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            print("❌ Location access denied/restricted")
            locationError = .permissionDenied
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        @unknown default:
            print("⚠️ Unknown authorization status")
            locationError = .unknown
        }
    }
    
    /// Start location updates with battery optimization
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("❌ Cannot start location updates - permission not granted")
            return
        }
        
        // Check if location services are enabled
        guard CLLocationManager.locationServicesEnabled() else {
            print("❌ Location services not enabled on device")
            locationError = .serviceDisabled
            return
        }
        
        print("▶️ Starting location updates...")
        locationManager.startUpdatingLocation()
        
        // Battery optimization: limit update frequency (F1.1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.optimizeLocationUpdates()
        }
    }
    
    /// Stop location updates
    func stopLocationUpdates() {
        print("⏹️ Stopping location updates")
        locationManager.stopUpdatingLocation()
    }
    
    /// Simulate Canberra location for testing purposes
    func simulateCanberraLocation() {
        print("🧪 Simulating Canberra location for testing...")
        
        let canberraLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300),
            altitude: 550, // Approximate elevation of Canberra
            horizontalAccuracy: 5.0,
            verticalAccuracy: 5.0,
            timestamp: Date()
        )
        
        // Update the current location
        currentLocation = canberraLocation
        locationError = nil
        
        print("📍 Simulated location set: Canberra CBD")
        print("   Coordinates: \(canberraLocation.coordinate.latitude), \(canberraLocation.coordinate.longitude)")
    }
    
    /// Battery optimization: reduce update frequency after initial location
    private func optimizeLocationUpdates() {
        if currentLocation != nil {
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            print("🔋 Optimized location accuracy for battery conservation")
        }
    }
    
    /// Calculate distance between two locations
    func distance(from location1: CLLocation, to location2: CLLocation) -> Double {
        let distance = location1.distance(from: location2)
        print("📏 Calculated distance: \(Int(distance))m")
        return distance
    }
    
    /// Check if location is within search radius
    func isWithinSearchRadius(location: CLLocation) -> Bool {
        guard let userLocation = currentLocation else {
            print("❌ No current location for radius check")
            return false
        }
        
        let distance = distance(from: userLocation, to: location)
        let withinRadius = distance <= searchRadius
        
        print("🎯 Location within radius (\(Int(searchRadius))m): \(withinRadius)")
        return withinRadius
    }
    
    /// Get families within search radius (placeholder for integration)
    func getFamiliesWithinRadius(_ families: [Family]) -> [Family] {
        guard currentLocation != nil else {
            print("❌ No current location for family filtering")
            return []
        }
        
        let nearbyFamilies = families.filter { family in
            let familyLocation = CLLocation(latitude: family.latitude, longitude: family.longitude)
            return isWithinSearchRadius(location: familyLocation)
        }
        
        print("👨‍👩‍👧‍👦 Found \(nearbyFamilies.count) families within \(Int(searchRadius))m radius")
        return nearbyFamilies
    }
    
    // MARK: - Private Helpers
    private func updateLocationAvailability() {
        isLocationAvailable = (authorizationStatus == .authorizedWhenInUse || 
                              authorizationStatus == .authorizedAlways) && 
                              CLLocationManager.locationServicesEnabled()
        
        print("📍 Location availability updated: \(isLocationAvailable)")
    }
    
    /// Handle location permission changes
    private func handleAuthorizationChange() {
        updateLocationAvailability()
        
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location permission granted")
            locationError = nil
            startLocationUpdates()
        case .denied, .restricted:
            print("❌ Location permission denied")
            locationError = .permissionDenied
            stopLocationUpdates()
        case .notDetermined:
            print("❓ Location permission not determined")
        @unknown default:
            print("⚠️ Unknown location authorization status")
            locationError = .unknown
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    
    nonisolated
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            handleLocationUpdate(locations)
        }
    }
    
    @MainActor
    private func handleLocationUpdate(_ locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Validate location accuracy (F1.1 requirement: ≤100m)
        guard location.horizontalAccuracy <= 100 else {
            print("⚠️ Location accuracy too low: \(location.horizontalAccuracy)m")
            return
        }
        
        // Check if significant location change (F1.1: >500m)
        let shouldUpdate: Bool
        if let lastLocation = currentLocation {
            let distanceMoved = location.distance(from: lastLocation)
            shouldUpdate = distanceMoved >= 500 // F1.1 requirement
            print("📍 Moved \(Int(distanceMoved))m from last location")
        } else {
            shouldUpdate = true
            print("📍 First location update received")
        }
        
        if shouldUpdate {
            currentLocation = location
            lastLocationUpdate = Date()
            locationError = nil
            
            print("✅ Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            print("🎯 Accuracy: \(location.horizontalAccuracy)m")
            
            // Optimize battery after getting good location
            optimizeLocationUpdates()
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            handleLocationError(error)
        }
    }
    
    @MainActor
    private func handleLocationError(_ error: Error) {
        print("❌ Location manager failed with error: \(error.localizedDescription)")
        
        if let clError = error as? CLError {
            switch clError.code {
            case .locationUnknown:
                locationError = .locationUnavailable
            case .denied:
                locationError = .permissionDenied
            case .network:
                locationError = .networkError
            default:
                locationError = .unknown
            }
        } else {
            locationError = .unknown
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            handleAuthorizationStatusChange(status)
        }
    }
    
    @MainActor
    private func handleAuthorizationStatusChange(_ status: CLAuthorizationStatus) {
        print("🔐 Location authorization changed to: \(status.description)")
        authorizationStatus = status
        handleAuthorizationChange()
    }
}

// MARK: - Location Errors
enum LocationError: Error, LocalizedError {
    case permissionDenied
    case serviceDisabled
    case locationUnavailable
    case networkError
    case accuracyTooLow
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location access denied. Please enable in Settings."
        case .serviceDisabled:
            return "Location services are disabled on this device."
        case .locationUnavailable:
            return "Current location is unavailable."
        case .networkError:
            return "Network error while getting location."
        case .accuracyTooLow:
            return "Location accuracy is too low for reliable matching."
        case .unknown:
            return "An unknown location error occurred."
        }
    }
    
    /// Fallback action description for users
    var fallbackAction: String {
        switch self {
        case .permissionDenied, .serviceDisabled:
            return "Enter your postcode manually"
        case .locationUnavailable, .networkError, .accuracyTooLow:
            return "Try again or enter postcode"
        case .unknown:
            return "Contact support if problem persists"
        }
    }
}

// MARK: - CLAuthorizationStatus Extension
extension CLAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Authorized Always"
        case .authorizedWhenInUse: return "Authorized When In Use"
        @unknown default: return "Unknown"
        }
    }
}
