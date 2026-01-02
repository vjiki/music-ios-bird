//
//  ShortsService.swift
//  music
//
//  Created by Nikolai Golubkin on 11/12/25.
//

import Foundation
import Combine

// MARK: - Protocol (Interface Segregation)
protocol ShortsServiceProtocol {
    var shorts: [ShortsModel] { get }
    var isLoading: Bool { get }
    
    func fetchShorts(userId: String) async
}

// MARK: - Implementation (Single Responsibility: Shorts Fetching)
class ShortsService: ObservableObject, ShortsServiceProtocol {
    @Published var shorts: [ShortsModel] = []
    @Published private(set) var isLoading: Bool = false
    
    private var baseURL: String {
        return "https://music-back-g2u6.onrender.com"
    }
    
    func fetchShorts(userId: String) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let apiURL = "\(baseURL)/api/v1/shorts/\(userId)"
            guard let url = URL(string: apiURL) else {
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
                let fetchedShorts = try decoder.decode([ShortsModel].self, from: data)
                
                await MainActor.run {
                    self.shorts = fetchedShorts
                    self.isLoading = false
                }
            } catch let decodingError as DecodingError {
                // Print detailed decoding error
                print("Failed to decode shorts: \(decodingError)")
                if let dataString = String(data: data, encoding: .utf8) {
                    print("Response data: \(String(dataString.prefix(500)))")
                }
                throw decodingError
            }
            
        } catch {
            // If API fails, use empty array
            print("Failed to fetch shorts from API: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                print("URL Error: \(urlError.localizedDescription)")
            }
            
            await MainActor.run {
                self.shorts = []
                self.isLoading = false
            }
        }
    }
    
    // Update a specific short in the list
    func updateShort(_ updatedShort: ShortsModel) {
        if let index = shorts.firstIndex(where: { $0.id == updatedShort.id }) {
            shorts[index] = updatedShort
        }
    }
}

// MARK: - Errors
enum ShortsServiceError: LocalizedError {
    case emptyResponse
    
    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "API returned empty response"
        }
    }
}

