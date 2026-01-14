//
//  CommentModel.swift
//  byrdio
//
//  Created by Nikolai Golubkin on 14. 1. 2026..
//

import Foundation

// MARK: - Comment Model
struct CommentModel: Identifiable, Codable, Equatable {
    let id: String
    let trackId: String
    let userId: String
    let userNickname: String
    let userAvatarUrl: String?
    let parentId: String?
    let content: String
    let status: String
    var likesCount: Int
    var repliesCount: Int
    var isLiked: Bool
    let createdAt: String
    let updatedAt: String?
    var replies: [CommentModel]
    
    enum CodingKeys: String, CodingKey {
        case id
        case trackId = "track_id"
        case userId = "user_id"
        case userNickname = "user_nickname"
        case userAvatarUrl = "user_avatar_url"
        case parentId = "parent_id"
        case content
        case status
        case likesCount = "likes_count"
        case repliesCount = "replies_count"
        case isLiked = "is_liked"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case replies
    }
    
    init(
        id: String,
        trackId: String,
        userId: String,
        userNickname: String,
        userAvatarUrl: String? = nil,
        parentId: String? = nil,
        content: String,
        status: String = "ACTIVE",
        likesCount: Int = 0,
        repliesCount: Int = 0,
        isLiked: Bool = false,
        createdAt: String,
        updatedAt: String? = nil,
        replies: [CommentModel] = []
    ) {
        self.id = id
        self.trackId = trackId
        self.userId = userId
        self.userNickname = userNickname
        self.userAvatarUrl = userAvatarUrl
        self.parentId = parentId
        self.content = content
        self.status = status
        self.likesCount = likesCount
        self.repliesCount = repliesCount
        self.isLiked = isLiked
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.replies = replies
    }
}

// MARK: - Comment Request Models
struct AddCommentRequest: Codable {
    let trackId: String
    let userId: String
    let content: String
    let parentId: String?
    
    enum CodingKeys: String, CodingKey {
        case trackId
        case userId
        case content
        case parentId
    }
    
    init(trackId: String, userId: String, content: String, parentId: String? = nil) {
        self.trackId = trackId
        self.userId = userId
        self.content = content
        self.parentId = parentId
    }
}

struct AddReactionRequest: Codable {
    let commentId: String
    let userId: String
    let reaction: String
    
    enum CodingKeys: String, CodingKey {
        case commentId
        case userId
        case reaction
    }
}
