//
//  SongsModel.swift
//  music
//
//  Created by Nikolai Golubkin on 11/8/25.
//

import SwiftUI

// MARK: - Song Tag Model
struct SongTag: Codable, Equatable {
    let name: String
    let weight: Double
}

// Now we create Songs Model List
struct SongsModel: Identifiable, Codable, Equatable {
    var id: String
    var artist: String
    var audio_url: String
    var cover: String
    var title: String
    var video_url: String?
    var tags: [SongTag]?
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
        case tags
        case isLiked
        case isDisliked
        case likesCount
        case dislikesCount
    }
    
    init(
        id: String = UUID().uuidString,
        artist: String,
        audio_url: String,
        cover: String,
        title: String,
        video_url: String? = nil,
        tags: [SongTag]? = nil,
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
        self.tags = tags
        self.isLiked = isLiked
        self.isDisliked = isDisliked
        self.likesCount = likesCount
        self.dislikesCount = dislikesCount
    }
}

// Demo List of Songs (fallback)
var sampleSongs: [SongsModel] = [
    .init(artist: "Scotch", audio_url: "https://drive.google.com/uc?export=download&id=1veW1fEVD-5wqd-_G8EC7ACVVC1D8jrV3", cover: "https://drive.google.com/uc?export=download&id=1pYVYMKPWFoBqof8e_bLCpfME8rwekpLd", title: "Лето без тебя", isLiked: false, isDisliked: false, likesCount: 0, dislikesCount: 0),
    .init(artist: "7раса", audio_url: "https://drive.google.com/uc?export=download&id=1Mg9bfPmczARpO_BNReFb0lS--ygYQWKz", cover: "https://drive.google.com/uc?export=download&id=1okM0wJHIasHmJFOGAkfMy6MtLRqVnr8-", title: "Вечное лето", isLiked: false, isDisliked: false, likesCount: 0, dislikesCount: 0)
]
