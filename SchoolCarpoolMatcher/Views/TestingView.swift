//
//  TestingView.swift
//  SchoolCarpoolMatcher
//
//  Debug and testing view for components (F2, F3 features)
//  F1 testing components moved to main Get Started flow
//  Applied Rule: Comprehensive debug logging and testing utilities
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Testing View
/// Debug view for testing all components without dependencies
struct TestingView: View {
    
    // MARK: - Navigation
    @Environment(\.dismiss) private var dismiss
    var onBack: (() -> Void)? = nil
    
    // MARK: - State
    @State private var selectedTab = 0
    @State private var showingSafetyWarning = false
    @StateObject private var locationManager = LocationManager()
    @StateObject private var matchingEngine: MatchingEngine
    @StateObject private var schoolDataService = SchoolDataService()
    @StateObject private var accidentDataService = AccidentDataService()
    @StateObject private var actTransportService = ACTTransportService()
    @StateObject private var scheduleCoordinationService = ScheduleCoordinationService()
    
    // API Testing State
    @State private var apiTestResults: [String] = []
    @State private var isTestingAPIs = false
    

    
    // MARK: - Initialization
    init(onBack: (() -> Void)? = nil) {
        print("🧪 TestingView initialized - bypassing location requirements")
        self.onBack = onBack
        
        let sharedLocationManager = LocationManager()
        self._locationManager = StateObject(wrappedValue: sharedLocationManager)
        self._matchingEngine = StateObject(wrappedValue: MatchingEngine(locationManager: sharedLocationManager))
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Test Component", selection: $selectedTab) {
                    Text("Debug Info").tag(0)
                    Text("API Testing").tag(1)
                    Text("F2.3 Multi-Modal").tag(2)
                    Text("F3.2 Location").tag(3)
                    Text("F3.3 Schedule").tag(4)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content
                TabView(selection: $selectedTab) {
                    // Debug Info Tab
                    debugInfoView
                        .tag(0)
                    
                    // API Testing Tab
                    apiTestingView
                        .tag(1)
                    
                    // F2.3 Multi-Modal Transport Tab
                    multiModalTransportTestView
                        .tag(2)
                    
                    // F3.2 Location Sharing Tab
                    locationSharingTestView
                        .tag(3)
                    
                    scheduleCoordinationTestView
                        .tag(4)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Component Testing")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        print("🔙 Returning from Component Testing to main app")
                        if let onBack = onBack {
                            onBack()
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - Debug Info View
    private var debugInfoView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // Location Status
                debugSection("Location Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        debugRow("Authorization Status", locationManager.authorizationStatus.rawValue.description)
                        debugRow("Location Available", locationManager.isLocationAvailable.description)
                        debugRow("Current Location", locationManager.currentLocation?.description ?? "nil")
                        debugRow("Last Error", locationManager.locationError?.localizedDescription ?? "None")
                    }
                }
                
                // Matching Engine Status
                debugSection("Matching Engine Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        debugRow("Is Loading", matchingEngine.isLoading.description)
                        debugRow("Available Families", "\(matchingEngine.availableFamilies.count)")
                        debugRow("Current Matches", "\(matchingEngine.currentMatches.count)")
                        debugRow("Last Update", matchingEngine.lastUpdateTime?.formatted() ?? "Never")
                        debugRow("Mock Data Count", "\(MockData.families.count)")
                    }
                }
                
                // Quick Actions
                debugSection("Quick Actions") {
                    VStack(spacing: 12) {
                        Button("Request Location Permission") {
                            locationManager.requestLocationPermission()
                        }
                        .buttonStyle(.borderedProminent)
                        

                        
                        Button("Reset Daily Swipes") {
                            matchingEngine.resetDailySwipes()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Simulate Location") {
                            simulateCanberraLocation()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Mock Data Preview
                debugSection("Mock Data Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        if MockData.families.count > 0 {
                            debugRow(MockData.families[0].parentName, "\(MockData.families[0].schoolName) - \(String(format: "%.1f", MockData.families[0].averageRating))⭐")
                        }
                        if MockData.families.count > 1 {
                            debugRow(MockData.families[1].parentName, "\(MockData.families[1].schoolName) - \(String(format: "%.1f", MockData.families[1].averageRating))⭐")
                        }
                        if MockData.families.count > 2 {
                            debugRow(MockData.families[2].parentName, "\(MockData.families[2].schoolName) - \(String(format: "%.1f", MockData.families[2].averageRating))⭐")
                        }
                        if MockData.families.count > 3 {
                            Text("... and \(MockData.families.count - 3) more families")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
    }
    

    

    
    // MARK: - API Testing View
    private var apiTestingView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("API Integration Testing")
                    .font(.title2.weight(.bold))
                
                Text("Test F2.1 ACT Government APIs for real-time data")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // API Status Cards
                VStack(spacing: 16) {
                    apiStatusCard(
                        title: "School Location API",
                        subtitle: "ACT Government School Data",
                        url: "https://www.data.act.gov.au/api/v3/views/8mi2-3658/query.json",
                        count: schoolDataService.schools.count,
                        lastUpdate: "Real-time", 
                        status: schoolDataService.schools.isEmpty ? .unknown : .connected
                    )
                    
                    apiStatusCard(
                        title: "Road Accident API", 
                        subtitle: "ACT Infrastructure GeoJSON",
                        url: "https://spatial.infrastructure.gov.au/server/rest/services/...",
                        count: accidentDataService.accidents.count,
                        lastUpdate: "Real-time",
                        status: accidentDataService.accidents.isEmpty ? .unknown : .connected
                    )
                    
                    apiStatusCard(
                        title: "ACT Transport API",
                        subtitle: "Public Transport Usage Data",
                        url: "https://www.data.act.gov.au/api/v3/views/nkxy-abdj/query.json",
                        count: actTransportService.transportData.count,
                        lastUpdate: "Real-time",
                        status: actTransportService.transportData.isEmpty ? .unknown : .connected
                    )
                }
                
                // Test Actions
                VStack(spacing: 12) {
                    if isTestingAPIs {
                        ProgressView("Testing APIs...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Button("Test All APIs") {
                            Task {
                                await testAllAPIs()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44) // Apple HIG compliance
                        
                        HStack(spacing: 12) {
                            Button("Test Schools API") {
                                Task {
                                    await testSchoolsAPI()
                                }
                            }
                            .buttonStyle(.bordered)
                            .frame(minHeight: 44)
                            
                            Button("Test Accidents API") {
                                Task {
                                    await testAccidentsAPI()
                                }
                            }
                            .buttonStyle(.bordered)
                            .frame(minHeight: 44)
                        }
                        
                        Button("Test ACT Transport API") {
                            Task {
                                await testACTTransportAPI()
                            }
                        }
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
                        .foregroundColor(.blue)
                    }
                }
                
                // Test Results
                if !apiTestResults.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Test Results:")
                            .font(.headline)
                        
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(apiTestResults.indices, id: \.self) { index in
                                HStack(alignment: .top) {
                                    Text("•")
                                        .foregroundColor(.blue)
                                    Text(apiTestResults[index])
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                
                // Sample Data Preview
                if !schoolDataService.schools.isEmpty || !accidentDataService.accidents.isEmpty || !actTransportService.transportData.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sample API Data:")
                            .font(.headline)
                        
                        if !schoolDataService.schools.isEmpty {
                            sampleDataSection(
                                title: "Schools (\(schoolDataService.schools.count))",
                                items: schoolDataService.schools.prefix(3).map { 
                                    "\($0.name) - \($0.latitude), \($0.longitude)" 
                                }
                            )
                        }
                        
                        if !accidentDataService.accidents.isEmpty {
                            sampleDataSection(
                                title: "Accident Data (\(accidentDataService.accidents.count))",
                                items: accidentDataService.accidents.prefix(3).map {
                                    "Severity: \($0.severity) - \($0.latitude), \($0.longitude)"
                                }
                            )
                        }
                        
                        if !actTransportService.transportData.isEmpty {
                            sampleDataSection(
                                title: "Transport Data (\(actTransportService.transportData.count))",
                                items: actTransportService.transportData.prefix(3).map { record in
                                    "\(record.date.formatted(date: .abbreviated, time: .omitted)) - Local: \(record.localRoute), Light Rail: \(record.lightRail)"
                                }
                            )
                        }
                    }
                }
                
                // Clear Results Button
                if !apiTestResults.isEmpty {
                    Button("Clear Results") {
                        apiTestResults.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Force Load Families View
    private var forceLoadFamiliesView: some View {
        VStack(spacing: 20) {
            Text("Force Load Families")
                .font(.title2.weight(.bold))
            
            Text("Bypass location requirements and force load mock families")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                
                
                Button("Simulate Canberra Location") {
                    simulateCanberraLocation()
                }
                .buttonStyle(.bordered)
                
                Button("Go to Main Matching View") {
                    // This would navigate to the main matching view
                    print("🧪 Navigate to main matching view")
                }
                .buttonStyle(.bordered)
            }
            
            // Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Status:")
                    .font(.headline)
                
                HStack {
                    Text("Available Families:")
                    Spacer()
                    Text("\(matchingEngine.availableFamilies.count)")
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("Is Loading:")
                    Spacer()
                    Text(matchingEngine.isLoading ? "Yes" : "No")
                        .foregroundColor(matchingEngine.isLoading ? .orange : .green)
                }
                
                HStack {
                    Text("Location Available:")
                    Spacer()
                    Text(locationManager.isLocationAvailable ? "Yes" : "No")
                        .foregroundColor(locationManager.isLocationAvailable ? .green : .red)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helper Views
    
    private func debugSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            content()
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
    
    private func debugRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label + ":")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - API Testing Helper Views
    
    private enum APIStatus {
        case connected, disconnected, unknown, error
        
        var color: Color {
            switch self {
            case .connected: return .green
            case .disconnected: return .red
            case .unknown: return .orange
            case .error: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .connected: return "checkmark.circle.fill"
            case .disconnected: return "xmark.circle.fill"
            case .unknown: return "questionmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
        
        var text: String {
            switch self {
            case .connected: return "Connected"
            case .disconnected: return "Disconnected"
            case .unknown: return "Unknown"
            case .error: return "Error"
            }
        }
    }
    
    private func apiStatusCard(
        title: String,
        subtitle: String,
        url: String,
        count: Int,
        lastUpdate: String,
        status: APIStatus
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: status.icon)
                            .foregroundColor(status.color)
                        Text(status.text)
                            .font(.caption.weight(.medium))
                            .foregroundColor(status.color)
                    }
                    
                    if count > 0 {
                        Text("\(count) records")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Text(url)
                .font(.caption2)
                .foregroundColor(.blue)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Text("Last Update: \(lastUpdate)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(status.color.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func sampleDataSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                ForEach(items.indices, id: \.self) { index in
                    Text("• \(items[index])")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - API Testing Methods
    
    private func testAllAPIs() async {
        isTestingAPIs = true
        apiTestResults.removeAll()
        
        addTestResult("🚀 Starting comprehensive API testing...")
        
        await testSchoolsAPI()
        await testAccidentsAPI()
        await testACTTransportAPI()
        
        addTestResult("✅ API testing completed!")
        isTestingAPIs = false
    }
    
    private func testSchoolsAPI() async {
        addTestResult("🏫 Testing ACT Schools API...")
        
        let startTime = Date()
        
        do {
            let _ = try await schoolDataService.fetchSchoolLocations()
            let duration = Date().timeIntervalSince(startTime)
            
            addTestResult("✅ Schools API: Success!")
            addTestResult("   📊 Fetched \(schoolDataService.schools.count) schools")
            addTestResult("   ⏱️ Response time: \(String(format: "%.2f", duration))s")
            
            if !schoolDataService.schools.isEmpty {
                let firstSchool = schoolDataService.schools[0]
                addTestResult("   📍 Sample: \(firstSchool.name)")
                addTestResult("   🗺️ Location: \(String(format: "%.4f", firstSchool.latitude)), \(String(format: "%.4f", firstSchool.longitude))")
            }
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            addTestResult("❌ Schools API: Failed!")
            addTestResult("   ⚠️ Error: \(error.localizedDescription)")
            addTestResult("   ⏱️ Failed after: \(String(format: "%.2f", duration))s")
        }
    }
    
    private func testAccidentsAPI() async {
        addTestResult("🚨 Testing ACT Accidents API...")
        
        let startTime = Date()
        
        do {
            let _ = try await accidentDataService.fetchAccidentData()
            let duration = Date().timeIntervalSince(startTime)
            
            addTestResult("✅ Accidents API: Success!")
            addTestResult("   📊 Fetched \(accidentDataService.accidents.count) accident records")
            addTestResult("   ⏱️ Response time: \(String(format: "%.2f", duration))s")
            
            if !accidentDataService.accidents.isEmpty {
                let firstAccident = accidentDataService.accidents[0]
                addTestResult("   🚨 Sample severity: \(firstAccident.severity)")
                addTestResult("   🗺️ Location: \(String(format: "%.4f", firstAccident.latitude)), \(String(format: "%.4f", firstAccident.longitude))")
            }
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            addTestResult("❌ Accidents API: Failed!")
            addTestResult("   ⚠️ Error: \(error.localizedDescription)")
            addTestResult("   ⏱️ Failed after: \(String(format: "%.2f", duration))s")
        }
    }
    
    private func testACTTransportAPI() async {
        addTestResult("🚌 Testing ACT Transport API...")
        
        let startTime = Date()
        
        do {
            // Create a temporary transport service instance for testing
            let transportService = ACTTransportService()
            let _ = try await transportService.fetchTransportData()
            let duration = Date().timeIntervalSince(startTime)
            
            addTestResult("✅ ACT Transport API: Success!")
            addTestResult("   📊 Fetched \(transportService.transportData.count) transport records")
            addTestResult("   ⏱️ Response time: \(String(format: "%.2f", duration))s")
            
            if !transportService.transportData.isEmpty {
                let firstRecord = transportService.transportData[0]
                addTestResult("   📅 Sample date: \(firstRecord.date.formatted())")
                addTestResult("   🚌 Local routes: \(firstRecord.localRoute)")
                addTestResult("   🚊 Light rail: \(firstRecord.lightRail)")
                addTestResult("   🏫 School routes: \(firstRecord.school)")
            }
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            addTestResult("❌ ACT Transport API: Failed!")
            addTestResult("   ⚠️ Error: \(error.localizedDescription)")
            addTestResult("   ⏱️ Failed after: \(String(format: "%.2f", duration))s")
        }
    }
    
    private func addTestResult(_ message: String) {
        let timestamp = DateFormatter.timeFormatter.string(from: Date())
        apiTestResults.append("[\(timestamp)] \(message)")
    }
    
    // MARK: - Multi-Modal Transport Test View
    private var multiModalTransportTestView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("F2.3 Multi-Modal Transport Testing")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                // Mock group and data
                VStack(alignment: .leading, spacing: 12) {
                    Text("Mock Data Setup")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Group: Northside School Run (3 members)")
                        Text("• School: Canberra Grammar School")
                        Text("• Members spread across Canberra suburbs")
                        Text("• Test includes Park & Ride locations and public transport")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Multi-Modal Transport View
                Group {
                    Text("Multi-Modal Transport Interface")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    // Create mock data for the component
                    let mockGroup = CarpoolGroup(
                        groupName: "Northside School Run",
                        adminId: UUID(),
                        members: [
                            GroupMember(familyId: UUID(), role: .admin),
                            GroupMember(familyId: UUID(), role: .driver),
                            GroupMember(familyId: UUID(), role: .passenger)
                        ],
                        schoolName: "Canberra Grammar School",
                        schoolAddress: "40 Monaro St, Red Hill ACT 2603",
                        scheduledDepartureTime: Date(),
                        pickupSequence: [],
                        optimizedRoute: Route(
                            groupId: UUID(),
                            pickupPoints: [],
                            safetyScore: 8.5
                        )
                    )
                    
                    let mockMembers = [
                        CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300), // Civic
                        CLLocationCoordinate2D(latitude: -35.2500, longitude: 149.1400), // Dickson
                        CLLocationCoordinate2D(latitude: -35.2700, longitude: 149.1200)  // Turner
                    ]
                    
                    let mockSchool = CLLocationCoordinate2D(latitude: -35.3365, longitude: 149.1207) // Red Hill
                    
                    MultiModalTransportView(
                        group: mockGroup,
                        members: mockMembers,
                        school: mockSchool
                    )
                    .frame(height: 600)
                    .cornerRadius(12)
                    .clipped()
                }
                
                // Testing instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Testing Instructions")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Overview tab shows comparison between carpool-only vs hybrid options")
                        Text("2. Park & Ride tab displays nearby P&R facilities with availability")
                        Text("3. Hybrid Routes tab shows detailed journey breakdowns")
                        Text("4. Service Status tab shows real-time transport service status")
                        Text("5. Test refresh functionality and real-time updates")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
    }
    
    // MARK: - F3.2 Location Sharing Test View
    private var locationSharingTestView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("F3.2: Live Location Sharing Testing")
                        .font(.title2.weight(.bold))
                    Text("Test real-time location sharing functionality for carpool groups")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Location Sharing Service Status
                debugSection("Location Sharing Service Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        debugRow("Service Active", "\(LocationSharingService.shared.isSharingLocation)")
                        debugRow("Active Shares", "\(LocationSharingService.shared.activeSharing.count)")
                        debugRow("Current Group", LocationSharingService.shared.currentSharingGroup?.uuidString ?? "None")
                        debugRow("Settings Enabled", "\(LocationSharingService.shared.sharingSettings.isEnabled)")
                        debugRow("Auto-stop Hours", "\(LocationSharingService.shared.sharingSettings.autoStopAfterHours)")
                        debugRow("Update Interval", "\(LocationSharingService.shared.sharingSettings.updateIntervalSeconds)s")
                    }
                }
                
                // Mock Group for Testing
                debugSection("Mock Group for Testing") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let mockGroup = MockData.sampleGroups.first {
                            debugRow("Group Name", mockGroup.groupName)
                            debugRow("Group ID", mockGroup.id.uuidString.prefix(8) + "...")
                            debugRow("Member Count", "\(mockGroup.members.count)")
                        } else {
                            Text("No mock groups available")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Location Sharing Controls
                debugSection("Location Sharing Controls") {
                    VStack(spacing: 12) {
                        Button("Start Location Sharing (2h)") {
                            startMockLocationSharing()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(LocationSharingService.shared.isSharingLocation)
                        
                        Button("Start Location Sharing (1h)") {
                            startMockLocationSharing(duration: 1 * 60 * 60)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(LocationSharingService.shared.isSharingLocation)
                        
                        Button("Stop All Location Sharing") {
                            stopAllLocationSharing()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!LocationSharingService.shared.isSharingLocation)
                        
                        Button("Simulate Location Update") {
                            simulateLocationUpdate()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!LocationSharingService.shared.isSharingLocation)
                        
                        Button("Test ETA Calculation") {
                            testETACalculation()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Active Location Shares
                if !LocationSharingService.shared.activeSharing.isEmpty {
                    debugSection("Active Location Shares") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(LocationSharingService.shared.activeSharing.values), id: \.id) { location in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("📍 \(location.familyName)")
                                            .font(.subheadline.weight(.medium))
                                        Spacer()
                                        Text(location.isActive ? "🟢 Active" : "🔴 Inactive")
                                            .font(.caption)
                                            .foregroundColor(location.isActive ? .green : .red)
                                    }
                                    
                                    Text("Group: \(location.groupId.uuidString.prefix(8))...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Expires: \(location.expiresAt, style: .time)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Time remaining: \(Int(location.timeUntilExpiry / 60))m")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                
                // Group Locations
                if !LocationSharingService.shared.groupLocations.isEmpty {
                    debugSection("Group Location History") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(LocationSharingService.shared.groupLocations.keys.sorted(), id: \.self) { groupId in
                                if let locations = LocationSharingService.shared.groupLocations[groupId] {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Group: \(groupId.uuidString.prefix(8))...")
                                            .font(.subheadline.weight(.medium))
                                        Text("Locations: \(locations.count)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.tertiarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }
                
                // Testing Instructions
                debugSection("Testing Instructions") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Start location sharing with different durations")
                        Text("2. Monitor active shares and expiration times")
                        Text("3. Test ETA calculations between locations")
                        Text("4. Verify automatic cleanup of expired locations")
                        Text("5. Test location sharing settings and privacy controls")
                        Text("6. Check integration with messaging system")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Helper Methods
    
    private func simulateCanberraLocation() {
        print("🧪 Simulating Canberra location...")
        
        // Create a mock location in Canberra
        let canberraLocation = CLLocation(
            latitude: -35.2809,
            longitude: 149.1300
        )
        
        // Update the matching engine with mock location
        Task {
        await matchingEngine.updateAvailableFamilies(
            userLocation: canberraLocation,
            userPreferences: UserPreferences.demoPreferences()
        )
            print("✅ Updated matching engine with Canberra location")
        }
    }
    
    // MARK: - F3.2 Location Sharing Helper Methods
    
    private func startMockLocationSharing(duration: TimeInterval = 2 * 60 * 60) {
        print("🧪 Starting mock location sharing for \(Int(duration / 60)) minutes")
        
        guard let mockGroup = MockData.sampleGroups.first else {
            print("❌ No mock groups available for testing")
            return
        }
        
        Task {
            do {
                try await LocationSharingService.shared.startLocationSharing(
                    for: mockGroup.id,
                    familyId: UUID(),
                    familyName: "Test User",
                    duration: duration
                )
                print("✅ Mock location sharing started successfully")
            } catch {
                print("❌ Failed to start mock location sharing: \(error)")
            }
        }
    }
    
    private func stopAllLocationSharing() {
        print("🧪 Stopping all location sharing")
        LocationSharingService.shared.stopAllLocationSharing()
    }
    
    private func simulateLocationUpdate() {
        print("🧪 Simulating location update")
        
        // This would trigger a location update in the service
        // For demo purposes, we'll just print the current status
        let activeShares = LocationSharingService.shared.activeSharing.count
        print("📍 Active location shares: \(activeShares)")
        
        if activeShares > 0 {
            print("📍 Simulating location update for active shares")
            // The service automatically updates locations every 30 seconds
        }
    }
    
    private func testETACalculation() {
        print("🧪 Testing ETA calculation")
        
        let canberraLocation = CLLocation(
            latitude: -35.2809,
            longitude: 149.1300
        )
        
        let forrestLocation = CLLocation(
            latitude: -35.3194,
            longitude: 149.1254
        )
        
        Task {
            let eta = await LocationSharingService.shared.calculateETA(
                from: canberraLocation,
                to: forrestLocation
            )
            
            print("🧭 ETA from Canberra to Forrest: \(Int(eta / 60)) minutes")
        }
    }
    
    // MARK: - F3.3 Schedule Coordination Testing
    private var scheduleCoordinationTestView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Service Status
                VStack(alignment: .leading, spacing: 12) {
                    Text("Schedule Coordination Service Status")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Image(systemName: scheduleCoordinationService.isCalendarAccessGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(scheduleCoordinationService.isCalendarAccessGranted ? .green : .red)
                        
                        Text("Calendar Integration:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(scheduleCoordinationService.isCalendarAccessGranted ? "Connected" : "Not Connected")
                            .font(.subheadline)
                            .foregroundColor(scheduleCoordinationService.isCalendarAccessGranted ? .green : .red)
                    }
                    
                    if let error = scheduleCoordinationService.lastError {
                        Text("Error: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // Mock Group Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("Mock Group Information")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let mockGroup = MockData.sampleGroups.first {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Group: \(mockGroup.groupName)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("School: \(mockGroup.schoolName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Current Departure: \(formatTime(mockGroup.scheduledDepartureTime))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // Testing Controls
                VStack(alignment: .leading, spacing: 12) {
                    Text("Testing Controls")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 12) {
                        Button("Test Calendar Permission") {
                            scheduleCoordinationService.checkCalendarPermission()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        
                        Button("Create Test Proposal") {
                            createTestProposal()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        
                        Button("Simulate Conflict Detection") {
                            simulateConflictDetection()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        
                        Button("Test Voting System") {
                            testVotingSystem()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // Active Proposals
                VStack(alignment: .leading, spacing: 12) {
                    Text("Active Proposals (\(scheduleCoordinationService.activeProposals.count))")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if scheduleCoordinationService.activeProposals.isEmpty {
                        Text("No active proposals")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(scheduleCoordinationService.activeProposals) { proposal in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(proposal.reason)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Text(proposal.status.displayName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(statusColor(for: proposal.status).opacity(0.1))
                                        .cornerRadius(8)
                                        .foregroundColor(statusColor(for: proposal.status))
                                }
                                
                                HStack {
                                    Text("\(formatTime(proposal.currentDepartureTime)) → \(formatTime(proposal.proposedDepartureTime))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("\(Int(proposal.approvalPercentage))% approved")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
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
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // Recent Changes
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Changes (\(scheduleCoordinationService.recentChanges.count))")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if scheduleCoordinationService.recentChanges.isEmpty {
                        Text("No recent changes")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(scheduleCoordinationService.recentChanges) { proposal in
                            HStack {
                                Image(systemName: proposal.status.icon)
                                    .foregroundColor(statusColor(for: proposal.status))
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(proposal.reason)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                    
                                    Text("\(formatTime(proposal.currentDepartureTime)) → \(formatTime(proposal.proposedDepartureTime))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(proposal.status.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(statusColor(for: proposal.status))
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
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
            .padding()
        }
        .refreshable {
            print("🔄 Refreshing schedule coordination data...")
        }
    }
    
    // MARK: - Schedule Coordination Helper Methods
    
    private func createTestProposal() {
        print("🧪 Creating test schedule proposal...")
        
        guard let mockGroup = MockData.sampleGroups.first else {
            print("❌ No mock groups available")
            return
        }
        
        Task {
            let proposal = await scheduleCoordinationService.proposeScheduleChange(
                groupId: mockGroup.id,
                currentDepartureTime: mockGroup.scheduledDepartureTime,
                proposedDepartureTime: Calendar.current.date(byAdding: .hour, value: 1, to: mockGroup.scheduledDepartureTime) ?? mockGroup.scheduledDepartureTime,
                reason: "Test proposal for demo purposes",
                priority: .normal
            )
            
            print("✅ Test proposal created: \(proposal.id.uuidString.prefix(8))")
        }
    }
    
    private func simulateConflictDetection() {
        print("🧪 Simulating conflict detection...")
        
        // This would trigger conflict detection in the service
        // For demo purposes, we'll just print the current status
        let activeProposals = scheduleCoordinationService.activeProposals.count
        print("📅 Active proposals: \(activeProposals)")
        
        if activeProposals > 0 {
            print("🔍 Simulating conflict detection for active proposals")
            // The service automatically detects conflicts when proposals are created
        }
    }
    
    private func testVotingSystem() {
        print("🧪 Testing voting system...")
        
        guard let proposal = scheduleCoordinationService.activeProposals.first else {
            print("❌ No active proposals to vote on")
            return
        }
        
        // Simulate different types of votes
        let voteTypes: [VoteType] = [.approve, .reject, .abstain]
        let randomVote = voteTypes.randomElement() ?? .approve
        
        scheduleCoordinationService.voteOnProposal(
            proposalId: proposal.id,
            userId: UUID(),
            vote: randomVote,
            comment: "Test vote for demo purposes"
        )
        
        print("🗳️ Test vote submitted: \(randomVote.displayName)")
    }
    
    private func statusColor(for status: ProposalStatus) -> Color {
        switch status {
        case .approved: return .green
        case .rejected: return .red
        case .expired: return .orange
        case .cancelled: return .gray
        default: return .blue
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Mock Route for Testing
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

// MARK: - Preview
// MARK: - Extensions

extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

struct TestingView_Previews: PreviewProvider {
    static var previews: some View {
        TestingView()
    }
}
