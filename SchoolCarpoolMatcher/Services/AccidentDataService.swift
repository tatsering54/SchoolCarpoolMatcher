//
//  AccidentDataService.swift
//  SchoolCarpoolMatcher
//
//  ACT Government road accident API integration for F2.1
//  Fetches accident data from: https://spatial.infrastructure.gov.au/server/rest/services/Hosted/RADAR_Curated_Prod_roadworks/FeatureServer/0/query
//  Applied Rule: Debug logs and safety-first data handling
//

import Foundation
import CoreLocation

// MARK: - Accident Data Service
/// Service for fetching road accident data from ACT Government spatial API
/// Used for F2.1 accident history penalty calculations
class AccidentDataService: ObservableObject {
    
    // MARK: - Constants
    private let baseURL = "https://spatial.infrastructure.gov.au/server/rest/services/Hosted/RADAR_Curated_Prod_roadworks/FeatureServer/0/query"
    private let requestTimeout: TimeInterval = 45.0 // Longer timeout for spatial API
    private let maxRetries = 3
    
    // MARK: - Published Properties
    @Published var accidents: [AccidentLocation] = []
    @Published var isLoading = false
    @Published var lastFetchDate: Date?
    @Published var error: AccidentDataError?
    
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
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        decoder.dateDecodingStrategy = .formatted(formatter)
        
