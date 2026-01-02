//
//  BandModel.swift
//  music
//
//  Created by Nikolai Golubkin on 11/9/25.
//

import Foundation

// MARK: - Band Response Model
struct BandResponse: Codable, Identifiable {
    let id: String
    let name: String
    let sortName: String?
    let countryCode: String?
    let isBand: Bool
    let debutYear: Int?
    let popularity: Int
    let createdAt: String
    let updatedAt: String
    let coverUrl: String?
    let songs: [SongsModel]
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case sortName = "sort_name"
        case countryCode = "country_code"
        case isBand = "is_band"
        case debutYear = "debut_year"
        case popularity
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case coverUrl = "cover_url"
        case songs
    }
}

