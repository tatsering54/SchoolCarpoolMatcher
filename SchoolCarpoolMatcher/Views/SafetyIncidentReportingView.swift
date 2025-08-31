//
//  SafetyIncidentReportingView.swift
//  SchoolCarpoolMatcher
//
//  Safety incident reporting interface
//  Implements F5.3 requirements: safety incident reporting with evidence
//

import SwiftUI
import PhotosUI

struct SafetyIncidentReportingView: View {
    @ObservedObject var verificationService: VerificationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedIncidentType: IncidentReport.IncidentType = .safetyConcern
    @State private var incidentDescription = ""
    @State private var selectedSeverity: IncidentReport.IncidentSeverity = .moderate
    @State private var isAnonymous = false
    @State private var selectedImage: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var errorMessage = ""
    @State private var isSuccess = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("Safety Incident Report")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.primary)
                        
                        Text("Report safety concerns to help keep our community safe")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Incident Type Selection
                    incidentTypeSelection
                    
                    // Incident Details
                    incidentDetails
                    
                    // Media Evidence
                    mediaEvidence
                    
                    // Anonymous Option
                    anonymousOption
                    
                    Spacer()
                    
                    // Submit Button
                    submitButton
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Safety Incident")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Reporting Error", isPresented: .constant(!errorMessage.isEmpty)) {
                Button("OK") {
                    errorMessage = ""
                }
            } message: {
                Text(errorMessage)
            }
            .alert("Incident Reported", isPresented: $isSuccess) {
                Button("Continue") {
                    dismiss()
                }
            } message: {
                Text("Your safety incident has been reported successfully!")
            }
        }
    }
    
    // MARK: - Incident Type Selection
    private var incidentTypeSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Incident Type")
                .font(.headline)
                .foregroundColor(.primary)
            
            Picker("Incident Type", selection: $selectedIncidentType) {
                ForEach(IncidentReport.IncidentType.allCases, id: \.self) { type in
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
    
    // MARK: - Incident Details
    private var incidentDetails: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("Describe what happened...", text: $incidentDescription, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Severity Level")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Picker("Severity", selection: $selectedSeverity) {
                    ForEach(IncidentReport.IncidentSeverity.allCases, id: \.self) { severity in
                        HStack {
                            Text(severity.displayName)
                            Spacer()
                            Text(severity.color == .red ? "🔴" : 
                                 severity.color == .orange ? "🟠" : 
                                 severity.color == .yellow ? "🟡" : "⚪")
                        }
                        .tag(severity)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
    
    // MARK: - Media Evidence
    private var mediaEvidence: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Media Evidence (Optional)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .cornerRadius(12)
                        .overlay(
                            Button("Remove") {
                                self.imageData = nil
                                self.selectedImage = nil
                            }
                            .padding(8)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(8),
                            alignment: .topTrailing
                        )
                } else {
                    PhotosPicker(selection: $selectedImage, matching: .images) {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                            
                            Text("Tap to add photo evidence")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [5]))
                        )
                    }
                    .onChange(of: selectedImage) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                await MainActor.run {
                                    self.imageData = data
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Anonymous Option
    private var anonymousOption: some View {
        HStack {
            Toggle("Submit Anonymously", isOn: $isAnonymous)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            if isAnonymous {
                Image(systemName: "eye.slash.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Submit Button
    private var submitButton: some View {
        Button(action: submitIncident) {
            HStack {
                if verificationService.isVerifying {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "paperplane.fill")
                }
                
                Text("Submit Report")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(12)
            .font(.headline)
        }
        .disabled(verificationService.isVerifying || incidentDescription.isEmpty)
        .opacity(verificationService.isVerifying || incidentDescription.isEmpty ? 0.6 : 1.0)
    }
    
    // MARK: - Actions
    private func submitIncident() {
        let incident = IncidentReport(
            id: UUID(),
            incidentType: selectedIncidentType,
            location: LocationData(
                latitude: 0.0, // Would get from location service
                longitude: 0.0,
                address: nil,
                description: nil
            ),
            description: incidentDescription,
            involvedFamilyIds: nil,
            mediaEvidence: imageData != nil ? [
                MediaEvidence(
                    id: UUID(),
                    type: .photo,
                    url: "",
                    thumbnailUrl: nil,
                    timestamp: Date(),
                    description: "Incident evidence"
                )
            ] : nil,
            timestamp: Date(),
            severity: selectedSeverity,
            isAnonymous: isAnonymous,
            reporterId: nil,
            status: .reported
        )
        
        Task {
            let success = await verificationService.reportIncident(incident)
            
            await MainActor.run {
                if success {
                    isSuccess = true
                } else {
                    errorMessage = "Failed to submit incident report. Please try again."
                }
            }
        }
    }
}