        print("📊 AccidentDataService initialized")
        print("   🔗 Base URL: \(baseURL)")
        print("   ⏱️ Timeout: \(requestTimeout)s")
    }
    
    // MARK: - Public Methods
    
    /// Fetch accident data from ACT Government spatial API
    func fetchAccidentData() async throws -> [AccidentLocation] {
        print("📥 Fetching accident data from ACT Government spatial API...")
        
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let fetchedAccidents = try await performAccidentAPIRequest()
            lastFetchDate = Date()
            accidents = fetchedAccidents // Update published property
            
            print("✅ Successfully fetched \(accidents.count) accident records")
            print("   📍 Coverage area: ACT region")
            
            return accidents
            
        } catch let apiError as AccidentDataError {
            print("❌ Accident API error: \(apiError.localizedDescription)")
            error = apiError
            throw apiError
            
        } catch {
            print("❌ Unexpected error fetching accident data: \(error)")
            let wrappedError = AccidentDataError.networkError(error)
            self.error = wrappedError
            throw wrappedError
        }
    }
    
    // MARK: - Private Methods
    
    /// Perform the actual spatial API request with retry logic
    private func performAccidentAPIRequest() async throws -> [AccidentLocation] {
        let urlString = buildAccidentAPIURL()
        
        guard let url = URL(string: urlString) else {
            throw AccidentDataError.invalidURL
        }
        
        var lastError: Error?
        
        // Retry logic for network reliability
        for attempt in 1...maxRetries {
            do {
                print("🔄 Accident API request attempt \(attempt)/\(maxRetries)")
                
                let (data, response) = try await urlSession.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AccidentDataError.invalidResponse
                }
                
                print("📡 Accident API response: \(httpResponse.statusCode)")
                print("   📦 Response size: \(data.count) bytes")
                
                guard 200...299 ~= httpResponse.statusCode else {
                    throw AccidentDataError.httpError(httpResponse.statusCode)
                }
                
                let accidents = try parseAccidentAPIResponse(data)
                return accidents
                
            } catch {
                lastError = error
                print("⚠️ Accident API attempt \(attempt) failed: \(error)")
                
                if attempt < maxRetries {
                    let delay = TimeInterval(attempt * 3) // Longer backoff for spatial API
                    print("⏳ Retrying in \(delay)s...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? AccidentDataError.unknownError
    }
    
    /// Build the complete API URL with query parameters
    private func buildAccidentAPIURL() -> String {
        var components = URLComponents(string: baseURL)!
        
        // Add query parameters for GeoJSON format and all fields
        components.queryItems = [
            URLQueryItem(name: "outFields", value: "*"),
            URLQueryItem(name: "where", value: "1=1"),
            URLQueryItem(name: "f", value: "geojson"),
            URLQueryItem(name: "returnGeometry", value: "true"),
            URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
            URLQueryItem(name: "outSR", value: "4326") // WGS84 coordinate system
        ]
        
        let finalURL = components.url?.absoluteString ?? baseURL
        print("🔗 Accident API URL: \(finalURL)")
        
        return finalURL
    }
    
    /// Parse the GeoJSON response from ACT spatial API
    private func parseAccidentAPIResponse(_ data: Data) throws -> [AccidentLocation] {
        print("📊 Parsing accident API response...")
        
        do {
            // First try to parse as GeoJSON
            let geoJSON = try decoder.decode(GeoJSONResponse.self, from: data)
            
            print("   📋 Raw accident features: \(geoJSON.features.count)")
            
            let accidents = geoJSON.features.compactMap { feature -> AccidentLocation? in
                guard let geometry = feature.geometry,
                      let coordinates = geometry.coordinates,
                      coordinates.count >= 2 else {
                    return nil
                }
                
                let longitude = coordinates[0]
                let latitude = coordinates[1]
                
                // Validate coordinates are within ACT bounds
                guard isWithinACTBounds(latitude: latitude, longitude: longitude) else {
                    return nil
                }
                
                let properties = feature.properties ?? [:]
                
                return AccidentLocation(
                    latitude: latitude,
                    longitude: longitude,
                    severity: extractSeverity(from: properties),
                    date: extractDate(from: properties),
                    description: extractDescription(from: properties)
                )
            }
            
            print("   ✅ Valid accident locations: \(accidents.count)")
            
            // Log sample accidents for debugging
            if accidents.count > 0 {
                print("   📍 Sample accident locations:")
                for accident in accidents.prefix(3) {
                    print("      • \(accident.severity) at (\(String(format: "%.4f", accident.latitude)), \(String(format: "%.4f", accident.longitude)))")
                }
            }
            
            return accidents
            
        } catch {
            print("❌ Failed to parse accident API response: \(error)")
            
            // Log response data for debugging (truncated)
            if let responseString = String(data: data.prefix(500), encoding: .utf8) {
                print("   📄 Response preview: \(responseString)...")
            }
            
            throw AccidentDataError.parsingError(error)
        }
    }
    
    // MARK: - Data Extraction Helpers
    
    /// Extract severity information from feature properties
    private func extractSeverity(from properties: [String: Any]) -> String {
        // Look for common severity field names
        let severityFields = ["severity", "SEVERITY", "accident_severity", "impact", "IMPACT"]
        
        for field in severityFields {
            if let severity = properties[field] as? String, !severity.isEmpty {
                return severity
            }
        }
        
        // Default based on other available data
        if properties["OBJECTID"] != nil {
            return "Moderate" // Has structured data, likely moderate
        }
        
        return "Minor" // Default fallback
    }
    
    /// Extract date information from feature properties
    private func extractDate(from properties: [String: Any]) -> Date {
        let dateFields = ["date", "DATE", "incident_date", "created_date", "CREATED_DATE"]
        
        for field in dateFields {
            if let dateValue = properties[field] {
                if let dateString = dateValue as? String {
                    // Try multiple date formats
                    let formatters = [
                        "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                        "yyyy-MM-dd'T'HH:mm:ssZ",
                        "yyyy-MM-dd HH:mm:ss",
                        "yyyy-MM-dd"
                    ]
                    
                    for format in formatters {
                        let formatter = DateFormatter()
                        formatter.dateFormat = format
                        if let date = formatter.date(from: dateString) {
                            return date
                        }
                    }
                } else if let timestamp = dateValue as? TimeInterval {
                    return Date(timeIntervalSince1970: timestamp / 1000) // Convert from milliseconds
                }
            }
        }
        
        // Default to recent past for safety calculations
        return Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    }
    
    /// Extract description from feature properties
    private func extractDescription(from properties: [String: Any]) -> String {
        let descriptionFields = ["description", "DESCRIPTION", "details", "DETAILS", "comments", "COMMENTS"]
        
        for field in descriptionFields {
            if let description = properties[field] as? String, !description.isEmpty {
                return description
            }
        }
        
        // Build description from available fields
        var descParts: [String] = []
        
        if let type = properties["type"] as? String ?? properties["TYPE"] as? String {
            descParts.append(type)
        }
        
        if let location = properties["location"] as? String ?? properties["LOCATION"] as? String {
            descParts.append("at \(location)")
        }
        
        return descParts.isEmpty ? "Road incident" : descParts.joined(separator: " ")
    }
    
    /// Check if coordinates are within ACT bounds
    private func isWithinACTBounds(latitude: Double, longitude: Double) -> Bool {
        // ACT approximate bounds
        let actBounds = (
            minLat: -35.921, maxLat: -35.124,
            minLon: 148.763, maxLon: 149.399
        )
        
        return latitude >= actBounds.minLat && latitude <= actBounds.maxLat &&
               longitude >= actBounds.minLon && longitude <= actBounds.maxLon
    }
}

// MARK: - GeoJSON Response Models

/// GeoJSON response structure from spatial API
private struct GeoJSONResponse: Codable {
    let type: String
    let features: [GeoJSONFeature]
}

/// Individual GeoJSON feature
private struct GeoJSONFeature: Codable {
    let type: String
    let geometry: GeoJSONGeometry?
    let properties: [String: Any]?
    
    private enum CodingKeys: String, CodingKey {
        case type, geometry, properties
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        geometry = try container.decodeIfPresent(GeoJSONGeometry.self, forKey: .geometry)
        
        // Handle properties as flexible dictionary
        if let propertiesContainer = try? container.nestedContainer(keyedBy: JSONCodingKeys.self, forKey: .properties) {
            var props: [String: Any] = [:]
            for key in propertiesContainer.allKeys {
                if let stringValue = try? propertiesContainer.decode(String.self, forKey: key) {
                    props[key.stringValue] = stringValue
                } else if let intValue = try? propertiesContainer.decode(Int.self, forKey: key) {
                    props[key.stringValue] = intValue
                } else if let doubleValue = try? propertiesContainer.decode(Double.self, forKey: key) {
                    props[key.stringValue] = doubleValue
                }
            }
            properties = props
        } else {
            properties = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(geometry, forKey: .geometry)
        
        // For encoding, we'll skip properties to avoid complexity
        // This is acceptable since we only decode, not encode
        try container.encodeIfPresent([String: String](), forKey: .properties)
    }
}

/// GeoJSON geometry structure
private struct GeoJSONGeometry: Codable {
    let type: String
    let coordinates: [Double]?
}

/// Dynamic JSON keys helper
private struct JSONCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
}

// MARK: - Error Handling

/// Errors that can occur when fetching accident data
enum AccidentDataError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case httpError(Int)
    case parsingError(Error)
    case noDataAvailable
    case spatialAPIError(String)
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid accident API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid spatial API response format"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .parsingError(let error):
            return "GeoJSON parsing error: \(error.localizedDescription)"
        case .noDataAvailable:
            return "No accident data available"
        case .spatialAPIError(let message):
            return "Spatial API error: \(message)"
        case .unknownError:
            return "Unknown error occurred"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError, .httpError:
            return "Check your internet connection and try again"
        case .parsingError, .spatialAPIError:
            return "The spatial API response format may have changed"
        default:
            return "Please try again later"
        }
    }
}
