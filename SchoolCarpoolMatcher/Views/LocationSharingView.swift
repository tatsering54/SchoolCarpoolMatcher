//
//  LocationSharingView.swift
//  SchoolCarpoolMatcher
//
//  F3.2 Live Location Sharing implementation
//  Real-time location sharing during pickup/dropoff with privacy controls and safety-first design
//  Applied Rule: Apple Design Guidelines with comprehensive accessibility and debug logging
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Supporting Data Models
struct GroupMemberLocation: Identifiable {
    let id: UUID
    let memberId: UUID
    let memberName: String
    let coordinate: CLLocationCoordinate2D
    let accuracy: Double
    let lastUpdated: Date
    let estimatedArrival: Date?
    let isMoving: Bool
    
    init(id: UUID = UUID(), memberId: UUID, memberName: String, coordinate: CLLocationCoordinate2D, accuracy: Double = 10.0, lastUpdated: Date = Date(), estimatedArrival: Date? = nil, isMoving: Bool = false) {
        self.id = id
        self.memberId = memberId
        self.memberName = memberName
        self.coordinate = coordinate
        self.accuracy = accuracy
        self.lastUpdated = lastUpdated
        self.estimatedArrival = estimatedArrival
        self.isMoving = isMoving
    }
}

// MARK: - Location Sharing View
/// Live location sharing interface for carpool group coordination
/// Implements F3.2 requirements: real-time positions, ETA calculations, privacy controls, auto-timeout
struct LocationSharingView: View {
    
