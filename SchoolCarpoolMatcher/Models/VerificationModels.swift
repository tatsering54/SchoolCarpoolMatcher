//
//  VerificationModels.swift
//  SchoolCarpoolMatcher
//
//  Data models for F5 Trust & Verification System
//  Follows Apple Design Guidelines and implements F5.1-F5.3 requirements
//

import Foundation
import SwiftUI

// MARK: - Phone Verification Models (F5.1)
/// Phone verification request and response models
/// Implements F5.1 requirements: phone number verification via SMS code
struct PhoneVerificationRequest: Codable {
    let phoneNumber: String // Format: "+61412345678"
    let countryCode: String // "AU"
    let verificationMethod: VerificationMethod
    
    enum VerificationMethod: String, Codable, CaseIterable {
        case sms = "sms"
        case call = "call"
    }
}

struct PhoneVerificationResponse: Codable {
    let verificationId: String
    let expiresAt: Date
    let attemptsRemaining: Int
    let message: String
}

struct PhoneVerificationConfirmation: Codable {
    let verificationId: String
    let code: String // "123456"
    let deviceId: String?
}

struct PhoneVerificationResult: Codable {
    let success: Bool
    let verificationStatus: VerificationStatus
    let verificationId: String?
    let expiresAt: Date?
    let errorMessage: String?
}

// MARK: - Document Verification Models (F5.1)
/// Document verification models for identity documents
/// Implements F5.1 requirements: optional identity document upload
struct DocumentVerificationRequest: Codable {
    let documentType: DocumentType
    let documentNumber: String
    let expiryDate: Date?
    let documentImage: String? // Base64 encoded image or URL
    let verificationLevel: VerificationLevel
    
    enum DocumentType: String, Codable, CaseIterable {
        case driversLicense = "drivers_license"
        case passport = "passport"
        case medicareCard = "medicare_card"
        case birthCertificate = "birth_certificate"
        
        var displayName: String {
            switch self {
            case .driversLicense: return "Driver's License"
            case .passport: return "Passport"
            case .medicareCard: return "Medicare Card"
            case .birthCertificate: return "Birth Certificate"
            }
        }
        
        var icon: String {
            switch self {
            case .driversLicense: return "🚗"
            case .passport: return "📘"
            case .medicareCard: return "🏥"
            case .birthCertificate: return "📄"
            }
        }
    }
    
    enum VerificationLevel: String, Codable, CaseIterable {
        case basic = "basic"
        case enhanced = "enhanced"
        case premium = "premium"
        
        var displayName: String {
            switch self {
            case .basic: return "Basic Verification"
            case .enhanced: return "Enhanced Verification"
            case .premium: return "Premium Verification"
            }
        }
    }
}

struct DocumentVerificationResult: Codable {
    let documentId: String
    let verificationStatus: DocumentVerificationStatus
    let verifiedAt: Date?
}

enum DocumentVerificationStatus: String, Codable, CaseIterable {
    case verified = "verified"
    case pending = "pending"
    case rejected = "rejected"
    case expired = "expired"
    
    var displayName: String {
        switch self {
        case .verified: return "Verified"
        case .pending: return "Pending Review"
        case .rejected: return "Rejected"
        case .expired: return "Expired"
        }
    }
    
    var color: Color {
        switch self {
        case .verified: return .green
        case .pending: return .orange
        case .rejected: return .red
        case .expired: return .gray
        }
    }
}

// MARK: - Background Check Models (F5.1)
/// Background check models for premium verification features
/// Implements F5.1 requirements: background check integration (optional premium feature)
struct BackgroundCheckRequest: Codable {
    let checkType: BackgroundCheckType
    let consentGiven: Bool
    let personalDetails: PersonalDetails
    let previousAddresses: [Address]
    
    enum BackgroundCheckType: String, Codable, CaseIterable {
        case basic = "basic"
        case standard = "standard"
        case comprehensive = "comprehensive"
        
        var displayName: String {
            switch self {
            case .basic: return "Basic Check"
            case .standard: return "Standard Check"
            case .comprehensive: return "Comprehensive Check"
            }
        }
        
        var description: String {
            switch self {
            case .basic: return "Identity verification and basic criminal record check"
            case .standard: return "Enhanced background check including driving record"
            case .comprehensive: return "Full background check including employment and education verification"
            }
        }
        
        var estimatedCost: Double {
            switch self {
            case .basic: return 29.99
            case .standard: return 49.99
            case .comprehensive: return 99.99
            }
        }
    }
}

struct PersonalDetails: Codable {
    let firstName: String
    let lastName: String
    let dateOfBirth: Date
    let currentAddress: Address
    let email: String
    let phone: String
}

struct Address: Codable {
    let street: String
    let city: String
    let state: String
    let postcode: String
    let country: String
    let fromDate: Date
    let toDate: Date?
}

