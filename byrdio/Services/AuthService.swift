//
//  AuthService.swift
//  music
//
//  Created by Nikolai Golubkin on 11/9/25.
//

import Foundation
import SwiftUI
import UIKit
import AuthenticationServices
import GoogleSignIn
import FirebaseAuth

// MARK: - User Model
struct User {
    let id: String
    let email: String?
    let name: String?
    let nickname: String?
    let avatarUrl: String?
    let provider: AuthProvider
}

// MARK: - API Response Models
struct AuthResponse: Codable {
    let authenticated: Bool
    let userId: String
    let message: String
}

struct UserResponse: Codable {
    let id: String
    let email: String
    let nickname: String?
    let avatarUrl: String?
    let accessLevel: String?
    let isActive: Bool
    let isVerified: Bool
    let lastLoginAt: String?
    let createdAt: String
}

struct AuthRequest: Codable {
    let email: String
    let password: String
}

struct UserExistsResponse: Codable {
    let exists: Bool
    let userId: String?
}

struct RegisterRequest: Codable {
    let email: String
    let nickname: String?
    let avatarUrl: String?
    let provider: String
}

struct RegisterResponse: Codable {
    let authenticated: Bool
    let userId: String
    let message: String
}

enum AuthProvider: String, Codable {
    case guest
    case google
    case apple
    case email
}

// MARK: - Protocol (Interface Segregation)
protocol AuthServiceProtocol: ObservableObject {
    var currentUser: User? { get }
    var isAuthenticated: Bool { get }
    
    func signInWithGoogle() async throws
    func signInWithApple(authorization: ASAuthorizationAppleIDCredential) async throws
    func signInWithEmail(email: String, password: String) async throws
    func signOut() async
}

// MARK: - Implementation (Single Responsibility: Authentication)
class AuthService: ObservableObject, AuthServiceProtocol {
    @Published private(set) var currentUser: User?
    @Published private(set) var isAuthenticated: Bool = false
    @Published var shouldNavigateToProfile: Bool = false
    
    private let userDefaultsKey = "current_user"
    
    init() {
        loadUser()
    }
    
    var effectiveUser: User {
        if let user = currentUser, user.provider != .guest {
            return user
        }
        // Return guest user by default
        return User(
            id: "3762deba-87a9-482e-b716-2111232148ca",
            email: "guest@example.com",
            name: "Guest",
            nickname: "Guest",
            avatarUrl: nil,
            provider: .guest
        )
    }
    
    // Get current user ID, defaulting to guest user if not logged in
    var currentUserId: String {
        currentUser?.id ?? "3762deba-87a9-482e-b716-2111232148ca"
    }
    
    // Base API URL - same as SongsService
    private var baseURL: String {
        return "https://music-back-g2u6.onrender.com"
    }
    
    func signInWithGoogle() async throws {
        guard let clientID = getGoogleClientID() else {
            throw AuthError.missingGoogleClientID
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Get the root view controller - try multiple approaches
        let rootViewController = await MainActor.run { () -> UIViewController? in
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    for window in windowScene.windows {
                        if window.isKeyWindow {
                            return window.rootViewController
                        }
                    }
                    // If no key window, try first window
                    if let firstWindow = windowScene.windows.first {
                        return firstWindow.rootViewController
                    }
                }
            }
            return nil
        }
        
        guard let presentingViewController = rootViewController else {
            throw AuthError.noPresentingViewController
        }
        
        // Sign in with Google using GoogleSignIn SDK
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
        
