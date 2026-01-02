//
//  CacheService.swift
//  music
//
//  Created by Nikolai Golubkin on 11/11/25.
//

import Foundation
import SwiftUI

// MARK: - Cache Metadata Models
struct CachedAudioMetadata: Codable {
    let url: String
    let title: String
    let artist: String
    let coverURL: String?
}

struct CachedImageMetadata: Codable {
    let url: String
}

struct CachedVideoMetadata: Codable {
    let url: String
    let title: String
    let artist: String
    let coverURL: String?
}

class CacheService: ObservableObject {
    static let shared = CacheService()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let imagesCacheDirectory: URL
    private let audioCacheDirectory: URL
    private let videoCacheDirectory: URL
    
    @Published private(set) var totalCacheSize: Double = 0.0 // GB
    @Published private(set) var imagesCacheSize: Double = 0.0 // GB
    @Published private(set) var audioCacheSize: Double = 0.0 // GB
    @Published private(set) var videoCacheSize: Double = 0.0 // GB
    
    // Store metadata for cached items
    private var imageMetadataMap: [String: CachedImageMetadata] = [:] // filename -> metadata
    private var audioMetadataMap: [String: CachedAudioMetadata] = [:] // filename -> metadata
    private var videoMetadataMap: [String: CachedVideoMetadata] = [:] // filename -> metadata
    
    private var imageMappingsURL: URL {
        imagesCacheDirectory.appendingPathComponent("metadata.json")
    }
    
    private var audioMappingsURL: URL {
        audioCacheDirectory.appendingPathComponent("metadata.json")
    }
    
    private var videoMappingsURL: URL {
        videoCacheDirectory.appendingPathComponent("metadata.json")
    }
    
    private init() {
        // Get cache directory
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cacheDir.appendingPathComponent("MusicAppCache")
        imagesCacheDirectory = cacheDirectory.appendingPathComponent("Images")
        audioCacheDirectory = cacheDirectory.appendingPathComponent("Audio")
        videoCacheDirectory = cacheDirectory.appendingPathComponent("Video")
        
        // Create directories if they don't exist
        createDirectoriesIfNeeded()
        
        // Calculate initial cache size
        Task {
            await calculateCacheSize()
        }
    }
    
