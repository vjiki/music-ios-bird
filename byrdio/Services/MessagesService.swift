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
    
    var errorDescription: String? {
        switch self {
        case .fetchFailed:
            return "Failed to fetch messages"
        case .invalidURL:
            return "Invalid URL"
        }
    }
}

