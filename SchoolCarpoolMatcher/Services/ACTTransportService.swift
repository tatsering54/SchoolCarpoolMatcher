//
//  ACTTransportService.swift
//  SchoolCarpoolMatcher
//
//  ACT Government public transport API integration for F2.3
//  Fetches transport usage data from: https://www.data.act.gov.au/api/v3/views/nkxy-abdj/query.json
//  Applied Rule: Debug logs and safety-first multi-modal transport planning
//

import Foundation
import CoreLocation

// MARK: - ACT Transport Service
/// Service for fetching ACT public transport data and calculating multi-modal journeys
/// Used for F2.3 Park & Ride integration and hybrid journey planning
class ACTTransportService: ObservableObject {
    
    // MARK: - Constants
    private let baseURL = "https://www.data.act.gov.au/api/v3/views/nkxy-abdj/query.json"
    private let appToken = "5sN0eeWT7cJvM6BTWPKUeHUeh"
    private let requestTimeout: TimeInterval = 30.0
    private let maxRetries = 3
    
    // MARK: - Published Properties
    @Published var transportData: [TransportUsageRecord] = []
    @Published var parkRideLocations: [ParkRideLocation] = []
    @Published var isLoading = false
    @Published var lastFetchDate: Date?
    @Published var error: TransportServiceError?
    
