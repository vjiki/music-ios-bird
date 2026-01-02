//
//  PlaylistsService.swift
//  music
//
//  Created by Nikolai Golubkin on 11/11/25.
//

import Foundation

// MARK: - API Response Models
struct PlaylistResponse: Codable, Identifiable {
    let id: String
    let userId: String
    let userName: String
    let userNickname: String
    let name: String
    let description: String?
    let coverUrl: String?
    let type: String
    let isPublic: Bool
    let createdAt: String
    let modifiedAt: String
    var songs: [PlaylistSongResponse]?
    
    var isDefaultLikes: Bool {
        name == "DEFAULT_LIKES"
    }
    
    var isDefaultDislikes: Bool {
        name == "DEFAULT_DISLIKES"
    }
}

struct PlaylistSongResponse: Codable, Identifiable {
    let id: String
    let playlistId: String
    let songId: String
    let songTitle: String
    let songArtist: String
    let songAudioUrl: String
    let songCoverUrl: String
    let position: Int
    let addedAt: String
    let addedBy: String
    
    func toSongsModel(librarySongs: [SongsModel] = []) -> SongsModel {
        // Try to find song in library to get like/dislike information
        if let existingSong = librarySongs.first(where: { $0.id == songId }) {
            // Use existing song's like/dislike info, but update other fields
            return SongsModel(
                id: songId,
                artist: songArtist,
                audio_url: songAudioUrl,
                cover: songCoverUrl,
                title: songTitle,
                isLiked: existingSong.isLiked,
                isDisliked: existingSong.isDisliked,
                likesCount: existingSong.likesCount,
                dislikesCount: existingSong.dislikesCount
            )
        }
        
        // Default values if not found in library
        return SongsModel(
            id: songId,
            artist: songArtist,
            audio_url: songAudioUrl,
            cover: songCoverUrl,
            title: songTitle,
            isLiked: false,
            isDisliked: false,
            likesCount: 0,
            dislikesCount: 0
        )
    }
}

// MARK: - Playlists Service
class PlaylistsService: ObservableObject {
    @Published private(set) var isLoading: Bool = false
    
    // Base API URL - same as SongsService
    private var baseURL: String {
        return "https://music-back-g2u6.onrender.com"
    }
    
    // MARK: - Fetch User Playlists
    func fetchUserPlaylists(userId: String) async throws -> [PlaylistResponse] {
        let url = URL(string: "\(baseURL)/api/v1/playlists/user/\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PlaylistsServiceError.fetchFailed
        }
        
        let decoder = JSONDecoder()
        let playlists = try decoder.decode([PlaylistResponse].self, from: data)
        
        return playlists
    }
    
    // MARK: - Fetch Playlist with Songs
    func fetchPlaylist(playlistId: String) async throws -> PlaylistResponse {
        let url = URL(string: "\(baseURL)/api/v1/playlists/\(playlistId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PlaylistsServiceError.fetchFailed
        }
        
        let decoder = JSONDecoder()
        let playlist = try decoder.decode(PlaylistResponse.self, from: data)
        
        return playlist
    }
    
    // MARK: - Add Song to Playlist
    func addSongToPlaylist(playlistId: String, songId: String, userId: String) async throws {
        let url = URL(string: "\(baseURL)/api/v1/playlists/\(playlistId)/songs")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        struct AddSongRequest: Codable {
            let songId: String
            let addedBy: String
        }
        
        let addRequest = AddSongRequest(songId: songId, addedBy: userId)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(addRequest)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PlaylistsServiceError.addSongFailed
        }
    }
    
    // MARK: - Remove Song from Playlist
    func removeSongFromPlaylist(playlistId: String, songId: String) async throws {
        let url = URL(string: "\(baseURL)/api/v1/playlists/\(playlistId)/songs/\(songId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PlaylistsServiceError.removeSongFailed
        }
    }
}

// MARK: - Errors
enum PlaylistsServiceError: LocalizedError {
    case fetchFailed
    case addSongFailed
    case removeSongFailed
    
    var errorDescription: String? {
        switch self {
        case .fetchFailed:
            return "Failed to fetch playlists"
        case .addSongFailed:
            return "Failed to add song to playlist"
        case .removeSongFailed:
            return "Failed to remove song from playlist"
        }
    }
}

