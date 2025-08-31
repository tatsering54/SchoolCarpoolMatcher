//
//  ContentView.swift
//  SchoolCarpoolMatcher
//
//  Main app interface with tab-based navigation
//  Match-first design for Tinder-style carpool matching
//  Follows Apple Design Guidelines for iOS native feel and accessibility
//

import SwiftUI

// MARK: - Main Content View
/// Main app interface with tab-based navigation for different app sections
/// Implements complete app structure matching theme.html design
struct ContentView: View {
    
    // MARK: - Properties
    @State private var selectedTab = 0
    
    // MARK: - Body
    var body: some View {
        TabView(selection: $selectedTab) {
            // Match Tab - Primary feature (Tinder-style matching)
            MatchingView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Match")
                }
                .tag(0)
            
            // Route Tab - Safety-First Route Optimization (F2)
            HomeDashboardView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Route")
                }
                .tag(1)
            
            // Groups Tab
            GroupsView()
                .tabItem {
                    Image(systemName: "person.3.sequence.fill")
                    Text("Groups")
                }
                .tag(2)
            
            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("Profile")
                }
                .tag(3)
            
            // Testing Tab
            TestingView(onBack: {})
                .tabItem {
                    Image(systemName: "wrench.and.screwdriver.fill")
                    Text("Testing")
                }
                .tag(4)
        }
        .accentColor(.blue)
        .onAppear {
            // Set tab bar appearance for iOS 15+ compatibility
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
