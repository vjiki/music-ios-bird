//
//  AudioPlayerService.swift
//  music
//
//  Created by Nikolai Golubkin on 11/9/25.
//

import Foundation
import AVFoundation

// MARK: - Protocol (Interface Segregation)
protocol AudioPlayerServiceProtocol {
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var isPlaying: Bool { get }
    
    func play()
    func pause()
    func seek(to time: TimeInterval)
    func load(url: URL, title: String?, artist: String?, coverURL: String?)
    func preloadNext(url: URL)
    func stop()
    
    var onTimeUpdate: ((TimeInterval) -> Void)? { get set }
    var onDurationUpdate: ((TimeInterval) -> Void)? { get set }
    var onPlaybackFinished: (() -> Void)? { get set }
    var onPlaybackStateChanged: ((Bool) -> Void)? { get set }
}

// MARK: - Implementation (Single Responsibility: Audio Playback)
class AudioPlayerService: AudioPlayerServiceProtocol {
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var playbackFinishedObserver: Any?
    private var nextPlayerItem: AVPlayerItem?
    
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    private(set) var isPlaying: Bool = false
    
    var onTimeUpdate: ((TimeInterval) -> Void)?
    var onDurationUpdate: ((TimeInterval) -> Void)?
    var onPlaybackFinished: (() -> Void)?
    var onPlaybackStateChanged: ((Bool) -> Void)?
    
    init() {
        configureAudioSession()
    }
    
    deinit {
        cleanup()
    }
    
    func play() {
        player?.play()
        isPlaying = true
        onPlaybackStateChanged?(true)
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        onPlaybackStateChanged?(false)
    }
    
    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clampedTime = min(max(time, 0), duration)
        let cmTime = CMTime(seconds: clampedTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clampedTime
    }
    
    func load(url: URL, title: String? = nil, artist: String? = nil, coverURL: String? = nil) {
        cleanup()
        
        // Check if URL is an m3u8 (HLS streaming) file
        let isM3U8 = isM3U8URL(url)
        let finalURL: URL
        
        if isM3U8 {
            // For m3u8 files, use the original URL directly (no caching)
            // AVPlayer natively supports HLS streaming
            finalURL = url
        } else {
            // For regular audio files, check cache first
            let cacheService = CacheService.shared
            
            if let cachedURL = cacheService.getCachedAudioURL(url: url) {
                finalURL = cachedURL
            } else {
                finalURL = url
                // Cache audio in background with metadata
                Task {
                    await cacheAudio(url: url, title: title, artist: artist, coverURL: coverURL)
                }
            }
        }
        
        let playerItem = AVPlayerItem(url: finalURL)
        
        // Configure for better buffering
        playerItem.preferredForwardBufferDuration = 30.0
        player = AVPlayer(playerItem: playerItem)
        
        // Configure player to minimize stalling
        if let player = player {
            player.automaticallyWaitsToMinimizeStalling = true
        }
        
        addPlaybackObservers(for: playerItem)
        addPeriodicTimeObserver()
        
        currentTime = 0
        duration = 0
    }
    
    func preloadNext(url: URL) {
        // Clear previous preloaded item
        nextPlayerItem = nil
        
        // Check if URL is an m3u8 (HLS streaming) file
        let isM3U8 = isM3U8URL(url)
        let finalURL: URL
        
        if isM3U8 {
            // For m3u8 files, use the original URL directly (no caching)
            finalURL = url
        } else {
            // For regular audio files, check cache first
            let cacheService = CacheService.shared
            
            if let cachedURL = cacheService.getCachedAudioURL(url: url) {
                finalURL = cachedURL
            } else {
                finalURL = url
            }
        }
        
        // Create and preload the next item
        let nextItem = AVPlayerItem(url: finalURL)
        nextItem.preferredForwardBufferDuration = 30.0
        
        // Preload the asset
        let asset = nextItem.asset
        asset.loadValuesAsynchronously(forKeys: ["playable", "duration"]) {
            // Item is preloaded and ready
        }
        
        nextPlayerItem = nextItem
    }
    
    /// Checks if a URL points to an m3u8 (HLS) playlist file
    private func isM3U8URL(_ url: URL) -> Bool {
        let urlString = url.absoluteString.lowercased()
        return urlString.hasSuffix(".m3u8") || urlString.contains(".m3u8?") || urlString.contains(".m3u8#")
    }
    
    private func cacheAudio(url: URL, title: String?, artist: String?, coverURL: String?) async {
        // Skip caching for m3u8 files (HLS streaming)
        if isM3U8URL(url) {
            return
        }
        
        let cacheService = CacheService.shared
        
        // Skip if already cached
        if cacheService.hasCachedAudio(url: url) {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            cacheService.cacheAudio(url: url, data: data, title: title, artist: artist, coverURL: coverURL)
        } catch {
            print("Failed to cache audio: \(error.localizedDescription)")
        }
    }
    
    func stop() {
        cleanup()
        isPlaying = false
        onPlaybackStateChanged?(false)
    }
    
    // MARK: - Private Methods
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session configuration failed: \(error)")
        }
    }
    
    private func addPeriodicTimeObserver() {
        guard let player else { return }
        let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            
            let currentSeconds = time.seconds
            if currentSeconds.isFinite {
                self.currentTime = currentSeconds
                self.onTimeUpdate?(currentSeconds)
            }
            
            if let durationSeconds = player.currentItem?.duration.seconds, durationSeconds.isFinite {
                if abs(self.duration - durationSeconds) > 0.1 {
                    self.duration = durationSeconds
                    self.onDurationUpdate?(durationSeconds)
                }
            }
        }
    }
    
    private func addPlaybackObservers(for item: AVPlayerItem) {
        playbackFinishedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.onPlaybackFinished?()
        }
    }
    
    private func cleanup() {
        if let timeObserverToken, let player {
            player.removeTimeObserver(timeObserverToken)
        }
        timeObserverToken = nil
        
        if let playbackFinishedObserver {
            NotificationCenter.default.removeObserver(playbackFinishedObserver)
        }
        playbackFinishedObserver = nil
        
        nextPlayerItem = nil
        
        player?.pause()
        player = nil
    }
}

