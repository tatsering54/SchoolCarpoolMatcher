//
//  SchoolDataService.swift
//  SchoolCarpoolMatcher
//
//  ACT Government school location API integration for F2.1
//  Fetches school data from: https://www.data.act.gov.au/api/v3/views/8mi2-3658/query.json
//  Applied Rule: Debug logs and comprehensive error handling
//

import Foundation
import CoreLocation

// MARK: - School Data Service
/// Service for fetching school location data from ACT Government API
/// Used for F2.1 school zone safety analysis
class SchoolDataService: ObservableObject {
    
    // MARK: - API Configuration
    private let apiURL = "https://www.data.act.gov.au/api/v3/views/q8rt-q8cy/query.json?$$app_token=5sN0eeWT7cJvM6BTWPKUeHUeh"
    private let requestTimeout: TimeInterval = 30.0
    private let maxRetries = 3
    
    // MARK: - Published Properties
    @Published var schools: [SchoolLocation] = []
    @Published var isLoading = false
    @Published var lastFetchDate: Date?
    @Published var error: SchoolDataError?
    
    // MARK: - Private Properties
    private let urlSession: URLSession
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = requestTimeout
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config)
        
        print("🏫 SchoolDataService initialized with direct API access")
        print("   🔗 API URL: \(apiURL)")
        print("   ⏱️ Timeout: \(requestTimeout)s")
    }
    
    // MARK: - Request Creation
    
    /// Create simple URLRequest for direct API access
    private func createRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        
        // Basic headers
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("SchoolCarpoolMatcher/1.0 (iOS; Canberra School Transport)", forHTTPHeaderField: "User-Agent")
        
        print("🔗 Created direct API request")
        print("   🌐 URL: \(url)")
        
        return request
    }
    
    // MARK: - Public Methods
    
    /// Fetch school locations from ACT Government API using direct access
    func fetchSchoolLocations() async throws -> [SchoolLocation] {
        print("📥 Fetching school locations from ACT Government API...")
        
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let fetchedSchools = try await performSchoolAPIRequest()
            lastFetchDate = Date()
            schools = fetchedSchools // Update published property
            
            print("✅ Successfully fetched \(schools.count) schools")
            print("   📍 Coverage area: Canberra, ACT")
            
            return schools
            
        } catch let apiError as SchoolDataError {
            print("❌ School API error: \(apiError.localizedDescription)")
            error = apiError
            throw apiError
            
        } catch {
            print("❌ Unexpected error fetching schools: \(error)")
            let wrappedError = SchoolDataError.networkError(error)
            self.error = wrappedError
            throw wrappedError
        }
    }
    
    // MARK: - Private Methods
    
    /// Perform the actual API request with retry logic
    private func performSchoolAPIRequest() async throws -> [SchoolLocation] {
        guard let url = URL(string: apiURL) else {
            throw SchoolDataError.invalidURL
        }
        
        // var lastError: Error? // Removed unused variable
        
        // Retry logic for network reliability
        for attempt in 1...maxRetries {
            do {
                print("🔄 School API request attempt \(attempt)/\(maxRetries)")
                
                // Create simple request
                let request = createRequest(url: url)
                
                print("📤 Making API request...")
                print("   🔗 URL: \(request.url?.absoluteString ?? "nil")")
                print("   📋 Headers: \(request.allHTTPHeaderFields ?? [:])")
                
                let (data, response) = try await urlSession.data(for: request)
                
                print("📥 Received response:")
                print("   📊 Data size: \(data.count) bytes")
                if let responseString = String(data: data.prefix(500), encoding: .utf8) {
                    print("   📄 Response preview: \(responseString)")
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw SchoolDataError.invalidResponse
                }
                
                print("📡 School API response: \(httpResponse.statusCode)")
                
                guard 200...299 ~= httpResponse.statusCode else {
                    print("❌ HTTP Error: \(httpResponse.statusCode)")
                    throw SchoolDataError.httpError(httpResponse.statusCode)
                }
                
                print("✅ API request successful")
                
                let schools = try parseSchoolAPIResponse(data)
                return schools
                
            } catch {
                print("⚠️ School API attempt \(attempt) failed: \(error)")
                
                if attempt < maxRetries {
                    let delay = TimeInterval(attempt * 2) // Exponential backoff
                    print("⏳ Retrying in \(delay)s...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw SchoolDataError.unknownError
    }
    
    /// Parse the JSON response from ACT Government schools API
    private func parseSchoolAPIResponse(_ data: Data) throws -> [SchoolLocation] {
        print("📊 Parsing school API response...")
        
        do {
            // Parse as direct array of school objects (based on actual API response)
            let schoolRecords = try decoder.decode([DirectSchoolRecord].self, from: data)
            print("   ✅ Parsed \(schoolRecords.count) school records")
            
            let schools = schoolRecords.compactMap { record -> SchoolLocation? in
                guard let schoolName = record.school_name,
                      let location = record.location_1,
                      let latitude = location.latitude,
                      let longitude = location.longitude,
                      !schoolName.isEmpty else {
                    return nil
                }
                
                return SchoolLocation(
                    name: schoolName,
                    latitude: latitude,
                    longitude: longitude,
                    address: record.street_address ?? "Address not available",
                    schoolType: record.type ?? "Unknown"
                )
            }
            
            print("   ✅ Valid school locations: \(schools.count)")
            
            // Log sample schools for debugging
            if schools.count > 0 {
                print("   📍 Sample schools:")
                for school in schools.prefix(3) {
                    print("      • \(school.name) (\(String(format: "%.4f", school.latitude)), \(String(format: "%.4f", school.longitude)))")
                }
            }
            
            return schools
            
        } catch {
            print("❌ Failed to parse school API response: \(error)")
            throw SchoolDataError.parsingError(error)
        }
    }
    

}

// MARK: - API Response Models

/// Direct school record from ACT Government API (based on actual response format)
private struct DirectSchoolRecord: Codable {
    let school_name: String?
    let street_address: String?
    let suburb: String?
    let sector: String?
    let type: String?
    let location_1: SchoolLocation1?
}

/// Location data structure from ACT API
private struct SchoolLocation1: Codable {
    let latitude: Double?
    let longitude: Double?
}

// MARK: - Error Handling

/// Errors that can occur when fetching school data
enum SchoolDataError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case httpError(Int)
    case parsingError(Error)
    case noDataAvailable
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid school API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid API response format"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .parsingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        case .noDataAvailable:
            return "No school data available"
        case .unknownError:
            return "Unknown error occurred"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError, .httpError:
            return "Check your internet connection and try again"
        case .parsingError:
            return "The API response format may have changed"
        default:
            return "Please try again later"
        }
    }
}

