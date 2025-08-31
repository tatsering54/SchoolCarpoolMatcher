//
//  MockData.swift
//  SchoolCarpoolMatcher
//
//  Realistic Canberra mock data for demo purposes
//  Includes actual suburbs, schools, and compelling family stories
//  Follows repo rule: Offline demo capability with edge cases
//

import Foundation
import CoreLocation

// MARK: - Mock Data Provider
/// Provides realistic Canberra-based mock data for hackathon demo
/// All data works offline and tells compelling stories
struct MockData {
    
    // MARK: - Canberra Schools Data
    static let canberraSchools = [
        School(name: "Telopea Park School", address: "New South Wales Cres, Forrest ACT 2603", 
               latitude: -35.3138, longitude: 149.1346),
        School(name: "Campbell Primary School", address: "Treloar Cres, Campbell ACT 2612", 
               latitude: -35.2891, longitude: 149.1527),
        School(name: "Red Hill Primary School", address: "Mugga Way, Red Hill ACT 2603", 
               latitude: -35.3360, longitude: 149.1315),
        School(name: "Forrest Primary School", address: "Hobart Ave, Forrest ACT 2603", 
               latitude: -35.3194, longitude: 149.1254),
        School(name: "Griffith Primary School", address: "Blaxland Cres, Griffith ACT 2603", 
               latitude: -35.3247, longitude: 149.1391),
        School(name: "Narrabundah College", address: "Jerrabomberra Ave, Narrabundah ACT 2604", 
               latitude: -35.3429, longitude: 149.1543),
        School(name: "Canberra Grammar School", address: "40 Monaro Cres, Red Hill ACT 2603", 
               latitude: -35.3380, longitude: 149.1295),
        School(name: "Burgmann Anglican School", address: "51 Burbury Cl, Gungahlin ACT 2912", 
               latitude: -35.1847, longitude: 149.1324)
    ]
    
