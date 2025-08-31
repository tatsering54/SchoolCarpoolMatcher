//
//  DocumentVerificationView.swift
//  SchoolCarpoolMatcher
//
//  Document verification interface for identity documents
//  Implements F5.1 requirements: optional identity document upload
//

import SwiftUI
import PhotosUI

struct DocumentVerificationView: View {
    @ObservedObject var verificationService: VerificationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDocumentType: DocumentVerificationRequest.DocumentType = .driversLicense
    @State private var documentNumber = ""
    @State private var expiryDate = Date()
    @State private var selectedImage: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var showingImagePicker = false
    @State private var errorMessage = ""
    @State private var isSuccess = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Document Verification")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.primary)
                        
                        Text("Upload identity documents to enhance your verification status")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Document Type Selection
                    documentTypeSelection
                    
                    // Document Details
                    documentDetails
                    
                    // Image Upload
                    imageUpload
                    
                    Spacer()
                    
                    // Submit Button
                    submitButton
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Document Verification")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Verification Error", isPresented: .constant(!errorMessage.isEmpty)) {
                Button("OK") {
                    errorMessage = ""
                }
            } message: {
                Text(errorMessage)
            }
            .alert("Document Submitted", isPresented: $isSuccess) {
                Button("Continue") {
                    dismiss()
                }
            } message: {
                Text("Your document has been submitted for verification!")
            }
        }
    }
    
    // MARK: - Document Type Selection
    private var documentTypeSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Document Type")
                .font(.headline)
                .foregroundColor(.primary)
            
            Picker("Document Type", selection: $selectedDocumentType) {
                ForEach(DocumentVerificationRequest.DocumentType.allCases, id: \.self) { type in
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
    
    // MARK: - Document Details
    private var documentDetails: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Document Number")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("Enter document number", text: $documentNumber)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Expiry Date (Optional)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
        }
    }
    
    // MARK: - Image Upload
    private var imageUpload: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Document Image")
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
                            
                            Text("Tap to select document image")
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
            
            Text("Upload a clear image of your \(selectedDocumentType.displayName.lowercased())")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Submit Button
    private var submitButton: some View {
        Button(action: submitDocument) {
            HStack {
                if verificationService.isVerifying {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "paperplane.fill")
                }
                
                Text("Submit Document")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(12)
            .font(.headline)
        }
        .disabled(verificationService.isVerifying || documentNumber.isEmpty)
        .opacity(verificationService.isVerifying || documentNumber.isEmpty ? 0.6 : 1.0)
    }
    
    // MARK: - Actions
    private func submitDocument() {
        Task {
            let result = await verificationService.uploadDocument(
                type: selectedDocumentType,
                documentNumber: documentNumber,
                imageData: imageData,
                expiryDate: expiryDate
            )
            
            await MainActor.run {
                if result.verificationStatus != .rejected {
                    isSuccess = true
                } else {
                    errorMessage = "Document verification failed. Please try again."
                }
            }
        }
    }
}
