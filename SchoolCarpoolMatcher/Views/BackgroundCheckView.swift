//
//  BackgroundCheckView.swift
//  SchoolCarpoolMatcher
//
//  Background check interface for premium verification
//  Implements F5.1 requirements: background check integration (optional premium feature)
//

import SwiftUI

struct BackgroundCheckView: View {
    @ObservedObject var verificationService: VerificationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCheckType: BackgroundCheckRequest.BackgroundCheckType = .basic
    @State private var showingCheckDetails = false
    @State private var errorMessage = ""
    @State private var isSuccess = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                    
                    Text("Background Check")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.primary)
                    
                    Text("Enhanced verification for maximum trust and safety")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Check Type Selection
                checkTypeSelection
                
                // Check Details
                checkDetails
                
                Spacer()
                
                // Request Button
                requestButton
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .navigationTitle("Background Check")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Check Error", isPresented: .constant(!errorMessage.isEmpty)) {
                Button("OK") {
                    errorMessage = ""
                }
            } message: {
                Text(errorMessage)
            }
            .alert("Check Requested", isPresented: $isSuccess) {
                Button("Continue") {
                    dismiss()
                }
            } message: {
                Text("Your background check request has been submitted!")
            }
        }
    }
    
    // MARK: - Check Type Selection
    private var checkTypeSelection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Check Type")
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)
            
            ForEach(BackgroundCheckRequest.BackgroundCheckType.allCases, id: \.self) { type in
                CheckTypeCard(
                    type: type,
                    isSelected: selectedCheckType == type,
                    onTap: { selectedCheckType = type }
                )
            }
        }
    }
    
    // MARK: - Check Details
    private var checkDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's Included")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(selectedCheckType.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Estimated Cost:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("$\(String(format: "%.2f", selectedCheckType.estimatedCost))")
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Request Button
    private var requestButton: some View {
        Button(action: requestBackgroundCheck) {
            HStack {
                if verificationService.isVerifying {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }
                
                Text("Request Background Check")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(12)
            .font(.headline)
        }
        .disabled(verificationService.isVerifying)
        .opacity(verificationService.isVerifying ? 0.6 : 1.0)
    }
    
    // MARK: - Actions
    private func requestBackgroundCheck() {
        Task {
            let result = await verificationService.requestBackgroundCheck(type: selectedCheckType)
            
            await MainActor.run {
                if result.status != .failed {
                    isSuccess = true
                } else {
                    errorMessage = "Background check request failed. Please try again."
                }
            }
        }
    }
}

// MARK: - Check Type Card
struct CheckTypeCard: View {
    let type: BackgroundCheckRequest.BackgroundCheckType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("$\(String(format: "%.2f", type.estimatedCost))")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
