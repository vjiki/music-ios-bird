//
//  CachedAsyncImage.swift
//  music
//
//  Created by Nikolai Golubkin on 11/11/25.
//

import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @StateObject private var loader = ImageLoader()
    
    var body: some View {
        Group {
            if let image = loader.image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .onAppear {
            if let url = url {
                loader.load(url: url)
            }
        }
        .onChange(of: url) { oldValue, newValue in
            // Reload image when URL changes
            if let newUrl = newValue {
                loader.load(url: newUrl)
            } else {
                // Clear image if URL becomes nil
                loader.image = nil
            }
        }
    }
}

private class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    private let cacheService = CacheService.shared
    private var currentURL: URL?
    
    func load(url: URL) {
        // If URL hasn't changed, don't reload
        if currentURL == url, image != nil {
            return
        }
        
        // Update current URL
        currentURL = url
        
        // Check cache first
        if let cachedImage = cacheService.getCachedImage(url: url) {
            self.image = cachedImage
            return
        }
        
        // Clear old image while loading new one
        self.image = nil
        
        // Load from network
        Task {
            // Verify URL hasn't changed while loading
            guard currentURL == url else { return }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                // Verify URL still matches before setting image
                guard currentURL == url else { return }
                
                if let uiImage = UIImage(data: data) {
                    // Cache the image
                    cacheService.cacheImage(url: url, data: data)
                    
                    await MainActor.run {
                        // Double-check URL still matches
                        if self.currentURL == url {
                            self.image = uiImage
                        }
                    }
                }
            } catch {
                // Ignore cancellation errors (expected when URL changes quickly)
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    // Task was cancelled, which is expected behavior
                    return
                }
                // Only log actual errors, not cancellations
                print("Failed to load image: \(error.localizedDescription)")
            }
        }
    }
}