    // MARK: - Properties
    let group: CarpoolGroup
    @StateObject private var locationSharingService = LocationSharingService.shared
    @StateObject private var locationManager = LocationManager.shared
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300), // Canberra
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var showingPrivacySettings = false
    @State private var showingMemberDetails = false
    @State private var selectedMember: GroupMemberLocation?
    @State private var sharingDuration: TimeInterval = 7200 // 2 hours default
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Computed Properties
    private var activeSharingMembers: [GroupMemberLocation] {
        locationSharingService.getActiveLocations(for: group.id)
    }
    
    private var isCurrentlySharing: Bool {
        locationSharingService.isSharing(for: group.id)
    }
    
    private var sharingTimeRemaining: TimeInterval {
        locationSharingService.getSharingTimeRemaining(for: group.id)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Map View
                mapView
                
                // MARK: - Control Panel
                controlPanel
            }
            .navigationTitle("Live Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Privacy", systemImage: "shield.checkered") {
                        showingPrivacySettings = true
                    }
                    .foregroundColor(.green)
                }
            }
            .sheet(isPresented: $showingPrivacySettings) {
                privacySettingsView
            }
            .sheet(isPresented: $showingMemberDetails) {
                if let member = selectedMember {
                    memberDetailsView(member: member)
                }
            }
            .onAppear {
                setupLocationSharing()
                print("📍 LocationSharingView appeared for group: \(group.groupName)")
            }
            .onDisappear {
                // Location sharing continues in background with auto-timeout
                print("📍 LocationSharingView disappeared - sharing continues in background")
            }
        }
        .accessibilityLabel("Live location sharing for \(group.groupName)")
    }
    
    // MARK: - Map View
    private var mapView: some View {
        Map(coordinateRegion: $mapRegion, annotationItems: activeSharingMembers) { member in
            MapAnnotation(coordinate: member.coordinate) {
                MemberLocationAnnotation(
                    member: member,
                    onTap: {
                        selectedMember = member
                        showingMemberDetails = true
                    }
                )
            }
        }
        .frame(minHeight: 300)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .onAppear {
            centerMapOnGroup()
        }
        .accessibilityLabel("Map showing live locations of group members")
    }
    
    // MARK: - Control Panel
    private var controlPanel: some View {
        VStack(spacing: 20) {
            // Sharing Status
            sharingStatusCard
            
            // Active Members List
            if !activeSharingMembers.isEmpty {
                activeMembersList
            }
            
            // Sharing Controls
            sharingControlsCard
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
    
    // MARK: - Sharing Status Card
    private var sharingStatusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: isCurrentlySharing ? "location.fill" : "location.slash")
                    .font(.title2)
                    .foregroundColor(isCurrentlySharing ? .green : .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Location Sharing")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text(isCurrentlySharing ? "Active" : "Inactive")
                        .font(.subheadline)
                        .foregroundColor(isCurrentlySharing ? .green : .secondary)
                }
                
                Spacer()
                
                if isCurrentlySharing {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Time Remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatTimeRemaining(sharingTimeRemaining))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                    }
                }
            }
            
            if isCurrentlySharing {
                ProgressView(value: 1.0 - (sharingTimeRemaining / sharingDuration))
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    .scaleEffect(y: 2.0)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Location sharing status: \(isCurrentlySharing ? "Active" : "Inactive")")
    }
    
    // MARK: - Active Members List
    private var activeMembersList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Locations (\(activeSharingMembers.count))")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            ForEach(activeSharingMembers) { member in
                MemberLocationRow(
                    member: member,
                    onTap: {
                        selectedMember = member
                        showingMemberDetails = true
                    }
                )
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Sharing Controls Card
    private var sharingControlsCard: some View {
        VStack(spacing: 16) {
            if !isCurrentlySharing {
                // Start sharing controls
                VStack(spacing: 12) {
                    Text("Share Your Location")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text("Let group members see your real-time location during pickup and dropoff")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // Duration picker
                    Picker("Sharing Duration", selection: $sharingDuration) {
                        Text("30 minutes").tag(TimeInterval(1800))
                        Text("1 hour").tag(TimeInterval(3600))
                        Text("2 hours").tag(TimeInterval(7200))
                        Text("4 hours").tag(TimeInterval(14400))
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Select sharing duration")
                    
                    Button("Start Sharing Location") {
                        startLocationSharing()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                }
            } else {
                // Stop sharing controls
                VStack(spacing: 12) {
                    Text("Location Sharing Active")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.green)
                    
                    Text("Your location is being shared with group members")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Stop Sharing") {
                        stopLocationSharing()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Privacy Settings View
    private var privacySettingsView: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("Privacy & Safety")
                        .font(.title2.weight(.bold))
                    
                    Text("Control how your location is shared with group members")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Privacy options
                VStack(spacing: 16) {
                    PrivacyOptionRow(
                        icon: "eye.slash",
                        title: "Auto-Stop Sharing",
                        description: "Automatically stop sharing after selected duration",
                        isEnabled: true
                    )
                    
                    PrivacyOptionRow(
                        icon: "location.circle",
                        title: "Approximate Location",
                        description: "Share general area instead of exact location",
                        isEnabled: false
                    )
                    
                    PrivacyOptionRow(
                        icon: "bell",
                        title: "Sharing Notifications",
                        description: "Get notified when sharing starts/stops",
                        isEnabled: true
                    )
                    
                    PrivacyOptionRow(
                        icon: "person.2",
                        title: "Group Members Only",
                        description: "Only share with verified group members",
                        isEnabled: true
                    )
                }
                
                Spacer()
                
                Button("Done") {
                    showingPrivacySettings = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .navigationTitle("Privacy Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Member Details View
    private func memberDetailsView(member: GroupMemberLocation) -> some View {
        NavigationView {
            VStack(spacing: 20) {
                // Member info
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 80, height: 80)
                        .overlay {
                            Text(member.memberName.prefix(1))
                                .font(.title.weight(.bold))
                                .foregroundColor(.white)
                        }
                    
                    Text(member.memberName)
                        .font(.title2.weight(.semibold))
                    
                    Text("Last updated: \(member.lastUpdated.formatted(.relative(presentation: .named)))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Location details
                VStack(spacing: 16) {
                    LocationDetailRow(
                        icon: "location.fill",
                        title: "Current Location",
                        value: "Lat: \(String(format: "%.4f", member.coordinate.latitude)), Long: \(String(format: "%.4f", member.coordinate.longitude))"
                    )
                    
                    if let eta = member.estimatedArrival {
                        LocationDetailRow(
                            icon: "clock.arrow.circlepath",
                            title: "Estimated Arrival",
                            value: eta.formatted(.dateTime.hour().minute())
                        )
                    }
                    
                    LocationDetailRow(
                        icon: "speedometer",
                        title: "Moving Status",
                        value: member.isMoving ? "In transit" : "Stationary"
                    )
                    
                    LocationDetailRow(
                        icon: "target",
                        title: "Accuracy",
                        value: "\(Int(member.accuracy))m"
                    )
                }
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    Button("Get Directions") {
                        openDirections(to: member.coordinate)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Send Message") {
                        // Navigate back to chat
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding()
            .navigationTitle("Member Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingMemberDetails = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupLocationSharing() {
        // Request location permission if needed
        locationManager.requestLocationPermission()
        
        // Load existing sharing sessions
        Task {
            await locationSharingService.loadActiveSessions(for: group.id)
        }
    }
    
    private func startLocationSharing() {
        print("📍 Starting location sharing for group: \(group.groupName)")
        print("   ⏱️ Duration: \(sharingDuration/3600) hours")
        
        Task {
            do {
                try await locationSharingService.startSharing(
                    for: group.id,
                    duration: sharingDuration
                )
                
                await MainActor.run {
                    // Update UI state
                    print("✅ Location sharing started successfully")
                }
            } catch {
                print("❌ Failed to start location sharing: \(error)")
                // In real app, would show error alert
            }
        }
    }
    
    private func stopLocationSharing() {
        print("📍 Stopping location sharing for group: \(group.groupName)")
        
        Task {
            await locationSharingService.stopSharing(for: group.id)
            
            await MainActor.run {
                print("✅ Location sharing stopped")
            }
        }
    }
    
    private func centerMapOnGroup() {
        if let firstMember = activeSharingMembers.first {
            mapRegion.center = firstMember.coordinate
        }
    }
    
    private func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func openDirections(to coordinate: CLLocationCoordinate2D) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = "Group Member Location"
        
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

// MARK: - Member Location Annotation
struct MemberLocationAnnotation: View {
    let member: GroupMemberLocation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Circle()
                    .fill(member.isMoving ? Color.green : Color.blue)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(member.memberName.prefix(1))
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                    }
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(radius: 4)
                
                Text(member.memberName)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(radius: 2)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(member.memberName) location")
        .accessibilityHint("Tap for details")
    }
}

// MARK: - Member Location Row
struct MemberLocationRow: View {
    let member: GroupMemberLocation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(member.isMoving ? Color.green : Color.blue)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(member.memberName.prefix(1))
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.memberName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Text(member.lastUpdated.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    if let eta = member.estimatedArrival {
                        Text("ETA: \(eta.formatted(.dateTime.hour().minute()))")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.green)
                    }
                    
                    Text(member.isMoving ? "Moving" : "Stationary")
                        .font(.caption2)
                        .foregroundColor(member.isMoving ? .green : .secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(member.memberName) location details")
    }
}

// MARK: - Privacy Option Row
struct PrivacyOptionRow: View {
    let icon: String
    let title: String
    let description: String
    @State var isEnabled: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Location Detail Row
struct LocationDetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview {
    let sampleGroup = CarpoolGroup(
        id: UUID(),
        groupName: "Forrest Primary Squad",
        adminId: UUID(),
        members: [],
        schoolName: "Forrest Primary School",
        schoolAddress: "6 Vasey Crescent, Forrest ACT 2603",
        scheduledDepartureTime: Date(),
        pickupSequence: [],
        optimizedRoute: Route(groupId: UUID(), pickupPoints: [], safetyScore: 9.2),
        safetyScore: 9.2
    )
    
    LocationSharingView(group: sampleGroup)
}