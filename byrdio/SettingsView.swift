//
//  SettingsView.swift
//  music
//
//  Created by Nikolai Golubkin on 11/9/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var songManager: SongManager
    @EnvironmentObject var authService: AuthService
    
    @State private var searchText = ""
    @State private var showLoginView = false
    @State private var showLogoutConfirmation = false
    @State private var isLoggingOut = false
    @State private var showDataAndStorage = false
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Search bar
                    searchBar
                    
                    // Your app and media section (only Data and Storage is implemented)
                    yourAppAndMediaSection
                    
                    // Login section
                    loginSection
                }
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
                    Text("Settings and activity")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.6))
            
            TextField("Search", text: $searchText)
                .foregroundStyle(.white)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
    
    // MARK: - Your App and Media Section
    private var yourAppAndMediaSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Your app and media")
            
            // Data and Storage row with green icon
            Button {
                showDataAndStorage = true
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(.green)
                        .frame(width: 24, height: 24)
                    
                    Text("Data and Storage")
                        .font(.body)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Login Section
    private var loginSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Login")
            
            if authService.isAuthenticated {
                // User is logged in - show user info and logout button
                if let user = authService.currentUser {
                    // User info section
                    HStack(spacing: 12) {
                        if let avatarUrl = user.avatarUrl, !avatarUrl.isEmpty {
                            AsyncImage(url: URL(string: avatarUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                ProgressView()
                                    .tint(.white.opacity(0.6))
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.nickname ?? user.name ?? "User")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            
                            if let email = user.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                
                // Logout button
                Button {
                    showLogoutConfirmation = true
                } label: {
                    HStack {
                        if isLoggingOut {
                            ProgressView()
                                .tint(.red)
                        } else {
                            Text("Log out")
                                .font(.body)
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .disabled(isLoggingOut)
            } else {
                // User is not logged in - show add account button
                Button {
                    showLoginView = true
                } label: {
                    Text("Add account")
                        .font(.body)
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
        }
        .sheet(isPresented: $showLoginView) {
            LoginView()
                .environmentObject(authService)
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            // Dismiss SettingsView when authentication succeeds
            if isAuthenticated {
                showLoginView = false
            }
        }
        .sheet(isPresented: $showDataAndStorage) {
            DataAndStorageView()
                .environmentObject(songManager)
        }
        .confirmationDialog("Log Out", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
            Button("Log Out", role: .destructive) {
                Task {
                    isLoggingOut = true
                    await authService.signOut()
                    isLoggingOut = false
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to log out?")
        }
    }
}

// MARK: - Section Header
private struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }
}

// MARK: - Settings Row
private struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let trailingView: AnyView?
    
    init(
        icon: String,
        title: String,
        subtitle: String? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.trailingView = nil
    }
    
    init<Trailing: View>(
        icon: String,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.trailingView = AnyView(trailing())
    }
    
    var body: some View {
        Button {
            // Action
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.white)
                    
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                if let trailingView {
                    trailingView
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
        .environmentObject(SongManager())
        .environmentObject(AuthService())
}