struct BackgroundCheckResult: Codable {
    let checkId: String
    let status: BackgroundCheckStatus
    let completedAt: Date?
    let expiresAt: Date?
    let reportUrl: String?
    let findings: [BackgroundCheckFinding]
    
    enum BackgroundCheckStatus: String, Codable, CaseIterable {
        case requested = "requested"
        case inProgress = "in_progress"
        case completed = "completed"
        case failed = "failed"
        case expired = "expired"
        
        var displayName: String {
            switch self {
            case .requested: return "Requested"
            case .inProgress: return "In Progress"
            case .completed: return "Completed"
            case .failed: return "Failed"
            case .expired: return "Expired"
            }
        }
        
        var color: Color {
            switch self {
            case .requested: return .blue
            case .inProgress: return .orange
            case .completed: return .green
            case .failed: return .red
            case .expired: return .gray
            }
        }
    }
}

struct BackgroundCheckFinding: Codable {
    let category: FindingCategory
    let severity: FindingSeverity
    let description: String
    let details: String?
    let recommendation: String?
    
    enum FindingCategory: String, Codable, CaseIterable {
        case criminalRecord = "criminal_record"
        case drivingRecord = "driving_record"
        case identityVerification = "identity_verification"
        case employmentHistory = "employment_history"
        case educationVerification = "education_verification"
        
        var displayName: String {
            switch self {
            case .criminalRecord: return "Criminal Record"
            case .drivingRecord: return "Driving Record"
            case .identityVerification: return "Identity Verification"
            case .employmentHistory: return "Employment History"
            case .educationVerification: return "Education Verification"
            }
        }
    }
    
    enum FindingSeverity: String, Codable, CaseIterable {
        case none = "none"
        case minor = "minor"
        case moderate = "moderate"
        case serious = "serious"
        case critical = "critical"
        
        var displayName: String {
            switch self {
            case .none: return "No Issues"
            case .minor: return "Minor Issues"
            case .moderate: return "Moderate Issues"
            case .serious: return "Serious Issues"
            case .critical: return "Critical Issues"
            }
        }
        
        var color: Color {
            switch self {
            case .none: return .green
            case .minor: return .yellow
            case .moderate: return .orange
            case .serious: return .red
            case .critical: return .purple
            }
        }
    }
}

// MARK: - Community Rating Models (F5.2)
/// Community rating system models
/// Implements F5.2 requirements: community rating system for trust building
struct UserRating: Codable, Identifiable {
    let id: UUID
    let rateeId: UUID
    let raterId: UUID
    let rating: Int // 1-5 stars
    let feedback: String?
    let tripId: UUID?
    let timestamp: Date
    let category: RatingCategory
    
    enum RatingCategory: String, Codable, CaseIterable {
        case reliability = "reliability"
        case punctuality = "punctuality"
        case safety = "safety"
        case communication = "communication"
        case cleanliness = "cleanliness"
        case overall = "overall"
        
        var displayName: String {
            switch self {
            case .reliability: return "Reliability"
            case .punctuality: return "Punctuality"
            case .safety: return "Safety"
            case .communication: return "Communication"
            case .cleanliness: return "Cleanliness"
            case .overall: return "Overall Experience"
            }
        }
        
        var icon: String {
            switch self {
            case .reliability: return "✅"
            case .punctuality: return "⏰"
            case .safety: return "🛡️"
            case .communication: return "💬"
            case .cleanliness: return "🧹"
            case .overall: return "⭐"
            }
        }
    }
}

struct RatingSubmission: Codable {
    let targetUserId: UUID
    let ratings: [CategoryRating]
    let feedback: String?
    let tripId: UUID?
    
    struct CategoryRating: Codable {
        let category: UserRating.RatingCategory
        let rating: Int // 1-5
    }
}

struct RatingSummary: Codable {
    let userId: UUID
    let averageRating: Double
    let totalRatings: Int
    let categoryBreakdown: [String: Double]
    let recentRatings: [UserRating]
    let ratingTrend: RatingTrend
    
    enum RatingTrend: String, Codable {
        case improving = "improving"
        case stable = "stable"
        case declining = "declining"
        
        var displayName: String {
            switch self {
            case .improving: return "Improving"
            case .stable: return "Stable"
            case .declining: return "Declining"
            }
        }
        
        var icon: String {
            switch self {
            case .improving: return "📈"
            case .stable: return "➡️"
            case .declining: return "📉"
            }
        }
    }
}

// MARK: - Safety Incident Reporting Models (F5.3)
/// Safety incident reporting models
/// Implements F5.3 requirements: safety incident reporting with evidence
struct IncidentReport: Codable, Identifiable {
    let id: UUID
    let incidentType: IncidentType
    let location: LocationData
    let description: String
    let involvedFamilyIds: [UUID]?
    let mediaEvidence: [MediaEvidence]?
    let timestamp: Date
    let severity: IncidentSeverity
    let isAnonymous: Bool
    let reporterId: UUID?
    let status: IncidentStatus
    