// MARK: - Mock Data for Development

/// Mock school data for development and fallback
struct MockSafetyData {
    static let canberraSchools: [SchoolLocation] = [
        SchoolLocation(
            name: "Canberra Grammar School",
            latitude: -35.3186,
            longitude: 149.1339,
            address: "40 Monaro Crescent, Red Hill ACT 2603",
            schoolType: "Independent"
        ),
        SchoolLocation(
            name: "Radford College",
            latitude: -35.3089,
            longitude: 149.0981,
            address: "1 College Street, Bruce ACT 2617",
            schoolType: "Independent"
        ),
        SchoolLocation(
            name: "Campbell Primary School",
            latitude: -35.2851,
            longitude: 149.1543,
            address: "Treloar Crescent, Campbell ACT 2612",
            schoolType: "Government"
        ),
        SchoolLocation(
            name: "Turner School",
            latitude: -35.2743,
            longitude: 149.1258,
            address: "Condamine Street, Turner ACT 2612",
            schoolType: "Government"
        ),
        SchoolLocation(
            name: "Dickson College",
            latitude: -35.2503,
            longitude: 149.1394,
            address: "Phillip Avenue, Dickson ACT 2602",
            schoolType: "Government"
        ),
        SchoolLocation(
            name: "Lyneham High School",
            latitude: -35.2447,
            longitude: 149.1244,
            address: "Goodwin Street, Lyneham ACT 2602",
            schoolType: "Government"
        ),
        SchoolLocation(
            name: "Hawker Primary School",
            latitude: -35.2447,
            longitude: 149.0356,
            address: "Murrawai Street, Hawker ACT 2614",
            schoolType: "Government"
        ),
        SchoolLocation(
            name: "Belconnen High School",
            latitude: -35.2389,
            longitude: 149.0667,
            address: "Swanson Court, Belconnen ACT 2617",
            schoolType: "Government"
        ),
        SchoolLocation(
            name: "Woden School",
            latitude: -35.3444,
            longitude: 149.0856,
            address: "Fremantle Drive, Phillip ACT 2606",
            schoolType: "Government"
        ),
        SchoolLocation(
            name: "Tuggeranong Valley Primary School",
            latitude: -35.4167,
            longitude: 149.0833,
            address: "Southern Cross Drive, Wanniassa ACT 2903",
            schoolType: "Government"
        )
    ]
    
    // Mock accident data for development
    static let accidentLocations: [AccidentLocation] = [
        AccidentLocation(
            latitude: -35.2808,
            longitude: 149.1300,
            severity: "Minor",
            date: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
            description: "Minor collision at intersection"
        ),
        AccidentLocation(
            latitude: -35.3089,
            longitude: 149.0981,
            severity: "Moderate",
            date: Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date(),
            description: "Vehicle-pedestrian incident"
        ),
        AccidentLocation(
            latitude: -35.2447,
            longitude: 149.1244,
            severity: "Minor",
            date: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
            description: "Rear-end collision"
        )
    ]
}
