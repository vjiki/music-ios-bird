//
//  SongsService.swift
//  music
//
//  Created by Nikolai Golubkin on 11/9/25.
//

import Foundation
import Combine

// MARK: - Pagination Response Model
struct CursorPageResponse<T: Codable>: Codable {
    let items: [T]
    let nextCursor: String?
    let hasNext: Bool
    let limit: Int?
}

// MARK: - Protocol (Interface Segregation)
protocol SongsServiceProtocol {
    var songs: [SongsModel] { get }
    var isLoading: Bool { get }
    var hasMore: Bool { get }
    var nextCursor: String? { get }
    
    func fetchSongs(userId: String) async
    func fetchSongsPage(userId: String, limit: Int, cursor: String?) async throws -> CursorPageResponse<SongsModel>
    func loadMoreSongs(userId: String) async
    func searchSongs(userId: String, query: String, limit: Int, cursor: String?) async throws -> CursorPageResponse<SongsModel>
    func fetchBand(userId: String, name: String, limit: Int) async throws -> CursorPageResponse<BandResponse>
}

// MARK: - Implementation (Single Responsibility: Songs Fetching)
class SongsService: ObservableObject, SongsServiceProtocol {
    @Published private(set) var songs: [SongsModel] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var hasMore: Bool = false
    @Published private(set) var nextCursor: String? = nil
    
    private var baseURL: String {
        return "https://music-back-g2u6.onrender.com"
    }
    
    private let defaultLimit = 20
    
    init() {
        // Initialize with fallback songs
        self.songs = sampleSongs
    }
    
    func fetchSongs(userId: String) async {
        // Reset pagination state and fetch first page
        await MainActor.run {
            isLoading = true
            songs = []
            nextCursor = nil
            hasMore = false
        }
        
        do {
            let page = try await fetchSongsPage(userId: userId, limit: defaultLimit, cursor: nil)
            await MainActor.run {
                self.songs = page.items
                self.nextCursor = page.nextCursor
                self.hasMore = page.hasNext
                self.isLoading = false
            }
        } catch {
            // If API fails, use fallback songs
            print("Failed to fetch songs from API: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                print("URL Error: \(urlError.localizedDescription)")
            }
            print("Using fallback songs from iOS application")
            
            await MainActor.run {
                self.songs = sampleSongs
                self.isLoading = false
                self.hasMore = false
                self.nextCursor = nil
            }
        }
    }
    
    func fetchSongsPage(userId: String, limit: Int, cursor: String?) async throws -> CursorPageResponse<SongsModel> {
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/songs/\(userId)/page")
        urlComponents?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        if let cursor = cursor {
            urlComponents?.queryItems?.append(URLQueryItem(name: "cursor", value: cursor))
        }
        
        guard let url = urlComponents?.url else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // Check if response is successful
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Decode JSON response
        let decoder = JSONDecoder()
        do {
            let pageResponse = try decoder.decode(CursorPageResponse<SongsModel>.self, from: data)
            return pageResponse
        } catch let decodingError as DecodingError {
            // Print detailed decoding error
            print("Failed to decode songs page: \(decodingError)")
            if let dataString = String(data: data, encoding: .utf8) {
                print("Response data: \(String(dataString.prefix(500)))")
            }
            throw decodingError
        }
    }
    
    func loadMoreSongs(userId: String) async {
        guard !isLoading && hasMore, let cursor = nextCursor else {
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let page = try await fetchSongsPage(userId: userId, limit: defaultLimit, cursor: cursor)
            await MainActor.run {
                self.songs.append(contentsOf: page.items)
                self.nextCursor = page.nextCursor
                self.hasMore = page.hasNext
                self.isLoading = false
            }
        } catch {
            print("Failed to load more songs: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    func searchSongs(userId: String, query: String, limit: Int = 20, cursor: String? = nil) async throws -> CursorPageResponse<SongsModel> {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw URLError(.badURL)
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/search/songs/\(userId)")
        urlComponents?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        if let cursor = cursor {
            urlComponents?.queryItems?.append(URLQueryItem(name: "cursor", value: cursor))
        }
        
        guard let url = urlComponents?.url else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // Check if response is successful
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Decode JSON response
        let decoder = JSONDecoder()
        do {
            let pageResponse = try decoder.decode(CursorPageResponse<SongsModel>.self, from: data)
            return pageResponse
        } catch let decodingError as DecodingError {
            // Print detailed decoding error
            print("Failed to decode search results: \(decodingError)")
            if let dataString = String(data: data, encoding: .utf8) {
                print("Response data: \(String(dataString.prefix(500)))")
            }
            throw decodingError
        }
    }
    
    func fetchBand(userId: String, name: String, limit: Int = 20) async throws -> CursorPageResponse<BandResponse> {
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/bands/page")
        urlComponents?.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        guard let url = urlComponents?.url else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // Check if response is successful
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Decode JSON response
        let decoder = JSONDecoder()
        do {
            let pageResponse = try decoder.decode(CursorPageResponse<BandResponse>.self, from: data)
            return pageResponse
        } catch let decodingError as DecodingError {
            // Print detailed decoding error
            print("Failed to decode band response: \(decodingError)")
            if let dataString = String(data: data, encoding: .utf8) {
                print("Response data: \(String(dataString.prefix(500)))")
            }
            throw decodingError
        }
    }
}

// MARK: - Errors
enum SongsServiceError: LocalizedError {
    case emptyResponse
    
    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "API returned empty response"
        }
    }
}

