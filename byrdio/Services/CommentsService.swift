//
//  CommentsService.swift
//  byrdio
//
//  Created by Nikolai Golubkin on 14. 1. 2026..
//

import Foundation

// MARK: - Comments Service
class CommentsService: ObservableObject {
    @Published private(set) var isLoading: Bool = false
    
    // Base API URL
    private var baseURL: String {
        return "https://music-back-g2u6.onrender.com"
    }
    
    // MARK: - Fetch Comments
    func fetchComments(trackId: String, userId: String? = nil) async throws -> [CommentModel] {
        isLoading = true
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        var urlString = "\(baseURL)/api/v1/comments/track/\(trackId)"
        if let userId = userId {
            urlString += "?userId=\(userId)"
        }
        
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CommentsServiceError.fetchFailed
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let comments = try decoder.decode([CommentModel].self, from: data)
        
        return comments
    }
    
    // MARK: - Add Comment
    func addComment(trackId: String, userId: String, content: String) async throws -> CommentModel {
        isLoading = true
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        let url = URL(string: "\(baseURL)/api/v1/comments")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let commentRequest = AddCommentRequest(trackId: trackId, userId: userId, content: content)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(commentRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CommentsServiceError.addFailed
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let comment = try decoder.decode(CommentModel.self, from: data)
        
        return comment
    }
    
    // MARK: - Add Reply
    func addReply(trackId: String, userId: String, content: String, parentId: String) async throws -> CommentModel {
        isLoading = true
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        let url = URL(string: "\(baseURL)/api/v1/comments")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let replyRequest = AddCommentRequest(trackId: trackId, userId: userId, content: content, parentId: parentId)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(replyRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CommentsServiceError.addFailed
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let reply = try decoder.decode(CommentModel.self, from: data)
        
        return reply
    }
    
    // MARK: - Add Reaction
    func addReaction(commentId: String, userId: String, reaction: String = "LIKE") async throws {
        let url = URL(string: "\(baseURL)/api/v1/comments/reactions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let reactionRequest = AddReactionRequest(commentId: commentId, userId: userId, reaction: reaction)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(reactionRequest)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CommentsServiceError.reactionFailed
        }
    }
    
    // MARK: - Remove Reaction
    func removeReaction(commentId: String, userId: String) async throws {
        let url = URL(string: "\(baseURL)/api/v1/comments/\(commentId)/reactions/\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CommentsServiceError.reactionFailed
        }
    }
    
    // MARK: - Remove Comment
    func removeComment(commentId: String) async throws {
        let url = URL(string: "\(baseURL)/api/v1/comments/\(commentId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CommentsServiceError.removeFailed
        }
    }
}

// MARK: - Errors
enum CommentsServiceError: LocalizedError {
    case fetchFailed
    case addFailed
    case reactionFailed
    case removeFailed
    
    var errorDescription: String? {
        switch self {
        case .fetchFailed:
            return "Failed to fetch comments"
        case .addFailed:
            return "Failed to add comment"
        case .reactionFailed:
            return "Failed to add/remove reaction"
        case .removeFailed:
            return "Failed to remove comment"
        }
    }
}
