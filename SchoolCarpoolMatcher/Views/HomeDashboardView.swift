//
//  HomeDashboardView.swift
//  SchoolCarpoolMatcher
//
//  Home dashboard with stats, schedule, and interactive map
//  Follows Apple Design Guidelines for iOS native feel and accessibility
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Home Dashboard View
/// Main dashboard showing key metrics, today's schedule, and interactive map
/// Implements F4.1 requirements: dashboard overview with key metrics
struct HomeDashboardView: View {
    
    // MARK: - Properties
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @StateObject private var routeAnalysisService = RouteAnalysisService()
    @StateObject private var safetyScoring = RouteRiskScoring()
    @StateObject private var routeAdaptationEngine = SimpleRouteAdaptationEngine()
    @StateObject private var multiModalService = MultiModalTransportService()
    @StateObject private var groupFormationService = GroupFormationService()
    
    // Route adaptation state
    @State private var showingAdaptationDetails = false
    @State private var selectedAdaptation: SimpleAdaptedRoute?
    
    // Multi-modal transport state
    @State private var selectedTransportTab = 0
    @State private var showingTransportDetails = false
    @State private var selectedTransportOption: HybridJourneyOption?
    @State private var isAnalyzingTransport = false
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Route Safety Score Grid
                    routeSafetyScoreGrid
                    
                    // Multi-Modal Transport Section
                    multiModalTransportSection
                    
