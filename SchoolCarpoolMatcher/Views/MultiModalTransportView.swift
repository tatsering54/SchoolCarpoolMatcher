//
//  MultiModalTransportView.swift
//  SchoolCarpoolMatcher
//
//  SwiftUI view for displaying multi-modal transport options (F2.3)
//  Shows Park & Ride locations, hybrid journeys, and transport integration
//  Applied Rule: iOS native patterns with comprehensive accessibility support
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Multi-Modal Transport View
/// SwiftUI component for displaying multi-modal transport options and recommendations
/// Implements F2.3 requirement for Park & Ride integration and hybrid journey planning
struct MultiModalTransportView: View {
    
    // MARK: - Properties
    let group: CarpoolGroup
    let members: [CLLocationCoordinate2D]
    let school: CLLocationCoordinate2D
    
    @StateObject private var transportService = MultiModalTransportService()
    @State private var analysisResult: MultiModalAnalysisResult?
    @State private var selectedTab = 0
    @State private var showingParkRideDetails = false
    @State private var selectedParkRide: ParkRideLocation?
    @State private var isAnalyzing = false
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with group info
                headerSection
                
                // Tab selector
                tabSelector
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    // Tab 0: Overview & Recommendations
                    overviewTab
                        .tag(0)
                    
                    // Tab 1: Park & Ride Options
                    parkRideTab
                        .tag(1)
                    
                    // Tab 2: Hybrid Journey Details
                    hybridJourneyTab
                        .tag(2)
                    
