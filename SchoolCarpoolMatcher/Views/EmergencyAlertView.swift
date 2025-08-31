//
//  EmergencyAlertView.swift
//  SchoolCarpoolMatcher
//
//  Emergency alert interface for immediate help
//  Implements F5.3 requirements: emergency button for immediate help
//

import SwiftUI

struct EmergencyAlertView: View {
    @ObservedObject var verificationService: VerificationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedEmergencyType: EmergencyAlert.EmergencyType = .safety
    @State private var emergencyDescription = ""
    @State private var selectedSeverity: EmergencyAlert.EmergencySeverity = .urgent
    @State private var contactEmergencyServices = true
    @State private var errorMessage = ""
    @State private var isSuccess = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Emergency Header
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("Emergency Alert")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.red)
                    
                    Text("Send immediate alert to group members and emergency services")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Emergency Type Selection
                emergencyTypeSelection
                
                // Emergency Details
                emergencyDetails
                
                // Emergency Services Option
                emergencyServicesOption
                
                Spacer()
                
                // Send Alert Button
                sendAlertButton
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .navigationTitle("Emergency Alert")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Alert Error", isPresented: .constant(!errorMessage.isEmpty)) {
                Button("OK") {
                    errorMessage = ""
                }
            } message: {
                Text(errorMessage)
            }
            .alert("Emergency Alert Sent", isPresented: $isSuccess) {
                Button("Continue") {
                    dismiss()
                }
            } message: {
                Text("Your emergency alert has been sent successfully!")
            }
        }
    }
    
    // MARK: - Emergency Type Selection
    private var emergencyTypeSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Emergency Type")
                .font(.headline)
                .foregroundColor(.primary)
            
            Picker("Emergency Type", selection: $selectedEmergencyType) {
                ForEach(EmergencyAlert.EmergencyType.allCases, id: \.self) { type in
                    HStack {
                        Text(type.icon)
                        Text(type.displayName)
                    }
                    .tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    // MARK: - Emergency Details
    private var emergencyDetails: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("Describe the emergency...", text: $emergencyDescription, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Severity Level")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Picker("Severity", selection: $selectedSeverity) {
                    ForEach(EmergencyAlert.EmergencySeverity.allCases, id: \.self) { severity in
                        HStack {
                            Text(severity.displayName)
                            Spacer()
                            Text(severity.color == .red ? "🔴" : 
                                 severity.color == .orange ? "🟠" : 
                                 severity.color == .yellow ? "🟡" : "🔵")
                        }
                        .tag(severity)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
    
    // MARK: - Emergency Services Option
    private var emergencyServicesOption: some View {
        HStack {
            Toggle("Contact Emergency Services (000)", isOn: $contactEmergencyServices)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            if contactEmergencyServices {
                Image(systemName: "phone.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Send Alert Button
    private var sendAlertButton: some View {
        Button(action: sendEmergencyAlert) {
            HStack {
                if verificationService.isVerifying {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                
                Text("Send Emergency Alert")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(12)
            .font(.headline)
        }
        .disabled(verificationService.isVerifying || emergencyDescription.isEmpty)
        .opacity(verificationService.isVerifying || emergencyDescription.isEmpty ? 0.6 : 1.0)
    }
    
    // MARK: - Actions
    private func sendEmergencyAlert() {
        let alert = EmergencyAlert(
            id: UUID(),
            alertType: selectedEmergencyType,
            location: LocationData(
                latitude: 0.0, // Would get from location service
                longitude: 0.0,
                address: nil,
                description: nil
            ),
            description: emergencyDescription,
            contactEmergencyServices: contactEmergencyServices,
            severity: selectedSeverity,
            timestamp: Date(),
            status: .active,
            groupId: nil
        )
        
        Task {
            let success = await verificationService.sendEmergencyAlert(alert)
            
            await MainActor.run {
                if success {
                    isSuccess = true
                } else {
                    errorMessage = "Failed to send emergency alert. Please try again."
                }
            }
        }
    }
}
