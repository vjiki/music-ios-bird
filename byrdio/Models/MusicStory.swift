//
//  MusicStory.swift
//  music
//
//  Created by Nikolai Golubkin on 11/9/25.
//

import SwiftUI

struct MusicStory: Identifiable {
    let id: String
    let userId: String
    let userName: String
    let profileImageURL: String?
    let song: SongsModel
    let timestamp: Date
    let isViewed: Bool
    let storyImageURL: String? // imageUrl from API
    let storyPreviewURL: String? // previewUrl from API
    
    init(id: String = UUID().uuidString, userId: String, userName: String, profileImageURL: String? = nil, song: SongsModel, timestamp: Date = Date(), isViewed: Bool = false, storyImageURL: String? = nil, storyPreviewURL: String? = nil) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.profileImageURL = profileImageURL
        self.song = song
        self.timestamp = timestamp
        self.isViewed = isViewed
        self.storyImageURL = storyImageURL
        self.storyPreviewURL = storyPreviewURL
    }
}

