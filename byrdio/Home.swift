//
//  Home.swift
//  music
//
//  Created by Nikolai Golubkin on 15. 8. 2025..
//

import SwiftUI

struct Home: View {
    enum Tab: Hashable, CaseIterable {
        case home
        case samples
        case search
        case playlists
        case profile
    }
    
    @State private var expandSheet = false
    @State private var storyImageURL: String? = nil
    @Namespace private var animation
    @StateObject var authService = AuthService()
    @StateObject var songManager = SongManager(authService: nil) // Will be set in onAppear
    @State private var currentTab: Tab = .home
    @State private var showSearch = false
    @State private var showPlaylists = false
    
    init() {
        UITabBar.appearance().isHidden = true
    }
    
    var body: some View {
        TabView(selection: $currentTab) {
            HomeTabContent(expandSheet: $expandSheet, animation: animation, storyImageURL: $storyImageURL, showSearch: $showSearch, showPlaylists: $showPlaylists)
                .tag(Tab.home)
                .environmentObject(songManager)
                .environmentObject(authService)
            
            SamplesView()
                .tag(Tab.samples)
                .environmentObject(songManager)
                .environmentObject(authService)
            
            ProfileView()
                .tag(Tab.profile)
                .environmentObject(songManager)
                .environmentObject(authService)
        }
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                // Hide mini player on samples view
                if !songManager.song.title.isEmpty && currentTab != .samples {
                    MiniPlayer()
                        .padding(.horizontal, 18)
                        .padding(.bottom, 8)
                }
                
                CustomTabBar(currentTab: $currentTab)
            }
            .opacity(expandSheet ? 0 : 1)
            .allowsHitTesting(!expandSheet)
        }
        .overlay {
            if expandSheet {
                ZStack {
                    // Opaque black background to hide content behind
                    Color.black
                        .ignoresSafeArea()
                    
                    MusicView(expandSheet: $expandSheet, animation: animation, storyImageURL: storyImageURL)
                        .environmentObject(songManager)
                        .environmentObject(authService)
                }
            }
        }
        .onChange(of: authService.shouldNavigateToProfile) { _, shouldNavigate in
            if shouldNavigate {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentTab = .profile
                }
                // Reset the flag after navigation
                Task { @MainActor in
                    authService.shouldNavigateToProfile = false
                }
            }
        }
        .onChange(of: expandSheet) { _, isExpanded in
            // Reset story image URL when MusicView is closed
            if !isExpanded {
                storyImageURL = nil
            }
        }
        .onAppear {
            // Set AuthService in SongManager
            songManager.setAuthService(authService)
        }
        .sheet(isPresented: $showSearch) {
            Search(expandSheet: $expandSheet, animation: animation)
                .environmentObject(songManager)
                .environmentObject(authService)
        }
        .sheet(isPresented: $showPlaylists) {
            PlaylistsView()
                .environmentObject(songManager)
                .environmentObject(authService)
        }
    }
    
    @ViewBuilder
    private func MiniPlayer() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.24), radius: 10, x: 0, y: 6)
                .overlay {
                    MusicInfo(expandSheet: $expandSheet, animation: animation)
                        .environmentObject(songManager)
                        .padding(.horizontal, 10)
                }
        }
        .frame(height: 58)
        .matchedGeometryEffect(id: "BACKGROUNDVIEW", in: animation)
    }
    
    private struct CustomTabBar: View {
        @Binding var currentTab: Tab
        
        private let items: [TabItem] = [
            TabItem(tab: .home, icon: "house", selectedIcon: "house.fill"),
            TabItem(tab: .samples, icon: "play.rectangle.on.rectangle", selectedIcon: "play.rectangle.on.rectangle.fill"),
            TabItem(tab: .profile, icon: "person.crop.circle", selectedIcon: "person.crop.circle.fill")
        ]
        
        // Check if we're on samples view to adjust opacity
        private var isSamplesView: Bool {
            currentTab == .samples
        }
        
        var body: some View {
            HStack {
                ForEach(items) { item in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            currentTab = item.tab
                        }
                    } label: {
                        Image(systemName: iconName(for: item.tab))
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(currentTab == item.tab ? .white : .white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(
                // Semi-transparent background - more transparent on samples view
                Color.black.opacity(isSamplesView ? 0.1 : 0.6)
                    .ignoresSafeArea(edges: .bottom)
            )
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 0.5),
                alignment: .top
            )
        }
        
        private func iconName(for tab: Tab) -> String {
            guard let item = items.first(where: { $0.tab == tab }) else {
                return "circle"
            }
            return currentTab == tab ? item.selectedIcon : item.icon
        }
        
        private struct TabItem: Identifiable {
            let tab: Tab
            let icon: String
            let selectedIcon: String
            var id: Tab { tab }
        }
    }
}

