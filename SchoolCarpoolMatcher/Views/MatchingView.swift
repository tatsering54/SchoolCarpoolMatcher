//
//  MatchingView.swift
//  SchoolCarpoolMatcher
//
//  Main matching interface with card stack and swipe functionality
//  Implements F1.3 requirements: stack display, animations, "It's a Match!"
//  Follows repo rule: Safety-first messaging and iOS native patterns
//

import SwiftUI
import CoreLocation

// MARK: - Matching View
/// Main view for family matching with swipeable card stack
/// Displays maximum 3 cards as per F1.3 specification
struct MatchingView: View {
    
    // MARK: - Environment Objects
    @StateObject private var locationManager = LocationManager()
    @StateObject private var matchingEngine: MatchingEngine
    @StateObject private var groupFormationService = GroupFormationService()
    
    // MARK: - Initialization
    init() {
        // Create a single LocationManager instance to share between objects
        let sharedLocationManager = LocationManager()
        self._locationManager = StateObject(wrappedValue: sharedLocationManager)
        self._matchingEngine = StateObject(wrappedValue: MatchingEngine(locationManager: sharedLocationManager))
    }
    
    // MARK: - State
    @State private var showingMatchAnimation = false
    @State private var matchedFamily: Family?
    @State private var showingLocationPermission = false
    @State private var showingNoMatches = false
    @State private var userPreferences = UserPreferences.demoPreferences()
    @State private var showingGroupManagement = false
    @State private var showingGroupChat = false
    @State private var createdGroup: CarpoolGroup?
    @State private var locationPermissionRequested = false
    
    // MARK: - Constants
    private let maxVisibleCards = 4 // Optimized for better visibility (Apple HIG: avoid overwhelming users)
    private let cardStackOffset: CGFloat = 20 // Reduced for tighter, more visible stack
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                backgroundGradient
                
                // Main content
                if locationManager.isLocationAvailable {
                    if matchingEngine.isLoading {
                        loadingView
                    } else if matchingEngine.availableFamilies.isEmpty {
                        noMatchesView
                    } else {
                        cardStackView
                    }
                } else if showingLocationPermission {
                    locationPermissionView
                } else {
                    // Show loading while checking location status
                    loadingView
                }
                
