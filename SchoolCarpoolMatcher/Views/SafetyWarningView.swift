//
//  SafetyWarningView.swift
//  SchoolCarpoolMatcher
//
//  Safety warning UI component for F2.1 route safety validation
//  Displays safety scores and recommendations with clear visual hierarchy
//  Applied Rule: Safety-first messaging and iOS native patterns
//

import SwiftUI
import MapKit

// MARK: - Safety Warning View
/// SwiftUI component for displaying route safety analysis and warnings
/// Implements F2.1 requirement for minimum 7.0/10 safety score validation
struct SafetyWarningView: View {
    
    // MARK: - Properties
    let analysis: RouteRiskAnalysis
    let showDetailedBreakdown: Bool
    let sourceCoordinate: CLLocationCoordinate2D?
    let destinationCoordinate: CLLocationCoordinate2D?
    
    @State private var isExpanded = false
    @State private var showingAlternatives = false
    @State private var showingMapView = false
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 16) {
            // Safety Score Header
            safetyScoreHeader
            
            // Risk Level Indicator
            riskLevelIndicator
            
            // Safety Recommendations
            if !analysis.recommendations.isEmpty {
                recommendationsSection
            }
            
            // Detailed Breakdown (Expandable)
            if showDetailedBreakdown {
                detailedBreakdownSection
            }
            
            // Action Buttons
            actionButtonsSection
        }
        .padding(20)
        .background(backgroundForRiskLevel)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColorForRiskLevel, lineWidth: 2)
        )
        .shadow(color: shadowColorForRiskLevel, radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showingMapView) {
            RouteMapView(
                analysis: analysis,
                sourceCoordinate: sourceCoordinate,
                destinationCoordinate: destinationCoordinate
            )
        }
    }
    
    // MARK: - Safety Score Header
    private var safetyScoreHeader: some View {
        HStack(spacing: 12) {
            // Safety Icon
            Image(systemName: iconForRiskLevel)
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(colorForRiskLevel)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Route Safety Score")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Text("\(String(format: "%.1f", analysis.overallScore))/10")
                        .font(.title2.weight(.bold))
                        .foregroundColor(colorForRiskLevel)
                    
                    if analysis.meetsMinimumSafety {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Analysis Date
            VStack(alignment: .trailing, spacing: 2) {
                Text("Analyzed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(analysis.lastAnalyzed, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Risk Level Indicator
    private var riskLevelIndicator: some View {
        HStack {
            Text(analysis.riskLevel.rawValue.capitalized)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(colorForRiskLevel)
            
            Text("Risk Level")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Risk level progress bar
            ProgressView(value: analysis.overallScore, total: 10.0)
                .progressViewStyle(LinearProgressViewStyle(tint: colorForRiskLevel))
                .frame(width: 80)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Recommendations Section
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                Text("Safety Recommendations")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            
            ForEach(Array(analysis.recommendations.enumerated()), id: \.offset) { index, recommendation in
                recommendationRow(recommendation, index: index)
            }
        }
    }
    
    private func recommendationRow(_ recommendation: RiskRecommendation, index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Priority indicator
            Circle()
                .fill(priorityColor(recommendation.priority))
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Text(recommendation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if recommendation.actionRequired {
                    Text("Action Required")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Detailed Breakdown Section
    private var detailedBreakdownSection: some View {
        VStack(spacing: 0) {
            // Expandable header
            Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.blue)
                    
                    Text("Safety Factor Breakdown")
                        .font(.subheadline.weight(.semibold))
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                    
                    // School Zone Coverage
                    safetyFactorRow(
                        title: "School Zone Coverage",
                        value: "\(String(format: "%.1f", analysis.safetyFactors.schoolZoneScore))%",
                        icon: "graduationcap.fill",
                        color: analysis.safetyFactors.schoolZoneScore > 50 ? .green : .orange
                    )
                    
                    // Road Type Score
                    safetyFactorRow(
                        title: "Road Type Safety",
                        value: String(format: "%.2fx", analysis.safetyFactors.roadTypeScore),
                        icon: "road.lanes",
                        color: analysis.safetyFactors.roadTypeScore > 1.3 ? .green : .orange
                    )
                    
                    // Traffic Light Coverage
                    safetyFactorRow(
                        title: "Traffic Control",
                        value: String(format: "%.2fx", analysis.safetyFactors.trafficLightScore),
                        icon: "traffic.light.fill",
                        color: analysis.safetyFactors.trafficLightScore > 1.2 ? .green : .orange
                    )
                    
                    // Accident History
                    safetyFactorRow(
                        title: "Accident History",
                        value: String(format: "%.2f", analysis.safetyFactors.accidentHistoryScore),
                        icon: "exclamationmark.triangle.fill",
                        color: analysis.safetyFactors.accidentHistoryScore >= 0 ? .green : .red
                    )
                }
                .padding(.top, 8)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func safetyFactorRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(color)
        }
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if !analysis.meetsMinimumSafety {
                // Primary action for unsafe routes
                Button(action: { showingAlternatives = true }) {
                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                        Text("Find Safer Route")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Secondary actions
            HStack(spacing: 12) {
                Button("View on Map") {
                    print("📍 Opening route map view")
                    showingMapView = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                Button("Share Analysis") {
                    // Action to share safety analysis
                    print("📤 Share safety analysis")
                }
                .font(.subheadline)
                .foregroundColor(.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Visual Styling Helpers
    
    private var backgroundForRiskLevel: Color {
        switch analysis.riskLevel {
        case .low:
            return Color.green.opacity(0.05)
        case .medium:
            return Color.yellow.opacity(0.05)
        case .high:
            return Color.orange.opacity(0.05)
        case .critical:
            return Color.red.opacity(0.05)
        }
    }
    
    private var borderColorForRiskLevel: Color {
        switch analysis.riskLevel {
        case .low:
            return Color.green.opacity(0.3)
        case .medium:
            return Color.yellow.opacity(0.3)
        case .high:
            return Color.orange.opacity(0.3)
        case .critical:
            return Color.red.opacity(0.3)
        }
    }
    
    private var shadowColorForRiskLevel: Color {
        switch analysis.riskLevel {
        case .low:
            return Color.green.opacity(0.1)
        case .medium:
            return Color.yellow.opacity(0.1)
        case .high:
            return Color.orange.opacity(0.1)
        case .critical:
            return Color.red.opacity(0.2)
        }
    }
    
    private var colorForRiskLevel: Color {
        switch analysis.riskLevel {
        case .low:
            return .green
        case .medium:
            return .yellow
        case .high:
            return .orange
        case .critical:
            return .red
        }
    }
    
    private var iconForRiskLevel: String {
        switch analysis.riskLevel {
        case .low:
            return "shield.checkered"
        case .medium:
            return "shield"
        case .high:
            return "exclamationmark.shield"
        case .critical:
            return "xmark.shield"
        }
    }
    
    private func priorityColor(_ priority: RecommendationPriority) -> Color {
        switch priority {
        case .low:
            return .blue
        case .medium:
            return .yellow
        case .high:
            return .orange
        case .critical:
            return .red
        }
    }
}

// MARK: - Preview Provider
struct SafetyWarningView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // High safety score example
            SafetyWarningView(
                analysis: RouteRiskAnalysis(
                    route: MockRoute(distance: 5000, expectedTravelTime: 600, polyline: MKPolyline()),
                    overallRiskScore: 1.5, // Low risk score (safe)
                    riskFactors: RiskFactors(
                        schoolZoneRiskReduction: 75.0,
                        roadTypeRiskScore: -1.5,
                        trafficLightRiskReduction: -1.3,
                        accidentRiskIncrease: 0.0
                    ),
                    isAcceptableRisk: true,
                    recommendations: [],
                    lastAnalyzed: Date()
                ),
                showDetailedBreakdown: true,
                sourceCoordinate: CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300),
                destinationCoordinate: CLLocationCoordinate2D(latitude: -35.2500, longitude: 149.1500)
            )
            
            // Low safety score with warnings
            SafetyWarningView(
                analysis: RouteRiskAnalysis(
                    route: MockRoute(distance: 8000, expectedTravelTime: 900, polyline: MKPolyline()),
                    overallRiskScore: 4.8, // High risk score (unsafe)
                    riskFactors: RiskFactors(
                        schoolZoneRiskReduction: 25.0,
                        roadTypeRiskScore: 2.0,
                        trafficLightRiskReduction: -0.5,
                        accidentRiskIncrease: 1.8
                    ),
                    isAcceptableRisk: false,
                    recommendations: [
                        RiskRecommendation(
                            priority: .critical,
                            title: "High Risk Route Warning",
                            description: "This route has a risk score of 4.8/10, above the maximum acceptable risk of 3.0/10. Consider alternative routes.",
                            actionRequired: true
                        ),
                        RiskRecommendation(
                            priority: .high,
                            title: "Accident-Prone Areas Detected",
                            description: "This route passes through areas with significant accident history (risk increase: +1.8). Extra caution recommended.",
                            actionRequired: true
                        )
                    ],
                    lastAnalyzed: Date()
                ),
                showDetailedBreakdown: true,
                sourceCoordinate: CLLocationCoordinate2D(latitude: -35.3000, longitude: 149.1200),
                destinationCoordinate: CLLocationCoordinate2D(latitude: -35.2700, longitude: 149.1600)
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Mock Route for Preview
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