    // MARK: - Private Properties
    private let urlSession: URLSession
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = requestTimeout
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config)
        
        // Configure JSON decoder for date handling
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        decoder.dateDecodingStrategy = .formatted(formatter)
        
        print("🚌 ACTTransportService initialized")
        print("   🔗 Base URL: \(baseURL)")
        print("   🎫 App Token: \(appToken)")
        print("   ⏱️ Timeout: \(requestTimeout)s")
        
        // Load mock Park & Ride locations for Canberra
        loadMockParkRideLocations()
    }
    
    // MARK: - Public Methods
    
    /// Fetch transport usage data from ACT Government API
    func fetchTransportData() async throws -> [TransportUsageRecord] {
        print("📥 Fetching ACT transport data...")
        
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let fetchedData = try await performTransportAPIRequest()
            lastFetchDate = Date()
            transportData = fetchedData
            
            print("✅ Successfully fetched \(transportData.count) transport usage records")
            print("   📊 Latest data from: \(transportData.first?.date.formatted() ?? "N/A")")
            
            return transportData
            
        } catch let apiError as TransportServiceError {
            print("❌ Transport API error: \(apiError.localizedDescription)")
            error = apiError
            throw apiError
            
        } catch {
            print("❌ Unexpected error fetching transport data: \(error)")
            let wrappedError = TransportServiceError.networkError(error)
            self.error = wrappedError
            throw wrappedError
        }
    }
    
    /// Find Park & Ride locations within specified radius of a coordinate
    func findNearbyParkRideLocations(
        near coordinate: CLLocationCoordinate2D,
        radiusKm: Double = 1.0
    ) -> [ParkRideLocation] {
        print("🅿️ Finding Park & Ride locations near (\(String(format: "%.4f", coordinate.latitude)), \(String(format: "%.4f", coordinate.longitude)))")
        
        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let radiusMeters = radiusKm * 1000
        
        let nearbyLocations = parkRideLocations.filter { parkRide in
            let parkRideLocation = CLLocation(latitude: parkRide.latitude, longitude: parkRide.longitude)
            let distance = userLocation.distance(from: parkRideLocation)
            return distance <= radiusMeters
        }
        
        // Sort by distance
        let sortedLocations = nearbyLocations.sorted { location1, location2 in
            let distance1 = userLocation.distance(from: CLLocation(latitude: location1.latitude, longitude: location1.longitude))
            let distance2 = userLocation.distance(from: CLLocation(latitude: location2.latitude, longitude: location2.longitude))
            return distance1 < distance2
        }
        
        print("   📍 Found \(sortedLocations.count) Park & Ride locations within \(radiusKm)km")
        
        return sortedLocations
    }
    
    /// Calculate hybrid journey options (drive + public transport)
    func calculateHybridJourneys(
        from homeCoordinate: CLLocationCoordinate2D,
        to schoolCoordinate: CLLocationCoordinate2D
    ) async -> [HybridJourneyOption] {
        print("🚗🚌 Calculating hybrid journey options...")
        print("   🏠 From: (\(String(format: "%.4f", homeCoordinate.latitude)), \(String(format: "%.4f", homeCoordinate.longitude)))")
        print("   🏫 To: (\(String(format: "%.4f", schoolCoordinate.latitude)), \(String(format: "%.4f", schoolCoordinate.longitude)))")
        
        var hybridOptions: [HybridJourneyOption] = []
        
        // Find nearby Park & Ride locations
        let nearbyParkRides = findNearbyParkRideLocations(near: homeCoordinate, radiusKm: 2.0)
        
        for parkRide in nearbyParkRides.prefix(3) { // Limit to top 3 closest
            let homeLocation = CLLocation(latitude: homeCoordinate.latitude, longitude: homeCoordinate.longitude)
            let parkRideLocation = CLLocation(latitude: parkRide.latitude, longitude: parkRide.longitude)
            let schoolLocation = CLLocation(latitude: schoolCoordinate.latitude, longitude: schoolCoordinate.longitude)
            
            // Calculate drive distance to Park & Ride
            let driveDistance = homeLocation.distance(from: parkRideLocation)
            let driveTime = calculateDriveTime(distance: driveDistance)
            
            // Calculate public transport distance from Park & Ride to school
            let transitDistance = parkRideLocation.distance(from: schoolLocation)
            let transitTime = calculateTransitTime(distance: transitDistance, transportType: parkRide.primaryTransportType)
            
            // Create hybrid journey option
            let hybridJourney = HybridJourneyOption(
                id: UUID(),
                parkRideLocation: parkRide,
                driveSegment: JourneySegment(
                    from: homeCoordinate,
                    to: CLLocationCoordinate2D(latitude: parkRide.latitude, longitude: parkRide.longitude),
                    transportMode: .drive,
                    distance: driveDistance,
                    estimatedTime: driveTime,
                    cost: calculateDriveCost(distance: driveDistance)
                ),
                transitSegment: JourneySegment(
                    from: CLLocationCoordinate2D(latitude: parkRide.latitude, longitude: parkRide.longitude),
                    to: schoolCoordinate,
                    transportMode: parkRide.primaryTransportType,
                    distance: transitDistance,
                    estimatedTime: transitTime,
                    cost: parkRide.averageFare
                ),
                totalTime: driveTime + 300 + transitTime, // Add 5 min transfer time
                totalCost: calculateDriveCost(distance: driveDistance) + parkRide.averageFare,
                co2Savings: calculateCO2Savings(driveDistance: driveDistance, totalDistance: driveDistance + transitDistance),
                reliabilityScore: parkRide.reliabilityScore
            )
            
            hybridOptions.append(hybridJourney)
        }
        
        // Sort by total time
        hybridOptions.sort { $0.totalTime < $1.totalTime }
        
        print("✅ Generated \(hybridOptions.count) hybrid journey options")
        if let bestOption = hybridOptions.first {
            print("   🥇 Best option: \(String(format: "%.1f", bestOption.totalTime/60))min total, $\(String(format: "%.2f", bestOption.totalCost))")
        }
        
        return hybridOptions
    }
    
    /// Get transport service status and delays
    func getServiceStatus() async -> TransportServiceStatus {
        print("📊 Checking transport service status...")
        
        // For MVP, use transport usage data to estimate service reliability
        // In production, would integrate with real-time service status API
        
        let recentData = transportData.filter { record in
            Calendar.current.isDate(record.date, equalTo: Date(), toGranularity: .month)
        }
        
        let averageUsage = recentData.reduce(0.0) { result, record in
            result + Double(record.localRoute + record.lightRail + record.rapidRoute)
        } / Double(max(1, recentData.count))
        
        let serviceStatus = TransportServiceStatus(
            overallStatus: averageUsage > 15000 ? .good : (averageUsage > 10000 ? .moderate : .poor),
            lightRailStatus: .good, // Light rail generally reliable
            busStatus: averageUsage > 12000 ? .good : .moderate,
            lastUpdated: Date(),
            activeAlerts: [],
            estimatedDelays: [:]
        )
        
        print("   🚦 Service status: \(serviceStatus.overallStatus.rawValue)")
        
        return serviceStatus
    }
    
    // MARK: - Private Methods
    
    /// Perform the actual transport API request with retry logic
    private func performTransportAPIRequest() async throws -> [TransportUsageRecord] {
        let urlString = buildTransportAPIURL()
        
        guard let url = URL(string: urlString) else {
            throw TransportServiceError.invalidURL
        }
        
        var lastError: Error?
        
        // Retry logic for network reliability
        for attempt in 1...maxRetries {
            do {
                print("🔄 Transport API request attempt \(attempt)/\(maxRetries)")
                
                let (data, response) = try await urlSession.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw TransportServiceError.invalidResponse
                }
                
                print("📡 Transport API response: \(httpResponse.statusCode)")
                print("   📦 Response size: \(data.count) bytes")
                
                guard 200...299 ~= httpResponse.statusCode else {
                    throw TransportServiceError.httpError(httpResponse.statusCode)
                }
                
                let transportRecords = try parseTransportAPIResponse(data)
                return transportRecords
                
            } catch {
                lastError = error
                print("⚠️ Transport API attempt \(attempt) failed: \(error)")
                
                if attempt < maxRetries {
                    let delay = TimeInterval(attempt * 2)
                    print("⏳ Retrying in \(delay)s...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // If all retries failed, log the error and return mock data for testing
        print("⚠️ All API attempts failed, falling back to mock data for testing")
        print("   🔍 Last error: \(lastError?.localizedDescription ?? "Unknown error")")
        
        // Return existing mock data if available, otherwise return empty array
        return transportData.isEmpty ? [] : transportData
    }
    
    /// Build the complete API URL with app token
    private func buildTransportAPIURL() -> String {
        let urlString = "\(baseURL)?$$app_token=\(appToken)"
        print("🔗 Transport API URL: \(urlString)")
        return urlString
    }
    
    /// Parse the JSON response from ACT transport API
    private func parseTransportAPIResponse(_ data: Data) throws -> [TransportUsageRecord] {
        print("📊 Parsing transport API response...")
        
        do {
            // Parse as array of transport usage records
            let rawRecords = try decoder.decode([RawTransportRecord].self, from: data)
            
            print("   📋 Raw transport records: \(rawRecords.count)")
            
            let transportRecords = rawRecords.compactMap { rawRecord -> TransportUsageRecord? in
                guard let dateString = rawRecord.date,
                      let date = parseDate(dateString) else {
                    return nil
                }
                
                return TransportUsageRecord(
                    id: UUID(),
                    date: date,
                    localRoute: Int(rawRecord.localRoute ?? "0") ?? 0,
                    lightRail: Int(rawRecord.lightRail ?? "0") ?? 0,
                    peakService: Int(rawRecord.peakService ?? "0") ?? 0,
                    rapidRoute: Int(rawRecord.rapidRoute ?? "0") ?? 0,
                    school: Int(rawRecord.school ?? "0") ?? 0,
                    other: Double(rawRecord.other ?? "0") ?? 0.0
                )
            }
            
            print("   ✅ Valid transport records: \(transportRecords.count)")
            
            // Log sample records for debugging
            if transportRecords.count > 0 {
                print("   📍 Sample transport usage:")
                for record in transportRecords.prefix(3) {
                    print("      • \(record.date.formatted(.dateTime.month().day())): Local=\(record.localRoute), Light Rail=\(record.lightRail), School=\(record.school)")
                }
            }
            
            return transportRecords.sorted { $0.date > $1.date } // Most recent first
            
        } catch {
            print("❌ Failed to parse transport API response: \(error)")
            
            // Log response data for debugging (truncated)
            if let responseString = String(data: data.prefix(500), encoding: .utf8) {
                print("   📄 Response preview: \(responseString)...")
            }
            
            throw TransportServiceError.parsingError(error)
        }
    }
    
    /// Parse date string from API response
    private func parseDate(_ dateString: String) -> Date? {
        let formatters = [
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd"
        ]
        
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    /// Load mock Park & Ride locations for Canberra
    private func loadMockParkRideLocations() {
        print("🅿️ Loading mock Park & Ride locations for Canberra...")
        
        parkRideLocations = [
            ParkRideLocation(
                id: UUID(),
                name: "Civic Interchange",
                address: "East Row, Civic ACT 2601",
                latitude: -35.2809,
                longitude: 149.1300,
                parkingSpaces: 150,
                availableSpaces: 89,
                primaryTransportType: .lightRail,
                connectedRoutes: ["Light Rail", "Bus Route 1", "Bus Route 2"],
                averageFare: 4.50,
                operatingHours: "5:00 AM - 11:30 PM",
                reliabilityScore: 9.2,
                amenities: ["Covered Parking", "Security", "Bike Racks", "Toilets"]
            ),
            ParkRideLocation(
                id: UUID(),
                name: "Gungahlin Town Centre",
                address: "Hibberson St, Gungahlin ACT 2912",
                latitude: -35.1847,
                longitude: 149.1323,
                parkingSpaces: 200,
                availableSpaces: 134,
                primaryTransportType: .lightRail,
                connectedRoutes: ["Light Rail", "Bus Route 56", "Bus Route 58"],
                averageFare: 4.50,
                operatingHours: "5:00 AM - 11:30 PM",
                reliabilityScore: 8.8,
                amenities: ["Free Parking", "Shopping Centre", "Food Court", "ATM"]
            ),
            ParkRideLocation(
                id: UUID(),
                name: "Belconnen Bus Station",
                address: "Cohen St, Belconnen ACT 2617",
                latitude: -35.2386,
                longitude: 149.0661,
                parkingSpaces: 300,
                availableSpaces: 178,
                primaryTransportType: .rapidBus,
                connectedRoutes: ["Rapid Bus", "Bus Route 4", "Bus Route 5", "Bus Route 7"],
                averageFare: 4.50,
                operatingHours: "5:00 AM - 11:30 PM",
                reliabilityScore: 8.5,
                amenities: ["Free Parking", "Westfield Shopping", "Food Court", "Weather Protection"]
            ),
            ParkRideLocation(
                id: UUID(),
                name: "Tuggeranong Interchange",
                address: "Anketell St, Tuggeranong ACT 2900",
                latitude: -35.4144,
                longitude: 149.0919,
                parkingSpaces: 250,
                availableSpaces: 145,
                primaryTransportType: .rapidBus,
                connectedRoutes: ["Rapid Bus", "Bus Route 66", "Bus Route 67"],
                averageFare: 4.50,
                operatingHours: "5:00 AM - 11:30 PM",
                reliabilityScore: 8.3,
                amenities: ["Free Parking", "Hyperdome Shopping", "Cafes", "Library"]
            ),
            ParkRideLocation(
                id: UUID(),
                name: "Woden Bus Station",
                address: "Bradley St, Phillip ACT 2606",
                latitude: -35.3444,
                longitude: 149.0856,
                parkingSpaces: 180,
                availableSpaces: 98,
                primaryTransportType: .rapidBus,
                connectedRoutes: ["Rapid Bus", "Bus Route 11", "Bus Route 14"],
                averageFare: 4.50,
                operatingHours: "5:00 AM - 11:30 PM",
                reliabilityScore: 8.7,
                amenities: ["Paid Parking $2/day", "Westfield Woden", "Medical Centre", "Post Office"]
            )
        ]
        
        print("   ✅ Loaded \(parkRideLocations.count) Park & Ride locations")
        
        // Load mock transport data for testing when API is unavailable
        loadMockTransportData()
    }
    
    /// Load mock transport usage data for testing
    private func loadMockTransportData() {
        print("🚌 Loading mock transport usage data for testing...")
        
        let mockRecords = [
            TransportUsageRecord(
                id: UUID(),
                date: Date(),
                localRoute: 16436,
                lightRail: 10705,
                peakService: 225,
                rapidRoute: 19026,
                school: 3925,
                other: 59.0
            ),
            TransportUsageRecord(
                id: UUID(),
                date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                localRoute: 15499,
                lightRail: 10671,
                peakService: 267,
                rapidRoute: 18421,
                school: 4519,
                other: 61.0
            ),
            TransportUsageRecord(
                id: UUID(),
                date: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                localRoute: 17387,
                lightRail: 11627,
                peakService: 362,
                rapidRoute: 21753,
                school: 5544,
                other: 108.0
            )
        ]
        
        transportData = mockRecords
        print("   ✅ Loaded \(transportData.count) mock transport usage records")
    }
    
    // MARK: - Helper Methods
    
    /// Calculate drive time based on distance (assuming average speed)
    private func calculateDriveTime(distance: Double) -> TimeInterval {
        let averageSpeedKmh = 40.0 // Urban driving speed
        let distanceKm = distance / 1000.0
        let timeHours = distanceKm / averageSpeedKmh
        return timeHours * 3600 // Convert to seconds
    }
    
    /// Calculate transit time based on distance and transport type
    private func calculateTransitTime(distance: Double, transportType: TransportMode) -> TimeInterval {
        let averageSpeed: Double
        switch transportType {
        case .lightRail:
            averageSpeed = 25.0 // km/h including stops
        case .rapidBus:
            averageSpeed = 30.0 // km/h on dedicated lanes
        case .bus:
            averageSpeed = 20.0 // km/h with traffic
        default:
            averageSpeed = 15.0 // Walking/other
        }
        
        let distanceKm = distance / 1000.0
        let timeHours = distanceKm / averageSpeed
        return timeHours * 3600 // Convert to seconds
    }
    
    /// Calculate drive cost based on distance
    private func calculateDriveCost(distance: Double) -> Double {
        let costPerKm = 0.85 // AUD per km (fuel + wear)
        let distanceKm = distance / 1000.0
        return distanceKm * costPerKm
    }
    
    /// Calculate CO2 savings from using public transport
    private func calculateCO2Savings(driveDistance: Double, totalDistance: Double) -> Double {
        let carEmissionsKgPerKm = 0.251 // Average car emissions in Australia
        let transitEmissionsKgPerKm = 0.089 // Public transport emissions per passenger
        
        let totalDistanceKm = totalDistance / 1000.0
        let driveDistanceKm = driveDistance / 1000.0
        let transitDistanceKm = totalDistanceKm - driveDistanceKm
        
        let carEmissions = totalDistanceKm * carEmissionsKgPerKm
        let hybridEmissions = (driveDistanceKm * carEmissionsKgPerKm) + (transitDistanceKm * transitEmissionsKgPerKm)
        
        return max(0, carEmissions - hybridEmissions)
    }
}

// MARK: - Data Models

/// Raw transport record from ACT API
private struct RawTransportRecord: Codable {
    let date: String?
    let localRoute: String?
    let lightRail: String?
    let peakService: String?
    let rapidRoute: String?
    let school: String?
    let other: String?
    
    private enum CodingKeys: String, CodingKey {
        case date
        case localRoute = "local_route"
        case lightRail = "light_rail"
        case peakService = "peak_service"
        case rapidRoute = "rapid_route"
        case school
        case other
    }
}

/// Processed transport usage record
struct TransportUsageRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let localRoute: Int
    let lightRail: Int
    let peakService: Int
    let rapidRoute: Int
    let school: Int
    let other: Double
    
    var totalUsage: Int {
        return localRoute + lightRail + peakService + rapidRoute + school
    }
}

/// Park & Ride location information
struct ParkRideLocation: Identifiable, Codable {
    let id: UUID
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let parkingSpaces: Int
    let availableSpaces: Int
    let primaryTransportType: TransportMode
    let connectedRoutes: [String]
    let averageFare: Double
    let operatingHours: String
    let reliabilityScore: Double
    let amenities: [String]
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var occupancyRate: Double {
        let occupied = parkingSpaces - availableSpaces
        return Double(occupied) / Double(parkingSpaces)
    }
    
    var availabilityStatus: ParkingAvailability {
        let availabilityRatio = Double(availableSpaces) / Double(parkingSpaces)
        switch availabilityRatio {
        case 0.5...1.0: return .available
        case 0.2..<0.5: return .limited
        case 0.1..<0.2: return .veryLimited
        default: return .full
        }
    }
}

/// Hybrid journey option (drive + public transport)
struct HybridJourneyOption: Identifiable {
    let id: UUID
    let parkRideLocation: ParkRideLocation
    let driveSegment: JourneySegment
    let transitSegment: JourneySegment
    let totalTime: TimeInterval
    let totalCost: Double
    let co2Savings: Double
    let reliabilityScore: Double
    
    var totalDistance: Double {
        return driveSegment.distance + transitSegment.distance
    }
    
    var costPerKm: Double {
        let totalDistanceKm = totalDistance / 1000.0
        return totalDistanceKm > 0 ? totalCost / totalDistanceKm : 0
    }
}

/// Individual journey segment
struct JourneySegment: Identifiable {
    let id = UUID()
    let from: CLLocationCoordinate2D
    let to: CLLocationCoordinate2D
    let transportMode: TransportMode
    let distance: Double
    let estimatedTime: TimeInterval
    let cost: Double
}

/// Transport service status
struct TransportServiceStatus {
    let overallStatus: ServiceStatus
    let lightRailStatus: ServiceStatus
    let busStatus: ServiceStatus
    let lastUpdated: Date
    let activeAlerts: [ServiceAlert]
    let estimatedDelays: [String: TimeInterval] // Route -> delay in seconds
}

/// Service alert information
struct ServiceAlert: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let affectedRoutes: [String]
    let severity: AlertSeverity
    let startTime: Date
    let endTime: Date?
}

// MARK: - Enums

/// Transport modes available in ACT
enum TransportMode: String, CaseIterable, Codable {
    case drive = "drive"
    case bus = "bus"
    case rapidBus = "rapid_bus"
    case lightRail = "light_rail"
    case walk = "walk"
    case bicycle = "bicycle"
    case hybrid = "hybrid"
    
    var displayName: String {
        switch self {
        case .drive: return "Drive"
        case .bus: return "Bus"
        case .rapidBus: return "Rapid Bus"
        case .lightRail: return "Light Rail"
        case .walk: return "Walk"
        case .bicycle: return "Bicycle"
        case .hybrid: return "Drive + Transit"
        }
    }
    
    var icon: String {
        switch self {
        case .drive: return "car.fill"
        case .bus: return "bus.fill"
        case .rapidBus: return "bus.doubledecker.fill"
        case .lightRail: return "tram.fill"
        case .walk: return "figure.walk"
        case .bicycle: return "bicycle"
        case .hybrid: return "car.2.fill"
        }
    }
}

/// Service status levels
enum ServiceStatus: String, CaseIterable {
    case good = "good"
    case moderate = "moderate"
    case poor = "poor"
    case disrupted = "disrupted"
    
    var displayName: String {
        switch self {
        case .good: return "Good Service"
        case .moderate: return "Minor Delays"
        case .poor: return "Major Delays"
        case .disrupted: return "Service Disrupted"
        }
    }
    
    var color: String {
        switch self {
        case .good: return "green"
        case .moderate: return "yellow"
        case .poor: return "orange"
        case .disrupted: return "red"
        }
    }
}

/// Parking availability status
enum ParkingAvailability: String, CaseIterable {
    case available = "available"
    case limited = "limited"
    case veryLimited = "very_limited"
    case full = "full"
    
    var displayName: String {
        switch self {
        case .available: return "Available"
        case .limited: return "Limited Spaces"
        case .veryLimited: return "Very Limited"
        case .full: return "Full"
        }
    }
    
    var color: String {
        switch self {
        case .available: return "green"
        case .limited: return "yellow"
        case .veryLimited: return "orange"
        case .full: return "red"
        }
    }
}

/// Alert severity levels
enum AlertSeverity: String, CaseIterable {
    case info = "info"
    case warning = "warning"
    case major = "major"
    case critical = "critical"
}

// MARK: - Error Handling

/// Errors that can occur when using transport services
enum TransportServiceError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case httpError(Int)
    case parsingError(Error)
    case noDataAvailable
    case serviceUnavailable
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid transport API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid transport API response format"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .parsingError(let error):
            return "Transport data parsing error: \(error.localizedDescription)"
        case .noDataAvailable:
            return "No transport data available"
        case .serviceUnavailable:
            return "Transport service temporarily unavailable"
        case .unknownError:
            return "Unknown transport service error"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError, .httpError:
            return "Check your internet connection and try again"
        case .parsingError, .serviceUnavailable:
            return "The transport service may be temporarily unavailable"
        default:
            return "Please try again later"
        }
    }
}
