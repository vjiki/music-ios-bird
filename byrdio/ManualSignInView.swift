//
//  ManualSignInView.swift
//  music
//
//  Created by Nikolai Golubkin on 11/11/25.
//

import SwiftUI

struct ManualSignInView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    let onSignInSuccess: (() -> Void)?
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var showError = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?
    
    init(onSignInSuccess: (() -> Void)? = nil) {
        self.onSignInSuccess = onSignInSuccess
    }
    
    enum Field {
        case email
        case password
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Sign in with Email")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text("Enter your email and password to continue")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 32)
                    
                    // Email field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        TextField("Enter your email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .foregroundStyle(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    
                    // Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        SecureField("Enter your password", text: $password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .foregroundStyle(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    
                    // Sign in button
                    Button {
                        Task {
                            await signIn()
                        }
                    } label: {
                        HStack {
                            if isSigningIn {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign In")
                                    .font(.body)
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            email.isEmpty || password.isEmpty || isSigningIn
                            ? Color.white.opacity(0.2)
                            : Color.blue
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .disabled(email.isEmpty || password.isEmpty || isSigningIn)
                    .padding(.top, 8)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(.white)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Sign In")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .alert("Sign In Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private func signIn() async {
        focusedField = nil
        isSigningIn = true
        
        do {
            try await authService.signInWithEmail(email: email, password: password)
            await MainActor.run {
                isSigningIn = false
                // Dismiss the manual sign-in view
                dismiss()
                // Call the success callback to dismiss parent LoginView
                onSignInSuccess?()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isSigningIn = false
            }
        }
    }
}

#Preview {
    ManualSignInView()
        .preferredColorScheme(.dark)
        .environmentObject(AuthService())
}

