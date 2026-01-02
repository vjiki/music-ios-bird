//
//  Search.swift
//  music
//
//  Created by Nikolai Golubkin on 11/8/25.
//

import SwiftUI

struct Search: View {
    @Binding var expandSheet: Bool
    var animation: Namespace.ID
    
    @State var searchText: String = ""
    @State var searchResults: [SongsModel] = []
    @State var isSearching: Bool = false
    @State var searchError: String? = nil
    @State var searchNextCursor: String? = nil
    @State var hasMoreSearchResults: Bool = false
    @StateObject private var songsService = SongsService()
    
    @EnvironmentObject var songManager: SongManager
    @EnvironmentObject var authService: AuthService
    
    private var displayedSongs: [SongsModel] {
        if searchText.isEmpty {
            return songManager.librarySongs
        } else {
            return searchResults
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.6))
                    
                    TextField("Search", text: $searchText)
                        .foregroundStyle(.white)
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                            searchError = nil
                            searchNextCursor = nil
                            hasMoreSearchResults = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    
                    Button {
                        performSearch()
                    } label: {
                        if isSearching {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Search")
                                .foregroundStyle(.white)
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                    .disabled(isSearching || searchText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
                .background(.white.opacity(0.2))
                .clipShape(Capsule())
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Error message
                if let error = searchError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                }
                
                // Tracks list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if searchText.isEmpty && displayedSongs.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.white.opacity(0.3))
                                Text("Start searching for songs")
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        } else if !searchText.isEmpty && searchResults.isEmpty && !isSearching {
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.white.opacity(0.3))
                                Text("No results found")
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        } else {
                            ForEach(displayedSongs) { item in
                                TrackRow(song: item) {
                                    songManager.playSong(item, in: displayedSongs)
                                    expandSheet = true
                                }
                            }
                            
                            // Load more search results indicator
                            if !searchText.isEmpty && hasMoreSearchResults && !isSearching {
                                ProgressView()
                                    .tint(.white.opacity(0.6))
                                    .padding()
                                    .onAppear {
                                        loadMoreSearchResults()
                                    }
                            }
                        }
                        
                        // Load more indicator for library songs
                        if searchText.isEmpty && songManager.hasMoreSongs {
                            ProgressView()
                                .tint(.white.opacity(0.6))
                                .padding()
                                .onAppear {
                                    Task {
                                        await songManager.loadMoreSongs()
                                    }
                                }
                        }
                    }
                    .padding(.top, 16)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Tracks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Menu action
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - Search Function
    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            searchResults = []
            searchNextCursor = nil
            hasMoreSearchResults = false
            return
        }
        
        Task {
            await MainActor.run {
                isSearching = true
                searchError = nil
                searchResults = []
                searchNextCursor = nil
                hasMoreSearchResults = false
            }
            
            do {
                let userId = authService.currentUserId
                let response = try await songsService.searchSongs(userId: userId, query: query, limit: 20, cursor: nil)
                
                await MainActor.run {
                    searchResults = response.items
                    searchNextCursor = response.nextCursor
                    hasMoreSearchResults = response.hasNext
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    searchError = "Failed to search. Please try again."
                    searchResults = []
                    searchNextCursor = nil
                    hasMoreSearchResults = false
                    print("Search error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Load More Search Results
    private func loadMoreSearchResults() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty, let cursor = searchNextCursor, !isSearching else {
            return
        }
        
        Task {
            await MainActor.run {
                isSearching = true
            }
            
            do {
                let userId = authService.currentUserId
                let response = try await songsService.searchSongs(userId: userId, query: query, limit: 20, cursor: cursor)
                
                await MainActor.run {
                    searchResults.append(contentsOf: response.items)
                    searchNextCursor = response.nextCursor
                    hasMoreSearchResults = response.hasNext
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    searchError = "Failed to load more results. Please try again."
                    print("Load more search error: \(error.localizedDescription)")
                }
            }
        }
    }
}

private struct TrackRow: View {
    let song: SongsModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Album art
                CachedAsyncImage(url: URL(string: song.cover)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                        .tint(.white.opacity(0.6))
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
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Like/dislike indicator
                if song.isLiked {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.pink)
                        .frame(width: 32, height: 32)
                } else if song.isDisliked {
                    Image(systemName: "heart.slash.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(width: 32, height: 32)
                }
                
                // Options button
                Button {
                    // Options action
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @Namespace var animation
        
        var body: some View {
            Search(expandSheet: .constant(false), animation: animation)
                .preferredColorScheme(.dark)
                .environmentObject(SongManager())
        }
    }
    
    return PreviewWrapper()
}
