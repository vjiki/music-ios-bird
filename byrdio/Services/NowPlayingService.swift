//
//  NowPlayingService.swift
//  music
//
//  Created by Nikolai Golubkin on 11/9/25.
//

import Foundation
import MediaPlayer
import UIKit

// MARK: - Protocol (Interface Segregation)
protocol NowPlayingServiceProtocol {
    func update(song: SongsModel, currentTime: TimeInterval, duration: TimeInterval, isPlaying: Bool)
    func setupRemoteCommandCenter(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onToggle: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void,
        onSeek: @escaping (TimeInterval) -> Void,
        onLike: @escaping () -> Void,
        onDislike: @escaping () -> Void
    )
}

// MARK: - Implementation (Single Responsibility: Lock Screen Widget)
class NowPlayingService: NowPlayingServiceProtocol {
    private var artworkTask: Task<Void, Never>?
    
    func update(song: SongsModel, currentTime: TimeInterval, duration: TimeInterval, isPlaying: Bool) {
        guard !song.title.isEmpty else { return }
        
        var nowPlayingInfo: [String: Any] = [:]
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration > 0 ? duration : 0
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        // Set initial info immediately
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        // Load album art asynchronously
        loadArtwork(for: song) { [weak self] artwork in
            guard let self = self else { return }
            var updatedInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            if let artwork = artwork {
                updatedInfo[MPMediaItemPropertyArtwork] = artwork
            }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
        }
    }
    
    func setupRemoteCommandCenter(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onToggle: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void,
        onSeek: @escaping (TimeInterval) -> Void,
        onLike: @escaping () -> Void,
        onDislike: @escaping () -> Void
    ) {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { _ in
            onPlay()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { _ in
            onPause()
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            onToggle()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { _ in
            onNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { _ in
            onPrevious()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            onSeek(event.positionTime)
            return .success
        }
        
        commandCenter.likeCommand.addTarget { _ in
            onLike()
            return .success
        }
        
        commandCenter.dislikeCommand.addTarget { _ in
            onDislike()
            return .success
        }
    }
    
    // MARK: - Private Methods
    
    private func loadArtwork(for song: SongsModel, completion: @escaping (MPMediaItemArtwork?) -> Void) {
        artworkTask?.cancel()
        
        guard let coverURL = URL(string: song.cover), !song.cover.isEmpty else {
            completion(nil)
            return
        }
        
        artworkTask = Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: coverURL)
                if let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    await MainActor.run {
                        completion(artwork)
                    }
                } else {
                    await MainActor.run {
                        completion(nil)
                    }
                }
            } catch {
                // Ignore cancellation errors (expected when switching songs quickly)
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    // Task was cancelled, which is expected behavior
                    return
                }
                // Only log actual errors, not cancellations
                print("Failed to load album art: \(error)")
                await MainActor.run {
                    completion(nil)
                }
            }
        }
    }
}

