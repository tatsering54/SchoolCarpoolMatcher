//
//  ProfileView.swift
//  SchoolCarpoolMatcher
//
//  User profile interface with verification status, safety scores, and personal information
//  Follows Apple Design Guidelines for iOS native feel and accessibility
//

import SwiftUI

// MARK: - Profile View
/// User profile interface showing personal information, verification status, and safety metrics
/// Implements F5.1-F5.3 requirements: trust & verification system
struct ProfileView: View {
    
    // MARK: - Properties
    @StateObject private var profileViewModel = ProfileViewModel()
    @StateObject private var verificationService = VerificationService()
    
    // MARK: - Sheet States
    @State private var showingPhoneVerification = false
    @State private var showingDocumentVerification = false
    @State private var showingBackgroundCheck = false
    @State private var showingCommunityRating = false
    @State private var showingSafetyIncident = false
    @State private var showingEmergencyAlert = false
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Profile Header
                    profileHeader
                    
                    // Profile Details
                    profileDetails
                    
                    // Verification & Trust Section (F5.1-F5.3)
                    verificationTrustSection
                    
                    // Safety & Emergency Section (F5.3)
                    safetyEmergencySection
                    

                }
            }
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarHidden(true)
            .refreshable {
                await profileViewModel.loadProfile()
            }
        }
        .onAppear {
            Task {
                await profileViewModel.loadProfile()
            }
        }
        .sheet(isPresented: $showingPhoneVerification) {
            PhoneVerificationView(verificationService: verificationService)
        }
        .sheet(isPresented: $showingDocumentVerification) {
            DocumentVerificationView(verificationService: verificationService)
        }
        .sheet(isPresented: $showingBackgroundCheck) {
            BackgroundCheckView(verificationService: verificationService)
        }
        .sheet(isPresented: $showingCommunityRating) {
            CommunityRatingView(verificationService: verificationService)
        }
        .sheet(isPresented: $showingSafetyIncident) {
            SafetyIncidentReportingView(verificationService: verificationService)
        }
        .sheet(isPresented: $showingEmergencyAlert) {
            EmergencyAlertView(verificationService: verificationService)
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 20) {
            // Avatar
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 100, height: 100)
                .overlay {
                    Text(profileViewModel.userProfile.name.prefix(1))
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(.white)
                }
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 3)
                }
            
            // Name and Subtitle
            VStack(spacing: 5) {
                Text(profileViewModel.userProfile.name)
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
                
                Text("Parent of \(profileViewModel.userProfile.childName) • \(profileViewModel.userProfile.schoolName)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Stats Row
            HStack(spacing: 20) {
                ProfileStat(value: String(format: "%.1f", profileViewModel.userProfile.averageRating), label: "⭐ Rating")
                ProfileStat(value: "\(profileViewModel.userProfile.totalTrips)", label: "🚗 Trips")
                ProfileStat(value: verificationService.currentVerificationStatus.displaySymbol, label: "🛡️ Verified")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 40)
        .padding(.bottom, 20)
    }
    
    // MARK: - Profile Details
    private var profileDetails: some View {
        VStack(spacing: 0) {
            // Personal Information Section
            ProfileSection(
                title: "Personal Information",
                items: [
                    ProfileItem(icon: "🚗", label: "Vehicle", value: profileViewModel.userProfile.vehicleInfo),
                    ProfileItem(icon: "🕐", label: "Usual Departure", value: profileViewModel.userProfile.departureTime),
                    ProfileItem(icon: "📍", label: "Address", value: profileViewModel.userProfile.address),
                    ProfileItem(icon: "📞", label: "Contact", value: profileViewModel.userProfile.phone)
                ]
            )
            
            // Safety & Verification Section
            ProfileSection(
                title: "Safety & Verification",
                items: [
                    ProfileItem(icon: "✅", label: "Phone Verified", value: verificationService.hasPhoneVerification ? "Yes" : "Not Verified"),
                    ProfileItem(icon: "🆔", label: "ID Documents", value: verificationService.hasDocumentVerification ? "Verified" : "Not Verified"),
                    ProfileItem(icon: "🛡️", label: "Safety Score", value: "\(String(format: "%.1f", profileViewModel.userProfile.safetyScore))/10 (Excellent)")
                ]
            )
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.top, 20)
    }
    
    // MARK: - Verification & Trust Section (F5.1-F5.3)
    private var verificationTrustSection: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundColor(.blue)
                Text("Verification & Trust")
                    .font(.headline.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Verification Cards
            VStack(spacing: 12) {
                // Phone Verification Card
                VerificationCard(
                    title: "Phone Verification",
                    subtitle: verificationService.hasPhoneVerification ? "Verified" : "Not Verified",
                    icon: "phone.circle.fill",
                    color: verificationService.hasPhoneVerification ? .green : .blue,
                    action: {
                        if !verificationService.hasPhoneVerification {
                            showingPhoneVerification = true
                        }
                    },
                    buttonTitle: verificationService.hasPhoneVerification ? "Verified ✓" : "Verify Now"
                )
                
                // Document Verification Card
                VerificationCard(
                    title: "Document Verification",
                    subtitle: verificationService.hasDocumentVerification ? "Verified" : "Not Verified",
                    icon: "doc.text.fill",
                    color: verificationService.hasDocumentVerification ? .green : .blue,
                    action: {
                        if !verificationService.hasDocumentVerification {
                            showingDocumentVerification = true
                        }
                    },
                    buttonTitle: verificationService.hasDocumentVerification ? "Verified ✓" : "Upload Documents"
                )
                
                // Background Check Card
                VerificationCard(
                    title: "Background Check",
                    subtitle: verificationService.hasBackgroundCheck ? "Completed" : "Premium Feature",
                    icon: "magnifyingglass.circle.fill",
                    color: verificationService.hasBackgroundCheck ? .green : .purple,
                    action: {
                        if !verificationService.hasBackgroundCheck {
                            showingBackgroundCheck = true
                        }
                    },
                    buttonTitle: verificationService.hasBackgroundCheck ? "Completed ✓" : "Request Check"
                )
                
                // Community Rating Card
                VerificationCard(
                    title: "Community Rating",
                    subtitle: "Build Trust",
                    icon: "star.circle.fill",
                    color: .yellow,
                    action: {
                        showingCommunityRating = true
                    },
                    buttonTitle: "Rate Families"
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.top, 20)
    }
    
    // MARK: - Safety & Emergency Section (F5.3)
    private var safetyEmergencySection: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Safety & Emergency")
                    .font(.headline.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Safety Cards
            VStack(spacing: 12) {
                // Safety Incident Reporting Card
                VerificationCard(
                    title: "Safety Incident Report",
                    subtitle: "Report Concerns",
                    icon: "exclamationmark.triangle.fill",
                    color: .orange,
                    action: {
                        showingSafetyIncident = true
                    },
                    buttonTitle: "Report Incident"
                )
                
                // Emergency Alert Card
                VerificationCard(
                    title: "Emergency Alert",
                    subtitle: "Immediate Help",
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    action: {
                        showingEmergencyAlert = true
                    },
                    buttonTitle: "Send Alert"
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.top, 20)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button("⚙️ Settings") {
                // TODO: Navigate to settings
                print("⚙️ Navigate to settings")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            
            Button("✏️ Edit Profile") {
                // TODO: Navigate to edit profile
                print("✏️ Navigate to edit profile")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)
        }
    }
}

// MARK: - Verification Card Component
struct VerificationCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    let buttonTitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action Button
            Button(action: action) {
                Text(buttonTitle)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(color)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Profile Stat Component
struct ProfileStat: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Profile Section Component
struct ProfileSection: View {
    let title: String
    let items: [ProfileItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
                .padding(.top, 20)
            
            ForEach(items) { item in
                ProfileItemRow(item: item)
            }
        }
    }
}

// MARK: - Profile Item Component
struct ProfileItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let value: String
}

// MARK: - Profile Item Row Component
struct ProfileItemRow: View {
    let item: ProfileItem
    
    var body: some View {
        HStack(spacing: 15) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 40, height: 40)
                
                Text(item.icon)
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            
            // Text Content
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                
                Text(item.value)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray5))
                .offset(y: 24),
            alignment: .bottom
        )
    }
}