    // MARK: - Sample Families with Compelling Stories
    /// 20+ realistic family profiles covering diverse situations
    /// Designed to demonstrate successful matching scenarios
    static let families: [Family] = [
        
        // STORY 1: The Busy Professional Family (High Trust)
        Family(
            id: UUID(),
            parentId: UUID(),
            parentName: "Sarah Chen",
            parentPhone: "+61412345678",
            parentEmail: "sarah.chen@example.com",
            childName: "Emma Chen",
            childAge: 8,
            childGrade: "Year 3",
            homeAddress: "15 Schlich Street, Yarralumla ACT 2600",
            latitude: -35.3089,
            longitude: 149.0981,
            postcode: "2600",
            suburb: "Yarralumla",
            schoolName: "Forrest Primary School",
            schoolAddress: "Hobart Ave, Forrest ACT 2603",
            schoolLatitude: -35.3194,
            schoolLongitude: 149.1254,
            preferredDepartureTime: createTime(hour: 8, minute: 15), // 8:15 AM
            departureTimeWindow: 10 * 60, // ±10 minutes
            maxDetourDistance: 2000, // 2km
            isDriverAvailable: true,
            vehicleType: .suv,
            vehicleSeats: 7,
            availableSeats: 4,
            verificationLevel: .verified,
            averageRating: 4.8,
            totalRatings: 23,
            backgroundCheckStatus: .cleared,
            joinDate: Calendar.current.date(byAdding: .month, value: -8, to: Date()) ?? Date(),
            lastActiveDate: Date()
        ),
        
        // STORY 2: The New Family (Needs Help)
        Family(
            id: UUID(),
            parentId: UUID(),
            parentName: "Michael Rodriguez",
            parentPhone: "+61423456789",
            parentEmail: "m.rodriguez@example.com",
            childName: "Lucas Rodriguez",
            childAge: 6,
            childGrade: "Year 1",
            homeAddress: "8 Dominion Circuit, Forrest ACT 2603",
            latitude: -35.3156,
            longitude: 149.1289,
            postcode: "2603",
            suburb: "Forrest",
            schoolName: "Forrest Primary School",
            schoolAddress: "Hobart Ave, Forrest ACT 2603",
            schoolLatitude: -35.3194,
            schoolLongitude: 149.1254,
            preferredDepartureTime: createTime(hour: 8, minute: 20), // 8:20 AM
            departureTimeWindow: 15 * 60, // ±15 minutes
            maxDetourDistance: 1500,
            isDriverAvailable: false, // Needs rides
            vehicleType: .none,
            vehicleSeats: 0,
            availableSeats: 0,
            verificationLevel: .phoneVerified,
            averageRating: 4.2,
            totalRatings: 5, // New user
            backgroundCheckStatus: .pending,
            joinDate: Calendar.current.date(byAdding: .weekOfYear, value: -2, to: Date()) ?? Date(),
            lastActiveDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        ),
        
        // STORY 3: The Community Builder (Perfect Match for Sarah)
        Family(
            id: UUID(),
            parentId: UUID(),
            parentName: "Jennifer Walsh",
            parentPhone: "+61434567890",
            parentEmail: "jen.walsh@example.com",
            childName: "Olivia Walsh",
            childAge: 8,
            childGrade: "Year 3",
            homeAddress: "22 Melbourne Avenue, Forrest ACT 2603",
            latitude: -35.3178,
            longitude: 149.1267,
            postcode: "2603",
            suburb: "Forrest",
            schoolName: "Forrest Primary School",
            schoolAddress: "Hobart Ave, Forrest ACT 2603",
            schoolLatitude: -35.3194,
            schoolLongitude: 149.1254,
            preferredDepartureTime: createTime(hour: 8, minute: 10), // 8:10 AM
            departureTimeWindow: 20 * 60, // ±20 minutes - very flexible
            maxDetourDistance: 3000,
            isDriverAvailable: true,
            vehicleType: .minivan,
            vehicleSeats: 8,
            availableSeats: 5, // Lots of space
            verificationLevel: .verified,
            averageRating: 4.9,
            totalRatings: 31,
            backgroundCheckStatus: .cleared,
            joinDate: Calendar.current.date(byAdding: .month, value: -12, to: Date()) ?? Date(),
            lastActiveDate: Date()
        ),
        
        // STORY 4: The Working Single Parent (Time Pressured)
        Family(
            id: UUID(),
            parentId: UUID(),
            parentName: "David Kim",
            parentPhone: "+61445678901",
            parentEmail: "david.kim@example.com",
            childName: "Sophie Kim",
            childAge: 9,
            childGrade: "Year 4",
            homeAddress: "45 Captain Cook Crescent, Griffith ACT 2603",
            latitude: -35.3211,
            longitude: 149.1378,
            postcode: "2603",
            suburb: "Griffith",
            schoolName: "Griffith Primary School",
            schoolAddress: "Blaxland Cres, Griffith ACT 2603",
            schoolLatitude: -35.3247,
            schoolLongitude: 149.1391,
            preferredDepartureTime: createTime(hour: 7, minute: 45), // Early start
            departureTimeWindow: 5 * 60, // ±5 minutes - strict schedule
            maxDetourDistance: 1000,
            isDriverAvailable: true,
            vehicleType: .sedan,
            vehicleSeats: 5,
            availableSeats: 2,
            verificationLevel: .documentsVerified,
            averageRating: 4.6,
            totalRatings: 18,
            backgroundCheckStatus: .cleared,
            joinDate: Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date(),
            lastActiveDate: Calendar.current.date(byAdding: .hour, value: -3, to: Date()) ?? Date()
        ),
        
        // STORY 5: The Eco-Conscious Family (Environmental Focus)
        Family(
            id: UUID(),
            parentId: UUID(),
            parentName: "Amanda Green",
            parentPhone: "+61456789012",
            parentEmail: "amanda.green@example.com",
            childName: "Noah Green",
            childAge: 7,
            childGrade: "Year 2",
            homeAddress: "12 National Circuit, Barton ACT 2600",
            latitude: -35.3042,
            longitude: 149.1347,
            postcode: "2600",
            suburb: "Barton",
            schoolName: "Telopea Park School",
            schoolAddress: "New South Wales Cres, Forrest ACT 2603",
            schoolLatitude: -35.3138,
            schoolLongitude: 149.1346,
            preferredDepartureTime: createTime(hour: 8, minute: 30), // 8:30 AM
            departureTimeWindow: 25 * 60, // Very flexible
            maxDetourDistance: 4000, // Happy to help others
            isDriverAvailable: true,
            vehicleType: .hatchback, // Fuel efficient
            vehicleSeats: 5,
            availableSeats: 3,
            verificationLevel: .verified,
            averageRating: 4.7,
            totalRatings: 15,
            backgroundCheckStatus: .cleared,
            joinDate: Calendar.current.date(byAdding: .month, value: -4, to: Date()) ?? Date(),
            lastActiveDate: Date()
        ),
        
        // STORY 6: The Reliable Grandparent Helper
        Family(
            id: UUID(),
            parentId: UUID(),
            parentName: "Margaret Thompson",
            parentPhone: "+61467890123",
            parentEmail: "margaret.thompson@example.com",
            childName: "Jack Thompson",
            childAge: 10,
            childGrade: "Year 5",
            homeAddress: "33 Hopetoun Circuit, Yarralumla ACT 2600",
            latitude: -35.3067,
            longitude: 149.0934,
            postcode: "2600",
            suburb: "Yarralumla",
            schoolName: "Forrest Primary School",
            schoolAddress: "Hobart Ave, Forrest ACT 2603",
            schoolLatitude: -35.3194,
            schoolLongitude: 149.1254,
            preferredDepartureTime: createTime(hour: 8, minute: 0), // Early and reliable
            departureTimeWindow: 30 * 60, // Very accommodating
            maxDetourDistance: 5000,
            isDriverAvailable: true,
            vehicleType: .suv,
            vehicleSeats: 7,
            availableSeats: 4,
            verificationLevel: .verified,
            averageRating: 5.0, // Perfect rating
            totalRatings: 42,
            backgroundCheckStatus: .cleared,
            joinDate: Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date(),
            lastActiveDate: Date()
        ),
        
        // Additional families for comprehensive demo...
        
        // STORY 7: The Tech Family (Campbell area)
        Family(
            id: UUID(),
            parentId: UUID(),
            parentName: "James Patterson",
            parentPhone: "+61478901234",
            parentEmail: "james.patterson@example.com",
            childName: "Ethan Patterson",
            childAge: 9,
            childGrade: "Year 4",
            homeAddress: "18 Treloar Crescent, Campbell ACT 2612",
            latitude: -35.2885,
            longitude: 149.1521,
            postcode: "2612",
            suburb: "Campbell",
            schoolName: "Campbell Primary School",
            schoolAddress: "Treloar Cres, Campbell ACT 2612",
            schoolLatitude: -35.2891,
            schoolLongitude: 149.1527,
            preferredDepartureTime: createTime(hour: 8, minute: 25),
            departureTimeWindow: 10 * 60,
            maxDetourDistance: 2500,
            isDriverAvailable: true,
            vehicleType: .suv,
            vehicleSeats: 7,
            availableSeats: 3,
            verificationLevel: .verified,
            averageRating: 4.5,
            totalRatings: 12,
            backgroundCheckStatus: .cleared,
            joinDate: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
            lastActiveDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        ),
        
        // STORY 8: The Arts Family (Red Hill)
        Family(
            id: UUID(),
            parentId: UUID(),
            parentName: "Lisa Martinez",
            parentPhone: "+61489012345",
            parentEmail: "lisa.martinez@example.com",
            childName: "Isabella Martinez",
            childAge: 6,
            childGrade: "Kindergarten",
            homeAddress: "7 Mugga Way, Red Hill ACT 2603",
            latitude: -35.3355,
            longitude: 149.1310,
            postcode: "2603",
            suburb: "Red Hill",
            schoolName: "Red Hill Primary School",
            schoolAddress: "Mugga Way, Red Hill ACT 2603",
            schoolLatitude: -35.3360,
            schoolLongitude: 149.1315,
            preferredDepartureTime: createTime(hour: 8, minute: 35),
            departureTimeWindow: 15 * 60,
            maxDetourDistance: 1800,
            isDriverAvailable: true,
            vehicleType: .hatchback,
            vehicleSeats: 5,
            availableSeats: 2,
            verificationLevel: .phoneVerified,
            averageRating: 4.3,
            totalRatings: 8,
            backgroundCheckStatus: .notRequested,
            joinDate: Calendar.current.date(byAdding: .weekOfYear, value: -6, to: Date()) ?? Date(),
            lastActiveDate: Calendar.current.date(byAdding: .hour, value: -12, to: Date()) ?? Date()
        ),
        
        // STORY 9: The Sports Family (Narrabundah)
        Family(
            id: UUID(),
            parentId: UUID(),
            parentName: "Robert Johnson",
            parentPhone: "+61490123456",
            parentEmail: "rob.johnson@example.com",
            childName: "Tyler Johnson",
            childAge: 11,
            childGrade: "Year 6",
            homeAddress: "25 Jerrabomberra Avenue, Narrabundah ACT 2604",
            latitude: -35.3425,
            longitude: 149.1538,
            postcode: "2604",
            suburb: "Narrabundah",
            schoolName: "Narrabundah College",
            schoolAddress: "Jerrabomberra Ave, Narrabundah ACT 2604",
            schoolLatitude: -35.3429,
            schoolLongitude: 149.1543,
            preferredDepartureTime: createTime(hour: 8, minute: 5),
            departureTimeWindow: 8 * 60,
            maxDetourDistance: 2200,
            isDriverAvailable: true,
            vehicleType: .ute,
            vehicleSeats: 5,
            availableSeats: 3,
            verificationLevel: .documentsVerified,
            averageRating: 4.4,
            totalRatings: 19,
            backgroundCheckStatus: .cleared,
            joinDate: Calendar.current.date(byAdding: .month, value: -5, to: Date()) ?? Date(),
            lastActiveDate: Calendar.current.date(byAdding: .hour, value: -6, to: Date()) ?? Date()
        ),
        
        // STORY 10: The Academic Family (Private School)
        Family(
            id: UUID(),
            parentId: UUID(),
            parentName: "Catherine Williams",
            parentPhone: "+61401234567",
            parentEmail: "catherine.williams@example.com",
            childName: "Alexander Williams",
            childAge: 12,
            childGrade: "Year 7",
            homeAddress: "14 Monaro Crescent, Red Hill ACT 2603",
            latitude: -35.3375,
            longitude: 149.1290,
            postcode: "2603",
            suburb: "Red Hill",
            schoolName: "Canberra Grammar School",
            schoolAddress: "40 Monaro Cres, Red Hill ACT 2603",
            schoolLatitude: -35.3380,
            schoolLongitude: 149.1295,
            preferredDepartureTime: createTime(hour: 7, minute: 50),
            departureTimeWindow: 5 * 60, // Strict private school timing
            maxDetourDistance: 1200,
            isDriverAvailable: true,
            vehicleType: .sedan,
            vehicleSeats: 5,
            availableSeats: 1, // Often full
            verificationLevel: .verified,
            averageRating: 4.8,
            totalRatings: 26,
            backgroundCheckStatus: .cleared,
            joinDate: Calendar.current.date(byAdding: .month, value: -10, to: Date()) ?? Date(),
            lastActiveDate: Date()
        ),
        
        // STORY 11: The Flexible Family (Different Time)
        Family(
            id: UUID(),
            parentId: UUID(),
            parentName: "David Thompson",
            parentPhone: "+61412345679",
            parentEmail: "david.thompson@example.com",
            childName: "Sophie Thompson",
            childAge: 9,
            childGrade: "Year 4",
            homeAddress: "22 Mugga Way, Red Hill ACT 2603",
            latitude: -35.3350,
            longitude: 149.1320,
            postcode: "2603",
            suburb: "Red Hill",
            schoolName: "Red Hill Primary School",
            schoolAddress: "Mugga Way, Red Hill ACT 2603",
            schoolLatitude: -35.3360,
            schoolLongitude: 149.1315,
            preferredDepartureTime: createTime(hour: 8, minute: 45), // Later departure
            departureTimeWindow: 20 * 60, // ±20 minutes flexibility
            maxDetourDistance: 2500,
            isDriverAvailable: true,
            vehicleType: .hatchback,
            vehicleSeats: 5,
            availableSeats: 2,
            verificationLevel: .verified,
            averageRating: 4.6,
            totalRatings: 18,
            backgroundCheckStatus: .cleared,
            joinDate: Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date(),
            lastActiveDate: Date()
        ),
        
        // STORY 12: The Large Family (Minivan)
        Family(
            id: UUID(),
            parentId: UUID(),
            parentName: "Jennifer O'Connor",
            parentPhone: "+61423456780",
            parentEmail: "jennifer.oconnor@example.com",
            childName: "Bridget O'Connor",
            childAge: 7,
            childGrade: "Year 2",
            homeAddress: "7 Hobart Avenue, Forrest ACT 2603",
            latitude: -35.3180,
            longitude: 149.1260,
            postcode: "2603",
            suburb: "Forrest",
            schoolName: "Forrest Primary School",
            schoolAddress: "Hobart Ave, Forrest ACT 2603",
            schoolLatitude: -35.3194,
            schoolLongitude: 149.1254,
            preferredDepartureTime: createTime(hour: 8, minute: 10),
            departureTimeWindow: 15 * 60,
            maxDetourDistance: 3000,
            isDriverAvailable: true,
            vehicleType: .minivan,
            vehicleSeats: 8,
            availableSeats: 5, // Lots of space
            verificationLevel: .verified,
            averageRating: 4.9,
            totalRatings: 31,
            backgroundCheckStatus: .cleared,
            joinDate: Calendar.current.date(byAdding: .month, value: -12, to: Date()) ?? Date(),
            lastActiveDate: Date()
        ),
        
        // STORY 13: The Newcomer Family (Needs Community)
        Family(
            id: UUID(),
            parentId: UUID(),
            parentName: "Raj Patel",
            parentPhone: "+61434567890",
            parentEmail: "raj.patel@example.com",
            childName: "Arjun Patel",
            childAge: 10,
            childGrade: "Year 5",
            homeAddress: "12 New South Wales Crescent, Forrest ACT 2603",
            latitude: -35.3140,
            longitude: 149.1350,
            postcode: "2603",
            suburb: "Forrest",
            schoolName: "Telopea Park School",
            schoolAddress: "New South Wales Cres, Forrest ACT 2603",
            schoolLatitude: -35.3138,
            schoolLongitude: 149.1346,
            preferredDepartureTime: createTime(hour: 8, minute: 25),
            departureTimeWindow: 25 * 60, // Very flexible
            maxDetourDistance: 4000, // Willing to travel further
            isDriverAvailable: false, // Needs rides initially
            vehicleType: .none,
            vehicleSeats: 0,
            availableSeats: 0,
            verificationLevel: .phoneVerified,
            averageRating: 0.0,
            totalRatings: 0,
            backgroundCheckStatus: .notRequested,
            joinDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
            lastActiveDate: Date()
        ),
        
        // STORY 14: The Early Bird Family (Early Departure)
        Family(
            id: UUID(),
            parentId: UUID(),
            parentName: "Lisa Anderson",
            parentPhone: "+61445678901",
            parentEmail: "lisa.anderson@example.com",
            childName: "Mia Anderson",
            childAge: 11,
            childGrade: "Year 6",
            homeAddress: "18 Dominion Circuit, Forrest ACT 2603",
            latitude: -35.3160,
            longitude: 149.1290,
            postcode: "2603",
            suburb: "Forrest",
            schoolName: "Forrest Primary School",
            schoolAddress: "Hobart Ave, Forrest ACT 2603",
            schoolLatitude: -35.3194,
            schoolLongitude: 149.1254,
            preferredDepartureTime: createTime(hour: 7, minute: 30), // Very early
            departureTimeWindow: 10 * 60,
            maxDetourDistance: 1800,
            isDriverAvailable: true,
            vehicleType: .suv,
            vehicleSeats: 6,
            availableSeats: 3,
            verificationLevel: .verified,
            averageRating: 4.7,
            totalRatings: 22,
            backgroundCheckStatus: .cleared,
            joinDate: Calendar.current.date(byAdding: .month, value: -9, to: Date()) ?? Date(),
            lastActiveDate: Date()
        ),
        
        // STORY 15: The Weekend Family (Occasional Driver)
        Family(
            id: UUID(),
            parentId: UUID(),
            parentName: "Mark Wilson",
            parentPhone: "+61456789012",
            parentEmail: "mark.wilson@example.com",
            childName: "Ethan Wilson",
            childAge: 8,
            childGrade: "Year 3",
            homeAddress: "25 Schlich Street, Yarralumla ACT 2600",
            latitude: -35.3090,
            longitude: 149.0990,
            postcode: "2600",
            suburb: "Yarralumla",
            schoolName: "Forrest Primary School",
            schoolAddress: "Hobart Ave, Forrest ACT 2603",
            schoolLatitude: -35.3194,
            schoolLongitude: 149.1254,
            preferredDepartureTime: createTime(hour: 8, minute: 30),
            departureTimeWindow: 30 * 60, // Very flexible
            maxDetourDistance: 3500,
            isDriverAvailable: true,
            vehicleType: .ute,
            vehicleSeats: 5,
            availableSeats: 2,
            verificationLevel: .verified,
            averageRating: 4.5,
            totalRatings: 15,
            backgroundCheckStatus: .cleared,
            joinDate: Calendar.current.date(byAdding: .month, value: -7, to: Date()) ?? Date(),
            lastActiveDate: Date()
        )
    ]
    
