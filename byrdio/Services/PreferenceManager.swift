//
//  PreferenceManager.swift
//  music
//
//  Created by Nikolai Golubkin on 11/9/25.
//

import Foundation
import Combine

// MARK: - Protocol (Interface Segregation)
protocol PreferenceManagerProtocol {
    func isLiked(_ song: SongsModel) -> Bool
    func isDisliked(_ song: SongsModel) -> Bool
    func toggleLike(_ song: SongsModel, userId: String) async -> SongsModel
    func toggleDislike(_ song: SongsModel, userId: String) async -> SongsModel
    func getLikedSongs(from songs: [SongsModel]) -> [SongsModel]
    func getDislikedSongs(from songs: [SongsModel]) -> [SongsModel]
}

// MARK: - Implementation (Single Responsibility: User Preferences)
class PreferenceManager: ObservableObject, PreferenceManagerProtocol {
    private let songLikesService = SongLikesService()
    
    func isLiked(_ song: SongsModel) -> Bool {
        song.isLiked
    }
    
    func isDisliked(_ song: SongsModel) -> Bool {
        song.isDisliked
    }
    
    func toggleLike(_ song: SongsModel, userId: String) async -> SongsModel {
        // Update local state immediately for responsive UI
        // Can only like, cannot unlike - allow multiple likes
        var updatedSong = song
        if !updatedSong.isLiked {
            // First like - set as liked and remove dislike
            updatedSong.isLiked = true
            updatedSong.isDisliked = false
            updatedSong.likesCount += 1
            if updatedSong.dislikesCount > 0 {
                updatedSong.dislikesCount -= 1
            }
        } else {
            // Already liked - add another like (multiple likes allowed)
            updatedSong.likesCount += 1
        }
        
        // Call API - backend handles the like logic
        do {
            try await songLikesService.likeSong(userId: userId, songId: song.id)
        } catch {
            print("Failed to like song: \(error.localizedDescription)")
            // Revert local state on error
            updatedSong.isLiked = song.isLiked
            updatedSong.isDisliked = song.isDisliked
            updatedSong.likesCount = song.likesCount
            updatedSong.dislikesCount = song.dislikesCount
        }
        
        return updatedSong
    }
    
    func toggleDislike(_ song: SongsModel, userId: String) async -> SongsModel {
        // Update local state immediately for responsive UI
        // Can only dislike, cannot undislike - allow multiple dislikes
        var updatedSong = song
        if !updatedSong.isDisliked {
            // First dislike - set as disliked and remove like
            updatedSong.isDisliked = true
            updatedSong.isLiked = false
            updatedSong.dislikesCount += 1
            if updatedSong.likesCount > 0 {
                updatedSong.likesCount -= 1
            }
        } else {
            // Already disliked - add another dislike (multiple dislikes allowed)
            updatedSong.dislikesCount += 1
        }
        
        // Call API - backend handles the dislike logic
        do {
            try await songLikesService.dislikeSong(userId: userId, songId: song.id)
        } catch {
            print("Failed to dislike song: \(error.localizedDescription)")
            // Revert local state on error
            updatedSong.isDisliked = song.isDisliked
            updatedSong.isLiked = song.isLiked
            updatedSong.likesCount = song.likesCount
            updatedSong.dislikesCount = song.dislikesCount
        }
        
        return updatedSong
    }
    
    func getLikedSongs(from songs: [SongsModel]) -> [SongsModel] {
        songs.filter { $0.isLiked }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
    
    func getDislikedSongs(from songs: [SongsModel]) -> [SongsModel] {
        songs.filter { $0.isDisliked }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
    
    // MARK: - My Vibe Preferences
    private let selectedMoodsKey = "selectedMoods"
    
    func getSelectedMoods() -> Set<String> {
        if let data = UserDefaults.standard.data(forKey: selectedMoodsKey),
           let moodsArray = try? JSONDecoder().decode([String].self, from: data) {
            return Set(moodsArray)
        }
        return []
    }
    
    func saveSelectedMoods(_ moods: Set<String>) {
        let moodsArray = Array(moods)
        if let data = try? JSONEncoder().encode(moodsArray) {
            UserDefaults.standard.set(data, forKey: selectedMoodsKey)
        }
    }
}