// MARK: - Profile View Model
class ProfileViewModel: ObservableObject {
    @Published var userProfile = UserProfile()
    
    func loadProfile() async {
        // TODO: Implement actual data loading from services
        await MainActor.run {
            // Mock data for now
            self.userProfile = UserProfile(
                name: "Sarah Johnson",
                childName: "Emma",
                schoolName: "Canberra Primary School",
                averageRating: 4.8,
                totalTrips: 47,
                verificationStatus: .verified,
                vehicleInfo: "Honda CR-V (4 seats)",
                departureTime: "8:15 AM (±10 minutes)",
                address: "15 Marcus Clarke St, Canberra",
                phone: "0412 345 678",
                phoneVerificationDate: "Confirmed on Dec 15, 2024",
                idVerificationStatus: "Driver's license verified",
                safetyScore: 9.1
            )
        }
    }
}

// MARK: - Data Models
struct UserProfile {
    var name: String = ""
    var childName: String = ""
    var schoolName: String = ""
    var averageRating: Double = 0.0
    var totalTrips: Int = 0
    var verificationStatus: VerificationStatus = .unverified
    var vehicleInfo: String = ""
    var departureTime: String = ""
    var address: String = ""
    var phone: String = ""
    var phoneVerificationDate: String = ""
    var idVerificationStatus: String = ""
    var safetyScore: Double = 0.0
}

enum VerificationStatus: String, CaseIterable, Codable {
    case unverified = "unverified"
    case phoneVerified = "phone_verified"
    case documentsVerified = "documents_verified"
    case verified = "verified"
    
    var displaySymbol: String {
        switch self {
        case .unverified: return "❓"
        case .phoneVerified: return "📱"
        case .documentsVerified: return "🆔"
        case .verified: return "✓"
        }
    }
    
    var displayName: String {
        switch self {
        case .unverified: return "Unverified"
        case .phoneVerified: return "Phone Verified"
        case .documentsVerified: return "Documents Verified"
        case .verified: return "Fully Verified"
        }
    }
}

// MARK: - Preview
#Preview {
    ProfileView()
}
