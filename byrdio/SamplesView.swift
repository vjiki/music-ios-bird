//
//  SamplesView.swift
//  music
//
//  Created by Nikolai Golubkin on 11/12/25.
//

import SwiftUI
import AVFoundation
import AVKit

// Unified player for SamplesView that handles both audio and video
class SamplesPlayer: NSObject, ObservableObject {
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var playbackFinishedObserver: Any?
    private var playerLayer: AVPlayerLayer?
    private var hasStatusObserver: Bool = false
    private var nextPlayerItem: AVPlayerItem?
    
    @Published var currentShort: ShortsModel?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    var isVideo: Bool {
        currentShort?.type == "SHORT_VIDEO"
    }
    
    override init() {
        super.init()
        configureAudioSession()
    }
    
    deinit {
        cleanup()
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session configuration failed: \(error)")
        }
    }
    
    func play() {
        player?.play()
        isPlaying = true
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func setPlaybackRate(_ rate: Float) {
        player?.rate = rate
    }
    
    func setFastPlayback() {
        // Set playback rate to 1.5x only if currently playing
        guard let player = player else { return }
        if isPlaying && player.rate > 0 {
            // Player is playing, speed it up to 1.5x
            player.rate = 1.5
        }
    }
    
    func setNormalPlayback() {
        // Restore normal playback rate (1.0) if currently playing
        guard let player = player else { return }
        if isPlaying && player.rate > 0 {
            // If playing, restore to normal speed (1.0)
            player.rate = 1.0
        }
        // If paused, rate is already 0, so no change needed
    }
    
    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clampedTime = min(max(time, 0), duration)
        let cmTime = CMTime(seconds: clampedTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clampedTime
    }
    
    func load(short: ShortsModel) {
        cleanup()
        
        // Update current short FIRST on main thread to trigger UI updates immediately
        Task { @MainActor in
            self.currentShort = short
        }
        
        let urlString: String?
        if short.type == "SHORT_VIDEO", let videoUrl = short.video_url, !videoUrl.isEmpty {
            urlString = videoUrl
        } else if let audioUrl = short.audio_url, !audioUrl.isEmpty {
            urlString = audioUrl
        } else {
            return
        }
        
        guard let urlString = urlString, let url = URL(string: urlString) else {
            return
        }
        
        // Check if URL is an m3u8 (HLS streaming) file
        let isM3U8 = isM3U8URL(url)
        let cacheService = CacheService.shared
        let finalURL: URL
        
        if short.type == "SHORT_VIDEO" {
            if isM3U8 {
                // For m3u8 video files, use the original URL directly (no caching)
                finalURL = url
            } else if let cachedURL = cacheService.getCachedVideoURL(url: url) {
                finalURL = cachedURL
            } else {
                finalURL = url
                // Cache video in background (skip for m3u8)
                Task {
                    await cacheVideo(url: url, short: short)
                }
            }
        } else {
            if isM3U8 {
                // For m3u8 files, use the original URL directly (no caching)
                finalURL = url
            } else if let cachedURL = cacheService.getCachedAudioURL(url: url) {
                finalURL = cachedURL
            } else {
                finalURL = url
                // Cache audio in background
                Task {
                    await cacheAudio(url: url, short: short)
                }
            }
        }
        
        let playerItem = AVPlayerItem(url: finalURL)
        
        // Configure buffering based on format
        // For m3u8 (HLS) - don't use preferredForwardBufferDuration for instant swipe
        // For regular files - use buffering for smoother playback
        if !isM3U8 {
            playerItem.preferredForwardBufferDuration = 30.0
        }
        
        player = AVPlayer(playerItem: playerItem)
        
        // Configure player to minimize stalling
        // For m3u8 (HLS) - set to false for instant swipe
        // For regular files - set to true for smoother playback
        if let player = player {
            player.automaticallyWaitsToMinimizeStalling = !isM3U8
        }
        
        // Configure player for video - loop playback
        if short.type == "SHORT_VIDEO" {
            player?.actionAtItemEnd = .none
            // Loop video when it ends
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { [weak self] _ in
                self?.player?.seek(to: .zero)
                self?.player?.play()
            }
        }
        
        // Remove old observers if they exist
        if let oldItem = currentPlayerItem {
            oldItem.removeObserver(self, forKeyPath: "duration")
            if hasStatusObserver {
                oldItem.removeObserver(self, forKeyPath: "status")
                hasStatusObserver = false
            }
        }
        
        currentPlayerItem = playerItem
        addPlaybackObservers(for: playerItem)
        addPeriodicTimeObserver()
        
        // Observe player item status for video
        if short.type == "SHORT_VIDEO" {
            playerItem.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
            hasStatusObserver = true
        }
        
        currentTime = 0
        duration = 0
    }
    
    func preloadNextShort(currentIndex: Int, shorts: [ShortsModel]) {
        // Get next short index
        let nextIndex = currentIndex + 1
        guard nextIndex < shorts.count else {
            return
        }
        
        let nextShort = shorts[nextIndex]
        let urlString: String?
        if nextShort.type == "SHORT_VIDEO", let videoUrl = nextShort.video_url, !videoUrl.isEmpty {
            urlString = videoUrl
        } else if let audioUrl = nextShort.audio_url, !audioUrl.isEmpty {
            urlString = audioUrl
        } else {
            return
        }
        
        guard let urlString = urlString, let url = URL(string: urlString) else {
            return
        }
        
        // Preload next short
        preloadNext(url: url, isVideo: nextShort.type == "SHORT_VIDEO")
    }
    
    private func preloadNext(url: URL, isVideo: Bool) {
        // Clear previous preloaded item
        nextPlayerItem = nil
        
        // Check if URL is an m3u8 (HLS streaming) file
        let isM3U8 = isM3U8URL(url)
        let finalURL: URL
        
        if isM3U8 {
            // For m3u8 files, use the original URL directly (no caching)
            finalURL = url
        } else {
            // For regular files, check cache first
            let cacheService = CacheService.shared
            
            if isVideo {
                if let cachedURL = cacheService.getCachedVideoURL(url: url) {
                    finalURL = cachedURL
                } else {
                    finalURL = url
                }
            } else {
                if let cachedURL = cacheService.getCachedAudioURL(url: url) {
                    finalURL = cachedURL
                } else {
                    finalURL = url
                }
            }
        }
        
        // Create and preload the next item
        let nextItem = AVPlayerItem(url: finalURL)
        
        // For m3u8 (HLS) - don't use preferredForwardBufferDuration for instant swipe
        // For regular files - use buffering for smoother playback
        if !isM3U8 {
            nextItem.preferredForwardBufferDuration = 30.0
        }
        
        // Preload the asset
        let asset = nextItem.asset
        asset.loadValuesAsynchronously(forKeys: ["playable", "duration"]) {
            // Item is preloaded and ready
        }
        
        nextPlayerItem = nextItem
    }
    
    private func cacheAudio(url: URL, short: ShortsModel) async {
        // Skip caching for m3u8 files (HLS streaming)
        if isM3U8URL(url) {
            return
        }
        
        let cacheService = CacheService.shared
        if cacheService.hasCachedAudio(url: url) { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            cacheService.cacheAudio(url: url, data: data, title: short.title ?? "Unknown", artist: short.artist ?? "Unknown", coverURL: short.cover)
        } catch {
            print("Failed to cache audio: \(error.localizedDescription)")
        }
    }
    
    /// Checks if a URL points to an m3u8 (HLS) playlist file
    private func isM3U8URL(_ url: URL) -> Bool {
        let urlString = url.absoluteString.lowercased()
        return urlString.hasSuffix(".m3u8") || urlString.contains(".m3u8?") || urlString.contains(".m3u8#")
    }
    
    private func cacheVideo(url: URL, short: ShortsModel) async {
        // Skip caching for m3u8 files (HLS streaming)
        if isM3U8URL(url) {
            return
        }
        
        let cacheService = CacheService.shared
        if cacheService.hasCachedVideo(url: url) { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            cacheService.cacheVideo(url: url, data: data, title: short.title ?? "Unknown", artist: short.artist ?? "Unknown", coverURL: short.cover)
        } catch {
            print("Failed to cache video: \(error.localizedDescription)")
        }
    }
    
    func stop() {
        cleanup()
        isPlaying = false
        currentShort = nil
    }
    
    private var currentPlayerItem: AVPlayerItem?
    
    private func cleanup() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        if let observer = playbackFinishedObserver {
            NotificationCenter.default.removeObserver(observer)
            playbackFinishedObserver = nil
        }
        
        // Remove all observers for video looping
        NotificationCenter.default.removeObserver(self)
        
        // Remove KVO observers safely
        if let item = currentPlayerItem {
            item.removeObserver(self, forKeyPath: "duration")
            if hasStatusObserver {
                item.removeObserver(self, forKeyPath: "status")
                hasStatusObserver = false
            }
        }
        currentPlayerItem = nil
        nextPlayerItem = nil
        
        player?.pause()
        player = nil
        playerLayer = nil
    }
    
    private func addPeriodicTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
        }
    }
    
    private func addPlaybackObservers(for item: AVPlayerItem) {
        // Observe duration
        item.addObserver(self, forKeyPath: "duration", options: [.new], context: nil)
        
        // Observe playback finished
        playbackFinishedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.isPlaying = false
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "duration", let item = object as? AVPlayerItem, item.duration.seconds.isFinite {
            DispatchQueue.main.async { [weak self] in
                self?.duration = item.duration.seconds
            }
        } else if keyPath == "status", let item = object as? AVPlayerItem {
            DispatchQueue.main.async { [weak self] in
                if item.status == .readyToPlay {
                    // Video is ready, start playing if it's a video
                    if self?.currentShort?.type == "SHORT_VIDEO" {
                        self?.player?.play()
                        self?.isPlaying = true
                    }
                }
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    func getPlayer() -> AVPlayer? {
        return player
    }
}

// Video Player View for fullscreen video playback
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> VideoPlayerContainerView {
        let containerView = VideoPlayerContainerView()
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        containerView.layer.addSublayer(playerLayer)
        containerView.playerLayer = playerLayer
        
        // Set initial frame to fill entire container
        DispatchQueue.main.async {
            playerLayer.frame = containerView.bounds
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: VideoPlayerContainerView, context: Context) {
        // Update frame when view size changes - ensure it fills the entire bounds
        DispatchQueue.main.async {
            let bounds = uiView.bounds
            uiView.playerLayer?.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        }
    }
}

// Container view to hold the player layer
class VideoPlayerContainerView: UIView {
    var playerLayer: AVPlayerLayer?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure player layer fills the entire bounds
        // The videoGravity .resizeAspectFill will handle proper filling
        playerLayer?.frame = bounds
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        // Ensure container fills its superview
        if let superview = superview {
            frame = superview.bounds
        }
    }
    
    override var frame: CGRect {
        didSet {
            // Update player layer when frame changes
            if frame != oldValue {
                playerLayer?.frame = bounds
            }
        }
    }
}

struct SamplesView: View {
    @EnvironmentObject var songManager: SongManager
    @StateObject private var shortsService = ShortsService()
    @StateObject private var samplesPlayer = SamplesPlayer()
    @State private var currentIndex: Int = 0
    @State private var lastPlayedIndex: Int = -1
    @State private var scrollPosition: Int? = 0
    
    private let songLikesService = SongLikesService()
    
    private var shorts: [ShortsModel] {
        shortsService.shorts
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if shortsService.isLoading {
                    VStack {
                        ProgressView()
                            .tint(.white)
                        Text("Loading shorts...")
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.top, 16)
                    }
                } else if !shorts.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(shorts.enumerated()), id: \.element.id) { index, short in
                                    ShortCard(
                                        short: short,
                                        index: index,
                                        currentIndex: $currentIndex,
                                        totalShorts: shorts.count,
                                        currentPlayingShortId: samplesPlayer.currentShort?.id,
                                        onLike: { short in
                                            await self.toggleLike(for: short)
                                        },
                                        onDislike: { short in
                                            await self.toggleDislike(for: short)
                                        }
                                    )
                                    .environmentObject(songManager)
                                    .environmentObject(samplesPlayer)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .id(index)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.paging)
                        .scrollPosition(id: $scrollPosition)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea(.all)
                        .onChange(of: scrollPosition) { oldValue, newValue in
                            if let newIndex = newValue, newIndex != currentIndex && newIndex >= 0 && newIndex < shorts.count {
                                currentIndex = newIndex
                                if newIndex != lastPlayedIndex {
                                    playShort(at: newIndex)
                                    lastPlayedIndex = newIndex
                                }
                            }
                        }
                        .onChange(of: currentIndex) { oldValue, newValue in
                            if newValue != scrollPosition && newValue >= 0 && newValue < shorts.count {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(newValue, anchor: .top)
                                }
                                scrollPosition = newValue
                            }
                        }
                        .onAppear {
                            if lastPlayedIndex == -1 {
                                scrollPosition = 0
                                currentIndex = 0
                                playShort(at: 0)
                                lastPlayedIndex = 0
                            }
                        }
                    }
                } else {
                    VStack {
                        Text("No shorts available")
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.top, 16)
                    }
                }
            }
        }
        .ignoresSafeArea(.all)
        .onAppear {
            // Fetch shorts when view appears
            Task {
                let userId = songManager.getCurrentUserId()
                await shortsService.fetchShorts(userId: userId)
            }
        }
        .onDisappear {
            // Stop playback when leaving samples view
            samplesPlayer.stop()
        }
    }
    
    private func playShort(at index: Int) {
        guard index >= 0 && index < shorts.count else { return }
        let short = shorts[index]
        
        // Load short (video will auto-play when ready, audio needs manual play)
        samplesPlayer.load(short: short)
        
        // For audio, play immediately. For video, it will play when ready
        if short.type != "SHORT_VIDEO" {
            samplesPlayer.play()
        }
        
        // Preload next short
        samplesPlayer.preloadNextShort(currentIndex: index, shorts: shorts)
    }
    
    // MARK: - Like/Dislike Methods
    func toggleLike(for short: ShortsModel) async {
        let userId = songManager.getCurrentUserId()
        var updatedShort = short
        
        // Update local state immediately for responsive UI
        await MainActor.run {
            if !updatedShort.isLiked {
                // First like - set as liked and remove dislike
                updatedShort.isLiked = true
                updatedShort.isDisliked = false
                updatedShort.likesCount += 1
                if updatedShort.dislikesCount > 0 {
                    updatedShort.dislikesCount -= 1
                }
            } else {
                // Already liked - add another like (multiple likes allowed)
                updatedShort.likesCount += 1
            }
        }
        
        // Call API - backend handles the like logic
        do {
            try await songLikesService.likeSong(userId: userId, songId: short.id)
            // Update short in service after successful API call
            await MainActor.run {
                shortsService.updateShort(updatedShort)
                // Update current short if it's the one being played
                if samplesPlayer.currentShort?.id == short.id {
                    samplesPlayer.currentShort = updatedShort
                }
            }
        } catch {
            print("Failed to like short: \(error.localizedDescription)")
            // Revert local state on error
            await MainActor.run {
                shortsService.updateShort(short)
            }
        }
    }
    
    func toggleDislike(for short: ShortsModel) async {
        let userId = songManager.getCurrentUserId()
        var updatedShort = short
        
        // Update local state immediately for responsive UI
        await MainActor.run {
            if !updatedShort.isDisliked {
                // First dislike - set as disliked and remove like
                updatedShort.isDisliked = true
                updatedShort.isLiked = false
                updatedShort.dislikesCount += 1
                if updatedShort.likesCount > 0 {
                    updatedShort.likesCount -= 1
                }
            } else {
                // Already disliked - add another dislike (multiple dislikes allowed)
                updatedShort.dislikesCount += 1
            }
        }
        
        // Call API - backend handles the dislike logic
        do {
            try await songLikesService.dislikeSong(userId: userId, songId: short.id)
            // Update short in service after successful API call
            await MainActor.run {
                shortsService.updateShort(updatedShort)
                // Update current short if it's the one being played
                if samplesPlayer.currentShort?.id == short.id {
                    samplesPlayer.currentShort = updatedShort
                }
            }
        } catch {
            print("Failed to dislike short: \(error.localizedDescription)")
            // Revert local state on error
            await MainActor.run {
                shortsService.updateShort(short)
            }
        }
    }
}

