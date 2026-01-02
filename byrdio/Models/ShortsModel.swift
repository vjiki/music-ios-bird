//
//  ShortsModel.swift
//  music
//
//  Created by Nikolai Golubkin on 11/12/25.
//

import SwiftUI

// Shorts Model for ShortResponse from backend
struct ShortsModel: Identifiable, Codable, Equatable {
    var id: String
    var artist: String?
    var audio_url: String?
    var cover: String?
    var title: String?
    var video_url: String?
    var type: String
    var isLiked: Bool
    var isDisliked: Bool
    var likesCount: Int
    var dislikesCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case artist
        case audio_url
        case cover
        case title
        case video_url
        case type
        case isLiked
        case isDisliked
        case likesCount
        case dislikesCount
    }
    
    init(
        id: String = UUID().uuidString,
        artist: String? = nil,
        audio_url: String? = nil,
        cover: String? = nil,
        title: String? = nil,
        video_url: String? = nil,
        type: String = "SONG",
        isLiked: Bool = false,
        isDisliked: Bool = false,
        likesCount: Int = 0,
        dislikesCount: Int = 0
    ) {
        self.id = id
        self.artist = artist
        self.audio_url = audio_url
        self.cover = cover
        self.title = title
        self.video_url = video_url
        self.type = type
        self.isLiked = isLiked
        self.isDisliked = isDisliked
        self.likesCount = likesCount
        self.dislikesCount = dislikesCount
    }
}

// Type enum for convenience
enum ShortType: String {
    case song = "SONG"
    case shortVideo = "SHORT_VIDEO"
}

