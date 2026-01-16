//
//  MessagesService.swift
//  music
//
//  Created by Nikolai Golubkin on 11/11/25.
//

import Foundation

// MARK: - API Response Models
struct ChatResponse: Codable, Identifiable {
    let chatId: String
    let chatType: String
    let title: String
    let avatarUrl: String?
    let lastMessagePreview: String?
    let lastMessageAt: String?
    let lastMessageSenderId: String?
    let lastMessageSenderName: String?
    let unreadCount: Int
    let isMuted: Bool
    let updatedAt: String
    let participants: [ChatParticipant]
    
    var id: String { chatId }
}

struct ChatDetailResponse: Codable {
    let id: String
    let type: String
    let title: String?
    let description: String?
    let avatarUrl: String?
    let ownerId: String?
    let ownerNickname: String?
    let isEncrypted: Bool
    let isArchived: Bool
    let isMuted: Bool
    let createdAt: String
    let updatedAt: String
    let participants: [ChatDetailParticipant]
}

struct ChatDetailParticipant: Codable {
    let userId: String
    let userEmail: String
    let userNickname: String
    let userAvatarUrl: String?
    let role: String
    let joinedAt: String
    let isMuted: Bool
}

struct ChatParticipant: Codable {
    let userId: String
    let userNickname: String
    let userAvatarUrl: String?
}

struct MessageResponse: Codable, Identifiable {
    let id: String
    let chatId: String
    let senderId: String
    let senderEmail: String
    let senderNickname: String
    let senderAvatarUrl: String?
    let replyToId: String?
    let messageType: String
    let content: String
    let songId: String?
    let attachmentCount: Int
    let isEdited: Bool
    let isDeleted: Bool
    let createdAt: String
    let updatedAt: String
}

struct MessageReactionResponse: Codable {
    let messageId: String
    let userId: String
    let emoji: String
    let createdAt: String
}

// MARK: - Request Models
struct CreateMessageRequest: Codable {
    let chatId: String
    let senderId: String
    let content: String
    let messageType: String
    let replyToId: String?
    let songId: String?
    let attachmentCount: Int?
}

struct CreateChatRequest: Codable {
    let type: String
    let title: String?
    let description: String?
    let avatarUrl: String?
    let ownerId: String?
    let participantIds: [String]
    let isEncrypted: Bool
}

struct MessageReactionRequest: Codable {
    let messageId: String
    let userId: String
    let emoji: String
}

// MARK: - Messages Service
class MessagesService: ObservableObject {
    @Published private(set) var isLoading: Bool = false
    
    // Base API URL - same as SongsService
    private var baseURL: String {
        return "https://music-back-g2u6.onrender.com"
    }
    
    func fetchChats(for userId: String) async throws -> [ChatResponse] {
        let url = URL(string: "\(baseURL)/api/v1/chats/user/\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MessagesServiceError.fetchFailed
        }
        
        let decoder = JSONDecoder()
        let chats = try decoder.decode([ChatResponse].self, from: data)
        
        return chats
    }
    
    func fetchMessages(chatId: String, userId1: String, userId2: String) async throws -> [MessageResponse] {
        let urlString = "\(baseURL)/api/v1/messages/chat/\(chatId)?userId1=\(userId1)&userId2=\(userId2)"
        guard let url = URL(string: urlString) else {
            throw MessagesServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MessagesServiceError.fetchFailed
        }
        
        let decoder = JSONDecoder()
        let messages = try decoder.decode([MessageResponse].self, from: data)
        
        // Filter out deleted messages and sort by creation date (oldest first)
        return messages
            .filter { !$0.isDeleted }
            .sorted { 
                let date1 = parseDate($0.createdAt) ?? Date.distantPast
                let date2 = parseDate($1.createdAt) ?? Date.distantPast
                return date1 < date2
            }
    }
    
    func fetchMessagesPage(chatId: String, limit: Int = 20, cursor: String? = nil) async throws -> CursorPageResponse<MessageResponse> {
        var urlString = "\(baseURL)/api/v1/messages/chat/\(chatId)/page?limit=\(limit)"
        if let cursor = cursor {
            urlString += "&cursor=\(cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor)"
        }
        
        guard let url = URL(string: urlString) else {
            throw MessagesServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MessagesServiceError.fetchFailed
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(CursorPageResponse<MessageResponse>.self, from: data)
    }
    
    // MARK: - Chat Operations
    func fetchChatById(_ chatId: String) async throws -> ChatDetailResponse {
        guard let url = URL(string: "\(baseURL)/api/v1/chats/\(chatId)") else {
            throw MessagesServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MessagesServiceError.fetchFailed
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ChatDetailResponse.self, from: data)
    }
    
    func createChat(_ request: CreateChatRequest) async throws -> ChatDetailResponse {
        guard let url = URL(string: "\(baseURL)/api/v1/chats") else {
            throw MessagesServiceError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MessagesServiceError.fetchFailed
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ChatDetailResponse.self, from: data)
    }
    
    func deleteChat(_ chatId: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/v1/chats/\(chatId)") else {
            throw MessagesServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MessagesServiceError.fetchFailed
        }
    }
    
    // MARK: - Message Operations
    func sendMessage(_ request: CreateMessageRequest) async throws -> MessageResponse {
        guard let url = URL(string: "\(baseURL)/api/v1/messages") else {
            throw MessagesServiceError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MessagesServiceError.fetchFailed
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(MessageResponse.self, from: data)
    }
    
    func deleteMessage(_ messageId: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/v1/messages/\(messageId)") else {
            throw MessagesServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MessagesServiceError.fetchFailed
        }
    }
    
    // MARK: - Reaction Operations
    func getMessageReactions(_ messageId: String) async throws -> [MessageReactionResponse] {
        guard let url = URL(string: "\(baseURL)/api/v1/messages/\(messageId)/reactions") else {
            throw MessagesServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MessagesServiceError.fetchFailed
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([MessageReactionResponse].self, from: data)
    }
    
    func addReaction(_ request: MessageReactionRequest) async throws {
        guard let url = URL(string: "\(baseURL)/api/v1/messages/reactions") else {
            throw MessagesServiceError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let (_, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MessagesServiceError.fetchFailed
        }
    }
    
    func removeReaction(messageId: String, userId: String, emoji: String) async throws {
        guard let encodedEmoji = emoji.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)/api/v1/messages/\(messageId)/reactions/\(userId)/\(encodedEmoji)") else {
            throw MessagesServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MessagesServiceError.fetchFailed
        }
    }
    
    // MARK: - Read Status
    func markMessageAsRead(messageId: String, userId: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/v1/messages/\(messageId)/read/\(userId)") else {
            throw MessagesServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MessagesServiceError.fetchFailed
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString)
    }
}

// MARK: - Errors
enum MessagesServiceError: LocalizedError {
    case fetchFailed
    case invalidURL
    case createFailed
    case deleteFailed
    
    var errorDescription: String? {
        switch self {
        case .fetchFailed:
            return "Failed to fetch data"
        case .invalidURL:
            return "Invalid URL"
        case .createFailed:
            return "Failed to create"
        case .deleteFailed:
            return "Failed to delete"
        }
    }
}