        // Extract tokens from Google Sign-In result
        // `idToken` is optional; `accessToken` is non-optional in recent GoogleSignIn versions
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.googleSignInFailed
        }
        let accessToken = result.user.accessToken.tokenString
        
        // Create Firebase credential with the Google ID token and access token
        let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                       accessToken: accessToken)
        
        // Sign in to Firebase with the Google credential
        // This will create a user in Firebase Auth if they don't exist
        let authResult: AuthDataResult
        do {
            authResult = try await Auth.auth().signIn(with: credential)
        } catch {
            // If Firebase sign-in fails, provide a more helpful error message
            print("⚠️ Firebase Auth sign-in failed: \(error.localizedDescription)")
            let nsError = error as NSError
            if nsError.domain == "FIRAuthErrorDomain" {
                throw AuthError.firebaseAuthFailed("Firebase authentication failed: \(error.localizedDescription)")
            }
            throw AuthError.firebaseAuthFailed("Unable to sign in with Firebase: \(error.localizedDescription)")
        }
        
        let firebaseUser = authResult.user
        
        // Get user profile from Google Sign-In result
        let profile = result.user.profile
        
        // Get user email (required for backend check)
        guard let userEmail = firebaseUser.email ?? profile?.email else {
            throw AuthError.googleSignInFailed
        }
        
        // Get user display name and avatar
        let displayName = firebaseUser.displayName ?? profile?.name
        let avatarUrl = firebaseUser.photoURL?.absoluteString ?? profile?.imageURL(withDimension: 200)?.absoluteString
        
        // Check if user exists on backend with GOOGLE provider
        let backendUserId: String?
        do {
            backendUserId = try await checkUserExists(email: userEmail, provider: "GOOGLE")
        } catch {
            print("⚠️ Failed to check if user exists: \(error.localizedDescription)")
            // Continue with registration if check fails
            backendUserId = nil
        }
        
        // If user doesn't exist, register them
        let finalUserId: String
        if let userId = backendUserId {
            // User exists, use the backend userId
            print("✅ User exists on backend with ID: \(userId)")
            finalUserId = userId
        } else {
            // Register new user on backend with GOOGLE provider
            print("📝 Registering new user on backend with GOOGLE provider...")
            do {
                finalUserId = try await registerUser(
                    email: userEmail,
                    nickname: displayName,
                    avatarUrl: avatarUrl,
                    provider: "GOOGLE"
                )
                print("✅ User registered successfully with ID: \(finalUserId)")
            } catch {
                print("❌ Failed to register user: \(error.localizedDescription)")
                throw AuthError.registrationFailed(error.localizedDescription)
            }
        }
        
        // Create user model with backend userId
        let authUser = User(
            id: finalUserId,
            email: userEmail,
            name: displayName,
            nickname: displayName,
            avatarUrl: avatarUrl,
            provider: .google
        )
        
        await MainActor.run {
            self.currentUser = authUser
            self.isAuthenticated = true
            saveUser(authUser)
        }
    }
    
    private func getGoogleClientID() -> String? {
        // Try to get from GoogleService-Info.plist
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let clientID = plist["CLIENT_ID"] as? String {
            return clientID
        }
        
        // Fallback: return nil (user needs to configure)
        return nil
    }
    
    // MARK: - Backend User Management
    
    /// Check if a user exists on the backend by email and provider
    private func checkUserExists(email: String, provider: String) async throws -> String? {
        guard let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedProvider = provider.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw AuthError.invalidEmail
        }
        
        let url = URL(string: "\(baseURL)/api/v1/auth/exists?email=\(encodedEmail)&provider=\(encodedProvider)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.authenticationFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.authenticationFailed
        }
        
        let decoder = JSONDecoder()
        let existsResponse = try decoder.decode(UserExistsResponse.self, from: data)
        
        // Return userId if user exists and userId is not nil
        if existsResponse.exists, let userId = existsResponse.userId {
            return userId
        }
        
        // User doesn't exist or userId is missing
        return nil
    }
    
    /// Register a new user on the backend
    private func registerUser(email: String, nickname: String?, avatarUrl: String?, provider: String) async throws -> String {
        let url = URL(string: "\(baseURL)/api/v1/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let registerRequest = RegisterRequest(
            email: email,
            nickname: nickname,
            avatarUrl: avatarUrl,
            provider: provider
        )
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(registerRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.authenticationFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.authenticationFailed
        }
        
        let decoder = JSONDecoder()
        let registerResponse = try decoder.decode(RegisterResponse.self, from: data)
        
        guard registerResponse.authenticated else {
            throw AuthError.authenticationFailed
        }
        
        return registerResponse.userId
    }
    
    func signInWithApple(authorization: ASAuthorizationAppleIDCredential) async throws {
        let user = User(
            id: authorization.user,
            email: authorization.email,
            name: authorization.fullName?.givenName,
            nickname: authorization.fullName?.givenName,
            avatarUrl: nil,
            provider: .apple
        )
        
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
            saveUser(user)
        }
    }
    
    func signInWithEmail(email: String, password: String) async throws {
        // Basic validation
        guard !email.isEmpty, !password.isEmpty else {
            throw AuthError.invalidCredentials
        }
        
        // Basic email validation
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        guard emailPredicate.evaluate(with: email) else {
            throw AuthError.invalidEmail
        }
        
        // Step 1: Authenticate with email and password
        let authURL = URL(string: "\(baseURL)/api/v1/auth/authenticate")!
        var request = URLRequest(url: authURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let authRequest = AuthRequest(email: email, password: password)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(authRequest)
        
        let (authData, authResponse) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = authResponse as? HTTPURLResponse else {
            throw AuthError.authenticationFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw AuthError.invalidCredentials
            }
            throw AuthError.authenticationFailed
        }
        
        let decoder = JSONDecoder()
        let authResult = try decoder.decode(AuthResponse.self, from: authData)
        
        guard authResult.authenticated else {
            throw AuthError.authenticationFailed
        }
        
        // Step 2: Get user information
        let userURL = URL(string: "\(baseURL)/api/v1/users/\(authResult.userId)")!
        var userRequest = URLRequest(url: userURL)
        userRequest.httpMethod = "GET"
        
        let (userData, userResponse) = try await URLSession.shared.data(for: userRequest)
        
        guard let userHttpResponse = userResponse as? HTTPURLResponse,
              (200...299).contains(userHttpResponse.statusCode) else {
            throw AuthError.userInfoFailed
        }
        
        let userResult = try decoder.decode(UserResponse.self, from: userData)
        
        // Create user from API response
        let authUser = User(
            id: userResult.id,
            email: userResult.email,
            name: userResult.nickname ?? userResult.email.components(separatedBy: "@").first,
            nickname: userResult.nickname,
            avatarUrl: userResult.avatarUrl,
            provider: .email
        )
        
        await MainActor.run {
            self.currentUser = authUser
            self.isAuthenticated = true
            self.shouldNavigateToProfile = true
            saveUser(authUser)
        }
    }
    
    func signOut() async {
        // Sign out from Firebase
        do {
            try Auth.auth().signOut()
        } catch {
            // Log error but continue with local sign out
            print("Firebase sign out error: \(error.localizedDescription)")
        }
        
        // Sign out from Google if signed in with Google
        if currentUser?.provider == .google {
            GIDSignIn.sharedInstance.signOut()
        }
        
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
            self.shouldNavigateToProfile = false
            clearUser()
        }
    }
    
    private func saveUser(_ user: User) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(user) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    private func loadUser() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let user = try? JSONDecoder().decode(User.self, from: data),
              user.provider != .guest else {
            // Default to guest user
            currentUser = nil
            isAuthenticated = false
            return
        }
        
        currentUser = user
        isAuthenticated = true
    }
    
    private func clearUser() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case noPresentingViewController
    case missingGoogleClientID
    case googleSignInFailed
    case firebaseAuthFailed(String)
    case invalidCredentials
    case invalidEmail
    case weakPassword
    case authenticationFailed
    case userInfoFailed
    case registrationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noPresentingViewController:
            return "No presenting view controller available"
        case .missingGoogleClientID:
            return "Google Client ID is missing. Please configure GoogleService-Info.plist"
        case .googleSignInFailed:
            return "Google Sign-In failed"
        case .firebaseAuthFailed(let message):
            return "Firebase authentication failed: \(message)"
        case .invalidCredentials:
            return "Invalid email or password"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .weakPassword:
            return "Password must be at least 6 characters long"
        case .authenticationFailed:
            return "Authentication failed. Please check your credentials and try again."
        case .userInfoFailed:
            return "Failed to retrieve user information. Please try again."
        case .registrationFailed(let message):
            return "Failed to register user: \(message)"
        }
    }
}

// MARK: - User Codable Extension
extension User: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case nickname
        case avatarUrl
        case provider
    }
}

