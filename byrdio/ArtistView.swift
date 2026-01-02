//
//  ArtistView.swift
//  music
//
//  Created by Nikolai Golubkin on 11/9/25.
//

import SwiftUI

struct ArtistView: View {
    let artistName: String
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var songManager: SongManager
    @EnvironmentObject var authService: AuthService
    
    @StateObject private var songsService = SongsService()
    @State private var band: BandResponse?
    @State private var artistSongs: [SongsModel] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var pulseScale: CGFloat = 1.0
    @State private var animationId: UUID = UUID()
    
    private var artistCoverUrl: String? {
        band?.coverUrl
    }
    
    private var isPlayingArtistSong: Bool {
        songManager.isPlaying && isArtistSongPlaying
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Artist Info Section (includes custom heart button on cover)
                    artistInfoSection
                    
                    // Recent Release Section
                    recentReleaseSection
                    
                    // All Songs Section
                    allSongsSection
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await fetchBandData()
                }
                // Start animation if music is already playing
                updatePulseAnimation()
            }
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
                    EmptyView()
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        // Search action
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.white)
                    }
                    
                    Button {
                        // Menu action
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - Artist Info Section
    private var artistInfoSection: some View {
        VStack(spacing: 0) {
            // Full width artist cover with custom heart button overlay
            ZStack(alignment: .bottom) {
                if let coverUrl = artistCoverUrl, let url = URL(string: coverUrl) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.black
                    }
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                    .clipped()
                } else {
                    // Artist photo placeholder
                    ZStack {
                        Color.black
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 120))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                }
                
                // Custom heart button at the bottom of cover
                customHeartButton
                    .padding(.bottom, 20)
            }
            
            // Artist name
            Text(artistName)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 20)
                .padding(.bottom, 20)
        }
    }
    
    // MARK: - Custom Heart Button
    private var customHeartButton: some View {
        Button {
            if isArtistSongPlaying {
                songManager.togglePlayPause()
            } else {
                songManager.playPlaylist(artistSongs)
            }
        } label: {
            ZStack {
                // Custom broken heart icon with fragments inside
                BrokenHeartIcon(
                    color: isPlayingArtistSong 
                        ? LinearGradient(
                            colors: [Color.red, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color.white],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .scaleEffect(pulseScale)
                .id(animationId)
                
                // Waveform overlay when playing
                if isPlayingArtistSong {
                    Image(systemName: "waveform")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .offset(x: 0, y: 15)
                }
            }
            .frame(width: 75, height: 75)
            .background(Color.white.opacity(0.15))
            .clipShape(Circle())
        }
        .onChange(of: songManager.isPlaying) { _, isPlaying in
            updatePulseAnimation()
        }
        .onChange(of: songManager.song.id) { _, _ in
            updatePulseAnimation()
        }
        .onChange(of: artistSongs.count) { _, _ in
            updatePulseAnimation()
        }
    }
    
    // MARK: - Interaction Buttons (removed - button is now on cover)
    private var interactionButtons: some View {
        // Empty view - button moved to cover image
        EmptyView()
    }
    
    // Check if current song is from this artist
    private var isArtistSongPlaying: Bool {
        artistSongs.contains { $0.id == songManager.song.id }
    }
    
    // Update pulse animation based on playing state
    private func updatePulseAnimation() {
        if isArtistSongPlaying && songManager.isPlaying {
            // Force animation restart by changing ID
            animationId = UUID()
            
            // Reset scale first
            pulseScale = 1.0
            
            // Then start pulsing animation - twice the icon size (scale 2.0)
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    self.pulseScale = 2.0
                }
            }
        } else {
            // Stop animation and reset scale
            animationId = UUID()
            withAnimation(.easeInOut(duration: 0.3)) {
                pulseScale = 1.0
            }
        }
    }
    
    // MARK: - Recent Release Section
    private var recentReleaseSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent release")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
            
            if let recentRelease = artistSongs.first {
                HStack(spacing: 16) {
                    // Album artwork
                    CachedAsyncImage(url: URL(string: recentRelease.cover)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                            .tint(.white.opacity(0.6))
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recentRelease.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        
                        Text("6 August 2025")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.white.opacity(0.6))
                        
                        Text("single")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
                .onTapGesture {
                    songManager.playSong(recentRelease, in: artistSongs)
                }
            }
        }
        .padding(.bottom, 30)
    }
    
    // MARK: - All Songs Section
    private var allSongsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All songs")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
            
            if isLoading {
                ProgressView()
                    .tint(.white.opacity(0.6))
                    .padding()
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(error)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 50)
            } else if artistSongs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No songs found")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 50)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(artistSongs) { song in
                        SongRow(
                            song: song,
                            isActive: song.id == songManager.song.id
                        ) {
                            songManager.playSong(song, in: artistSongs)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 100)
    }
    
    // MARK: - Fetch Band Data
    private func fetchBandData() async {
        // Ensure we're on the main actor to safely access environment objects
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Get userId on main actor to ensure environment object is available
        let userId = await MainActor.run {
            authService.currentUserId
        }
        
        do {
            let response = try await songsService.fetchBand(userId: userId, name: artistName, limit: 20)
            
            await MainActor.run {
                if let firstBand = response.items.first {
                    band = firstBand
                    artistSongs = firstBand.songs
                } else {
                    errorMessage = "Artist not found"
                    artistSongs = []
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to load artist data. Please try again."
                artistSongs = []
                print("Failed to fetch band: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Song Row
private struct SongRow: View {
    let song: SongsModel
    let isActive: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Album artwork
                CachedAsyncImage(url: URL(string: song.cover)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.clear
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                // Track info
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text(song.artist)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Like/dislike indicator
                if song.isLiked {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.pink)
                } else if song.isDisliked {
                    Image(systemName: "heart.slash.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.red)
                }
                
                // Active indicator with animation
                if isActive {
                    AnimatedWaveformIcon()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(isActive ? Color.white.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Broken Heart Icon
private struct BrokenHeartIcon: View {
    let color: LinearGradient
    @State private var fragmentAnimation: Bool = false
    
    var body: some View {
        ZStack {
            // Main heart shape (adjusted for smaller button)
            Image(systemName: "heart.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(color)
            
            // Large center fragment creating the main break
            Image(systemName: "heart.fill")
                .font(.system(size: 6, weight: .semibold))
                .foregroundStyle(color)
                .offset(x: 0, y: -2.5)
                .opacity(0.95)
                .scaleEffect(fragmentAnimation ? 1.05 : 1.0)
            
            // Top-left fragments
            Image(systemName: "heart.fill")
                .font(.system(size: 4, weight: .medium))
                .foregroundStyle(color)
                .offset(x: -4, y: -5)
                .opacity(0.85)
            
            Image(systemName: "heart.fill")
                .font(.system(size: 3, weight: .medium))
                .foregroundStyle(color)
                .offset(x: -3, y: -3.5)
                .opacity(0.75)
            
            // Top-right fragments
            Image(systemName: "heart.fill")
                .font(.system(size: 4.5, weight: .medium))
                .foregroundStyle(color)
                .offset(x: 4.5, y: -4.5)
                .opacity(0.85)
            
            Image(systemName: "heart.fill")
                .font(.system(size: 2.5, weight: .medium))
                .foregroundStyle(color)
                .offset(x: 3.5, y: -3)
                .opacity(0.7)
            
            // Left side fragments
            Image(systemName: "heart.fill")
                .font(.system(size: 3.5, weight: .medium))
                .foregroundStyle(color)
                .offset(x: -5, y: 1)
                .opacity(0.8)
            
            Image(systemName: "heart.fill")
                .font(.system(size: 2.5, weight: .medium))
                .foregroundStyle(color)
                .offset(x: -3.5, y: 2.5)
                .opacity(0.7)
            
            // Right side fragments
            Image(systemName: "heart.fill")
                .font(.system(size: 3, weight: .medium))
                .foregroundStyle(color)
                .offset(x: 5, y: 1.5)
                .opacity(0.8)
            
            Image(systemName: "heart.fill")
                .font(.system(size: 3.5, weight: .medium))
                .foregroundStyle(color)
                .offset(x: 4, y: 3.5)
                .opacity(0.75)
            
            // Center fragments creating crack effect
            Image(systemName: "heart.fill")
                .font(.system(size: 3, weight: .medium))
                .foregroundStyle(color)
                .offset(x: -1.5, y: 3)
                .opacity(0.8)
            
            Image(systemName: "heart.fill")
                .font(.system(size: 2.5, weight: .medium))
                .foregroundStyle(color)
                .offset(x: 2, y: 4)
                .opacity(0.7)
            
            // Bottom fragments
            Image(systemName: "heart.fill")
                .font(.system(size: 3, weight: .medium))
                .foregroundStyle(color)
                .offset(x: -3, y: 6)
                .opacity(0.75)
            
            Image(systemName: "heart.fill")
                .font(.system(size: 2.5, weight: .medium))
                .foregroundStyle(color)
                .offset(x: 3.5, y: 7)
                .opacity(0.65)
            
            // Additional small fragments for shattered effect
            Image(systemName: "heart.fill")
                .font(.system(size: 2, weight: .medium))
                .foregroundStyle(color)
                .offset(x: 1, y: 2)
                .opacity(0.6)
            
            Image(systemName: "heart.fill")
                .font(.system(size: 2, weight: .medium))
                .foregroundStyle(color)
                .offset(x: -2, y: 4.5)
                .opacity(0.55)
            
            Image(systemName: "heart.fill")
                .font(.system(size: 1.5, weight: .medium))
                .foregroundStyle(color)
                .offset(x: 2.5, y: 0.5)
                .opacity(0.5)
        }
        .onAppear {
            // Subtle animation for fragments
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                fragmentAnimation = true
            }
        }
    }
}

// MARK: - Animated Waveform Icon
private struct AnimatedWaveformIcon: View {
    @State private var scale: CGFloat = 1.0
    @State private var ring1Scale: CGFloat = 1.0
    @State private var ring1Opacity: Double = 0.6
    @State private var ring2Scale: CGFloat = 1.0
    @State private var ring2Opacity: Double = 0.4
    
    var body: some View {
        ZStack {
            // Main waveform circle with pulsing scale
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.red)
                .scaleEffect(scale)
            
            // Pulsing rings effect
            Circle()
                .stroke(Color.red.opacity(ring1Opacity), lineWidth: 2)
                .frame(width: 24, height: 24)
                .scaleEffect(ring1Scale)
            
            Circle()
                .stroke(Color.red.opacity(ring2Opacity), lineWidth: 1.5)
                .frame(width: 24, height: 24)
                .scaleEffect(ring2Scale)
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Main icon pulse
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            scale = 1.2
        }
        
        // First ring animation with reset
        animateRing(scale: $ring1Scale, opacity: $ring1Opacity, delay: 0.0)
        
        // Second ring animation with reset (delayed)
        animateRing(scale: $ring2Scale, opacity: $ring2Opacity, delay: 0.4)
    }
    
    private func animateRing(scale: Binding<CGFloat>, opacity: Binding<Double>, delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: 1.2)) {
                scale.wrappedValue = 1.8
                opacity.wrappedValue = 0.0
            }
            
            // Reset and repeat
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                scale.wrappedValue = 1.0
                opacity.wrappedValue = delay == 0.0 ? 0.6 : 0.4
                animateRing(scale: scale, opacity: opacity, delay: 0.0)
            }
        }
    }
}

#Preview {
    ArtistView(artistName: "Scotch")
        .preferredColorScheme(.dark)
        .environmentObject(SongManager())
        .environmentObject(AuthService())
}

