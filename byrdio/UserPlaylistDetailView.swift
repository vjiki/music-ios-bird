//
//  UserPlaylistDetailView.swift
//  music
//
//  Created by Nikolai Golubkin on 11/11/25.
//

import SwiftUI

struct UserPlaylistDetailView: View {
    let playlist: PlaylistResponse
    @EnvironmentObject var songManager: SongManager
    @EnvironmentObject var authService: AuthService
    
    @StateObject private var playlistsService = PlaylistsService()
    @State private var playlistWithSongs: PlaylistResponse?
    @State private var isLoading = false
    
    private var songs: [SongsModel] {
        playlistWithSongs?.songs?.map { $0.toSongsModel(librarySongs: songManager.librarySongs) } ?? []
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                header
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding(.top, 40)
                } else if songs.isEmpty {
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
        .navigationTitle(playlist.name)
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
        .task {
            await loadPlaylistSongs()
        }
    }
    
    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            // Use coverUrl if available, otherwise use first song's cover, otherwise use gradient
            if let coverUrl = playlist.coverUrl, !coverUrl.isEmpty {
                CachedAsyncImage(url: URL(string: coverUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.blue.opacity(0.3))
                }
                .frame(width: 86, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else if let firstSong = songs.first, !firstSong.cover.isEmpty {
                CachedAsyncImage(url: URL(string: firstSong.cover)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.cyan],
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
                            colors: [Color.blue, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 86, height: 86)
                    .overlay {
                        Image(systemName: "music.note.list")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(playlist.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let description = playlist.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Text("\(songs.count) songs")
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
            Image(systemName: "music.note.list")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(.white.opacity(0.6))
            
            Text("No songs in playlist")
                .font(.headline)
            
            Text("Add songs to this playlist to see them here")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
    
    private func loadPlaylistSongs() async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let playlist = try await playlistsService.fetchPlaylist(playlistId: playlist.id)
            await MainActor.run {
                playlistWithSongs = playlist
                isLoading = false
            }
        } catch {
            print("Failed to load playlist songs: \(error.localizedDescription)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