// MARK: - Home Tab Content
private struct HomeTabContent: View {
    @Binding var expandSheet: Bool
    var animation: Namespace.ID
    @Binding var storyImageURL: String?
    
    @EnvironmentObject var songManager: SongManager
    @EnvironmentObject var authService: AuthService
    @StateObject private var storyManager = StoryManager()
    @StateObject private var storiesService = StoriesService()
    @StateObject private var preferenceManager = PreferenceManager()
    @State private var showStoryCreation = false
    @State private var showMessages = false
    @Binding var showSearch: Bool
    @Binding var showPlaylists: Bool
    @State private var quickPlaySongs: [SongsModel] = []
    @State private var mixesSongs: [SongsModel] = []
    @State private var showCustomizeMyVibe = false
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Add spacing at top to account for fixed top bar
                    Spacer()
                        .frame(height: max(0, getSafeAreaTop() - 20) + 50)
                    
                    DiscoverRow()
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                
                QuickPlay()
                
                    MixesSection()
                }
                .padding(.bottom, 200)
            }
            .background(Color.black.ignoresSafeArea())
            
            // Fixed top bar at the top - positioned near camera/notch
            instagramTopBar
                .padding(.top, max(0, getSafeAreaTop() - 20))
                .padding(.horizontal, 0)
                .padding(.vertical, 0)
                .background(
                    Color.black.opacity(0.6)
                        .ignoresSafeArea(edges: .top)
                )
        }
        .task {
            // Fetch stories from API when view appears
            await fetchStoriesFromAPI()
            updateQuickPlaySongs()
            updateMixesSongs()
        }
        .onAppear {
            updateQuickPlaySongs()
            updateMixesSongs()
        }
        .onChange(of: songManager.librarySongs) { _, _ in
            updateQuickPlaySongs()
            updateMixesSongs()
        }
        .onChange(of: songManager.likedSongs) { _, _ in
            updateQuickPlaySongs()
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            // Refetch stories when authentication state changes
            if isAuthenticated {
                Task {
                    await fetchStoriesFromAPI()
                }
            }
            updateQuickPlaySongs()
        }
        .sheet(isPresented: $showStoryCreation) {
            StoryCreationView(storyManager: storyManager, songManager: songManager)
        }
        .sheet(isPresented: $showCustomizeMyVibe) {
            CustomizeMyVibeView()
        }
        .sheet(isPresented: $showMessages) {
            MessagesView()
                .environmentObject(authService)
        }
    }
    
    private var instagramTopBar: some View {
        VStack(spacing: 0) {
            // Header with action buttons
            HStack(spacing: 12) {
                // Story creation button on the left
                Button {
                    showStoryCreation = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.pink, Color.orange, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        
                        Circle()
                            .fill(Color.black)
                            .frame(width: 38, height: 38)
                        
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.3))
                        
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .offset(x: 12, y: 12)
                    }
                }
                .buttonStyle(.plain)
                
                // Story buttons - from left to middle
                if !storyManager.stories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(storyManager.stories.prefix(10)) { story in
                                Button {
                                    // Only open if song has audio URL
                                    guard !story.song.audio_url.isEmpty else {
                                        storyManager.markStoryAsViewed(story.id)
                                        return
                                    }
                                    
                                    // Set the story image URL first
                                    storyImageURL = story.storyImageURL ?? story.storyPreviewURL
                                    
                                    // Play the song from the story
                                    songManager.playSong(story.song, in: [story.song])
                                    
                                    // Open MusicView with animation
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        expandSheet = true
                                    }
                                    
                                    // Mark story as viewed
                                    storyManager.markStoryAsViewed(story.id)
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: story.isViewed ? [Color.gray, Color.gray] : [Color.pink, Color.orange, Color.purple],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 40, height: 40)
                                        
                                        Circle()
                                            .fill(Color.black)
                                            .frame(width: 38, height: 38)
                                        
                                        if let profileImageURL = story.profileImageURL, !profileImageURL.isEmpty {
                                            CachedAsyncImage(url: URL(string: profileImageURL)) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                            } placeholder: {
                                                Image(systemName: "person.crop.circle.fill")
                                                    .font(.system(size: 32))
                                                    .foregroundStyle(.white.opacity(0.3))
                                            }
                                            .frame(width: 38, height: 38)
                                            .clipShape(Circle())
                                        } else {
                                            Image(systemName: "person.crop.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundStyle(.white.opacity(0.3))
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.5)
                }
                
                Spacer()
                
                Button {
                    showMessages = true
                } label: {
                    Image(systemName: "message")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                
                Button {
                    showSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                
                Button {
                    showPlaylists = true
                } label: {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 0)
        }
    }
    
    @ViewBuilder
    private func DiscoverRow() -> some View {
        HStack(spacing: 16) {
            let myVibeSong = getMyVibeSong()
            let selectedMoods = preferenceManager.getSelectedMoods()
            let filteredSongs = !selectedMoods.isEmpty ? filterSongsByMoodTags(songManager.librarySongs, moods: selectedMoods) : songManager.librarySongs
            let playlistToUse = !filteredSongs.isEmpty ? filteredSongs : songManager.librarySongs
            
            myVibeCard(
                subtitle: myVibeSong?.title ?? "Breathe with me"
            ) {
                if let song = myVibeSong {
                    songManager.playSong(song, in: playlistToUse)
                } else if let first = playlistToUse.first {
                    songManager.playSong(first, in: playlistToUse)
                }
            }
            
            discoverCard(
                title: "For You",
                subtitle: "Tailored tracks",
                icon: "person.2.fill"
            ) {
                if let first = songManager.librarySongs.first {
                    songManager.playSong(first, in: songManager.librarySongs)
                }
            }
            
            discoverCard(
                title: "Trends",
                subtitle: "What's hot now",
                icon: "flame.fill"
            ) {
                if let randomSong = songManager.librarySongs.randomElement() {
                    songManager.playSong(randomSong, in: songManager.librarySongs.shuffled())
                }
            }
        }
    }
    
    // MARK: - Mood to Tags Mapping
    private func getTagsForMood(_ mood: String) -> [String] {
        switch mood.lowercased() {
        case "energetic":
            return ["Energetic", "Aggressive", "Workout", "Rock", "Alternative"]
        case "cheerful":
            return ["Cheerful", "Chill", "Happy", "Indie", "Electronic"]
        case "calm":
            return ["Calm", "Chill", "Focus", "Melancholic", "Indie"]
        case "sad":
            return ["Sad", "Dark", "Melancholic", "Indie"]
        default:
            return []
        }
    }
    
    // MARK: - Filter Songs by Tags
    private func filterSongsByMoodTags(_ songs: [SongsModel], moods: Set<String>) -> [SongsModel] {
        guard !moods.isEmpty else { return songs }
        
        // Get all relevant tags for selected moods
        let relevantTags = moods.flatMap { getTagsForMood($0) }
        guard !relevantTags.isEmpty else { return songs }
        
        // Filter songs that have at least one matching tag with weight >= 0.5
        return songs.filter { song in
            guard let tags = song.tags, !tags.isEmpty else { return false }
            
            // Check if song has any tag matching the mood tags with sufficient weight
            return tags.contains { tag in
                relevantTags.contains(where: { $0.lowercased() == tag.name.lowercased() }) && tag.weight >= 0.5
            }
        }
    }
    
    private func getMyVibeSong() -> SongsModel? {
        guard !songManager.librarySongs.isEmpty else { return nil }
        
        // Get selected moods from preferences
        let selectedMoods = preferenceManager.getSelectedMoods()
        
        // If moods are selected, filter songs by tags
        var candidateSongs = songManager.librarySongs
        if !selectedMoods.isEmpty {
            candidateSongs = filterSongsByMoodTags(candidateSongs, moods: selectedMoods)
        }
        
        // If no songs match the mood tags, fall back to all songs
        if candidateSongs.isEmpty {
            candidateSongs = songManager.librarySongs
        }
        
        // For authenticated users, get the most liked song from filtered results
        if authService.isAuthenticated {
            return candidateSongs.max(by: { $0.likesCount < $1.likesCount })
        } else {
            // For guest users, return the first song from filtered results
            return candidateSongs.first
        }
    }
    
    private func myVibeCard(subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .medium))
                    Spacer()
                    Button {
                        showCustomizeMyVibe = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 12, weight: .medium))
                            Text("Customize")
                                .font(.caption)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.white.opacity(0.7))
                
                Text("My Vibe")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(0.18), Color.white.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
    
    private func discoverCard(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                    Spacer()
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.7))
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(0.18), Color.white.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
    
    // Tags View
    @ViewBuilder func TagsView() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Genres & moods")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal, 24)
            
        ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                ForEach(sampleTagList, id: \.id) { item in
                    Text(item.tag)
                            .font(.subheadline)
                            .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    
    // Quick Play Songs
    @ViewBuilder func QuickPlay() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Quick Play")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Button("See all") { }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 24)
            
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)], spacing: 18) {
                ForEach(quickPlaySongs, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 7) {
                        CachedAsyncImage(url: URL(string: item.cover)) { img in
                            img.resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: (UIScreen.main.bounds.width - 48 - 18) / 2 * 0.88 - 20)
                        .frame(height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        
                            Text(item.artist)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    .frame(width: (UIScreen.main.bounds.width - 48 - 18) / 2 * 0.88, alignment: .leading)
                    .frame(height: 171)
                    .padding(10)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 7)
                    .onTapGesture {
                        songManager.playSong(item, in: songManager.librarySongs)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
    }
    
    // Mixes / New Releases Section
    @ViewBuilder func MixesSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Mixes")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    if let first = songManager.librarySongs.first {
                        songManager.playSong(first, in: songManager.librarySongs)
                    }
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(LinearGradient(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .padding(.horizontal, 24)
            
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)], spacing: 18) {
                ForEach(mixesSongs, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 7) {
                        CachedAsyncImage(url: URL(string: item.cover)) { img in
                            img.resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: (UIScreen.main.bounds.width - 48 - 18) / 2 * 0.88 - 20)
                        .frame(height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        
                            Text(item.artist)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    .frame(width: (UIScreen.main.bounds.width - 48 - 18) / 2 * 0.88, alignment: .leading)
                    .frame(height: 171)
                    .padding(10)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 7)
                    .onTapGesture {
                        songManager.playSong(item, in: songManager.librarySongs)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
    }
    
    // Here we create a function to get Size of Top Safe Area
    private func getSafeAreaTop() -> CGFloat {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.top ?? 0
        
        return keyWindow
    }
    
    // Fetch stories from API
    private func fetchStoriesFromAPI() async {
        // Always use current user ID (defaults to guest if not authenticated)
        let currentUserId = authService.currentUserId
        
        // Fetch followers for current user
        var followers: [FollowerResponse] = []
        do {
            followers = try await storiesService.fetchFollowers(for: currentUserId)
        } catch {
            print("Failed to fetch followers: \(error.localizedDescription)")
        }
        
        // Fetch stories from API
        await storyManager.fetchStoriesFromAPI(
            currentUserId: currentUserId,
            followers: followers,
            allSongs: songManager.librarySongs
        )
    }
    
    // Update Quick Play songs
    private func updateQuickPlaySongs() {
        let likedSongs = songManager.likedSongs
        if !likedSongs.isEmpty {
            quickPlaySongs = Array(likedSongs.shuffled().prefix(6))
        } else {
            quickPlaySongs = Array(songManager.librarySongs.shuffled().prefix(6))
        }
    }
    
    // Update Mixes songs
    private func updateMixesSongs() {
        mixesSongs = Array(songManager.librarySongs.shuffled().prefix(6))
    }
}

// MARK: - Story Components

private struct StoryCircleView: View {
    let story: MusicStory
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    if story.isViewed {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            .frame(width: 70, height: 70)
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.pink, Color.orange, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 70, height: 70)
                    }
                    
                    Circle()
                        .fill(Color.black)
                        .frame(width: 66, height: 66)
                    
                    if let profileImageURL = story.profileImageURL, !profileImageURL.isEmpty {
                        CachedAsyncImage(url: URL(string: profileImageURL)) { img in
                            img.resizable()
                                .scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .frame(width: 66, height: 66)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                
                Text(story.userName)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(width: 70)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct StoryCreationView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var storyManager: StoryManager
    @ObservedObject var songManager: SongManager
    @State private var selectedSong: SongsModel?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Create Music Story")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.top)
                    
                    Text("Select a song to share")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.bottom)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                        ForEach(songManager.librarySongs) { song in
                            Button {
                                selectedSong = song
                                storyManager.createStory(with: song)
                                dismiss()
                            } label: {
                                VStack(spacing: 12) {
                                    CachedAsyncImage(url: URL(string: song.cover)) { img in
                                        img.resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 150, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    
                                    VStack(spacing: 4) {
                                        Text(song.title)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        
                                        Text(song.artist)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.7))
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - Customize My Vibe View
struct CustomizeMyVibeView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var preferenceManager = PreferenceManager()
    
    @State private var selectedActivities: Set<String> = []
    @State private var selectedCharacters: Set<String> = []
    @State private var selectedMoods: Set<String> = []
    @State private var selectedLanguages: Set<String> = []
    
    let activities = ["Waking up", "Working", "Working out", "Falling asleep", "Traveling"]
    let characters = [
        ("Favorite", "heart.fill", Color.red),
        ("Unfamiliar", "star.fill", Color.yellow),
        ("Popular", "bolt.fill", Color.white)
    ]
    let moods = [
        ("Energetic", Color.orange),
        ("Cheerful", Color.green),
        ("Calm", Color.cyan),
        ("Sad", Color.blue)
    ]
    let languages = ["Russian", "Foreign", "Wordless"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // by activity
                        VStack(alignment: .leading, spacing: 16) {
                            Text("by activity")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 24)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(activities, id: \.self) { activity in
                                        Button {
                                            if selectedActivities.contains(activity) {
                                                selectedActivities.remove(activity)
                                            } else {
                                                selectedActivities.insert(activity)
                                            }
                                        } label: {
                                            Text(activity)
                                                .font(.subheadline)
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 18)
                                                .padding(.vertical, 10)
                                                .background(
                                                    Capsule()
                                                        .fill(selectedActivities.contains(activity) ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        
                        // by character
                        VStack(alignment: .leading, spacing: 16) {
                            Text("by character")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 24)
                            
                            HStack(spacing: 16) {
                                ForEach(characters, id: \.0) { character in
                                    Button {
                                        if selectedCharacters.contains(character.0) {
                                            selectedCharacters.remove(character.0)
                                        } else {
                                            selectedCharacters.insert(character.0)
                                        }
                                    } label: {
                                        VStack(spacing: 12) {
                                            Image(systemName: character.1)
                                                .font(.system(size: 32, weight: .medium))
                                                .foregroundStyle(character.2)
                                            
                                            Text(character.0)
                                                .font(.subheadline)
                                                .foregroundStyle(.white)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 20)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(selectedCharacters.contains(character.0) ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        // by mood
                        VStack(alignment: .leading, spacing: 16) {
                            Text("by mood")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 24)
                            
                            HStack(spacing: 16) {
                                ForEach(moods, id: \.0) { mood in
                                    Button {
                                        if selectedMoods.contains(mood.0) {
                                            selectedMoods.remove(mood.0)
                                        } else {
                                            selectedMoods.insert(mood.0)
                                        }
                                        // Save moods immediately when changed
                                        preferenceManager.saveSelectedMoods(selectedMoods)
                                    } label: {
                                        VStack(spacing: 12) {
                                            Circle()
                                                .fill(mood.1)
                                                .frame(width: 60, height: 60)
                                            
                                            Text(mood.0)
                                                .font(.subheadline)
                                                .foregroundStyle(.white)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(selectedMoods.contains(mood.0) ? Color.white.opacity(0.2) : Color.clear)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        // by language
                        VStack(alignment: .leading, spacing: 16) {
                            Text("by language")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 24)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(languages, id: \.self) { language in
                                        Button {
                                            if selectedLanguages.contains(language) {
                                                selectedLanguages.remove(language)
                                            } else {
                                                selectedLanguages.insert(language)
                                            }
                                        } label: {
                                            Text(language)
                                                .font(.subheadline)
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 18)
                                                .padding(.vertical, 10)
                                                .background(
                                                    Capsule()
                                                        .fill(selectedLanguages.contains(language) ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        
                        // Reset button
                        Button {
                            selectedActivities.removeAll()
                            selectedCharacters.removeAll()
                            selectedMoods.removeAll()
                            selectedLanguages.removeAll()
                            // Save empty moods when reset
                            preferenceManager.saveSelectedMoods([])
                        } label: {
                            Text("Reset")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                    .padding(.top, 60)
                }
            }
            .navigationTitle("Customize My Vibe")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Save moods before dismissing
                        preferenceManager.saveSelectedMoods(selectedMoods)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .onAppear {
                // Load saved moods when view appears
                selectedMoods = preferenceManager.getSelectedMoods()
            }
        }
    }
}

#Preview {
    Home()
        .preferredColorScheme(.dark)
}