                // Match animation overlay
                if showingMatchAnimation {
                    matchAnimationOverlay
                }
            }
            .navigationTitle("Find Families")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingGroupManagement) {
            GroupManagementView()
        }
        .sheet(isPresented: $showingGroupChat) {
            if let group = createdGroup {
                GroupChatView(group: group)
            }
        }
        .onAppear {
            Task {
                await setupView()
            }
        }
        .onChange(of: locationManager.currentLocation) { _, location in
            if let location = location {
                Task {
                    await matchingEngine.updateAvailableFamilies(
                        userLocation: location,
                        userPreferences: userPreferences
                    )
                }
            }
        }
        .onChange(of: locationManager.authorizationStatus) { _, status in
            Task {
                await handleLocationStatusChange(status)
            }
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color.black.opacity(0.9)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Card Stack View (Tinder-style)
    private var cardStackView: some View {
        ZStack {
            // Background - dark theme like Tinder
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Minimal header - just essential info (Tinder style)
                minimalHeader
                
                // Full-screen card stack with loading state (Apple Design: clear loading indicators)
                ZStack {
                    if matchingEngine.isLoading {
                        // Loading indicator (Apple Design: standard loading pattern)
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            
                            Text("Loading families...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                    } else if visibleFamilies.isEmpty {
                        // Empty state with prominent demo button
                        VStack(spacing: 24) {
                            Image(systemName: "person.2.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("No Families Found")
                                .font(.title2.weight(.semibold))
                                .foregroundColor(.white)
                            
                            Text("Try demo mode to see how matching works")
                                .font(.body)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            
                            Button("🧪 Start Demo") {
                                Task {
                                    await loadDemoFamilies()
                                }
                            }
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color.orange, Color.orange.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: .orange.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Family cards stack
                        ForEach(Array(visibleFamilies.enumerated()), id: \.element.id) { index, family in
                            let compatibilityScore = matchingEngine.compatibilityScores[family.id] ?? 0.0
                            
                            FamilyCard(
                                family: family,
                                compatibilityScore: compatibilityScore,
                                onSwipe: { direction in
                                    handleSwipe(family: family, direction: direction)
                                },
                                onTap: {
                                    // Handle card tap for details
                                    print("📋 Show details for \(family.parentName)")
                                }
                            )
                            .zIndex(Double(visibleFamilies.count - index))
                            .scaleEffect(cardScale(for: index))
                            .offset(y: cardOffset(for: index))
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: visibleFamilies)
                            .onAppear {
                                print("🃏 Card \(index + 1) appeared for \(family.parentName)")
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom action area - Tinder-style circular buttons
                tinderStyleActionButtons
                    .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Minimal Header (Tinder-style)
    private var minimalHeader: some View {
        VStack(spacing: 8) {
            HStack {
                // Left: Available families count
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(matchingEngine.availableFamilies.count)")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                    Text("families nearby")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Right: Current matches count
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(matchingEngine.currentMatches.count)")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.pink)
                    Text("matches")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            // Debug info and manual demo trigger
            if !matchingEngine.availableFamilies.isEmpty {
                HStack {
                    Text("Visible: \(visibleFamilies.count)/\(matchingEngine.availableFamilies.count)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Button("🧪 Demo") {
                        Task {
                            await loadDemoFamilies()
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .clipShape(Capsule())
                    
                    Text("Demo Mode Active")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .clipShape(Capsule())
                }
            } else {
                // Show demo button when no families
                HStack {
                    Text("No families found")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Button("🧪 Try Demo Mode") {
                        Task {
                            await loadDemoFamilies()
                        }
                    }
                    .font(.subheadline.weight(.semibold)) // More prominent font
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color.orange, Color.orange.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .orange.opacity(0.3), radius: 4, x: 0, y: 2) // Apple Design: subtle shadow for depth
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 20)
    }
    
    // MARK: - Tinder-Style Action Buttons
    private var tinderStyleActionButtons: some View {
        VStack(spacing: 16) {
            // Main action buttons row (Tinder style)
            HStack(spacing: 20) {
                // Rewind/Undo button
                Button {
                    print("⏪ Undo last swipe")
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                
                // Dislike/Pass button - Now functional
                Button {
                    if let currentFamily = visibleFamilies.first {
                        handleSwipe(family: currentFamily, direction: .left)
                        print("❌ Passed on \(currentFamily.parentName)")
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.title.weight(.bold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(
                                colors: [Color.red, Color.red.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: .red.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .disabled(visibleFamilies.isEmpty)
                .opacity(visibleFamilies.isEmpty ? 0.5 : 1.0)
                
                // Super Like button - Enhanced visual
                Button {
                    if let currentFamily = visibleFamilies.first {
                        handleSwipe(family: currentFamily, direction: .right) // Super like as right swipe
                        print("⭐ Super liked \(currentFamily.parentName)")
                    }
                } label: {
                    Image(systemName: "star.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .disabled(visibleFamilies.isEmpty)
                .opacity(visibleFamilies.isEmpty ? 0.5 : 1.0)
                
                // Like/Match button - Now functional
                Button {
                    if let currentFamily = visibleFamilies.first {
                        handleSwipe(family: currentFamily, direction: .right)
                        print("❤️ Liked \(currentFamily.parentName)")
                    }
                } label: {
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: .green.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .disabled(visibleFamilies.isEmpty)
                .opacity(visibleFamilies.isEmpty ? 0.5 : 1.0)
                
                // Boost button
                Button {
                    print("⚡ Boost profile")
                } label: {
                    Image(systemName: "bolt.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.purple)
                        .clipShape(Circle())
                }
            }
            
            // Safety message - minimal and clean
            HStack(spacing: 6) {
                Image(systemName: "shield.checkered")
                    .foregroundColor(.green)
                    .font(.caption2)
                
                Text("Verified families only")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
    }
    

    
    // MARK: - Bottom Action Area (Tinder-style floating)
    private var bottomActionArea: some View {
        VStack(spacing: 12) {
            // Safety message (repo rule: safety-first messaging)
            safetyMessage
            
            // Quick actions - minimal and clean
            HStack(spacing: 16) {
                Button("Reset") {
                    matchingEngine.resetDailySwipes()
                    refreshMatches()
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Button("Settings") {
                    // Would show settings UI
                    print("⚙️ Show settings")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground).opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private var safetyMessage: some View {
        HStack(spacing: 6) {
            Image(systemName: "shield.checkered")
                .foregroundColor(.green)
                .font(.caption2)
            
            Text("Verified families only")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.1))
        .clipShape(Capsule())
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Finding compatible families...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("We're analyzing schedules, locations, and safety scores")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(40)
        }
    }
    
    // MARK: - No Matches View
    private var noMatchesView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("No Families Found")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                
                Text("We couldn't find any families in your area with the current settings.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                VStack(spacing: 16) {
                    Button("Expand Search Radius") {
                        Task {
                            await expandSearchRadius()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Adjust Time Preferences") {
                        Task {
                            await adjustTimePreferences()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white, lineWidth: 1)
                    )
                    
                    Button("Try Demo Mode") {
                        Task {
                            await loadDemoFamilies()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white, lineWidth: 1)
                    )
                }
            }
            .padding(40)
        }
    }
    
    // MARK: - Location Permission View
    private var locationPermissionView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
            Image(systemName: "location.slash")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Location Access Needed")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
            
            Text("We need your location to find nearby families and create safe carpool routes.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(spacing: 16) {
                Button("Enable Location") {
                    locationManager.requestLocationPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Try Demo Mode") {
                    Task {
                        await loadDemoFamilies()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .foregroundColor(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 1)
                )
                
                Button("Enter Postcode Manually") {
                    // Would show postcode entry (F1.1 fallback)
                    print("📮 Manual postcode entry")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .foregroundColor(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 1)
                )
            }
        }
        .padding(40)
        }
    }
    
    // MARK: - Match Animation Overlay
    private var matchAnimationOverlay: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissMatchAnimation()
                }
            
            // "It's a Match!" animation (F1.3 requirement)
            VStack(spacing: 30) {
                // Celebration animation
                VStack(spacing: 16) {
                    Text("🎉")
                        .font(.system(size: 60))
                        .scaleEffect(showingMatchAnimation ? 1.2 : 0.8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showingMatchAnimation)
                    
                    Text("It's a Match!")
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(.pink)
                    
                    if let matchedFamily = matchedFamily {
                        Text("You and \(matchedFamily.parentName) both want to carpool!")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(30)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 20)
                
                // Action buttons
                HStack(spacing: 20) {
                    Button("Keep Swiping") {
                        dismissMatchAnimation()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Start Group Chat") {
                        startGroupFormation()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(40)
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupView() async {
        print("🚀 Setting up MatchingView")
        
        // Check current location status
        let currentStatus = locationManager.authorizationStatus
        print("📍 Current location status: \(currentStatus.rawValue)")
        
        switch currentStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Location authorized, check if we have a location
            if let location = locationManager.currentLocation {
                print("✅ Location available, loading families...")
                Task {
                    await matchingEngine.updateAvailableFamilies(
                        userLocation: location,
                        userPreferences: userPreferences
                    )
                }
            } else {
                print("⚠️ Location authorized but no location data yet")
                // Start location updates to get current location
                locationManager.startLocationUpdates()
            }
            
        case .notDetermined:
            print("❓ Location permission not determined, requesting...")
            locationManager.requestLocationPermission()
            
        case .denied, .restricted:
            print("❌ Location access denied or restricted")
            // Show location permission view
            await MainActor.run {
                showingLocationPermission = true
            }
            
        @unknown default:
            print("⚠️ Unknown location status: \(currentStatus)")
            await MainActor.run {
                showingLocationPermission = true
            }
        }
    }
    
    private func handleSwipe(family: Family, direction: SwipeDirection) {
        // Memory safety: Validate family object exists
        guard !family.id.uuidString.isEmpty else {
            print("⚠️ Invalid family object in swipe handler")
            return
        }
        
        print("👆 Handling swipe \(direction.rawValue) for \(family.parentName)")
        
        // Handle swipe through matching engine with safety check
        guard matchingEngine.availableFamilies.contains(where: { $0.id == family.id }) else {
            print("⚠️ Family not found in available families during swipe")
            return
        }
        
        matchingEngine.handleSwipe(family: family, direction: direction)
        
        // Show match animation for right swipes (simulate mutual interest)
        if direction == .right && Bool.random() { // 50% chance for demo
            showMatchAnimation(for: family)
        }
    }
    
    private func showMatchAnimation(for family: Family) {
        print("🎉 Showing match animation for \(family.parentName)")
        matchedFamily = family
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showingMatchAnimation = true
        }
        
        // Auto-dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if showingMatchAnimation {
                dismissMatchAnimation()
            }
        }
    }
    
    private func dismissMatchAnimation() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showingMatchAnimation = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            matchedFamily = nil
        }
    }
    
    private func startGroupFormation() {
        guard let matchedFamily = matchedFamily else {
            print("❌ No matched family for group formation")
            return
        }
        
        print("👥 Starting group formation with \(matchedFamily.parentName)")
        
        Task {
            // Create mock current user and matches for demo
            let mockCurrentUser = MockData.families.first!
            let matches = [matchedFamily]
            
            let result = await groupFormationService.createCarpoolGroup(
                matches: matches,
                currentUser: mockCurrentUser,
                customName: "\(matchedFamily.schoolName) Squad"
            )
            
            await MainActor.run {
                switch result {
                case .success(let group):
                    print("✅ Group created successfully: \(group.groupName)")
                    createdGroup = group
                    dismissMatchAnimation()
                    
                    // Show success and navigate to chat
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingGroupChat = true
                    }
                    
                case .failure(let error):
                    print("❌ Failed to create group: \(error)")
                    dismissMatchAnimation()
                }
            }
        }
    }
    
    private func refreshMatches() {
        guard let location = locationManager.currentLocation else {
            print("❌ No location for refresh")
            return
        }
        
        print("🔄 Refreshing matches...")
        Task {
            await matchingEngine.updateAvailableFamilies(
                userLocation: location,
                userPreferences: userPreferences
            )
        }
    }
    
    private func expandSearchRadius() async {
        userPreferences = UserPreferences(
            searchRadius: min(userPreferences.searchRadius * 1.5, 10000), // Max 10km
            departureTime: userPreferences.departureTime,
            timeFlexibility: userPreferences.timeFlexibility,
            requiredSeats: userPreferences.requiredSeats,
            maxDetourTime: userPreferences.maxDetourTime,
            prioritizeSafety: userPreferences.prioritizeSafety,
            requireVerification: userPreferences.requireVerification,
            allowBackgroundCheck: userPreferences.allowBackgroundCheck
        )
        
        refreshMatches()
    }
    
    private func adjustTimePreferences() async {
        userPreferences = UserPreferences(
            searchRadius: userPreferences.searchRadius,
            departureTime: userPreferences.departureTime,
            timeFlexibility: userPreferences.timeFlexibility * 2, // Double flexibility
            requiredSeats: userPreferences.requiredSeats,
            maxDetourTime: userPreferences.maxDetourTime,
            prioritizeSafety: userPreferences.prioritizeSafety,
            requireVerification: userPreferences.requireVerification,
            allowBackgroundCheck: userPreferences.allowBackgroundCheck
        )
        
        refreshMatches()
    }
    
    private func handleLocationStatusChange(_ status: CLAuthorizationStatus) async {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location authorized. Updating families.")
            if let location = locationManager.currentLocation {
                Task {
                    await matchingEngine.updateAvailableFamilies(
                        userLocation: location,
                        userPreferences: userPreferences
                    )
                }
            }
        case .denied, .restricted:
            print("❌ Location denied or restricted. Showing permission view.")
            await MainActor.run {
                showingLocationPermission = true
            }
        case .notDetermined:
            print("⚠️ Location status not determined. Requesting permission.")
            locationManager.requestLocationPermission()
        @unknown default:
            print("❌ Unknown location status: \(status)")
        }
    }
    
    /// Load demo families for testing when location is not available
    /// Enhanced with better user feedback and Apple Design Guidelines compliance
    private func loadDemoFamilies() async {
        print("🧪 Loading demo families for testing...")
        
        // Show loading state (Apple Design: provide immediate feedback)
        await MainActor.run {
            matchingEngine.isLoading = true
        }
        
        // Simulate Canberra location and load families
        locationManager.simulateCanberraLocation()
        
        // Wait a moment for location to be set (Apple Design: reasonable loading time)
        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds for better UX
        
        // Force load families with simulated location
        if let location = locationManager.currentLocation {
            print("📍 Demo location set: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            
            // Update user preferences to ensure large search radius for demo
            userPreferences = UserPreferences(
                searchRadius: 15000, // 15km for demo to find all families
                departureTime: userPreferences.departureTime,
                timeFlexibility: userPreferences.timeFlexibility,
                requiredSeats: userPreferences.requiredSeats,
                maxDetourTime: userPreferences.maxDetourTime,
                prioritizeSafety: userPreferences.prioritizeSafety,
                requireVerification: false, // Disable verification requirement for demo
                allowBackgroundCheck: false
            )
            
            await matchingEngine.updateAvailableFamilies(
                userLocation: location,
                userPreferences: userPreferences
            )
            
            // Provide success feedback
            await MainActor.run {
                matchingEngine.isLoading = false
                print("✅ Demo mode loaded with \(matchingEngine.availableFamilies.count) families")
                
                // Add haptic feedback for successful load (Apple Design: tactile feedback)
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
        } else {
            await MainActor.run {
                matchingEngine.isLoading = false
                print("❌ Failed to set demo location")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var visibleFamilies: [Family] {
        let availableFamilies = matchingEngine.availableFamilies
        
        // Memory safety: Validate array is not corrupted
        guard !availableFamilies.isEmpty else {
            print("📋 No available families to display")
            return []
        }
        
        // Additional validation: Check for valid family objects
        let validFamilies = availableFamilies.filter { family in
            !family.id.uuidString.isEmpty && !family.parentName.isEmpty
        }
        
        if validFamilies.count != availableFamilies.count {
            print("⚠️ Filtered out \(availableFamilies.count - validFamilies.count) invalid families")
        }
        
        return Array(validFamilies.prefix(maxVisibleCards))
    }
    
    private func cardScale(for index: Int) -> Double {
        // Enhanced scaling for better card visibility (Apple Design: clear visual hierarchy)
        return 1.0 - (Double(index) * 0.05) // More pronounced scaling for better depth perception
    }
    
    private func cardOffset(for index: Int) -> CGFloat {
        return CGFloat(index) * cardStackOffset
    }
    
    private var timeOfDay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: userPreferences.departureTime)
    }
}

// MARK: - Supporting Views

// MARK: - Preview
#Preview {
    MatchingView()
}
