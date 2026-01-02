//
//  StoriesService.swift
//  music
//
//  Created by Nikolai Golubkin on 11/11/25.
//

import Foundation

// MARK: - API Response Models
struct StoryResponse: Codable {
    let id: String
    let userId: String
    let userNickname: String
    let userAvatarUrl: String?
    let imageUrl: String?
    let previewUrl: String?
    let storyType: String
    let songId: String?
    let songTitle: String?
    let songArtist: String?
    let caption: String?
    let location: String?
    let viewsCount: Int
    let createdAt: String
    let expiresAt: String
    let isExpired: Bool
}

struct FollowerResponse: Codable {
    let followerId: String
    let followerEmail: String
    let followerNickname: String
    let followerAvatarUrl: String?
    let followedAt: String
}

// MARK: - Stories Service
class StoriesService: ObservableObject {
    @Published private(set) var isLoading: Bool = false
    
    // Base API URL - same as SongsService
    private var baseURL: String {
        return "https://music-back-g2u6.onrender.com"
    }
    
    func fetchStories(for userId: String) async throws -> [StoryResponse] {
        let url = URL(string: "\(baseURL)/api/v1/stories/user/\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw StoriesServiceError.fetchFailed
        }
        
        let decoder = JSONDecoder()
        let stories = try decoder.decode([StoryResponse].self, from: data)
        
        // Filter out expired stories
        return stories.filter { !$0.isExpired }
    }
    
    func fetchFollowers(for userId: String) async throws -> [FollowerResponse] {
        let url = URL(string: "\(baseURL)/api/v1/followers/\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw StoriesServiceError.fetchFailed
        }
        
        let decoder = JSONDecoder()
        let followers = try decoder.decode([FollowerResponse].self, from: data)
        
        return followers
    }
}

// MARK: - Errors
enum StoriesServiceError: LocalizedError {
    case fetchFailed
    
    var errorDescription: String? {
        switch self {
        case .fetchFailed:
            return "Failed to fetch stories"
        }
    }
}

