//
//  Family.swift
//  SchoolCarpoolMatcher
//
//  Core data model for family profiles with location and preferences
//  Follows repo rule: Debug logs and comprehensive comments
//

import Foundation
import CoreLocation

// MARK: - Family Model
/// Primary data model representing a family in the carpool matching system
/// Includes personal info, location data, transport preferences, and trust metrics
struct Family: Identifiable, Codable, Equatable {
    // MARK: - Primary Identifiers
    let id: UUID
    let parentId: UUID
    
    // MARK: - Personal Information  
    let parentName: String
    let parentPhone: String
    let parentEmail: String
    let childName: String
    let childAge: Int
    let childGrade: String
    
    // MARK: - Location Data
    let homeAddress: String
    let latitude: Double
    let longitude: Double
    let postcode: String
    let suburb: String
    
    // MARK: - School Information
    let schoolName: String
    let schoolAddress: String
    let schoolLatitude: Double
    let schoolLongitude: Double
    
    // MARK: - Transport Preferences
    let preferredDepartureTime: Date
    let departureTimeWindow: TimeInterval // ±15 minutes flexibility
    let maxDetourDistance: Double // meters
    let isDriverAvailable: Bool
    let vehicleType: VehicleType
    let vehicleSeats: Int
    let availableSeats: Int
    
    // MARK: - Trust & Safety
    let verificationLevel: VerificationLevel
    let averageRating: Double
    let totalRatings: Int
    let backgroundCheckStatus: BackgroundCheckStatus
    let joinDate: Date
    let lastActiveDate: Date
    
    // MARK: - Computed Properties
    /// CLLocationCoordinate2D for home location
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// CLLocationCoordinate2D for school location
    var schoolCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: schoolLatitude, longitude: schoolLongitude)
    }
    
    /// Determines if family meets high trust criteria
    /// Used for priority matching and safety features
    var isHighTrust: Bool {
        let result = verificationLevel == .verified && averageRating >= 4.5 && totalRatings >= 10
        print("🔍 Family \(parentName) high trust check: \(result) (verification: \(verificationLevel), rating: \(averageRating), reviews: \(totalRatings))")
        return result
    }
    
    /// CLLocation object for distance calculations
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    /// CLLocation object for school
    var schoolLocation: CLLocation {
        CLLocation(latitude: schoolLatitude, longitude: schoolLongitude)
    }
    
    // MARK: - Helper Methods
    
    /// Calculate distance to another family's home
    func distanceTo(family: Family) -> Double {
        let distance = location.distance(from: family.location)
        print("📍 Distance from \(parentName) to \(family.parentName): \(Int(distance))m")
        return distance
    }
    
    /// Calculate distance to school
    var distanceToSchool: Double {
        let distance = location.distance(from: schoolLocation)
        print("🏫 Distance from \(parentName) to \(schoolName): \(Int(distance))m")
        return distance
    }
}

// MARK: - Supporting Enums

/// Vehicle types available for carpool matching
enum VehicleType: String, CaseIterable, Codable {
    case sedan = "sedan"
    case suv = "suv" 
    case hatchback = "hatchback"
    case minivan = "minivan"
    case ute = "ute"
    case none = "none" // Passenger only
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .sedan: return "Sedan"
        case .suv: return "SUV"
        case .hatchback: return "Hatchback"
        case .minivan: return "Minivan"
        case .ute: return "Ute"
        case .none: return "Passenger Only"
        }
    }
    
    /// Typical seating capacity for vehicle type
    var typicalSeats: Int {
        switch self {
        case .sedan: return 5
        case .suv: return 7
        case .hatchback: return 5
        case .minivan: return 8
        case .ute: return 5
        case .none: return 0
        }
    }
}

/// Verification levels for trust and safety
enum VerificationLevel: String, CaseIterable, Codable {
    case unverified = "unverified"
    case phoneVerified = "phone_verified"  
    case documentsVerified = "documents_verified"
    case verified = "verified" // Full verification complete
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .unverified: return "Unverified"
        case .phoneVerified: return "Phone Verified"
        case .documentsVerified: return "Documents Verified"
        case .verified: return "Fully Verified"
        }
    }
    
    /// Trust score multiplier for matching algorithm
    var trustMultiplier: Double {
        switch self {
        case .unverified: return 0.5
        case .phoneVerified: return 0.7
        case .documentsVerified: return 0.9
        case .verified: return 1.0
        }
    }
}

/// Background check status for enhanced safety
enum BackgroundCheckStatus: String, CaseIterable, Codable {
    case notRequested = "not_requested"
    case pending = "pending"
    case cleared = "cleared"
    case flagged = "flagged"
    case failed = "failed"
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .notRequested: return "Not Requested"
        case .pending: return "Pending"
        case .cleared: return "Cleared"
        case .flagged: return "Flagged"
        case .failed: return "Failed"
        }
    }
    
    /// Whether this status allows participation
    var isEligible: Bool {
        switch self {
        case .cleared, .notRequested: return true
        case .pending: return true // Allow with warning
        case .flagged, .failed: return false
        }
    }
}

// MARK: - User Preferences Model

/// User preferences for matching algorithm
struct UserPreferences: Codable {
    let searchRadius: Double // meters, default 3000
    let departureTime: Date
    let timeFlexibility: TimeInterval // seconds, default ±15 minutes
    let requiredSeats: Int
    let maxDetourTime: TimeInterval // seconds, default 10 minutes
    let prioritizeSafety: Bool // default true
    let requireVerification: Bool // default false
    let allowBackgroundCheck: Bool // default false
    
    init(
        searchRadius: Double = 3000,
        departureTime: Date = Date(),
        timeFlexibility: TimeInterval = 15 * 60, // 15 minutes
        requiredSeats: Int = 1,
        maxDetourTime: TimeInterval = 10 * 60, // 10 minutes
        prioritizeSafety: Bool = true,
        requireVerification: Bool = false,
        allowBackgroundCheck: Bool = false
    ) {
        self.searchRadius = searchRadius
        self.departureTime = departureTime
        self.timeFlexibility = timeFlexibility
        self.requiredSeats = requiredSeats
        self.maxDetourTime = maxDetourTime
        self.prioritizeSafety = prioritizeSafety
        self.requireVerification = requireVerification
        self.allowBackgroundCheck = allowBackgroundCheck
        
        // Debug log for preference creation
        print("⚙️ Created UserPreferences: radius=\(Int(searchRadius))m, seats=\(requiredSeats), safety=\(prioritizeSafety)")
    }
}
