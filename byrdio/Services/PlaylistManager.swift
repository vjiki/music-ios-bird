//
//  PlaylistManager.swift
//  music
//
//  Created by Nikolai Golubkin on 11/9/25.
//

import Foundation

// MARK: - Protocol (Interface Segregation)
protocol PlaylistManagerProtocol {
    var currentPlaylist: [SongsModel] { get }
    var currentIndex: Int? { get }
    var isShuffling: Bool { get }
    var repeatMode: RepeatMode { get }
    
    func configurePlaylist(_ playlist: [SongsModel], selecting song: SongsModel)
    func getCurrentSong() -> SongsModel?
    func getNextIndex() -> Int?
    func getPreviousIndex() -> Int?
    func toggleShuffle()
    func cycleRepeatMode()
    func setCurrentIndex(_ index: Int)
}

// MARK: - Repeat Mode Enum
enum RepeatMode: Int, CaseIterable {
    case none
    case all
    case one
    
    mutating func cycle() {
        switch self {
        case .none: self = .all
        case .all: self = .one
        case .one: self = .none
        }
    }
    
    var iconName: String {
        switch self {
        case .none, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

// MARK: - Implementation (Single Responsibility: Playlist Management)
class PlaylistManager: PlaylistManagerProtocol {
    private(set) var currentPlaylist: [SongsModel] = []
    private(set) var currentIndex: Int?
    private(set) var isShuffling: Bool = false
    private(set) var repeatMode: RepeatMode = .none
    
    private var originalPlaylist: [SongsModel] = []
    
    func configurePlaylist(_ playlist: [SongsModel], selecting song: SongsModel) {
        guard !playlist.isEmpty else { return }
        
        originalPlaylist = playlist
        let selectedID = song.id
        
        if isShuffling {
            currentPlaylist = shuffledPlaylist(from: playlist, keeping: song)
        } else {
            currentPlaylist = playlist
        }
        
        currentIndex = currentPlaylist.firstIndex(where: { $0.id == selectedID })
    }
    
    func getCurrentSong() -> SongsModel? {
        guard let currentIndex,
              currentPlaylist.indices.contains(currentIndex) else {
            return nil
        }
        return currentPlaylist[currentIndex]
    }
    
    func getNextIndex() -> Int? {
        guard let currentIndex, !currentPlaylist.isEmpty else { return nil }
        
        let nextIndex = currentIndex + 1
        if nextIndex >= currentPlaylist.count {
            return repeatMode == .all ? 0 : nil
        }
        return nextIndex
    }
    
    func getPreviousIndex() -> Int? {
        guard let currentIndex, !currentPlaylist.isEmpty else { return nil }
        
        let previousIndex = currentIndex - 1
        if currentPlaylist.indices.contains(previousIndex) {
            return previousIndex
        } else if let lastIndex = currentPlaylist.indices.last {
            return lastIndex
        }
        return nil
    }
    
    func toggleShuffle() {
        guard !originalPlaylist.isEmpty, let currentSong = getCurrentSong() else { return }
        
        isShuffling.toggle()
        
        if isShuffling {
            currentPlaylist = shuffledPlaylist(from: originalPlaylist, keeping: currentSong)
        } else {
            currentPlaylist = originalPlaylist
        }
        
        currentIndex = currentPlaylist.firstIndex(where: { $0.id == currentSong.id })
    }
    
    func cycleRepeatMode() {
        repeatMode.cycle()
    }
    
    func setCurrentIndex(_ index: Int) {
        guard currentPlaylist.indices.contains(index) else { return }
        currentIndex = index
    }
    
    // MARK: - Private Methods
    
    private func shuffledPlaylist(from playlist: [SongsModel], keeping currentSong: SongsModel) -> [SongsModel] {
        var remainingSongs = playlist.filter { $0.id != currentSong.id }
        remainingSongs.shuffle()
        return [currentSong] + remainingSongs
    }
}

