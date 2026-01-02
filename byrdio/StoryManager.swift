//
//  StoryManager.swift
//  music
//
//  Created by Nikolai Golubkin on 11/9/25.
//

import SwiftUI
import Foundation

class StoryManager: ObservableObject {
    @Published private(set) var stories: [MusicStory] = []
    @Published private(set) var userStories: [MusicStory] = []
    @Published private(set) var isLoading: Bool = false
    
    private let storiesService = StoriesService()
    private let currentUserId = "current_user"
    private let currentUserName = "You"
    private let currentUserProfileImage: String? = nil
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    init(songs: [SongsModel] = sampleSongs) {
        // Keep fallback for now
        loadStories(from: songs)
    }
    
    func createStory(with song: SongsModel) {
        let newStory = MusicStory(
            userId: currentUserId,
            userName: currentUserName,
            profileImageURL: currentUserProfileImage,
            song: song,
            timestamp: Date(),
            isViewed: false,
            storyImageURL: nil,
            storyPreviewURL: nil
        )
        
        userStories.insert(newStory, at: 0)
        stories.insert(newStory, at: 0)
        
        // Keep only last 24 hours of stories
        let dayAgo = Date().addingTimeInterval(-24 * 60 * 60)
        userStories = userStories.filter { $0.timestamp > dayAgo }
        stories = stories.filter { $0.timestamp > dayAgo }
    }
    
    func markStoryAsViewed(_ storyId: String) {
        if let index = stories.firstIndex(where: { $0.id == storyId }) {
            let story = stories[index]
            let updated = MusicStory(
                id: story.id,
                userId: story.userId,
                userName: story.userName,
                profileImageURL: story.profileImageURL,
                song: story.song,
                timestamp: story.timestamp,
                isViewed: true,
                storyImageURL: story.storyImageURL,
                storyPreviewURL: story.storyPreviewURL
            )
            stories[index] = updated
        }
        
        if let index = userStories.firstIndex(where: { $0.id == storyId }) {
            let story = userStories[index]
            let updated = MusicStory(
                id: story.id,
                userId: story.userId,
                userName: story.userName,
                profileImageURL: story.profileImageURL,
                song: story.song,
                timestamp: story.timestamp,
                isViewed: true,
                storyImageURL: story.storyImageURL,
                storyPreviewURL: story.storyPreviewURL
            )
            userStories[index] = updated
        }
    }
    
    var hasUnviewedStories: Bool {
        userStories.contains { !$0.isViewed }
    }
    
    func updateStories(from songs: [SongsModel]) {
        // Keep fallback for now
        loadStories(from: songs)
    }
    
    func fetchStoriesFromAPI(currentUserId: String, followers: [FollowerResponse], allSongs: [SongsModel]) async {
        await MainActor.run {
            isLoading = true
        }
        
        var allStories: [MusicStory] = []
        
        // Fetch stories for current user
        do {
            let userStories = try await storiesService.fetchStories(for: currentUserId)
            let mappedStories = mapStories(userStories, allSongs: allSongs)
            allStories.append(contentsOf: mappedStories)
        } catch {
            print("Failed to fetch user stories: \(error.localizedDescription)")
        }
        
        // Fetch stories for each follower
        for follower in followers {
            do {
                let followerStories = try await storiesService.fetchStories(for: follower.followerId)
                let mappedStories = mapStories(followerStories, allSongs: allSongs)
                allStories.append(contentsOf: mappedStories)
            } catch {
                print("Failed to fetch stories for follower \(follower.followerId): \(error.localizedDescription)")
            }
        }
        
        // Sort by creation date (newest first)
        allStories.sort { $0.timestamp > $1.timestamp }
        
        await MainActor.run {
            self.stories = allStories
            self.isLoading = false
        }
    }
    
    private func mapStories(_ storyResponses: [StoryResponse], allSongs: [SongsModel]) -> [MusicStory] {
        return storyResponses.compactMap { storyResponse in
            // Find the song by ID or create a placeholder
            let song: SongsModel
            if let songId = storyResponse.songId,
               let foundSong = allSongs.first(where: { $0.id == songId }) {
                song = foundSong
            } else if let songTitle = storyResponse.songTitle,
                      let songArtist = storyResponse.songArtist {
                // Create a placeholder song if not found
                song = SongsModel(
                    id: storyResponse.songId ?? UUID().uuidString,
                    artist: songArtist,
                    audio_url: "",
                    cover: storyResponse.previewUrl ?? "",
                    title: songTitle,
                    isLiked: false,
                    isDisliked: false,
                    likesCount: 0,
                    dislikesCount: 0
                )
            } else {
                // Skip stories without song information
                return nil
            }
            
            // Parse date
            let timestamp = dateFormatter.date(from: storyResponse.createdAt) ?? Date()
            
            return MusicStory(
                id: storyResponse.id,
                userId: storyResponse.userId,
                userName: storyResponse.userNickname,
                profileImageURL: storyResponse.userAvatarUrl,
                song: song,
                timestamp: timestamp,
                isViewed: storyResponse.viewsCount > 0,
                storyImageURL: storyResponse.imageUrl,
                storyPreviewURL: storyResponse.previewUrl
            )
        }
    }
    
    private func loadStories(from songs: [SongsModel]) {
        // Sample stories for demo (fallback)
        let sampleStories = songs.prefix(5).enumerated().map { index, song in
            MusicStory(
                userId: "user_\(index)",
                userName: "User \(index + 1)",
                profileImageURL: song.cover,
                song: song,
                timestamp: Date().addingTimeInterval(-Double(index) * 3600),
                isViewed: index > 2,
                storyImageURL: nil,
                storyPreviewURL: nil
            )
        }
        
        stories = sampleStories
    }
}

