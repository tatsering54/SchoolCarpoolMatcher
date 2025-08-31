import SwiftUI

struct PhoneVerificationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var verificationService: VerificationService
    
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var isShowingCodeInput = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var verificationId: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 15) {
                    Image(systemName: "phone.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Phone Verification")
                        .font(.title2.weight(.bold))
                    
                    Text("Verify your phone number to build trust in the community")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                if !isShowingCodeInput {
                    // Phone Number Input
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Phone Number")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("+61 400 000 000", text: $phoneNumber)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.phonePad)
                        }
                        
                        Button(action: sendVerificationCode) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                }
                                Text("Send Verification Code")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(phoneNumber.isEmpty || isLoading)
                    }
                    .padding(.horizontal, 20)
                } else {
                    // Verification Code Input
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Verification Code")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Enter the 6-digit code sent to \(phoneNumber)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("123456", text: $verificationCode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                        }
                        
                        Button(action: verifyCode) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text("Verify Code")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(verificationCode.isEmpty || isLoading)
                        
                        Button("Resend Code") {
                            sendVerificationCode()
                        }
                        .foregroundColor(.blue)
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 20)
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            .navigationTitle("Phone Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func sendVerificationCode() {
        guard !phoneNumber.isEmpty else { return }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let result = try await verificationService.initiatePhoneVerification(phoneNumber: phoneNumber)
                await MainActor.run {
                    isLoading = false
                    if result.success {
                        verificationId = result.verificationId ?? ""
                        isShowingCodeInput = true
                    } else {
                        errorMessage = result.errorMessage ?? "Failed to send verification code"
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func verifyCode() {
        guard !verificationCode.isEmpty else { return }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let result = try await verificationService.confirmPhoneVerification(
                    verificationId: verificationId,
                    code: verificationCode
                )
                await MainActor.run {
                    isLoading = false
                    if result.success {
                        // Success - dismiss the view
                        dismiss()
                    } else {
                        errorMessage = result.errorMessage ?? "Verification failed"
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    PhoneVerificationView(verificationService: VerificationService())
}
