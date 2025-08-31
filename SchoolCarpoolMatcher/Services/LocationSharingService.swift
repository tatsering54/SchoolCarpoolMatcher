//
//  LocationSharingService.swift
//  SchoolCarpoolMatcher
//
//  F3.2: Live Location Sharing Service
//  Handles real-time location updates, ETA calculations, and privacy controls
//  Applied Rule: Safety-First Messaging with comprehensive debug logging
//

import Foundation
import CoreLocation
import MapKit
import Combine

// MARK: - Location Sharing Models
struct SharedLocation: Identifiable, Codable {
    let id: UUID
    let groupId: UUID
    let familyId: UUID
    let familyName: String
    var coordinate: CLLocationCoordinate2D
    var accuracy: Double
    var speed: Double?
    var course: Double?
    var timestamp: Date
    var isActive: Bool
    var estimatedArrival: Date?
    let sharingDuration: TimeInterval
    let expiresAt: Date
    
    // Computed properties
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    var timeUntilExpiry: TimeInterval {
        max(0, expiresAt.timeIntervalSinceNow)
    }
    
    // MARK: - Codable Conformance
    enum CodingKeys: String, CodingKey {
        case id, groupId, familyId, familyName, accuracy, speed, course, timestamp
        case isActive, estimatedArrival, sharingDuration, expiresAt
        case latitude, longitude // For CLLocationCoordinate2D
    }
    
    init(
        id: UUID = UUID(),
        groupId: UUID,
        familyId: UUID,
        familyName: String,
        coordinate: CLLocationCoordinate2D,
        accuracy: Double,
        speed: Double? = nil,
        course: Double? = nil,
        timestamp: Date = Date(),
        isActive: Bool = true,
        estimatedArrival: Date? = nil,
        sharingDuration: TimeInterval = 2 * 60 * 60 // 2 hours default
    ) {
        self.id = id
        self.groupId = groupId
        self.familyId = familyId
        self.familyName = familyName
        self.coordinate = coordinate
        self.accuracy = accuracy
        self.speed = speed
        self.course = course
        self.timestamp = timestamp
        self.isActive = isActive
        self.estimatedArrival = estimatedArrival
        self.sharingDuration = sharingDuration
        self.expiresAt = timestamp.addingTimeInterval(sharingDuration)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        groupId = try container.decode(UUID.self, forKey: .groupId)
        familyId = try container.decode(UUID.self, forKey: .familyId)
        familyName = try container.decode(String.self, forKey: .familyName)
        accuracy = try container.decode(Double.self, forKey: .accuracy)
        speed = try container.decodeIfPresent(Double.self, forKey: .speed)
        course = try container.decodeIfPresent(Double.self, forKey: .course)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        estimatedArrival = try container.decodeIfPresent(Date.self, forKey: .estimatedArrival)
        sharingDuration = try container.decode(TimeInterval.self, forKey: .sharingDuration)
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        
        // Decode coordinate from separate latitude/longitude
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(groupId, forKey: .groupId)
        try container.encode(familyId, forKey: .familyId)
        try container.encode(familyName, forKey: .familyName)
        try container.encode(accuracy, forKey: .accuracy)
        try container.encodeIfPresent(speed, forKey: .speed)
        try container.encodeIfPresent(course, forKey: .course)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(isActive, forKey: .isActive)
        try container.encodeIfPresent(estimatedArrival, forKey: .estimatedArrival)
        try container.encode(sharingDuration, forKey: .sharingDuration)
        try container.encode(expiresAt, forKey: .expiresAt)
        
        // Encode coordinate as separate latitude/longitude
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
    }
}

struct LocationSharingSettings: Codable {
    var isEnabled: Bool
    var autoStopAfterHours: Double
    var updateIntervalSeconds: Double
    var allowBackgroundUpdates: Bool
    var shareWithEmergencyContacts: Bool
    
    static let `default` = LocationSharingSettings(
        isEnabled: true,
        autoStopAfterHours: 2.0,
        updateIntervalSeconds: 30.0,
        allowBackgroundUpdates: false,
        shareWithEmergencyContacts: true
    )
}