    enum IncidentType: String, Codable, CaseIterable {
        case recklessDriving = "reckless_driving"
        case inappropriateBehavior = "inappropriate_behavior"
        case safetyConcern = "safety_concern"
        case routeHazard = "route_hazard"
        case equipmentFailure = "equipment_failure"
        case other = "other"
        
        var displayName: String {
            switch self {
            case .recklessDriving: return "Reckless Driving"
            case .inappropriateBehavior: return "Inappropriate Behavior"
            case .safetyConcern: return "Safety Concern"
            case .routeHazard: return "Route Hazard"
            case .equipmentFailure: return "Equipment Failure"
            case .other: return "Other"
            }
        }
        
        var icon: String {
            switch self {
            case .recklessDriving: return "🚗"
            case .inappropriateBehavior: return "⚠️"
            case .safetyConcern: return "🛡️"
            case .routeHazard: return "🚧"
            case .equipmentFailure: return "🔧"
            case .other: return "❓"
            }
        }
    }
    
    enum IncidentSeverity: String, Codable, CaseIterable {
        case minor = "minor"
        case moderate = "moderate"
        case serious = "serious"
        case severe = "severe"
        
        var displayName: String {
            switch self {
            case .minor: return "Minor"
            case .moderate: return "Moderate"
            case .serious: return "Serious"
            case .severe: return "Severe"
            }
        }
        
        var color: Color {
            switch self {
            case .minor: return .yellow
            case .moderate: return .orange
            case .serious: return .red
            case .severe: return .purple
            }
        }
    }
    
    enum IncidentStatus: String, Codable, CaseIterable {
        case reported = "reported"
        case underReview = "under_review"
        case investigationStarted = "investigation_started"
        case resolved = "resolved"
        case closed = "closed"
        
        var displayName: String {
            switch self {
            case .reported: return "Reported"
            case .underReview: return "Under Review"
            case .investigationStarted: return "Investigation Started"
            case .resolved: return "Resolved"
            case .closed: return "Closed"
            }
        }
        
        var color: Color {
            switch self {
            case .reported: return .blue
            case .underReview: return .orange
            case .investigationStarted: return .yellow
            case .resolved: return .green
            case .closed: return .gray
            }
        }
    }
}

struct LocationData: Codable {
    let latitude: Double
    let longitude: Double
    let address: String?
    let description: String?
}

struct MediaEvidence: Codable, Identifiable {
    let id: UUID
    let type: MediaType
    let url: String
    let thumbnailUrl: String?
    let timestamp: Date
    let description: String?
    
    enum MediaType: String, Codable {
        case photo = "photo"
        case video = "video"
        case audio = "audio"
        case document = "document"
    }
}

// MARK: - Emergency Alert Models (F5.3)
/// Emergency alert models for immediate help
/// Implements F5.3 requirements: emergency button for immediate help
struct EmergencyAlert: Codable, Identifiable {
    let id: UUID
    let alertType: EmergencyType
    let location: LocationData
    let description: String?
    let contactEmergencyServices: Bool
    let severity: EmergencySeverity
    let timestamp: Date
    let status: EmergencyStatus
    let groupId: UUID?
    
    enum EmergencyType: String, Codable, CaseIterable {
        case accident = "accident"
        case breakdown = "breakdown"
        case medical = "medical"
        case safety = "safety_concern"
        case missing = "missing_child"
        case other = "other"
        
        var displayName: String {
            switch self {
            case .accident: return "Accident"
            case .breakdown: return "Vehicle Breakdown"
            case .medical: return "Medical Emergency"
            case .safety: return "Safety Concern"
            case .missing: return "Missing Child"
            case .other: return "Other Emergency"
            }
        }
        
        var icon: String {
            switch self {
            case .accident: return "🚨"
            case .breakdown: return "🚗"
            case .medical: return "🏥"
            case .safety: return "🛡️"
            case .missing: return "👶"
            case .other: return "⚠️"
            }
        }
    }
    
    enum EmergencySeverity: String, Codable, CaseIterable {
        case info = "info"
        case warning = "warning"
        case urgent = "urgent"
        case critical = "critical"
        
        var displayName: String {
            switch self {
            case .info: return "Information"
            case .warning: return "Warning"
            case .urgent: return "Urgent"
            case .critical: return "Critical"
            }
        }
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .yellow
            case .urgent: return .orange
            case .critical: return .red
            }
        }
    }
    
    enum EmergencyStatus: String, Codable, CaseIterable {
        case active = "active"
        case acknowledged = "acknowledged"
        case resolved = "resolved"
        case closed = "closed"
        
        var displayName: String {
            switch self {
            case .active: return "Active"
            case .acknowledged: return "Acknowledged"
            case .resolved: return "Resolved"
            case .closed: return "Closed"
            }
        }
    }
}