struct ShortCard: View {
    let short: ShortsModel
    let index: Int
    @Binding var currentIndex: Int
    let totalShorts: Int
    let currentPlayingShortId: String?
    let onLike: (ShortsModel) async -> Void
    let onDislike: (ShortsModel) async -> Void
    
    @EnvironmentObject var songManager: SongManager
    @EnvironmentObject var samplesPlayer: SamplesPlayer
    
    // Get the short to display - prioritize currently playing short if this card matches it
    private var displayShort: ShortsModel {
        // Always use the currently playing short if this card matches it
        if let currentPlaying = samplesPlayer.currentShort, currentPlaying.id == short.id {
            return currentPlaying
        }
        return short
    }
    
    // Check if this is the currently playing short
    private var isCurrentlyPlaying: Bool {
        let currentId = currentPlayingShortId ?? samplesPlayer.currentShort?.id
        return currentId == short.id
    }
    
    private var isVideo: Bool {
        displayShort.type == "SHORT_VIDEO"
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video player for SHORT_VIDEO type - full screen
                if isVideo && isCurrentlyPlaying {
                    if let player = samplesPlayer.getPlayer() {
                        VideoPlayerView(player: player)
                            .id(displayShort.id) // Force view update when short changes
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .ignoresSafeArea(.all)
                            .contentShape(Rectangle())
                    } else {
                        // Show loading placeholder while video is loading
                        Rectangle()
                            .fill(Color.black)
                            .overlay {
                                ProgressView()
                                    .tint(.white)
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .ignoresSafeArea(.all)
                    }
                } else {
                    // Cover image for SONG type or when video is not playing
                    let coverToShow = displayShort.cover ?? ""
                    
                    CachedAsyncImage(url: URL(string: coverToShow)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay {
                                ProgressView()
                                    .tint(.white)
                            }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea(.all)
                }
                
                // Dark overlay for better text readability (only for non-video or when video is paused)
                if !isVideo || !isCurrentlyPlaying {
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                
                // Bottom song information
                VStack {
                    Spacer()
                    HStack(alignment: .bottom, spacing: 12) {
                        // Album art thumbnail
                        if let cover = displayShort.cover, !cover.isEmpty {
                            CachedAsyncImage(url: URL(string: cover)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        // Title and artist
                        VStack(alignment: .leading, spacing: 4) {
                            if let title = displayShort.title, !title.isEmpty {
                                Text(title)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            if let artist = displayShort.artist, !artist.isEmpty {
                                Text(artist)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
                
                // Tap area for play/pause - placed before buttons so buttons are on top
                // Use simultaneousGesture so it doesn't block scrolling
                if isCurrentlyPlaying {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .simultaneousGesture(
                            // Tap gesture for play/pause - won't block scrolling
                            TapGesture()
                                .onEnded { _ in
                                    // Toggle play/pause
                                    if samplesPlayer.isPlaying {
                                        samplesPlayer.pause()
                                    } else {
                                        samplesPlayer.play()
                                    }
                                }
                        )
                }
                
                // Right side interaction buttons (always visible, positioned on the right)
                HStack {
                    Spacer()
                    
                    VStack(spacing: 24) {
                        Spacer()
                        
                        // Like button
                        let buttonShort = displayShort
                        VStack(spacing: 8) {
                            Button {
                                Task {
                                    await onLike(buttonShort)
                                }
                            } label: {
                                Image(systemName: buttonShort.isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: songManager.iconSize(for: buttonShort.likesCount, baseSize: 28), weight: .medium))
                                    .foregroundStyle(buttonShort.isLiked ? .pink : .white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.black.opacity(0.15))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(ScaleButtonStyle())
                            
                            Text("\(buttonShort.likesCount)")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                        
                        // Dislike button
                        VStack(spacing: 8) {
                            Button {
                                Task {
                                    await onDislike(buttonShort)
                                }
                            } label: {
                                Image(systemName: buttonShort.isDisliked ? "heart.slash.fill" : "heart.slash")
                                    .font(.system(size: songManager.iconSize(for: buttonShort.dislikesCount, baseSize: 28), weight: .medium))
                                    .foregroundStyle(buttonShort.isDisliked ? .red : .white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.black.opacity(0.15))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(ScaleButtonStyle())
                            
                            Text("\(buttonShort.dislikesCount)")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                        
                        // Comment button
                        VStack(spacing: 8) {
                            Button {
                                // Comment action
                            } label: {
                                Image(systemName: "bubble.right")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.black.opacity(0.15))
                                    .clipShape(Circle())
                            }
                            
                            Text("0")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                        
                        Spacer()
                    }
                    .padding(.trailing, 16)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

// Button style for scale animation on press
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.2 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    SamplesView()
        .environmentObject(SongManager())
        .preferredColorScheme(.dark)
}