                    // Tab 3: Service Status
                    serviceStatusTab
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Multi-Modal Transport")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadTransportOptions()
            }
            .refreshable {
                await refreshData()
            }
            .sheet(isPresented: $showingParkRideDetails) {
                if let parkRide = selectedParkRide {
                    ParkRideDetailView(parkRide: parkRide)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "car.2.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.groupName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(members.count) members • \(group.schoolName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isAnalyzing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Quick stats if analysis is available
            if let result = analysisResult {
                quickStatsView(result: result)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "Overview", icon: "chart.bar.fill", index: 0)
            tabButton(title: "Park & Ride", icon: "parkingsign.circle.fill", index: 1)
            tabButton(title: "Hybrid Routes", icon: "arrow.triangle.branch", index: 2)
            tabButton(title: "Service Status", icon: "antenna.radiowaves.left.and.right", index: 3)
        }
        .padding(.horizontal)
        .background(Color(.systemBackground))
    }
    
    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(selectedTab == index ? .blue : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Overview Tab
    private var overviewTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let result = analysisResult {
                    // Comparison cards
                    comparisonSection(result: result)
                    
                    // Top recommendations
                    recommendationsSection(result: result)
                    
                    // Environmental impact
                    environmentalImpactSection(result: result)
                } else if isAnalyzing {
                    loadingView
                } else {
                    emptyStateView
                }
            }
            .padding()
        }
    }
    
    // MARK: - Park & Ride Tab
    private var parkRideTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let result = analysisResult {
                    ForEach(result.memberHybridOptions, id: \.memberIndex) { memberOption in
                        memberParkRideSection(memberOption: memberOption)
                    }
                } else {
                    Text("Loading Park & Ride options...")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
        }
    }
    
    // MARK: - Hybrid Journey Tab
    private var hybridJourneyTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let result = analysisResult, !result.groupRecommendations.isEmpty {
                    ForEach(result.groupRecommendations, id: \.id) { journey in
                        hybridJourneyCard(journey: journey)
                    }
                } else {
                    Text("No hybrid journey options available")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
        }
    }
    
    // MARK: - Service Status Tab
    private var serviceStatusTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let status = analysisResult?.serviceStatus {
                    serviceStatusSection(status: status)
                } else {
                    Text("Loading service status...")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
        }
    }
    
    // MARK: - Quick Stats View
    private func quickStatsView(result: MultiModalAnalysisResult) -> some View {
        HStack(spacing: 20) {
            statItem(
                icon: "clock.fill",
                value: "\(Int(result.carpoolOnlyOption.totalTime / 60))min",
                label: "Carpool Time"
            )
            
            if let bestHybrid = result.groupRecommendations.first {
                statItem(
                    icon: "arrow.triangle.branch",
                    value: "\(Int(bestHybrid.totalTime / 60))min",
                    label: "Best Hybrid"
                )
            }
            
            statItem(
                icon: "leaf.fill",
                value: "\(String(format: "%.1f", result.co2ComparisonData.potentialSavings))kg",
                label: "CO₂ Saved"
            )
        }
        .padding(.top, 8)
    }
    
    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Comparison Section
    private func comparisonSection(result: MultiModalAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transport Options Comparison")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Carpool-only option
            transportOptionCard(
                title: "Carpool Only",
                icon: "car.fill",
                time: result.carpoolOnlyOption.totalTime,
                cost: result.carpoolOnlyOption.estimatedCost,
                co2: result.co2ComparisonData.carpoolOnlyCO2,
                color: .blue,
                isRecommended: false
            )
            
            // Best hybrid option
            if let bestHybrid = result.groupRecommendations.first {
                transportOptionCard(
                    title: "Drive + Transit",
                    icon: "car.2.fill",
                    time: bestHybrid.totalTime,
                    cost: bestHybrid.totalCost,
                    co2: result.co2ComparisonData.bestHybridCO2,
                    color: .green,
                    isRecommended: true
                )
            }
        }
    }
    
    private func transportOptionCard(
        title: String,
        icon: String,
        time: TimeInterval,
        cost: Double,
        co2: Double,
        color: Color,
        isRecommended: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if isRecommended {
                    Text("RECOMMENDED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(4)
                }
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(time / 60)) min")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cost")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.2f", cost))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("CO₂")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", co2))kg")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Recommendations Section
    private func recommendationsSection(result: MultiModalAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(result.groupRecommendations.prefix(2), id: \.id) { journey in
                recommendationCard(journey: journey)
            }
        }
    }
    
    private func recommendationCard(journey: HybridJourneyOption) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
                
                Text(journey.parkRideLocation.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("Score: \(String(format: "%.1f", journey.reliabilityScore))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("\(Int(journey.totalTime / 60))min", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("$\(String(format: "%.2f", journey.totalCost))", systemImage: "dollarsign.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("View Details") {
                    selectedParkRide = journey.parkRideLocation
                    showingParkRideDetails = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    // MARK: - Environmental Impact Section
    private func environmentalImpactSection(result: MultiModalAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Environmental Impact")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CO₂ Savings Potential")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("\(String(format: "%.1f", result.co2ComparisonData.potentialSavings))kg CO₂ per trip")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(String(format: "%.0f", result.co2ComparisonData.savingsPercentage))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                ProgressView(value: result.co2ComparisonData.savingsPercentage / 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Member Park & Ride Section
    private func memberParkRideSection(memberOption: MemberHybridOptions) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Member \(memberOption.memberIndex + 1) Options")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            ForEach(memberOption.hybridOptions.prefix(3), id: \.id) { option in
                parkRideOptionCard(option: option)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func parkRideOptionCard(option: HybridJourneyOption) -> some View {
        Button(action: {
            selectedParkRide = option.parkRideLocation
            showingParkRideDetails = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.parkRideLocation.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        Label("\(Int(option.totalTime / 60))min", systemImage: "clock")
                        Label("$\(String(format: "%.2f", option.totalCost))", systemImage: "dollarsign.circle")
                        Label(option.parkRideLocation.availabilityStatus.displayName, systemImage: "parkingsign")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Hybrid Journey Card
    private func hybridJourneyCard(journey: HybridJourneyOption) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hybrid Journey")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("via \(journey.parkRideLocation.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(journey.totalTime / 60))min")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    
                    Text("$\(String(format: "%.2f", journey.totalCost))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Journey segments
            VStack(spacing: 8) {
                journeySegmentRow(
                    icon: "car.fill",
                    title: "Drive to Park & Ride",
                    distance: journey.driveSegment.distance,
                    time: journey.driveSegment.estimatedTime,
                    cost: journey.driveSegment.cost,
                    color: .blue
                )
                
                journeySegmentRow(
                    icon: journey.transitSegment.transportMode.icon,
                    title: journey.transitSegment.transportMode.displayName,
                    distance: journey.transitSegment.distance,
                    time: journey.transitSegment.estimatedTime,
                    cost: journey.transitSegment.cost,
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func journeySegmentRow(
        icon: String,
        title: String,
        distance: Double,
        time: TimeInterval,
        cost: Double,
        color: Color
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.subheadline)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("\(String(format: "%.1f", distance/1000))km • \(Int(time/60))min • $\(String(format: "%.2f", cost))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Service Status Section
    private func serviceStatusSection(status: TransportServiceStatus) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transport Service Status")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Overall status
            statusCard(
                title: "Overall Service",
                status: status.overallStatus,
                icon: "antenna.radiowaves.left.and.right"
            )
            
            // Light rail status
            statusCard(
                title: "Light Rail",
                status: status.lightRailStatus,
                icon: "tram.fill"
            )
            
            // Bus status
            statusCard(
                title: "Bus Network",
                status: status.busStatus,
                icon: "bus.fill"
            )
            
            // Last updated
            Text("Last updated: \(status.lastUpdated.formatted(.dateTime.hour().minute()))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func statusCard(title: String, status: ServiceStatus, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(status.color))
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(status.displayName)
                    .font(.caption)
                    .foregroundColor(Color(status.color))
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Loading and Empty States
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Analyzing transport options...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.2.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Transport Analysis")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Tap refresh to analyze multi-modal transport options for your group")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Analyze Options") {
                loadTransportOptions()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Methods
    private func loadTransportOptions() {
        isAnalyzing = true
        
        Task {
            let result = await transportService.analyzeMultiModalOptions(
                for: group,
                members: members,
                school: school
            )
            
            await MainActor.run {
                analysisResult = result
                isAnalyzing = false
            }
        }
    }
    
    private func refreshData() async {
        await transportService.updateWithRealTimeData()
        
        if analysisResult != nil {
            loadTransportOptions()
        }
    }
}

// MARK: - Park & Ride Detail View
struct ParkRideDetailView: View {
    let parkRide: ParkRideLocation
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(parkRide.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(parkRide.address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Parking availability
                    availabilitySection
                    
                    // Transport connections
                    connectionsSection
                    
                    // Amenities
                    amenitiesSection
                    
                    // Operating hours
                    operatingHoursSection
                }
                .padding()
            }
            .navigationTitle("Park & Ride Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
    
    private var availabilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parking Availability")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(parkRide.availableSpaces)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color(parkRide.availabilityStatus.color))
                    
                    Text("Available Spaces")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(parkRide.parkingSpaces)")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Total Spaces")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            ProgressView(value: Double(parkRide.parkingSpaces - parkRide.availableSpaces) / Double(parkRide.parkingSpaces))
                .progressViewStyle(LinearProgressViewStyle(tint: Color(parkRide.availabilityStatus.color)))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transport Connections")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(parkRide.connectedRoutes, id: \.self) { route in
                    HStack {
                        Image(systemName: route.contains("Light Rail") ? "tram.fill" : "bus.fill")
                            .foregroundColor(.blue)
                        
                        Text(route)
                            .font(.subheadline)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var amenitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amenities")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(parkRide.amenities, id: \.self) { amenity in
                    HStack {
                        Image(systemName: amenityIcon(for: amenity))
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text(amenity)
                            .font(.caption)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var operatingHoursSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Operating Hours")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
                
                Text(parkRide.operatingHours)
                    .font(.subheadline)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func amenityIcon(for amenity: String) -> String {
        switch amenity.lowercased() {
        case let str where str.contains("parking"):
            return "parkingsign"
        case let str where str.contains("security"):
            return "shield.fill"
        case let str where str.contains("bike"):
            return "bicycle"
        case let str where str.contains("toilet"):
            return "figure.walk"
        case let str where str.contains("shopping"):
            return "bag.fill"
        case let str where str.contains("food"):
            return "fork.knife"
        case let str where str.contains("atm"):
            return "creditcard.fill"
        default:
            return "checkmark.circle.fill"
        }
    }
}

// MARK: - Preview Provider
struct MultiModalTransportView_Previews: PreviewProvider {
    static var previews: some View {
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
            CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300),
            CLLocationCoordinate2D(latitude: -35.2500, longitude: 149.1400),
            CLLocationCoordinate2D(latitude: -35.2700, longitude: 149.1200)
        ]
        
        let mockSchool = CLLocationCoordinate2D(latitude: -35.3365, longitude: 149.1207)
        
        MultiModalTransportView(
            group: mockGroup,
            members: mockMembers,
            school: mockSchool
        )
    }
}