    // MARK: - Directory Setup
    private func createDirectoriesIfNeeded() {
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: imagesCacheDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: audioCacheDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: videoCacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Image Caching
    func cacheImage(url: URL, data: Data) {
        let fileName = url.absoluteString.md5 + ".jpg"
        let fileURL = imagesCacheDirectory.appendingPathComponent(fileName)
        
        // Store metadata for easier lookup (thread-safe)
        let metadata = CachedImageMetadata(url: url.absoluteString)
        Task { @MainActor in
            imageMetadataMap[fileName] = metadata
            await saveImageMappings()
        }
        
        try? data.write(to: fileURL)
        
        Task {
            await calculateCacheSize()
        }
    }
    
    func getCachedImage(url: URL) -> UIImage? {
        let fileName = url.absoluteString.md5 + ".jpg"
        let fileURL = imagesCacheDirectory.appendingPathComponent(fileName)
        
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        
        return UIImage(data: data)
    }
    
    func hasCachedImage(url: URL) -> Bool {
        let fileName = url.absoluteString.md5 + ".jpg"
        let fileURL = imagesCacheDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    // MARK: - Audio Caching
    func cacheAudio(url: URL, data: Data, title: String? = nil, artist: String? = nil, coverURL: String? = nil) {
        let fileName = url.absoluteString.md5 + ".mp3"
        let fileURL = audioCacheDirectory.appendingPathComponent(fileName)
        
        // Store metadata with song information (thread-safe)
        let metadata = CachedAudioMetadata(
            url: url.absoluteString,
            title: title ?? "Unknown Song",
            artist: artist ?? "Unknown Artist",
            coverURL: coverURL
        )
        Task { @MainActor in
            audioMetadataMap[fileName] = metadata
            await saveAudioMappings()
        }
        
        try? data.write(to: fileURL)
        
        Task {
            await calculateCacheSize()
        }
    }
    
    func getCachedAudioURL(url: URL) -> URL? {
        let fileName = url.absoluteString.md5 + ".mp3"
        let fileURL = audioCacheDirectory.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        return fileURL
    }
    
    func hasCachedAudio(url: URL) -> Bool {
        let fileName = url.absoluteString.md5 + ".mp3"
        let fileURL = audioCacheDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    // MARK: - Video Caching
    func cacheVideo(url: URL, data: Data, title: String? = nil, artist: String? = nil, coverURL: String? = nil) {
        let fileName = url.absoluteString.md5 + ".mp4"
        let fileURL = videoCacheDirectory.appendingPathComponent(fileName)
        
        // Store metadata with video information (thread-safe)
        let metadata = CachedVideoMetadata(
            url: url.absoluteString,
            title: title ?? "Unknown Video",
            artist: artist ?? "Unknown Artist",
            coverURL: coverURL
        )
        Task { @MainActor in
            videoMetadataMap[fileName] = metadata
            await saveVideoMappings()
        }
        
        try? data.write(to: fileURL)
        
        Task {
            await calculateCacheSize()
        }
    }
    
    func getCachedVideoURL(url: URL) -> URL? {
        let fileName = url.absoluteString.md5 + ".mp4"
        let fileURL = videoCacheDirectory.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        return fileURL
    }
    
    func hasCachedVideo(url: URL) -> Bool {
        let fileName = url.absoluteString.md5 + ".mp4"
        let fileURL = videoCacheDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    // MARK: - Cache Size Calculation
    func calculateCacheSize() async {
        let imagesSize = await calculateDirectorySize(url: imagesCacheDirectory)
        let audioSize = await calculateDirectorySize(url: audioCacheDirectory)
        let videoSize = await calculateDirectorySize(url: videoCacheDirectory)
        
        await MainActor.run {
            self.imagesCacheSize = imagesSize
            self.audioCacheSize = audioSize
            self.videoCacheSize = videoSize
            self.totalCacheSize = imagesSize + audioSize + videoSize
        }
    }
    
    private func calculateDirectorySize(url: URL) async -> Double {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0.0
        }
        
        var totalSize: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        
        // Convert bytes to GB
        return Double(totalSize) / (1024.0 * 1024.0 * 1024.0)
    }
    
    // MARK: - Clear Cache
    func clearAllCache() async {
        // Clear mappings first
        await MainActor.run {
            imageMetadataMap.removeAll()
            audioMetadataMap.removeAll()
            videoMetadataMap.removeAll()
        }
        
        // Clear directories
        await clearDirectory(url: imagesCacheDirectory)
        await clearDirectory(url: audioCacheDirectory)
        await clearDirectory(url: videoCacheDirectory)
        
        // Recalculate cache size (should be 0 now)
        await calculateCacheSize()
        
        // Ensure mappings are empty
        await MainActor.run {
            imageMetadataMap.removeAll()
            audioMetadataMap.removeAll()
            videoMetadataMap.removeAll()
        }
    }
    
    func clearImagesCache() async {
        await clearDirectory(url: imagesCacheDirectory)
        await calculateCacheSize()
    }
    
    func clearAudioCache() async {
        await clearDirectory(url: audioCacheDirectory)
        await calculateCacheSize()
    }
    
    func clearVideoCache() async {
        await clearDirectory(url: videoCacheDirectory)
        await calculateCacheSize()
    }
    
    // MARK: - Clear Individual Items
    func clearCachedImage(url: URL) async {
        let fileName = url.absoluteString.md5 + ".jpg"
        let fileURL = imagesCacheDirectory.appendingPathComponent(fileName)
        
        // Remove from mappings
        await MainActor.run {
            imageMetadataMap.removeValue(forKey: fileName)
        }
        await saveImageMappings()
        
        // Remove file
        try? fileManager.removeItem(at: fileURL)
        
        // Recalculate cache size
        await calculateCacheSize()
    }
    
    func clearCachedAudio(url: URL) async {
        let fileName = url.absoluteString.md5 + ".mp3"
        let fileURL = audioCacheDirectory.appendingPathComponent(fileName)
        
        // Remove from mappings
        await MainActor.run {
            audioMetadataMap.removeValue(forKey: fileName)
        }
        await saveAudioMappings()
        
        // Remove file
        try? fileManager.removeItem(at: fileURL)
        
        // Recalculate cache size
        await calculateCacheSize()
    }
    
    func clearCachedVideo(url: URL) async {
        let fileName = url.absoluteString.md5 + ".mp4"
        let fileURL = videoCacheDirectory.appendingPathComponent(fileName)
        
        // Remove from mappings
        await MainActor.run {
            videoMetadataMap.removeValue(forKey: fileName)
        }
        await saveVideoMappings()
        
        // Remove file
        try? fileManager.removeItem(at: fileURL)
        
        // Recalculate cache size
        await calculateCacheSize()
    }
    
    private func clearDirectory(url: URL) async {
        // Get all files first (including subdirectories)
        var filesToRemove: [URL] = []
        
        if let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                filesToRemove.append(fileURL)
            }
        }
        
        // Also get direct children
        if let directChildren = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
            filesToRemove.append(contentsOf: directChildren)
        }
        
        // Remove all files
        for fileURL in filesToRemove {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) {
                do {
                    try fileManager.removeItem(at: fileURL)
                } catch {
                    print("Failed to remove \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
        
        // Clear mappings
        if url == imagesCacheDirectory {
            await MainActor.run {
                imageMetadataMap.removeAll()
            }
        } else if url == audioCacheDirectory {
            await MainActor.run {
                audioMetadataMap.removeAll()
            }
        } else if url == videoCacheDirectory {
            await MainActor.run {
                videoMetadataMap.removeAll()
            }
        }
        
        // Wait a bit for file system to update
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify directory is empty and recreate if needed
        if let remainingFiles = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil),
           !remainingFiles.isEmpty {
            // Try to remove remaining files again
            for fileURL in remainingFiles {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
    
    // MARK: - Get Cache Statistics
    func getCacheStatistics() -> CacheData {
        let totalSize = totalCacheSize
        let imagesPercentage = totalSize > 0 ? (imagesCacheSize / totalSize) * 100 : 0
        let audioPercentage = totalSize > 0 ? (audioCacheSize / totalSize) * 100 : 0
        let videoPercentage = totalSize > 0 ? (videoCacheSize / totalSize) * 100 : 0
        
        var categories: [CacheCategory] = []
        
        if imagesCacheSize > 0 {
            categories.append(CacheCategory(
                name: "Photos",
                size: imagesCacheSize,
                percentage: imagesPercentage,
                color: .cyan
            ))
        }
        
        if audioCacheSize > 0 {
            categories.append(CacheCategory(
                name: "Music",
                size: audioCacheSize,
                percentage: audioPercentage,
                color: .red
            ))
        }
        
        if videoCacheSize > 0 {
            categories.append(CacheCategory(
                name: "Videos",
                size: videoCacheSize,
                percentage: videoPercentage,
                color: .purple
            ))
        }
        
        // Add "Other" category if there's any remaining space
        let otherSize = totalSize - imagesCacheSize - audioCacheSize - videoCacheSize
        if otherSize > 0.001 { // 1 MB threshold
            let otherPercentage = (otherSize / totalSize) * 100
            categories.append(CacheCategory(
                name: "Other",
                size: otherSize,
                percentage: otherPercentage,
                color: .orange
            ))
        }
        
        return CacheData(totalSize: totalSize, categories: categories)
    }
    
    // MARK: - Get Cached Items
    func getCachedImageMetadata() async -> [CachedImageMetadata] {
        // Always reload from disk to get current state
        await loadImageURLMappings(force: true)
        return await MainActor.run {
            Array(imageMetadataMap.values)
        }
    }
    
    func getCachedAudioMetadata() async -> [CachedAudioMetadata] {
        // Always reload from disk to get current state
        await loadAudioURLMappings(force: true)
        return await MainActor.run {
            Array(audioMetadataMap.values)
        }
    }
    
    // Legacy methods for backward compatibility
    func getCachedImageURLs() async -> [String] {
        let metadata = await getCachedImageMetadata()
        return metadata.map { $0.url }
    }
    
    func getCachedAudioURLs() async -> [String] {
        let metadata = await getCachedAudioMetadata()
        return metadata.map { $0.url }
    }
    
    func getCachedVideoMetadata() async -> [CachedVideoMetadata] {
        // Always reload from disk to get current state
        await loadVideoURLMappings(force: true)
        return await MainActor.run {
            Array(videoMetadataMap.values)
        }
    }
    
    func getCachedVideoURLs() async -> [String] {
        let metadata = await getCachedVideoMetadata()
        return metadata.map { $0.url }
    }
    
    // Force reload mappings from disk (used after clearing cache)
    func reloadMappings() async {
        await MainActor.run {
            imageMetadataMap.removeAll()
            audioMetadataMap.removeAll()
            videoMetadataMap.removeAll()
        }
    }
    
    private func loadImageURLMappings(force: Bool = false) async {
        if !force {
            let isEmpty = await MainActor.run {
                return imageMetadataMap.isEmpty
            }
            guard isEmpty else { return }
        }
        
        // Clear existing mappings if forcing reload
        if force {
            await MainActor.run {
                imageMetadataMap.removeAll()
            }
        }
        
        // Try to load from persisted metadata file first
        if let data = try? Data(contentsOf: imageMappingsURL),
           let mappings = try? JSONDecoder().decode([String: CachedImageMetadata].self, from: data) {
            await MainActor.run {
                imageMetadataMap = mappings
            }
            return
        }
        
        // Fallback: try to reconstruct from filenames (for backward compatibility)
        guard let enumerator = fileManager.enumerator(
            at: imagesCacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }
        
        var mappings: [String: CachedImageMetadata] = [:]
        for case let fileURL as URL in enumerator {
            let fileName = fileURL.lastPathComponent
            // Skip metadata file
            if fileName == "metadata.json" { continue }
            // Try to extract URL from filename
            if let range = fileName.range(of: "_", options: .backwards) {
                let urlPart = String(fileName[range.upperBound...])
                let originalURL = urlPart.replacingOccurrences(of: ".jpg", with: "")
                mappings[fileName] = CachedImageMetadata(url: originalURL)
            }
        }
        
        await MainActor.run {
            imageMetadataMap = mappings
            // Save mappings for next time
            Task {
                await saveImageMappings()
            }
        }
    }
    
    private func loadAudioURLMappings(force: Bool = false) async {
        if !force {
            let isEmpty = await MainActor.run {
                return audioMetadataMap.isEmpty
            }
            guard isEmpty else { return }
        }
        
        // Clear existing mappings if forcing reload
        if force {
            await MainActor.run {
                audioMetadataMap.removeAll()
            }
        }
        
        // Try to load from persisted metadata file first
        if let data = try? Data(contentsOf: audioMappingsURL),
           let mappings = try? JSONDecoder().decode([String: CachedAudioMetadata].self, from: data) {
            await MainActor.run {
                audioMetadataMap = mappings
            }
            return
        }
        
        // Fallback: try to reconstruct from filenames (for backward compatibility)
        guard let enumerator = fileManager.enumerator(
            at: audioCacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }
        
        var mappings: [String: CachedAudioMetadata] = [:]
        for case let fileURL as URL in enumerator {
            let fileName = fileURL.lastPathComponent
            // Skip metadata file
            if fileName == "metadata.json" { continue }
            // Try to extract URL from filename
            if let range = fileName.range(of: "_", options: .backwards) {
                let urlPart = String(fileName[range.upperBound...])
                let originalURL = urlPart.replacingOccurrences(of: ".mp3", with: "")
                mappings[fileName] = CachedAudioMetadata(url: originalURL, title: "Unknown Song", artist: "Unknown Artist", coverURL: nil)
            }
        }
        
        await MainActor.run {
            audioMetadataMap = mappings
            // Save mappings for next time
            Task {
                await saveAudioMappings()
            }
        }
    }
    
    private func saveImageMappings() async {
        let mappings = await MainActor.run {
            return imageMetadataMap
        }
        
        if let data = try? JSONEncoder().encode(mappings) {
            try? data.write(to: imageMappingsURL)
        }
    }
    
    private func saveAudioMappings() async {
        let mappings = await MainActor.run {
            return audioMetadataMap
        }
        
        if let data = try? JSONEncoder().encode(mappings) {
            try? data.write(to: audioMappingsURL)
        }
    }
    
    private func loadVideoURLMappings(force: Bool = false) async {
        if !force {
            let isEmpty = await MainActor.run {
                return videoMetadataMap.isEmpty
            }
            guard isEmpty else { return }
        }
        
        // Clear existing mappings if forcing reload
        if force {
            await MainActor.run {
                videoMetadataMap.removeAll()
            }
        }
        
        // Try to load from persisted metadata file first
        if let data = try? Data(contentsOf: videoMappingsURL),
           let mappings = try? JSONDecoder().decode([String: CachedVideoMetadata].self, from: data) {
            await MainActor.run {
                videoMetadataMap = mappings
            }
            return
        }
        
        // Fallback: try to reconstruct from filenames (for backward compatibility)
        guard let enumerator = fileManager.enumerator(
            at: videoCacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }
        
        var mappings: [String: CachedVideoMetadata] = [:]
        for case let fileURL as URL in enumerator {
            let fileName = fileURL.lastPathComponent
            // Skip metadata file
            if fileName == "metadata.json" { continue }
            // Try to extract URL from filename
            if let range = fileName.range(of: "_", options: .backwards) {
                let urlPart = String(fileName[range.upperBound...])
                let originalURL = urlPart.replacingOccurrences(of: ".mp4", with: "")
                mappings[fileName] = CachedVideoMetadata(url: originalURL, title: "Unknown Video", artist: "Unknown Artist", coverURL: nil)
            }
        }
        
        await MainActor.run {
            videoMetadataMap = mappings
            // Save mappings for next time
            Task {
                await saveVideoMappings()
            }
        }
    }
    
    private func saveVideoMappings() async {
        let mappings = await MainActor.run {
            return videoMetadataMap
        }
        
        if let data = try? JSONEncoder().encode(mappings) {
            try? data.write(to: videoMappingsURL)
        }
    }
    
    func getCachedImageURLsSync() -> [String] {
        return Array(imageMetadataMap.values.map { $0.url })
    }
    
    func getCachedAudioURLsSync() -> [String] {
        return Array(audioMetadataMap.values.map { $0.url })
    }
    
    func getCachedVideoURLsSync() -> [String] {
        return Array(videoMetadataMap.values.map { $0.url })
    }
}

// MARK: - String Hash Extension
extension String {
    var md5: String {
        // Create a safe filename from URL string
        // Replace invalid characters with underscores
        let invalidChars = CharacterSet(charactersIn: "/:?=&%")
        let safeString = self.components(separatedBy: invalidChars).joined(separator: "_")
        // Use hash for uniqueness
        let hash = abs(safeString.hash)
        return "\(hash)_\(safeString.prefix(50))"
    }
}

