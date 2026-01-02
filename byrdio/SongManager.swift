//
//  SongManager.swift
//  music
//
//  Created by Nikolai Golubkin on 11/8/25.
//

import SwiftUI
import Foundation

// MARK: - PlaylistKind Enum
enum PlaylistKind: String, CaseIterable, Hashable {
    case liked
    case disliked
}

// MARK: - SongManager (Orchestrator - Dependency Inversion Principle)
class SongManager: ObservableObject {
    // MARK: - Dependencies (Dependency Inversion)
    private var audioPlayer: AudioPlayerServiceProtocol
    private let playlistManager: PlaylistManagerProtocol
    private let preferenceManager: PreferenceManagerProtocol
    private let nowPlayingService: NowPlayingServiceProtocol
    private let songsService: SongsServiceProtocol
    private var authService: AuthService?
    private var refreshTask: Task<Void, Never>?
    
    // MARK: - Published Properties
    @Published private(set) var song: SongsModel = SongsModel(artist: "", audio_url: "", cover: "", title: "", isLiked: false, isDisliked: false, likesCount: 0, dislikesCount: 0)
    @Published private(set) var playlist: [SongsModel] = []
    @Published private(set) var currentIndex: Int?
    @Published private(set) var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published private(set) var isShuffling: Bool = false
    @Published private(set) var repeatMode: RepeatMode = .none
    @Published private(set) var librarySongs: [SongsModel] = []
    
    // MARK: - Computed Properties
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    var formattedCurrentTime: String {
        secondsToTimeString(currentTime)
    }
    
    var formattedDuration: String {
        secondsToTimeString(duration)
    }
    
    var repeatIconName: String {
        repeatMode.iconName
    }
    
    var likedSongs: [SongsModel] {
        preferenceManager.getLikedSongs(from: librarySongs)
    }
    
    var dislikedSongs: [SongsModel] {
        preferenceManager.getDislikedSongs(from: librarySongs)
    }
    
    var isCurrentSongLiked: Bool {
        preferenceManager.isLiked(song)
    }
    
    var isCurrentSongDisliked: Bool {
        preferenceManager.isDisliked(song)
    }
    
    var likeIconName: String {
        isCurrentSongLiked ? "heart.fill" : "heart"
    }
    
    var dislikeIconName: String {
        isCurrentSongDisliked ? "heart.slash.fill" : "heart.slash"
    }
    
    // Calculate icon size based on like/dislike count
    func iconSize(for count: Int, baseSize: CGFloat = 24) -> CGFloat {
        if count >= 50 {
            return baseSize * 1.4  // Max size at 50+
        } else if count >= 30 {
            return baseSize * 1.3  // Bigger at 30+
        } else if count >= 20 {
            return baseSize * 1.2  // Bigger at 20+
        } else if count >= 10 {
            return baseSize * 1.1  // Slightly bigger at 10+
        }
        return baseSize  // Default size
    }
    
    var likeIconSize: CGFloat {
        iconSize(for: song.likesCount)
    }
    
    var dislikeIconSize: CGFloat {
        iconSize(for: song.dislikesCount)
    }
    
    var hasMoreSongs: Bool {
        songsService.hasMore
    }
    
    var isLoadingMoreSongs: Bool {
        songsService.isLoading
    }
    
    // MARK: - Initialization (Dependency Injection)
    init(
        audioPlayer: AudioPlayerServiceProtocol = AudioPlayerService(),
        playlistManager: PlaylistManagerProtocol = PlaylistManager(),
        preferenceManager: PreferenceManagerProtocol = PreferenceManager(),
        nowPlayingService: NowPlayingServiceProtocol = NowPlayingService(),
        songsService: SongsServiceProtocol = SongsService(),
        authService: AuthService? = nil
    ) {
        self.audioPlayer = audioPlayer
        self.playlistManager = playlistManager
        self.preferenceManager = preferenceManager
        self.nowPlayingService = nowPlayingService
        self.songsService = songsService
        self.authService = authService
        
        // Initialize with songs from service (fallback to sampleSongs)
        self.librarySongs = songsService.songs
        
        setupAudioPlayerCallbacks()
        setupNowPlayingService()
        
        // Fetch songs from API
        Task {
            let userId = authService?.currentUserId ?? "3762deba-87a9-482e-b716-2111232148ca"
            await songsService.fetchSongs(userId: userId)
            await MainActor.run {
                // Songs from API should have correct like/dislike information
                self.librarySongs = songsService.songs
            }
        }
        
        // Start periodic refresh of songs to get updated like/dislike counts
        startPeriodicRefresh()
    }
    