// MARK: - Location Sharing Service
@MainActor
class LocationSharingService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var activeSharing: [UUID: SharedLocation] = [:] // groupId -> location
    @Published var groupLocations: [UUID: [SharedLocation]] = [:] // groupId -> [locations]
    @Published var isSharingLocation = false
    @Published var currentSharingGroup: UUID?
    @Published var sharingSettings = LocationSharingSettings.default
    @Published var lastError: LocationSharingError?
    
    // MARK: - Private Properties
    private var locationManager: CLLocationManager?
    private var updateTimer: Timer?
    private var etaCalculationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Singleton
    static let shared = LocationSharingService()
    
    private init() {
        print("📍 LocationSharingService initialized")
        setupLocationManager()
        startCleanupTimer()
    }
    
    // MARK: - Public Methods
    
    /// Start sharing location with a carpool group
    func startLocationSharing(
        for groupId: UUID,
        familyId: UUID,
        familyName: String,
        duration: TimeInterval? = nil
    ) async throws {
        print("📍 Starting location sharing for group: \(groupId)")
        
        guard sharingSettings.isEnabled else {
            throw LocationSharingError.sharingDisabled
        }
        
        guard let location = await getCurrentLocation() else {
            throw LocationSharingError.locationUnavailable
        }
        
        let sharingDuration = duration ?? (sharingSettings.autoStopAfterHours * 60 * 60)
        
        let sharedLocation = SharedLocation(
            groupId: groupId,
            familyId: familyId,
            familyName: familyName,
            coordinate: location.coordinate,
            accuracy: location.horizontalAccuracy,
            speed: location.speed,
            course: location.course,
            sharingDuration: sharingDuration
        )
        
        // Store active sharing
        activeSharing[groupId] = sharedLocation
        
        // Add to group locations
        if groupLocations[groupId] == nil {
            groupLocations[groupId] = []
        }
        groupLocations[groupId]?.append(sharedLocation)
        
        // Update state
        isSharingLocation = true
        currentSharingGroup = groupId
        
        // Start location updates
        startLocationUpdates()
        
        // Start ETA calculations
        startETACalculations(for: groupId)
        
        print("✅ Location sharing started successfully")
        
        // Post notification
        NotificationCenter.default.post(
            name: .locationSharingStarted,
            object: sharedLocation
        )
    }
    
    /// Stop location sharing for a specific group
    func stopLocationSharing(for groupId: UUID) {
        print("🛑 Stopping location sharing for group: \(groupId)")
        
        // Remove from active sharing
        activeSharing.removeValue(forKey: groupId)
        
        // Update state
        if activeSharing.isEmpty {
            isSharingLocation = false
            currentSharingGroup = nil
            stopLocationUpdates()
        }
        
        // Mark as inactive in group locations
        if let index = groupLocations[groupId]?.firstIndex(where: { $0.id == activeSharing[groupId]?.id }) {
            groupLocations[groupId]?[index].isActive = false
        }
        
        print("✅ Location sharing stopped for group: \(groupId)")
        
        // Post notification
        NotificationCenter.default.post(
            name: .locationSharingStopped,
            object: groupId
        )
    }
    
    /// Stop all location sharing
    func stopAllLocationSharing() {
        print("🛑 Stopping all location sharing")
        
        let groupIds = Array(activeSharing.keys)
        for groupId in groupIds {
            stopLocationSharing(for: groupId)
        }
    }
    
    /// Get current locations for a group
    func getGroupLocations(for groupId: UUID) -> [SharedLocation] {
        return groupLocations[groupId]?.filter { $0.isActive && !$0.isExpired } ?? []
    }
    
    /// Calculate ETA between two locations
    func calculateETA(
        from: CLLocation,
        to: CLLocation
    ) async -> TimeInterval {
        print("🧭 Calculating ETA from \(from.coordinate) to \(to.coordinate)")
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to.coordinate))
        request.transportType = .automobile
        
        do {
            let directions = MKDirections(request: request)
            let response = try await directions.calculate()
            
            guard let route = response.routes.first else {
                print("⚠️ No route found for ETA calculation")
                return 0
            }
            
            let eta = route.expectedTravelTime
            print("✅ ETA calculated: \(eta) seconds")
            return eta
            
        } catch {
            print("❌ ETA calculation failed: \(error)")
            lastError = .etaCalculationFailed(error)
            return 0
        }
    }
    
    /// Update location sharing settings
    func updateSettings(_ newSettings: LocationSharingSettings) {
        print("⚙️ Updating location sharing settings")
        sharingSettings = newSettings
        
        // Apply new settings
        if !newSettings.isEnabled {
            stopAllLocationSharing()
        }
        
        // Update timer intervals
        if let timer = updateTimer {
            timer.invalidate()
            startLocationUpdates()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.distanceFilter = 10 // Update every 10 meters
        locationManager?.allowsBackgroundLocationUpdates = sharingSettings.allowBackgroundUpdates
    }
    
    private func getCurrentLocation() async -> CLLocation? {
        // DEMO: Return mock Canberra location for testing
        let mockLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300),
            altitude: 0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 5.0,
            timestamp: Date()
        )
        
        print("📍 Mock location obtained: \(mockLocation.coordinate)")
        return mockLocation
    }
    
    private func startLocationUpdates() {
        print("🔄 Starting location updates every \(sharingSettings.updateIntervalSeconds) seconds")
        
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: sharingSettings.updateIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateActiveLocations()
            }
        }
    }
    
    private func stopLocationUpdates() {
        print("🛑 Stopping location updates")
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func updateActiveLocations() async {
        guard !activeSharing.isEmpty else { return }
        
        print("🔄 Updating \(activeSharing.count) active location shares")
        
        for (groupId, sharedLocation) in activeSharing {
            guard let newLocation = await getCurrentLocation() else { continue }
            
            // Update location data
            var updatedLocation = sharedLocation
            updatedLocation.coordinate = newLocation.coordinate
            updatedLocation.accuracy = newLocation.horizontalAccuracy
            updatedLocation.speed = newLocation.speed
            updatedLocation.course = newLocation.course
            updatedLocation.timestamp = Date()
            
            // Update storage
            activeSharing[groupId] = updatedLocation
            
            // Update group locations
            if let index = groupLocations[groupId]?.firstIndex(where: { $0.id == sharedLocation.id }) {
                groupLocations[groupId]?[index] = updatedLocation
            }
        }
        
        // Post notification for updates
        NotificationCenter.default.post(
            name: .locationSharingUpdated,
            object: activeSharing
        )
    }
    
    private func startETACalculations(for groupId: UUID) {
        print("🧭 Starting ETA calculations for group: \(groupId)")
        
        etaCalculationTimer?.invalidate()
        etaCalculationTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateETAs(for: groupId)
            }
        }
    }
    
    private func updateETAs(for groupId: UUID) async {
        guard let groupLocations = groupLocations[groupId],
              let currentUserLocation = activeSharing[groupId] else { return }
        
        print("🧭 Updating ETAs for group: \(groupId)")
        
        for location in groupLocations where location.familyId != currentUserLocation.familyId {
            let fromLocation = CLLocation(latitude: currentUserLocation.coordinate.latitude, longitude: currentUserLocation.coordinate.longitude)
            let toLocation = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            
            let eta = await calculateETA(from: fromLocation, to: toLocation)
            let estimatedArrival = Date().addingTimeInterval(eta)
            
            // Update ETA in storage
            if let index = self.groupLocations[groupId]?.firstIndex(where: { $0.id == location.id }) {
                self.groupLocations[groupId]?[index].estimatedArrival = estimatedArrival
            }
        }
    }
    
    private func startCleanupTimer() {
        // Clean up expired locations every 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupExpiredLocations()
            }
        }
    }
    
    private func cleanupExpiredLocations() {
        print("🧹 Cleaning up expired location shares")
        
        var locationsToRemove: [UUID] = []
        
        for (groupId, sharedLocation) in activeSharing {
            if sharedLocation.isExpired {
                locationsToRemove.append(groupId)
                print("🗑️ Removing expired location for group: \(groupId)")
            }
        }
        
        for groupId in locationsToRemove {
            stopLocationSharing(for: groupId)
        }
        
        // Clean up group locations
        for groupId in groupLocations.keys {
            groupLocations[groupId]?.removeAll { $0.isExpired }
        }
    }
    
    // MARK: - Public Methods for UI Integration
    
    /// Get active locations for a specific group
    func getActiveLocations(for groupId: UUID) -> [GroupMemberLocation] {
        guard let sharedLocations = groupLocations[groupId] else { return [] }
        
        return sharedLocations.compactMap { sharedLocation in
            GroupMemberLocation(
                memberId: sharedLocation.familyId,
                memberName: sharedLocation.familyName,
                coordinate: sharedLocation.coordinate,
                accuracy: sharedLocation.accuracy,
                lastUpdated: sharedLocation.timestamp,
                estimatedArrival: sharedLocation.estimatedArrival,
                isMoving: (sharedLocation.speed ?? 0) > 1.0 // Moving if speed > 1 m/s
            )
        }
    }
    
    /// Check if currently sharing location for a group
    func isSharing(for groupId: UUID) -> Bool {
        return currentSharingGroup == groupId && isSharingLocation
    }
    
    /// Get remaining sharing time for a group
    func getSharingTimeRemaining(for groupId: UUID) -> TimeInterval {
        guard let sharedLocation = activeSharing[groupId] else { return 0 }
        let remaining = sharedLocation.expiresAt.timeIntervalSinceNow
        return max(0, remaining)
    }
    
    /// Load active sharing sessions for a group
    func loadActiveSessions(for groupId: UUID) async {
        print("📍 Loading active sessions for group: \(groupId)")
        
        // Mock implementation - in real app would load from server
        await MainActor.run {
            // Create some mock active locations for demo
            var mockLocation1 = SharedLocation(
                id: UUID(),
                groupId: groupId,
                familyId: UUID(),
                familyName: "Sarah Chen",
                coordinate: CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300),
                accuracy: 10.0,
                speed: 0.0,
                course: nil,
                timestamp: Date(),
                isActive: true,
                estimatedArrival: Date().addingTimeInterval(15 * 60),
                sharingDuration: 3600
            )
            
            var mockLocation2 = SharedLocation(
                id: UUID(),
                groupId: groupId,
                familyId: UUID(),
                familyName: "Mike Johnson",
                coordinate: CLLocationCoordinate2D(latitude: -35.2820, longitude: 149.1310),
                accuracy: 15.0,
                speed: 2.5,
                course: 45.0,
                timestamp: Date(),
                isActive: true,
                estimatedArrival: Date().addingTimeInterval(12 * 60),
                sharingDuration: 3600
            )
            
            let mockLocations = [mockLocation1, mockLocation2]
            
            self.groupLocations[groupId] = mockLocations
            print("✅ Loaded \(mockLocations.count) active locations")
        }
    }
    
    /// Start sharing location for a group
    func startSharing(for groupId: UUID, duration: TimeInterval) async throws {
        print("📍 Starting location sharing for group: \(groupId)")
        print("   ⏱️ Duration: \(duration/3600) hours")
        
        await MainActor.run {
            self.currentSharingGroup = groupId
            self.isSharingLocation = true
            
            // Create mock sharing session
            let mockLocation = SharedLocation(
                id: UUID(),
                groupId: groupId,
                familyId: UUID(), // Mock current user ID
                familyName: "Current User",
                coordinate: CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300),
                accuracy: 10.0,
                speed: nil,
                course: nil,
                timestamp: Date(),
                isActive: true,
                estimatedArrival: nil,
                sharingDuration: duration
            )
            
            self.activeSharing[groupId] = mockLocation
            
            // Add to group locations
            if self.groupLocations[groupId] == nil {
                self.groupLocations[groupId] = []
            }
            self.groupLocations[groupId]?.append(mockLocation)
            
            print("✅ Location sharing started successfully")
        }
    }
    
    /// Stop sharing location for a group
    func stopSharing(for groupId: UUID) async {
        print("📍 Stopping location sharing for group: \(groupId)")
        
        await MainActor.run {
            self.activeSharing.removeValue(forKey: groupId)
            
            if self.currentSharingGroup == groupId {
                self.currentSharingGroup = nil
                self.isSharingLocation = false
            }
            
            // Remove current user from group locations
            self.groupLocations[groupId]?.removeAll { $0.familyName == "Current User" }
            
            print("✅ Location sharing stopped")
        }
    }
}

// MARK: - Location Sharing Errors
enum LocationSharingError: LocalizedError {
    case sharingDisabled
    case locationUnavailable
    case permissionDenied
    case groupNotFound
    case etaCalculationFailed(Error)
    case networkError
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .sharingDisabled:
            return "Location sharing is disabled in settings"
        case .locationUnavailable:
            return "Unable to determine current location"
        case .permissionDenied:
            return "Location permission denied"
        case .groupNotFound:
            return "Carpool group not found"
        case .etaCalculationFailed(let error):
            return "ETA calculation failed: \(error.localizedDescription)"
        case .networkError:
            return "Network error occurred"
        case .timeout:
            return "Request timed out"
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let locationSharingStarted = Notification.Name("locationSharingStarted")
    static let locationSharingStopped = Notification.Name("locationSharingStopped")
    static let locationSharingUpdated = Notification.Name("locationSharingUpdated")
}
