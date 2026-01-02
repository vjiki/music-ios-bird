//
//  LoginView.swift
//  music
//
//  Created by Nikolai Golubkin on 11/11/25.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    @State private var showManualSignIn = false
    @State private var showAppleSignInError = false
    @State private var appleSignInError: String?
    @State private var showGoogleSignInError = false
    @State private var googleSignInError: String?
    @State private var isSigningInWithGoogle = false
    @State private var isSigningInWithApple = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Sign in to Music")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text("Choose how you want to sign in")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 32)
                    
                    // Apple Sign-In Button
                    if isSigningInWithApple {
                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                            Text("Continue with Apple")
                                .font(.body)
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        SignInWithAppleButton(
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            },
                            onCompletion: { result in
                                switch result {
                                case .success(let authorization):
                                    if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                        Task { @MainActor in
                                            isSigningInWithApple = true
                                            do {
                                                try await authService.signInWithApple(authorization: appleIDCredential)
                                                isSigningInWithApple = false
                                                dismiss()
                                            } catch {
                                                appleSignInError = error.localizedDescription
                                                showAppleSignInError = true
                                                isSigningInWithApple = false
                                            }
                                        }
                                    }
                                case .failure(let error):
                                    Task { @MainActor in
                                        let nsError = error as NSError
                                        let errorCode = nsError.code
                                        
                                        // Don't show error for user cancellation
                                        if errorCode != ASAuthorizationError.canceled.rawValue {
                                            var errorMessage = error.localizedDescription
                                            
                                            if errorCode == 1000 {
                                                errorMessage = "Sign in with Apple is not properly configured. Please ensure:\n1. 'Sign in with Apple' capability is enabled in Xcode\n2. Your Bundle ID is registered in Apple Developer Portal\n3. You're running on a device or simulator with a valid Apple ID"
                                            }
                                            
                                            appleSignInError = errorMessage
                                            showAppleSignInError = true
                                        }
                                        isSigningInWithApple = false
                                    }
                                }
                            }
                        )
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .disabled(isSigningInWithGoogle || isSigningInWithApple)
                    }
                    
                    // Google Sign-In Button
                    Button {
                        guard !isSigningInWithGoogle && !isSigningInWithApple else { return }
                        isSigningInWithGoogle = true
                        Task {
                            do {
                                try await authService.signInWithGoogle()
                                await MainActor.run {
                                    isSigningInWithGoogle = false
                                    dismiss()
                                }
                            } catch {
                                await MainActor.run {
                                    googleSignInError = error.localizedDescription
                                    showGoogleSignInError = true
                                    isSigningInWithGoogle = false
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if isSigningInWithGoogle {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "globe")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                            }
                            
                            Text("Continue with Google")
                                .font(.body)
                                .foregroundStyle(.white)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .disabled(isSigningInWithGoogle || isSigningInWithApple)
                    
                    // Manual Sign-In Button
                    Button {
                        showManualSignIn = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                            
                            Text("Sign in with Email")
                                .font(.body)
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .disabled(isSigningInWithGoogle || isSigningInWithApple)
                    
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
            .sheet(isPresented: $showManualSignIn) {
                ManualSignInView(onSignInSuccess: {
                    // Dismiss both ManualSignInView and LoginView when sign-in succeeds
                    showManualSignIn = false
                    dismiss()
                })
                .environmentObject(authService)
            }
            .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
                // Dismiss LoginView when authentication succeeds
                if isAuthenticated {
                    dismiss()
                }
            }
            .alert("Sign In Error", isPresented: $showAppleSignInError) {
                Button("OK", role: .cancel) {
                    isSigningInWithApple = false
                }
            } message: {
                if let error = appleSignInError {
                    Text(error)
                }
            }
            .alert("Google Sign-In Error", isPresented: $showGoogleSignInError) {
                Button("OK", role: .cancel) {
                    isSigningInWithGoogle = false
                }
            } message: {
                if let error = googleSignInError {
                    Text(error)
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .preferredColorScheme(.dark)
        .environmentObject(AuthService())
}