    // MARK: - Helper Functions
    
    /// Create a time for today at specified hour and minute
    private static func createTime(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let components = DateComponents(hour: hour, minute: minute)
        return calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) ?? now
    }
    
    /// Get families near a specific location for testing
    static func getFamiliesNear(location: CLLocation, radius: Double = 3000) -> [Family] {
        return families.filter { family in
            let familyLocation = CLLocation(latitude: family.latitude, longitude: family.longitude)
            return location.distance(from: familyLocation) <= radius
        }
    }
    
    /// Get families attending the same school
    static func getFamiliesForSchool(_ schoolName: String) -> [Family] {
        return families.filter { $0.schoolName == schoolName }
    }
    
    /// Get high-trust families for safety demonstration
    static func getHighTrustFamilies() -> [Family] {
        return families.filter { $0.isHighTrust }
    }
    
    /// Get families available as drivers
    static func getDriverFamilies() -> [Family] {
        return families.filter { $0.isDriverAvailable && $0.availableSeats > 0 }
    }
    
    /// Get families needing rides
    static func getPassengerFamilies() -> [Family] {
        return families.filter { !$0.isDriverAvailable || $0.availableSeats == 0 }
    }
    
    // MARK: - Mock Carpool Groups for Testing
    static let sampleGroups: [CarpoolGroup] = [
        CarpoolGroup(
            groupName: "Forrest Primary Carpool",
            adminId: UUID(),
            members: [
                GroupMember(
                    familyId: families[0].id,
                    role: .admin,
                    contributionScore: 95.0
                ),
                GroupMember(
                    familyId: families[2].id,
                    role: .driver,
                    contributionScore: 88.0
                )
            ],
            schoolName: "Forrest Primary School",
            schoolAddress: "Hobart Ave, Forrest ACT 2603",
            scheduledDepartureTime: createTime(hour: 8, minute: 15),
            pickupSequence: [
                PickupPoint(
                    familyId: families[0].id,
                    coordinate: families[0].coordinate,
                    address: families[0].homeAddress,
                    sequenceOrder: 1
                ),
                PickupPoint(
                    familyId: families[2].id,
                    coordinate: families[2].coordinate,
                    address: families[2].homeAddress,
                    sequenceOrder: 2
                )
            ],
            optimizedRoute: Route(
                groupId: UUID(),
                pickupPoints: [
                    PickupPoint(
                        familyId: families[0].id,
                        coordinate: families[0].coordinate,
                        address: families[0].homeAddress,
                        sequenceOrder: 1
                    ),
                    PickupPoint(
                        familyId: families[2].id,
                        coordinate: families[2].coordinate,
                        address: families[2].homeAddress,
                        sequenceOrder: 2
                    )
                ],
                safetyScore: 8.5
            ),
            safetyScore: 8.5
        )
    ]
}

