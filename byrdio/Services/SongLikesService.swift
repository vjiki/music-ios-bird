//
//  SongLikesService.swift
//  music
//
//  Created by Nikolai Golubkin on 11/11/25.
//

import Foundation

// MARK: - API Request Models
struct SongLikeRequest: Codable {
    let songId: String
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case songId
        case userId
    }
}

// MARK: - Song Likes Service
class SongLikesService: ObservableObject {
    @Published private(set) var isLoading: Bool = false
    
    // Base API URL - same as SongsService
    private var baseURL: String {
        return "https://music-back-g2u6.onrender.com"
    }
    
    // MARK: - Like Song
    func likeSong(userId: String, songId: String) async throws {
        // Verify parameters are not empty
        guard !userId.isEmpty, !songId.isEmpty else {
            print("Error: userId or songId is empty. userId: '\(userId)', songId: '\(songId)'")
            throw SongLikesServiceError.likeFailed
        }
        
        let url = URL(string: "\(baseURL)/api/v1/song-likes/like")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let likeRequest = SongLikeRequest(songId: songId, userId: userId)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(likeRequest)
        
        // Debug: Print request body for verification
        if let httpBody = request.httpBody,
           let bodyString = String(data: httpBody, encoding: .utf8) {
            print("Like API Request Body: \(bodyString)")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("Like API failed with status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw SongLikesServiceError.likeFailed
        }
    }
    
    // MARK: - Dislike Song
    func dislikeSong(userId: String, songId: String) async throws {
        // Verify parameters are not empty
        guard !userId.isEmpty, !songId.isEmpty else {
            print("Error: userId or songId is empty. userId: '\(userId)', songId: '\(songId)'")
            throw SongLikesServiceError.dislikeFailed
        }
        
        let url = URL(string: "\(baseURL)/api/v1/song-likes/dislike")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let dislikeRequest = SongLikeRequest(songId: songId, userId: userId)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(dislikeRequest)
        
        // Debug: Print request body for verification
        if let httpBody = request.httpBody,
           let bodyString = String(data: httpBody, encoding: .utf8) {
            print("Dislike API Request Body: \(bodyString)")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("Dislike API failed with status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw SongLikesServiceError.dislikeFailed
        }
    }
    
}

// MARK: - Errors
enum SongLikesServiceError: LocalizedError {
    case likeFailed
    case dislikeFailed
    
    var errorDescription: String? {
        switch self {
        case .likeFailed:
            return "Failed to like song"
        case .dislikeFailed:
            return "Failed to dislike song"
        }
    }
}