    private func startPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            // Refresh every 30 seconds to get updated like/dislike counts
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                guard !Task.isCancelled else { break }
                await self?.refreshSongs()
            }
        }
    }
    
    // MARK: - Public Methods
    
    func playSong(_ song: SongsModel, in playlist: [SongsModel]? = nil) {
        var basePlaylist = playlist ?? playlistManager.currentPlaylist
        if basePlaylist.isEmpty {
            basePlaylist = [song]
        } else if !basePlaylist.contains(where: { $0.id == song.id }) {
            basePlaylist.append(song)
        }
        
        playlistManager.configurePlaylist(basePlaylist, selecting: song)
        startPlaybackAtCurrentIndex()
    }
    
    func playSong(at index: Int, playlist newPlaylist: [SongsModel]? = nil) {
        if let newPlaylist {
            guard newPlaylist.indices.contains(index) else { return }
            let selectedSong = newPlaylist[index]
            playlistManager.configurePlaylist(newPlaylist, selecting: selectedSong)
        } else {
            playlistManager.setCurrentIndex(index)
        }
        
        startPlaybackAtCurrentIndex()
    }
    
    func play() {
        // If player is already playing, just call play
        if audioPlayer.isPlaying {
            audioPlayer.play()
            return
        }
        
        // If no song loaded, try to resume last song
        if currentTime == 0 && duration == 0 && song.audio_url.isEmpty {
            resumeLastSongIfPossible()
        } else {
            audioPlayer.play()
        }
    }
    
    func pause() {
        audioPlayer.pause()
    }
    
    func togglePlayPause() {
        isPlaying ? pause() : play()
    }
    
    func playNext(autoAdvance: Bool = false) {
        guard let currentSong = playlistManager.getCurrentSong() else { return }
        
        if autoAdvance, repeatMode == .one {
            audioPlayer.seek(to: 0)
            play()
            return
        }
        
        guard let nextIndex = playlistManager.getNextIndex() else {
            if autoAdvance {
                switch repeatMode {
                case .none:
                    pause()
                case .all:
                    if let firstIndex = playlistManager.currentPlaylist.indices.first {
                        playSong(at: firstIndex)
                    }
                case .one:
                    audioPlayer.seek(to: 0)
                    play()
                }
            }
            return
        }
        
        playSong(at: nextIndex)
    }
    
    func playPrevious() {
        guard let previousIndex = playlistManager.getPreviousIndex() else { return }
        playSong(at: previousIndex)
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer.seek(to: time)
    }
    
    func toggleShuffle() {
        playlistManager.toggleShuffle()
        isShuffling = playlistManager.isShuffling
        playlist = playlistManager.currentPlaylist
    }
    
    func cycleRepeatMode() {
        playlistManager.cycleRepeatMode()
        repeatMode = playlistManager.repeatMode
    }
    
    func toggleLike() {
        guard !song.title.isEmpty else { return }
        let userId = getCurrentUserId()
        Task {
            let updatedSong = await preferenceManager.toggleLike(song, userId: userId)
            await MainActor.run {
                // Update current song
                song = updatedSong
                // Update song in library
                if let index = librarySongs.firstIndex(where: { $0.id == updatedSong.id }) {
                    librarySongs[index] = updatedSong
                }
                // Update song in playlist
                if let index = playlist.firstIndex(where: { $0.id == updatedSong.id }) {
                    playlist[index] = updatedSong
                }
            }
        }
    }
    
    func toggleDislike() {
        guard !song.title.isEmpty else { return }
        let userId = getCurrentUserId()
        Task {
            let updatedSong = await preferenceManager.toggleDislike(song, userId: userId)
            await MainActor.run {
                // Update current song
                song = updatedSong
                // Update song in library
                if let index = librarySongs.firstIndex(where: { $0.id == updatedSong.id }) {
                    librarySongs[index] = updatedSong
                }
                // Update song in playlist
                if let index = playlist.firstIndex(where: { $0.id == updatedSong.id }) {
                    playlist[index] = updatedSong
                }
            }
        }
    }
    
    func getCurrentUserId() -> String {
        return authService?.currentUserId ?? "3762deba-87a9-482e-b716-2111232148ca"
    }
    
    func setAuthService(_ authService: AuthService) {
        self.authService = authService
    }
    
    func songs(for kind: PlaylistKind) -> [SongsModel] {
        switch kind {
        case .liked:
            return likedSongs
        case .disliked:
            return dislikedSongs
        }
    }
    
    func playPlaylist(_ songs: [SongsModel]) {
        guard !songs.isEmpty else { return }
        playSong(songs[0], in: songs)
    }
    
    func playPlaylist(_ kind: PlaylistKind) {
        playPlaylist(songs(for: kind))
    }
    
    func updateSongInLibrary(_ updatedSong: SongsModel) {
        if let index = librarySongs.firstIndex(where: { $0.id == updatedSong.id }) {
            librarySongs[index] = updatedSong
        }
    }
    
    func refreshSongs() async {
        let userId = getCurrentUserId()
        let currentSongId = song.id
        await songsService.fetchSongs(userId: userId)
        await MainActor.run {
            // Merge new songs with existing to preserve current playback state
            let newSongs = songsService.songs
            var mergedSongs: [SongsModel] = []
            
            for newSong in newSongs {
                if let existingIndex = librarySongs.firstIndex(where: { $0.id == newSong.id }) {
                    // Update with new like/dislike counts from API
                    let mergedSong = newSong
                    mergedSongs.append(mergedSong)
                    
                    // Update current song if it's the same
                    if currentSongId == newSong.id {
                        // Update current song with latest like/dislike counts
                        var updatedCurrentSong = song
                        updatedCurrentSong.likesCount = newSong.likesCount
                        updatedCurrentSong.dislikesCount = newSong.dislikesCount
                        updatedCurrentSong.isLiked = newSong.isLiked
                        updatedCurrentSong.isDisliked = newSong.isDisliked
                        song = updatedCurrentSong
                    }
                } else {
                    mergedSongs.append(newSong)
                }
            }
            
            self.librarySongs = mergedSongs
        }
    }
    
    func loadMoreSongs() async {
        let userId = getCurrentUserId()
        await songsService.loadMoreSongs(userId: userId)
        await MainActor.run {
            // Update library songs with newly loaded songs
            let newSongs = songsService.songs
            var mergedSongs = librarySongs
            
            // Add new songs that aren't already in library
            for newSong in newSongs {
                if !mergedSongs.contains(where: { $0.id == newSong.id }) {
                    mergedSongs.append(newSong)
                } else if let index = mergedSongs.firstIndex(where: { $0.id == newSong.id }) {
                    // Update existing song with latest data
                    mergedSongs[index] = newSong
                }
            }
            
            self.librarySongs = mergedSongs
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAudioPlayerCallbacks() {
        audioPlayer.onTimeUpdate = { [weak self] time in
            self?.currentTime = time
            self?.updateNowPlayingInfo()
        }
        
        audioPlayer.onDurationUpdate = { [weak self] duration in
            self?.duration = duration
            self?.updateNowPlayingInfo()
        }
        
        audioPlayer.onPlaybackFinished = { [weak self] in
            self?.playNext(autoAdvance: true)
        }
        
        audioPlayer.onPlaybackStateChanged = { [weak self] isPlaying in
            self?.isPlaying = isPlaying
            self?.updateNowPlayingInfo()
        }
    }
    
    private func setupNowPlayingService() {
        nowPlayingService.setupRemoteCommandCenter(
            onPlay: { [weak self] in self?.play() },
            onPause: { [weak self] in self?.pause() },
            onToggle: { [weak self] in self?.togglePlayPause() },
            onNext: { [weak self] in self?.playNext() },
            onPrevious: { [weak self] in self?.playPrevious() },
            onSeek: { [weak self] time in self?.seek(to: time) },
            onLike: { [weak self] in self?.toggleLike() },
            onDislike: { [weak self] in self?.toggleDislike() }
        )
    }
    
    private func startPlaybackAtCurrentIndex() {
        guard let currentSong = playlistManager.getCurrentSong() else { return }
        
        syncLibrary(with: currentSong)
        
        song = currentSong
        currentIndex = playlistManager.currentIndex
        playlist = playlistManager.currentPlaylist
        isShuffling = playlistManager.isShuffling
        repeatMode = playlistManager.repeatMode
        
        currentTime = 0
        duration = 0
        
        // Song like/dislike status is now included in the song response from backend
        // No need to fetch separately
        
        guard let url = URL(string: currentSong.audio_url), !currentSong.audio_url.isEmpty else {
            return
        }
        
        audioPlayer.load(url: url, title: currentSong.title, artist: currentSong.artist, coverURL: currentSong.cover)
        audioPlayer.play()
        updateNowPlayingInfo()
    }
    
    private func resumeLastSongIfPossible() {
        if let currentIndex = playlistManager.currentIndex {
            playSong(at: currentIndex)
        } else if !playlistManager.currentPlaylist.isEmpty {
            playSong(at: 0)
        } else if !song.audio_url.isEmpty {
            playSong(song)
        }
    }
    
    private func syncLibrary(with song: SongsModel) {
        if let existingIndex = librarySongs.firstIndex(where: { $0.id == song.id }) {
            let existingSong = librarySongs[existingIndex]
            // Merge: prefer new song's like/dislike info if it has valid data, otherwise keep existing
            var mergedSong = song
            // If new song has default values but existing has real values, keep existing
            if song.isLiked == false && song.isDisliked == false && 
               song.likesCount == 0 && song.dislikesCount == 0 &&
               (existingSong.isLiked || existingSong.isDisliked || existingSong.likesCount > 0 || existingSong.dislikesCount > 0) {
                mergedSong.isLiked = existingSong.isLiked
                mergedSong.isDisliked = existingSong.isDisliked
                mergedSong.likesCount = existingSong.likesCount
                mergedSong.dislikesCount = existingSong.dislikesCount
            }
            librarySongs[existingIndex] = mergedSong
        } else {
            librarySongs.append(song)
        }
    }
    
    private func updateNowPlayingInfo() {
        nowPlayingService.update(
            song: song,
            currentTime: currentTime,
            duration: duration,
            isPlaying: isPlaying
        )
    }
    
    private func secondsToTimeString(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "0:00" }
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