// MARK: - Supporting School Model
struct School {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Demo Scenarios
/// Predefined scenarios for compelling hackathon demonstrations
struct DemoScenarios {
    
    /// Scenario 1: Perfect Match
    /// Sarah Chen (Yarralumla) matches with Jennifer Walsh (Forrest)
    /// Both going to Forrest Primary, similar times, high trust
    static let perfectMatch = [
        MockData.families[0], // Sarah Chen
        MockData.families[2]  // Jennifer Walsh
    ]
    
    /// Scenario 2: Community Building
    /// New family Michael Rodriguez gets help from established community
    static let communityBuilding = [
        MockData.families[1], // Michael Rodriguez (new, needs help)
        MockData.families[5], // Margaret Thompson (helpful grandparent)
        MockData.families[2]  // Jennifer Walsh (community builder)
    ]
    
    /// Scenario 3: Time-Critical Matching
    /// David Kim (strict schedule) finds compatible families
    static let timeCritical = [
        MockData.families[3], // David Kim (strict timing)
        MockData.families[9]  // Catherine Williams (also early/strict)
    ]
    
    /// Scenario 4: Environmental Impact
    /// Amanda Green builds eco-friendly carpool group
    static let environmentalImpact = [
        MockData.families[4], // Amanda Green (eco-conscious)
        MockData.families[1], // Michael Rodriguez (passenger)
        MockData.families[4]  // Multiple families reducing emissions
    ]
}

// MARK: - Debug Helpers
extension MockData {
    /// Print family information for debugging
    static func debugPrintFamilies() {
        print("🏠 MOCK DATA: \(families.count) families loaded")
        for family in families {
            print("👨‍👩‍👧‍👦 \(family.parentName) - \(family.childName) (\(family.suburb))")
            print("   🏫 School: \(family.schoolName)")
            print("   🚗 Vehicle: \(family.vehicleType.displayName) (\(family.availableSeats) seats)")
            print("   ⭐ Rating: \(family.averageRating) (\(family.totalRatings) reviews)")
            print("   ✅ Trust: \(family.verificationLevel.displayName)")
            print("   ---")
        }
    }
}

// MARK: - User Preferences Extension
extension UserPreferences {
    /// Demo preferences for testing
    static func demoPreferences() -> UserPreferences {
        return UserPreferences(
            searchRadius: 10000, // Increased from 3000 to 10000m (10km) to find all families
            departureTime: createTime(hour: 8, minute: 15), // 8:15 AM
            timeFlexibility: 15 * 60, // ±15 minutes
            requiredSeats: 1,
            maxDetourTime: 10 * 60, // 10 minutes
            prioritizeSafety: true,
            requireVerification: false,
            allowBackgroundCheck: false
        )
    }
    
    private static func createTime(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let components = DateComponents(hour: hour, minute: minute)
        return calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) ?? now
    }
}
