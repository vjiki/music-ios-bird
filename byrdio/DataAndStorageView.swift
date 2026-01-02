//
//  DataAndStorageView.swift
//  music
//
//  Created by Nikolai Golubkin on 11/11/25.
//

import SwiftUI

struct DataAndStorageView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var songManager: SongManager
    
    @StateObject private var cacheService = CacheService.shared
    @State private var selectedTab: CacheTab = .media
    @State private var selectedCacheSize: CacheSize = .fiveGB
    @State private var showClearCacheConfirmation = false
    @State private var isClearingCache = false
    @State private var cacheData = CacheData(totalSize: 0.0, categories: [])
    @State private var cachedImageURLs: [String] = []
    @State private var cachedAudioURLs: [String] = []
    @State private var isLoadingCachedItems = false
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    if cacheData.totalSize > 0 {
                        // Donut chart
                        donutChartView
                        
                        // Memory usage summary
                        memoryUsageSummary
                        
                        // Cache categories list
                        cacheCategoriesList
                        
                        // Clear cache button
                        clearCacheButton
                        
                        // Cloud storage note
                        cloudStorageNote
                    } else {
                        // Empty state
                        emptyStateView
                    }
                    
                    // Auto-delete section
                    autoDeleteSection
                    
                    // Maximum cache size section
                    maximumCacheSizeSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await cacheService.calculateCacheSize()
                updateCacheData()
                await loadCachedItems()
            }
            .onChange(of: cacheService.totalCacheSize) { _, _ in
                updateCacheData()
                Task {
                    await loadCachedItems()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(.blue)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Data and Storage")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .confirmationDialog("Clear Cache", isPresented: $showClearCacheConfirmation, titleVisibility: .visible) {
                Button("Clear All Cache", role: .destructive) {
                    clearAllCache()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will clear \(String(format: "%.1f", cacheData.totalSize)) GB of cached data. All media will remain in the cloud and can be downloaded again if needed.")
            }
        }
    }
    
    // MARK: - Donut Chart
    private var donutChartView: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 30)
                .frame(width: 200, height: 200)
            
            // Segmented donut chart
            DonutChart(data: cacheData.categories)
                .frame(width: 200, height: 200)
            
            // Center text
            VStack(spacing: 4) {
                Text(String(format: "%.1f Гб", cacheData.totalSize))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Memory Usage Summary
    private var memoryUsageSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Memory Usage")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            
            Text("Music occupies \(String(format: "%.1f", cacheData.totalSize * 0.278))% of free space on the device.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
            
            Rectangle()
                .fill(Color.blue.opacity(0.3))
                .frame(height: 1)
                .padding(.top, 8)
        }
    }
    
    // MARK: - Cache Categories List
    private var cacheCategoriesList: some View {
        VStack(spacing: 0) {
            ForEach(Array(cacheData.categories.enumerated()), id: \.offset) { index, category in
                CacheCategoryRow(category: category, isSelected: true) {
                    // Toggle selection
                }
            }
            
            // Show cached items details
            if cacheData.totalSize > 0 {
                CachedItemsSection()
                    .environmentObject(songManager)
                    .environmentObject(cacheService)
            }
        }
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: - Clear Cache Button
    private var clearCacheButton: some View {
        Button {
            showClearCacheConfirmation = true
        } label: {
            Text("Clear All Cache \(String(format: "%.1f", cacheData.totalSize)) GB")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(isClearingCache)
    }
    
    // MARK: - Cloud Storage Note
    private var cloudStorageNote: some View {
        Text("All media will remain in the cloud; you can download them again if needed.")
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.6))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
    }
    
    // MARK: - Auto-Delete Section
    private var autoDeleteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AUTO-DELETE CACHED MEDIA")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            
            AutoDeleteRow(icon: "person.fill", title: "Personal chats", value: "Never")
            AutoDeleteRow(icon: "person.2.fill", title: "Groups", value: "1 month")
            AutoDeleteRow(icon: "megaphone.fill", title: "Channels", value: "1 week")
        }
    }
    
    // MARK: - Maximum Cache Size Section
    private var maximumCacheSizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MAXIMUM CACHE SIZE")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            
            Text("Photos, videos and other files that you have not opened during this period will be deleted from the device to save space on your phone.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
            
            // Cache size selector
            HStack(spacing: 0) {
                ForEach(CacheSize.allCases, id: \.self) { size in
                    Button {
                        selectedCacheSize = size
                    } label: {
                        Text(size.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(selectedCacheSize == size ? .white : .white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                selectedCacheSize == size
                                ? Color.blue.opacity(0.3)
                                : Color.clear
                            )
                    }
                }
            }
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            Text("If the cache size exceeds this limit, the oldest unused media will be deleted from the device's memory.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
    
    // MARK: - Update Cache Data
    private func updateCacheData() {
        cacheData = cacheService.getCacheStatistics()
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No cached data")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            
            Text("Cached songs and images will appear here")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Clear Cache
    private func clearAllCache() {
        isClearingCache = true
        Task {
            await cacheService.clearAllCache()
            // Force reload mappings to ensure they're empty
            await cacheService.reloadMappings()
            // Wait a moment for file system to update
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            await MainActor.run {
                updateCacheData()
                cachedImageURLs = []
                cachedAudioURLs = []
                isClearingCache = false
            }
        }
    }
    
    // MARK: - Load Cached Items
    private func loadCachedItems() async {
        await MainActor.run {
            isLoadingCachedItems = true
        }
        
        let imageURLs = await cacheService.getCachedImageURLs()
        let audioURLs = await cacheService.getCachedAudioURLs()
        
        await MainActor.run {
            cachedImageURLs = imageURLs
            cachedAudioURLs = audioURLs
            isLoadingCachedItems = false
        }
    }
}

// MARK: - Cache Data Models
struct CacheData {
    var totalSize: Double // GB
    var categories: [CacheCategory]
}

struct CacheCategory: Identifiable {
    let id = UUID()
    let name: String
    let size: Double // GB
    let percentage: Double
    let color: Color
}

enum CacheSize: String, CaseIterable {
    case fiveGB = "5 GB"
    case twentyGB = "20 GB"
    case fiftyGB = "50 GB"
    case none = "None"
    
    var displayName: String {
        switch self {
        case .fiveGB: return "5 Гб"
        case .twentyGB: return "20 Гб"
        case .fiftyGB: return "50 Гб"
        case .none: return "Нет"
        }
    }
}

enum CacheTab {
    case chats
    case media
    case files
}

// MARK: - Donut Chart View
struct DonutChart: View {
    let data: [CacheCategory]
    private let lineWidth: CGFloat = 30
    private let radius: CGFloat = 100
    
    var body: some View {
        ZStack {
            ForEach(Array(data.enumerated()), id: \.offset) { index, category in
                DonutSegment(
                    category: category,
                    startAngle: startAngle(for: index),
                    endAngle: endAngle(for: index),
                    lineWidth: lineWidth,
                    radius: radius
                )
            }
        }
    }
    
    private func startAngle(for index: Int) -> Double {
        let previousTotal = data.prefix(index).reduce(0.0) { $0 + $1.percentage }
        return (previousTotal / 100.0) * 360.0 - 90.0
    }
    
    private func endAngle(for index: Int) -> Double {
        let currentTotal = data.prefix(index + 1).reduce(0.0) { $0 + $1.percentage }
        return (currentTotal / 100.0) * 360.0 - 90.0
    }
}

struct DonutSegment: View {
    let category: CacheCategory
    let startAngle: Double
    let endAngle: Double
    let lineWidth: CGFloat
    let radius: CGFloat
    
    var body: some View {
        Path { path in
            let center = CGPoint(x: radius, y: radius)
            path.addArc(
                center: center,
                radius: radius - lineWidth / 2,
                startAngle: .degrees(startAngle),
                endAngle: .degrees(endAngle),
                clockwise: false
            )
        }
        .stroke(
            category.color,
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )
        .frame(width: radius * 2, height: radius * 2)
    }
}

// MARK: - Cache Category Row
struct CacheCategoryRow: View {
    let category: CacheCategory
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? category.color : .white.opacity(0.3))
                
                // Category name
                Text(category.name)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Percentage and size
                HStack(spacing: 8) {
                    Text("\(String(format: "%.1f", category.percentage))%")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Text(formatSize(category.size))
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func formatSize(_ size: Double) -> String {
        if size >= 1.0 {
            return String(format: "%.1f Гб", size)
        } else {
            return String(format: "%.1f МБ", size * 1024)
        }
    }
}

// MARK: - Auto Delete Row
struct AutoDeleteRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        Button {
            // Action
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text(value)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cached Items Section
struct CachedItemsSection: View {
    @EnvironmentObject var songManager: SongManager
    @EnvironmentObject var cacheService: CacheService
    @State private var cachedImageMetadata: [CachedImageMetadata] = []
    @State private var cachedAudioMetadata: [CachedAudioMetadata] = []
    @State private var isLoading = false
    @State private var showImages = false
    @State private var showSongs = false
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Images section
            Button {
                showImages.toggle()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.cyan)
                        .frame(width: 24, height: 24)
                    
                    Text("Cached Images")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("\(cachedImageMetadata.count)")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
                        
                        Image(systemName: showImages ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if showImages {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else if cachedImageMetadata.isEmpty {
                    Text("No cached images")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.vertical, 8)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(cachedImageMetadata, id: \.url) { metadata in
                                if let url = URL(string: metadata.url) {
                                    ZStack(alignment: .topTrailing) {
                                        CachedAsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            Rectangle()
                                                .fill(Color.white.opacity(0.1))
                                                .overlay {
                                                    ProgressView()
                                                        .tint(.white)
                                                }
                                        }
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        Button {
                                            Task {
                                                await cacheService.clearCachedImage(url: url)
                                                await loadCachedItems()
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(.red)
                                                .background(Circle().fill(Color.white))
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Songs section
            Button {
                showSongs.toggle()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.system(size: 20))
                        .foregroundStyle(.red)
                        .frame(width: 24, height: 24)
                    
                    Text("Cached Songs")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("\(cachedAudioMetadata.count)")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
                        
                        Image(systemName: showSongs ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if showSongs {
                if isLoading {
                    ProgressView()
                        .padding(.vertical, 8)
                } else if cachedAudioMetadata.isEmpty {
                    Text("No cached songs")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 8) {
                        ForEach(cachedAudioMetadata, id: \.url) { metadata in
                            HStack(spacing: 12) {
                                if let coverURLString = metadata.coverURL, !coverURLString.isEmpty, let coverURL = URL(string: coverURLString) {
                                    CachedAsyncImage(url: coverURL) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.1))
                                            .overlay {
                                                ProgressView()
                                                    .tint(.white)
                                            }
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                } else {
                                    // Try to find song in library to get cover
                                    if let song = songManager.librarySongs.first(where: { $0.audio_url == metadata.url }),
                                       let coverURL = URL(string: song.cover) {
                                        CachedAsyncImage(url: coverURL) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            Rectangle()
                                                .fill(Color.white.opacity(0.1))
                                                .overlay {
                                                    ProgressView()
                                                        .tint(.white)
                                                }
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    } else {
                                        Image(systemName: "music.note")
                                            .font(.system(size: 20))
                                            .foregroundStyle(.white.opacity(0.5))
                                            .frame(width: 40, height: 40)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(metadata.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    
                                    Text(metadata.artist)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.6))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Spacer()
                                
                                Button {
                                    Task {
                                        if let url = URL(string: metadata.url) {
                                            await cacheService.clearCachedAudio(url: url)
                                            await loadCachedItems()
                                        }
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.red)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .task {
            await loadCachedItems()
        }
        .onChange(of: cacheService.totalCacheSize) { _, _ in
            Task {
                await loadCachedItems()
            }
        }
    }
    
    private func loadCachedItems() async {
        await MainActor.run {
            isLoading = true
        }
        
        // Force reload mappings from disk
        await cacheService.reloadMappings()
        
        let imageMetadata = await cacheService.getCachedImageMetadata()
        let audioMetadata = await cacheService.getCachedAudioMetadata()
        
        await MainActor.run {
            cachedImageMetadata = imageMetadata
            cachedAudioMetadata = audioMetadata
            isLoading = false
        }
    }
}

#Preview {
    DataAndStorageView()
        .environmentObject(SongManager())
        .preferredColorScheme(.dark)
}

