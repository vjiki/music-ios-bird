//
//  ProfileView.swift
//  music
//
//  Created by Nikolai Golubkin on 11/9/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var songManager: SongManager
    @EnvironmentObject var authService: AuthService
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header
                    
                    statsSection
                    
                    likedSongsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 100)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(songManager)
                    .environmentObject(authService)
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 16) {
            // Avatar or placeholder
            if let avatarUrl = authService.currentUser?.avatarUrl, !avatarUrl.isEmpty {
                CachedAsyncImage(url: URL(string: avatarUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                        .tint(.white.opacity(0.6))
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                )
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white.opacity(0.3))
            }
            
            // Display nickname if available, otherwise name, otherwise "Music Lover"
            Text(authService.currentUser?.nickname ?? authService.effectiveUser.name ?? "Music Lover")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            if authService.isAuthenticated, let email = authService.currentUser?.email {
                Text(email)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                Text("Guest")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    private var statsSection: some View {
        HStack(spacing: 24) {
            StatCard(title: "\(songManager.likedSongs.count)", subtitle: "Liked")
            StatCard(title: "\(songManager.dislikedSongs.count)", subtitle: "Disliked")
            StatCard(title: "\(songManager.librarySongs.count)", subtitle: "Total")
        }
    }
    
    private var likedSongsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recently Liked")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            if songManager.likedSongs.isEmpty {
                Text("No liked songs yet")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.vertical, 20)
            } else {
                ForEach(Array(songManager.likedSongs.prefix(5).enumerated()), id: \.element.id) { index, song in
                    HStack(spacing: 12) {
                        CachedAsyncImage(url: URL(string: song.cover)) { img in
                            img.resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(.rect(cornerRadius: 8))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(song.title)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            
                            Text(song.artist)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Like indicator (should always be true for liked songs, but show it anyway)
                        if song.isLiked {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.pink)
                        }
                    }
                    .padding(.vertical, 8)
                    .onTapGesture {
                        songManager.playSong(song, in: songManager.likedSongs)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    private struct StatCard: View {
        let title: String
        let subtitle: String
        
        var body: some View {
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(SongManager())
        .environmentObject(AuthService())
        .preferredColorScheme(.dark)
}