                    // Real-Time Route Adaptation Section
                    routeAdaptationSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemGroupedBackground), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Safety First Route")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await dashboardViewModel.loadDashboardData()
                await refreshTransportData()
            }
        }
        .onAppear {
            Task {
                await dashboardViewModel.loadDashboardData()
                routeAdaptationEngine.startMonitoring()
                await loadTransportOptions()
            }
        }
        .onDisappear {
            routeAdaptationEngine.stopMonitoring()
        }
        .sheet(isPresented: $showingAdaptationDetails) {
            if let adaptation = selectedAdaptation {
                RouteAdaptationDetailSheet(adaptation: adaptation)
            }
        }
        .sheet(isPresented: $showingTransportDetails) {
            if let option = selectedTransportOption {
                TransportOptionDetailSheet(option: option)
            }
        }
    }
    
    // MARK: - Real-Time Route Adaptation Section
    private var routeAdaptationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with monitoring status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Real-Time Route Adaptation")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(routeAdaptationEngine.isMonitoring ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        
                        Text(routeAdaptationEngine.isMonitoring ? "Monitoring Active" : "Monitoring Inactive")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Monitoring toggle - 44pt minimum hit target
                Button(action: {
                    if routeAdaptationEngine.isMonitoring {
                        routeAdaptationEngine.stopMonitoring()
                    } else {
                        routeAdaptationEngine.startMonitoring()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: routeAdaptationEngine.isMonitoring ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title3)
                        
                        Text(routeAdaptationEngine.isMonitoring ? "Pause" : "Start")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(routeAdaptationEngine.isMonitoring ? Color.orange : Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                }
                .frame(minHeight: 44) // Apple HIG minimum hit target
            }
            
            // Current conditions grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                // Weather condition card
                conditionCard(
                    title: "Weather",
                    icon: weatherIcon(for: routeAdaptationEngine.currentWeatherCondition?.condition ?? "Clear"),
                    value: routeAdaptationEngine.currentWeatherCondition?.condition ?? "Loading...",
                    subtitle: routeAdaptationEngine.currentWeatherCondition != nil ? 
                        "\(String(format: "%.0f", routeAdaptationEngine.currentWeatherCondition!.temperature))°C" : "",
                    color: weatherColor(for: routeAdaptationEngine.currentWeatherCondition?.condition ?? "Clear")
                )
                
                // Traffic incidents card
                conditionCard(
                    title: "Traffic",
                    icon: "car.fill",
                    value: "\(routeAdaptationEngine.activeTrafficIncidents.count) incidents",
                    subtitle: routeAdaptationEngine.activeTrafficIncidents.isEmpty ? "Clear roads" : "Delays expected",
                    color: routeAdaptationEngine.activeTrafficIncidents.isEmpty ? .green : .orange
                )
            }
            
            // Recent adaptations
            if !routeAdaptationEngine.routeHistory.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Adaptations")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    ForEach(routeAdaptationEngine.routeHistory.prefix(2)) { entry in
                        adaptationHistoryRow(entry: entry)
                    }
                    
                    if routeAdaptationEngine.routeHistory.count > 2 {
                        Button("View All Adaptations") {
                            // Show all adaptations
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("No route adaptations yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Routes will adapt automatically based on weather and traffic")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Route Safety Score Grid
    private var routeSafetyScoreGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Route Safety Score")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            if let currentAnalysis = routeAnalysisService.currentAnalysis {
                // Show Safety Warning View with current analysis
                SafetyWarningView(
                    analysis: currentAnalysis.primaryRoute,
                    showDetailedBreakdown: true,
                    sourceCoordinate: currentAnalysis.sourceCoordinate,
                    destinationCoordinate: currentAnalysis.destinationCoordinate
                )
            } else {
                // Show placeholder when no analysis available
                VStack(spacing: 16) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Route Analysis Available")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text("Analyze a route to see safety scores and recommendations")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Analyze Sample Route") {
                        Task {
                            await analyzeSampleRoute()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
                }
                .padding(20)
                .background(Color(.systemGray6))
                .cornerRadius(16)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Multi-Modal Transport Section
    private var multiModalTransportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "car.2.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Multi-Modal Transport")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text("Optimize your journey with Park & Ride options")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isAnalyzingTransport {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Transport Options Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                // Overview Card
                transportOptionCard(
                    title: "Overview",
                    icon: "chart.bar.fill",
                    color: .blue,
                    action: { selectedTransportTab = 0 }
                )
                
                // Park & Ride Card
                transportOptionCard(
                    title: "Park & Ride",
                    icon: "parkingsign.circle.fill",
                    color: .green,
                    action: { selectedTransportTab = 1 }
                )
                
                // Hybrid Routes Card
                transportOptionCard(
                    title: "Hybrid Routes",
                    icon: "arrow.triangle.branch",
                    color: .orange,
                    action: { selectedTransportTab = 2 }
                )
                
                // Service Status Card
                transportOptionCard(
                    title: "Service Status",
                    icon: "antenna.radiowaves.left.and.right",
                    color: .purple,
                    action: { selectedTransportTab = 3 }
                )
            }
            
            // Selected Tab Content
            selectedTabContent
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Transport Option Card
    private func transportOptionCard(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedTransportTab == getTabIndex(for: title) ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Selected Tab Content
    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTransportTab {
        case 0:
            transportOverviewTab
        case 1:
            parkRideTab
        case 2:
            hybridRoutesTab
        case 3:
            serviceStatusTab
        default:
            transportOverviewTab
        }
    }
    
    // MARK: - Transport Overview Tab
    private var transportOverviewTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transport Options Overview")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            if let analysisResult = multiModalService.analysisResult {
                // Quick Stats
                HStack(spacing: 20) {
                    statItem(
                        icon: "clock.fill",
                        value: "\(Int(analysisResult.carpoolOnlyOption.totalTime / 60))min",
                        label: "Carpool Time"
                    )
                    
                    if let bestHybrid = analysisResult.groupRecommendations.first {
                        statItem(
                            icon: "arrow.triangle.branch",
                            value: "\(Int(bestHybrid.totalTime / 60))min",
                            label: "Best Hybrid"
                        )
                    }
                    
                    statItem(
                        icon: "leaf.fill",
                        value: "\(String(format: "%.1f", analysisResult.co2ComparisonData.potentialSavings))kg",
                        label: "CO₂ Saved"
                    )
                }
                
                // Environmental Impact
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.green)
                        
                        Text("CO₂ Savings: \(String(format: "%.0f", analysisResult.co2ComparisonData.savingsPercentage))%")
                            .font(.subheadline.weight(.medium))
                        
                        Spacer()
                    }
                    
                    ProgressView(value: analysisResult.co2ComparisonData.savingsPercentage / 100.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
            } else if isAnalyzingTransport {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Analyzing transport options...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "car.2.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text("No Transport Analysis")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Text("Tap refresh to analyze multi-modal options")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
    }
    
    // MARK: - Park & Ride Tab
    private var parkRideTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Park & Ride Options")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            if let analysisResult = multiModalService.analysisResult {
                ForEach(analysisResult.memberHybridOptions.prefix(3), id: \.memberIndex) { memberOption in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Member \(memberOption.memberIndex + 1)")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                        
                        ForEach(memberOption.hybridOptions.prefix(2), id: \.id) { option in
                            parkRideOptionRow(option: option)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Text("Loading Park & Ride options...")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }
    
    // MARK: - Hybrid Routes Tab
    private var hybridRoutesTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hybrid Journey Options")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            if let analysisResult = multiModalService.analysisResult,
               !analysisResult.groupRecommendations.isEmpty {
                ForEach(analysisResult.groupRecommendations.prefix(3), id: \.id) { journey in
                    hybridJourneyRow(journey: journey)
                }
            } else {
                Text("No hybrid journey options available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }
    
    // MARK: - Service Status Tab
    private var serviceStatusTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transport Service Status")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            if let status = multiModalService.serviceStatus {
                VStack(spacing: 12) {
                    serviceStatusRow(
                        title: "Overall Service",
                        status: status.overallStatus,
                        icon: "antenna.radiowaves.left.and.right"
                    )
                    
                    serviceStatusRow(
                        title: "Light Rail",
                        status: status.lightRailStatus,
                        icon: "tram.fill"
                    )
                    
                    serviceStatusRow(
                        title: "Bus Network",
                        status: status.busStatus,
                        icon: "bus.fill"
                    )
                }
                
                Text("Last updated: \(status.lastUpdated.formatted(.dateTime.hour().minute()))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Loading service status...")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }
    
    // MARK: - Helper Methods
    private func safetyScoreColor(_ score: Double) -> Color {
        switch score {
        case 8.5...10.0: return .green
        case 7.0..<8.5: return .orange
        case 5.0..<7.0: return .red
        default: return .gray
        }
    }
    
    // MARK: - Route Adaptation Helper Methods
    
    private func conditionCard(title: String, icon: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func adaptationHistoryRow(entry: SimpleRouteHistoryEntry) -> some View {
        Button(action: {
            selectedAdaptation = SimpleAdaptedRoute(
                originalRoute: entry.originalRoute,
                adaptedRoute: entry.adaptedRoute,
                estimatedDelay: entry.estimatedDelay,
                adaptationReasons: entry.adaptationReasons,
                weatherCondition: entry.weatherCondition,
                trafficIncidents: entry.trafficIncidents,
                adaptedAt: entry.timestamp
            )
            showingAdaptationDetails = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.adaptationReasons.joined(separator: ", "))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 12) {
                        Label("+\(String(format: "%.0f", entry.estimatedDelay/60))min", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Label(entry.timestamp.formatted(.relative(presentation: .named)), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func weatherIcon(for condition: String) -> String {
        switch condition.lowercased() {
        case let str where str.contains("rain"):
            return str.contains("heavy") ? "cloud.heavyrain.fill" : "cloud.rain.fill"
        case let str where str.contains("fog"):
            return "cloud.fog.fill"
        case let str where str.contains("cloud"):
            return "cloud.fill"
        case "clear":
            return "sun.max.fill"
        default:
            return "cloud.sun.fill"
        }
    }
    
    private func weatherColor(for condition: String) -> Color {
        switch condition.lowercased() {
        case let str where str.contains("heavy rain"):
            return .red
        case let str where str.contains("rain"):
            return .blue
        case let str where str.contains("fog"):
            return .gray
        case let str where str.contains("cloud"):
            return .secondary
        case "clear":
            return .yellow
        default:
            return .blue
        }
    }
    
    private func analyzeSampleRoute() async {
        print("🔍 Creating demo route analysis for testing...")
        
        // Use the demo route analysis method for reliable testing
        let result = await routeAnalysisService.createDemoRouteAnalysis()
        
        print("✅ Demo route analysis complete:")
        print("   🛡️ Safety score: \(String(format: "%.1f", result.bestSafetyScore))/10")
        print("   📊 Risk score: \(String(format: "%.1f", result.bestRiskScore))/10")
        print("   ✅ Acceptable risk: \(result.primaryRoute.isAcceptableRisk)")
        print("   🎯 Total routes: \(result.alternativeRoutes.count + 1)")
        
        // Update the UI to show the new analysis
        await MainActor.run {
            // The UI will automatically update since we're using @StateObject
            print("🔄 UI updated with new safety analysis")
        }
    }
    
    private func shareSafetyAnalysis() {
        guard let analysis = routeAnalysisService.currentAnalysis else {
            print("⚠️ No safety analysis available to share")
            return
        }
        
        let safetyReport = """
        🛡️ Route Safety Analysis Report
        
        📍 Route: (\(String(format: "%.4f", analysis.sourceCoordinate.latitude)), \(String(format: "%.4f", analysis.sourceCoordinate.longitude))) to (\(String(format: "%.4f", analysis.destinationCoordinate.latitude)), \(String(format: "%.4f", analysis.destinationCoordinate.longitude)))
        
        🎯 Best Safety Score: \(String(format: "%.1f", analysis.bestSafetyScore))/10
        📊 Alternative Routes: \(analysis.alternativeRoutes.count)
        ✅ Safety Compliance: \(analysis.allRoutesMeetSafety ? "Yes" : "No")
        
        📅 Analysis Date: \(analysis.analysisDate.formatted(date: .abbreviated, time: .omitted))
        🕐 Analysis Time: \(analysis.analysisDate.formatted(date: .omitted, time: .shortened))
        
        Generated by SchoolCarpoolMatcher
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [safetyReport],
            applicationActivities: nil
        )
        
        // Present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    // MARK: - Transport Helper Methods
    
    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
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
    
    private func parkRideOptionRow(option: HybridJourneyOption) -> some View {
        Button(action: {
            selectedTransportOption = option
            showingTransportDetails = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.parkRideLocation.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        Label("\(Int(option.totalTime / 60))min", systemImage: "clock")
                        Label("$\(String(format: "%.2f", option.totalCost))", systemImage: "dollarsign.circle")
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
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func hybridJourneyRow(journey: HybridJourneyOption) -> some View {
        Button(action: {
            selectedTransportOption = journey
            showingTransportDetails = true
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundColor(.blue)
                    
                    Text("via \(journey.parkRideLocation.name)")
                        .font(.subheadline.weight(.medium))
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(journey.totalTime / 60))min")
                            .font(.subheadline.weight(.bold))
                        
                        Text("$\(String(format: "%.2f", journey.totalCost))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 16) {
                    Label("\(String(format: "%.1f", journey.driveSegment.distance/1000))km", systemImage: "car.fill")
                    Label("\(String(format: "%.1f", journey.transitSegment.distance/1000))km", systemImage: journey.transitSegment.transportMode.icon)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func serviceStatusRow(title: String, status: ServiceStatus, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(status.color))
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                
                Text(status.displayName)
                    .font(.caption)
                    .foregroundColor(Color(status.color))
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func getTabIndex(for title: String) -> Int {
        switch title {
        case "Overview": return 0
        case "Park & Ride": return 1
        case "Hybrid Routes": return 2
        case "Service Status": return 3
        default: return 0
        }
    }
    
    private func loadTransportOptions() async {
        // Mock data for demo purposes
        isAnalyzingTransport = true
        
        // Mock member locations for demo
        let mockMembers = [
            CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300), // Civic
            CLLocationCoordinate2D(latitude: -35.2500, longitude: 149.1400), // Dickson
            CLLocationCoordinate2D(latitude: -35.2700, longitude: 149.1200)  // Turner
        ]
        
        let mockSchool = CLLocationCoordinate2D(latitude: -35.3365, longitude: 149.1207) // Red Hill
        
        // Create mock carpool group for analysis
        let mockRoute = Route(
            groupId: UUID(),
            pickupPoints: [],
            safetyScore: 9.2
        )
        
        let mockCarpoolGroup = CarpoolGroup(
            id: UUID(),
            groupName: "Demo Route Group",
            adminId: UUID(),
            members: [],
            schoolName: "Demo School",
            schoolAddress: "Demo Address",
            scheduledDepartureTime: Date(),
            pickupSequence: [],
            optimizedRoute: mockRoute,
            safetyScore: 9.2
        )
        
        let result = await multiModalService.analyzeMultiModalOptions(
            for: mockCarpoolGroup,
            members: mockMembers,
            school: mockSchool
        )
        
        await MainActor.run {
            multiModalService.analysisResult = result
            isAnalyzingTransport = false
        }
    }
    
    private func refreshTransportData() async {
        await multiModalService.updateWithRealTimeData()
        
        if multiModalService.analysisResult != nil {
            await loadTransportOptions()
        }
    }
}

// MARK: - Transport Option Detail Sheet
struct TransportOptionDetailSheet: View {
    let option: HybridJourneyOption
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Transport Option Details")
                    .font(.title2.weight(.bold))
                
                Text("Total Time: \(Int(option.totalTime / 60)) minutes")
                    .font(.headline)
                
                Text("Total Cost: $\(String(format: "%.2f", option.totalCost))")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Text("CO₂ Savings: \(String(format: "%.1f", option.co2Savings))kg")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Transport Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Safety Feature Card Component
struct SafetyFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Safety Score Display Card Component
struct SafetyScoreDisplayCard: View {
    let currentScore: Double
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
            } else {
                Image(systemName: "shield.checkered")
                    .font(.title2)
                    .foregroundColor(safetyScoreColor(currentScore))
            }
            
            Text("Current Score")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            if isLoading {
                Text("Analyzing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text(String(format: "%.1f/10", currentScore))
                    .font(.title3.weight(.bold))
                    .foregroundColor(safetyScoreColor(currentScore))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func safetyScoreColor(_ score: Double) -> Color {
        switch score {
        case 8.5...10.0: return .green
        case 7.0..<8.5: return .orange
        case 5.0..<7.0: return .red
        default: return .gray
        }
    }
}

// MARK: - Stat Card Component
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(icon)
                .font(.title2)
            
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Dashboard View Model
class DashboardViewModel: ObservableObject {
    @Published var todaySchedule: [TransportScheduleItem] = []
    @Published var communityStats = CommunityStats(
        totalFamilies: 0,
        activeGroups: 0,
        totalTripsCompleted: 0,
        averageGroupSize: 0.0,
        memberRetentionRate: 0.0
    )
    @Published var environmentalImpact = EnvironmentalImpact(
        co2SavedKg: 0.0,
        fuelSavedLiters: 0.0,
        kmShared: 0.0,
        equivalentTreesPlanted: 0.0,
        costSavings: 0.0
    )
    
    func loadDashboardData() async {
        // TODO: Implement actual data loading from services
        await MainActor.run {
            // Mock data for now
            self.todaySchedule = [
                TransportScheduleItem(
                    id: UUID(),
                    groupName: "Morning Squad",
                    departureTime: Calendar.current.date(bySettingHour: 8, minute: 15, second: 0, of: Date()) ?? Date(),
                    estimatedDuration: 12 * 60, // 12 minutes
                    safetyScore: 9.2,
                    participants: [
                        TripParticipant(id: UUID(), name: "Sarah", isDriver: true),
                        TripParticipant(id: UUID(), name: "Mike", isDriver: false),
                        TripParticipant(id: UUID(), name: "Amy", isDriver: false),
                        TripParticipant(id: UUID(), name: "David", isDriver: false)
                    ]
                )
            ]
            
            self.communityStats = CommunityStats(
                totalFamilies: 24,
                activeGroups: 8,
                totalTripsCompleted: 156,
                averageGroupSize: 3.2,
                memberRetentionRate: 0.87
            )
            
            self.environmentalImpact = EnvironmentalImpact(
                co2SavedKg: 2.1,
                fuelSavedLiters: 8.5,
                kmShared: 45.2,
                equivalentTreesPlanted: 0.12,
                costSavings: 67.50
            )
        }
    }
}

// MARK: - Data Models
struct TransportScheduleItem: Identifiable {
    let id: UUID
    let groupName: String
    let departureTime: Date
    let estimatedDuration: TimeInterval
    let safetyScore: Double
    let participants: [TripParticipant]
}

struct TripParticipant: Identifiable {
    let id: UUID
    let name: String
    let isDriver: Bool
}

struct CommunityStats {
    let totalFamilies: Int
    let activeGroups: Int
    let totalTripsCompleted: Int
    let averageGroupSize: Double
    let memberRetentionRate: Double
}

struct EnvironmentalImpact {
    let co2SavedKg: Double
    let fuelSavedLiters: Double
    let kmShared: Double
    let equivalentTreesPlanted: Double
    let costSavings: Double
}

// MARK: - Route Adaptation Detail Sheet
struct RouteAdaptationDetailSheet: View {
    let adaptation: SimpleAdaptedRoute
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Route Adaptation Details")
                            .font(.title2.weight(.bold))
                        
                        Text("Adapted at \(adaptation.adaptedAt.formatted(.dateTime.hour().minute()))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Delay summary
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Additional Delay")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("+\(String(format: "%.0f", adaptation.estimatedDelay/60)) minutes")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Adaptation reasons
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Adaptation Reasons")
                            .font(.headline.weight(.semibold))
                        
                        ForEach(adaptation.adaptationReasons, id: \.self) { reason in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                
                                Text(reason)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    // Weather conditions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Weather Conditions")
                            .font(.headline.weight(.semibold))
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(adaptation.weatherCondition.condition)
                                    .font(.subheadline.weight(.medium))
                                
                                Text("\(String(format: "%.0f", adaptation.weatherCondition.temperature))°C")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                if adaptation.weatherCondition.requiresCoveredPickup {
                                    Label("Covered pickup needed", systemImage: "umbrella.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                
                                if adaptation.weatherCondition.reducesVisibility {
                                    Label("Reduced visibility", systemImage: "eye.slash")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Traffic incidents
                    if !adaptation.trafficIncidents.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Traffic Incidents")
                                .font(.headline.weight(.semibold))
                            
                            ForEach(adaptation.trafficIncidents) { incident in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(incident.type)
                                        .font(.subheadline.weight(.medium))
                                    
                                    Text(incident.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Delay: +\(String(format: "%.0f", incident.estimatedDelay/60))min")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Route Adaptation")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

// MARK: - Preview
#Preview {
    HomeDashboardView()
}
