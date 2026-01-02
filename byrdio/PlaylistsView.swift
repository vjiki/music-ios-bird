//
//  PlaylistsView.swift
//  music
//
//  Created by Nikolai Golubkin on 11/9/25.
//

import SwiftUI

struct PlaylistsView: View {
    @EnvironmentObject var songManager: SongManager
    @EnvironmentObject var authService: AuthService
    
    @StateObject private var playlistsService = PlaylistsService()
    @State private var userPlaylists: [PlaylistResponse] = []
    @State private var isLoading = false
    
    private let gridColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 20)
    ]
    
    private var playlistCards: [PlaylistCard] {
        var cards: [PlaylistCard] = []
        
        // Add default playlists (Liked/Disliked)
        for kind in PlaylistKind.allCases {
            let songs = songManager.songs(for: kind)
            // Use first song's cover if available
            let coverUrl = songs.first?.cover.isEmpty == false ? songs.first?.cover : nil
            cards.append(PlaylistCard(
                kind: kind,
                title: kind.displayTitle,
                subtitle: subtitle(for: songs.count),
                icon: kind.systemImageName,
                gradient: kind.gradientColors,
                songCount: songs.count,
                playlistId: nil,
                coverUrl: coverUrl
            ))
        }
        
        // Add user playlists from API (excluding default ones)
        for playlist in userPlaylists where !playlist.isDefaultLikes && !playlist.isDefaultDislikes {
            // Get cover from first song if coverUrl is empty
            let coverUrl = playlist.coverUrl ?? playlist.songs?.first?.songCoverUrl
            
            cards.append(PlaylistCard(
                kind: nil,
                title: playlist.name,
                subtitle: subtitle(for: playlist.songs?.count ?? 0),
                icon: "music.note.list",
                gradient: [Color.blue, Color.cyan],
                songCount: playlist.songs?.count ?? 0,
                playlistId: playlist.id,
                coverUrl: coverUrl
            ))
        }
        
        return cards
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding(.top, 100)
                } else {
                    LazyVGrid(columns: gridColumns, spacing: 24) {
                        ForEach(playlistCards) { card in
                            if let kind = card.kind {
                                NavigationLink(value: kind) {
                                    PlaylistTile(card: card)
                                }
                                .buttonStyle(.plain)
                                .disabled(card.songCount == 0)
                                .opacity(card.songCount == 0 ? 0.45 : 1)
                            } else if let playlistId = card.playlistId {
                                NavigationLink(value: playlistId) {
                                    PlaylistTile(card: card)
                                }
                                .buttonStyle(.plain)
                                .disabled(card.songCount == 0)
                                .opacity(card.songCount == 0 ? 0.45 : 1)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 30)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Playlists")
            .task {
                await loadUserPlaylists()
            }
            .navigationDestination(for: PlaylistKind.self) { kind in
                PlaylistDetailView(kind: kind)
            }
            .navigationDestination(for: String.self) { playlistId in
                if let playlist = userPlaylists.first(where: { $0.id == playlistId }) {
                    UserPlaylistDetailView(playlist: playlist)
                        .environmentObject(songManager)
                        .environmentObject(authService)
                }
            }
        }
    }
    
    private func subtitle(for count: Int) -> String {
        switch count {
        case 0:
            return "No songs yet"
        case 1:
            return "1 song"
        default:
            return "\(count) songs"
        }
    }
    
    private func loadUserPlaylists() async {
        let userId = authService.currentUserId
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            var playlists = try await playlistsService.fetchUserPlaylists(userId: userId)
            
            // Load songs for playlists without coverUrl to get cover images from first song
            for index in playlists.indices {
                if playlists[index].coverUrl == nil && playlists[index].songs == nil {
                    do {
                        let fullPlaylist = try await playlistsService.fetchPlaylist(playlistId: playlists[index].id)
                        playlists[index] = fullPlaylist
                    } catch {
                        print("Failed to load songs for playlist \(playlists[index].id): \(error.localizedDescription)")
                    }
                }
            }
            
            await MainActor.run {
                userPlaylists = playlists
                isLoading = false
            }
        } catch {
            print("Failed to load playlists: \(error.localizedDescription)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

private struct PlaylistCard: Identifiable {
    var id: String {
        if let kind = kind {
            return kind.rawValue
        } else if let playlistId = playlistId {
            return playlistId
        } else {
            return UUID().uuidString
        }
    }
    let kind: PlaylistKind?
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let songCount: Int
    let playlistId: String?
    let coverUrl: String?
}

private struct PlaylistTile: View {
    let card: PlaylistCard
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Use cover image if available, otherwise use gradient
            if let coverUrl = card.coverUrl, !coverUrl.isEmpty {
                CachedAsyncImage(url: URL(string: coverUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: card.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: card.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
                    .frame(height: 160)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: card.icon)
                    .font(.title2)
                    .padding(12)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.title)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    
                    Text(card.subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(20)
        }
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 10)
    }
}

private struct PlaylistDetailView: View {
    @EnvironmentObject var songManager: SongManager
    let kind: PlaylistKind
    
    private var songs: [SongsModel] {
        songManager.songs(for: kind)
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                header
                
                if songs.isEmpty {
                    emptyState
                } else {
                    songList
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 100)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(kind.displayTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !songs.isEmpty {
                    Button {
                        songManager.playPlaylist(songs)
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .accessibilityLabel("Play all songs in playlist")
                }
            }
        }
    }
    
    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            // Use first song's cover if available, otherwise use gradient
            if let firstSong = songs.first, !firstSong.cover.isEmpty {
                CachedAsyncImage(url: URL(string: firstSong.cover)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: kind.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(width: 86, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: kind.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 86, height: 86)
                    .overlay {
                        Image(systemName: kind.systemImageName)
                            .font(.title)
                            .foregroundStyle(.white)
                    }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(kind.displayTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(kind.subtitle(for: songs.count))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(20)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
    
    private var songList: some View {
        LazyVStack(spacing: 16) {
            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                PlaylistSongRow(
                    index: index + 1,
                    song: song,
                    isActive: song.id == songManager.song.id,
                    songManager: songManager
                )
                .onTapGesture {
                    songManager.playSong(song, in: songs)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: kind.emptyStateIcon)
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(.white.opacity(0.6))
            
            Text(kind.emptyStateMessage)
                .font(.headline)
            
            Text(kind.emptyStateDetail)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct PlaylistSongRow: View {
    let index: Int
    let song: SongsModel
    let isActive: Bool
    let songManager: SongManager
    
    var body: some View {
        HStack(spacing: 16) {
            Text("\(index)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 28, alignment: .leading)
            
            CachedAsyncImage(url: URL(string: song.cover)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(song.artist)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isActive {
                Image(systemName: "waveform.circle.fill")
                    .foregroundStyle(Color.blue)
            } else if song.isLiked {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
            } else if song.isDisliked {
                Image(systemName: "heart.slash.fill")
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(isActive ? 0.12 : 0.06))
        )
    }
}

private extension PlaylistKind {
    var displayTitle: String {
        switch self {
        case .liked:
            return "Liked Songs"
        case .disliked:
            return "Disliked Songs"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .liked:
            return "heart.fill"
        case .disliked:
            return "heart.slash"
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .liked:
            return [Color.purple, Color.pink]
        case .disliked:
            return [Color.red, Color.orange]
        }
    }
    
    func subtitle(for count: Int) -> String {
        switch count {
        case 0:
            return "No songs added yet"
        case 1:
            return "1 song"
        default:
            return "\(count) songs"
        }
    }
    
    var emptyStateIcon: String {
        switch self {
        case .liked:
            return "heart"
        case .disliked:
            return "heart.slash"
        }
    }
    
    var emptyStateMessage: String {
        switch self {
        case .liked:
            return "No liked songs yet"
        case .disliked:
            return "No disliked songs"
        }
    }
    
    var emptyStateDetail: String {
        switch self {
        case .liked:
            return "Tap the heart icon while a song is playing to save it to your favourites."
        case .disliked:
            return "Use the broken-heart icon while a song is playing to send it here."
        }
    }
}

#Preview {
    PlaylistsView()
        .environmentObject(SongManager())
        .preferredColorScheme(.dark)
}

