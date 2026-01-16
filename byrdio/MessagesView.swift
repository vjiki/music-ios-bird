//
//  MessagesView.swift
//  music
//
//  Created by Nikolai Golubkin on 11/9/25.
//

import SwiftUI

struct MessagesView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    @StateObject private var messagesService = MessagesService()
    @StateObject private var storiesService = StoriesService()
    @State private var chats: [ChatResponse] = []
    @State private var followers: [FollowerResponse] = []
    @State private var isLoading: Bool = false
    @State private var isLoadingFollowers: Bool = false
    @State private var searchText: String = ""
    @State private var selectedChat: ChatResponse?
    @State private var showChatView = false
    
    private var currentUserNickname: String {
        authService.effectiveUser.nickname ?? authService.effectiveUser.name ?? "Guest"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Search bar
                searchBarView
                
                // Notes/Stories section
                notesSection
                
                // Messages section
                messagesSection
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                await loadChats()
                await loadFollowers()
            }
            .sheet(isPresented: $showChatView) {
                if let chat = selectedChat {
                    ChatView(chat: chat)
                        .environmentObject(authService)
                }
            }
        }
    }
    
    // MARK: - Load Chats
    private func loadChats() async {
        let currentUserId = authService.currentUserId
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let fetchedChats = try await messagesService.fetchChats(for: currentUserId)
            await MainActor.run {
                // Sort by last message time (newest first)
                chats = fetchedChats.sorted { chat1, chat2 in
                    let date1 = parseDate(chat1.lastMessageAt ?? chat1.updatedAt) ?? Date.distantPast
                    let date2 = parseDate(chat2.lastMessageAt ?? chat2.updatedAt) ?? Date.distantPast
                    return date1 > date2
                }
                isLoading = false
            }
        } catch {
            print("Failed to fetch chats: \(error.localizedDescription)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    // MARK: - Load Followers
    private func loadFollowers() async {
        let currentUserId = authService.currentUserId
        
        await MainActor.run {
            isLoadingFollowers = true
        }
        
        do {
            let fetchedFollowers = try await storiesService.fetchFollowers(for: currentUserId)
            await MainActor.run {
                followers = fetchedFollowers
                isLoadingFollowers = false
            }
        } catch {
            print("Failed to fetch followers: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingFollowers = false
            }
        }
    }
    
    // MARK: - Open Chat with Follower
    private func openChatWithFollower(_ follower: FollowerResponse) async {
        let currentUserId = authService.currentUserId
        
        // First, try to find an existing chat with this follower
        let existingChat = chats.first { chat in
            chat.participants.contains { $0.userId == follower.followerId }
        }
        
        if let chat = existingChat {
            await MainActor.run {
                selectedChat = chat
                showChatView = true
            }
        } else {
            // Create a new chat via API
            do {
                let request = CreateChatRequest(
                    type: "DIRECT",
                    title: nil,
                    description: nil,
                    avatarUrl: nil,
                    ownerId: nil,
                    participantIds: [currentUserId, follower.followerId],
                    isEncrypted: false
                )
                
                let chatDetail = try await messagesService.createChat(request)
                
                // Convert ChatDetailResponse to ChatResponse
                let newChat = ChatResponse(
                    chatId: chatDetail.id,
                    chatType: chatDetail.type,
                    title: chatDetail.title ?? "Direct Chat",
                    avatarUrl: chatDetail.avatarUrl,
                    lastMessagePreview: nil,
                    lastMessageAt: nil,
                    lastMessageSenderId: nil,
                    lastMessageSenderName: nil,
                    unreadCount: 0,
                    isMuted: chatDetail.isMuted,
                    updatedAt: chatDetail.updatedAt,
                    participants: chatDetail.participants.map { participant in
                        ChatParticipant(
                            userId: participant.userId,
                            userNickname: participant.userNickname,
                            userAvatarUrl: participant.userAvatarUrl
                        )
                    }
                )
                
                await MainActor.run {
                    chats.insert(newChat, at: 0)
                    selectedChat = newChat
                    showChatView = true
                }
            } catch {
                print("Failed to create chat: \(error.localizedDescription)")
            }
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString)
    }
    
    private func timeAgoString(from dateString: String?) -> String {
        guard let dateString = dateString,
              let date = parseDate(dateString) else {
            return ""
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - Filtered Chats
    private var filteredChats: [ChatResponse] {
        if searchText.isEmpty {
            return chats
        }
        return chats.filter { chat in
            chat.title.localizedCaseInsensitiveContains(searchText) ||
            chat.participants.contains { $0.userNickname.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
            }
            
            Text(currentUserNickname)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            
            Spacer()
            
            Button {
                // Edit action
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Search Bar View
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.6))
                .padding(.leading, 12)
            
            TextField("Search", text: $searchText)
                .foregroundStyle(.white)
                .padding(.vertical, 10)
        }
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
    
    // MARK: - Notes Section
    private var notesSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Followers
                if isLoadingFollowers {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 70, height: 70)
                } else {
                    ForEach(followers, id: \.followerId) { follower in
                        FollowerNoteItem(follower: follower) {
                            Task {
                                await openChatWithFollower(follower)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 16)
    }
    
    // MARK: - Messages Section
    private var messagesSection: some View {
        VStack(spacing: 0) {
            // Messages header
            HStack {
                Text("Messages")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                
                Image(systemName: "arrow.2.squarepath")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.leading, 8)
                
                Spacer()
                
                Button {
                    // Requests action
                } label: {
                    Text("Requests (1)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Messages list
            ScrollView {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding(.top, 40)
                } else if chats.isEmpty {
                    Text("No messages yet")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredChats) { chat in
                            ChatRow(chat: chat, timeAgo: timeAgoString(from: chat.lastMessageAt ?? chat.updatedAt)) {
                                selectedChat = chat
                                showChatView = true
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Note Item
private struct NoteItem: View {
    let profileImage: String?
    let bubbleText: String
    let label: String
    var showLocationOff: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .top) {
                // Profile image
                if let avatarUrl = profileImage, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(width: 70, height: 70)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(width: 70, height: 70)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // Bubble
                if !bubbleText.isEmpty {
                    Text(bubbleText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .offset(y: -25)
                        .frame(maxWidth: 100)
                }
            }
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.white)
                .lineLimit(1)
            
            if showLocationOff {
                Text("Location off")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .frame(width: 80)
    }
}

// MARK: - Follower Note Item
private struct FollowerNoteItem: View {
    let follower: FollowerResponse
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Profile image
                if let avatarUrl = follower.followerAvatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(width: 70, height: 70)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(width: 70, height: 70)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Text(follower.followerNickname)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(width: 80)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chat Row
private struct ChatRow: View {
    let chat: ChatResponse
    let timeAgo: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile image
                if let avatarUrl = chat.avatarUrl ?? chat.participants.first?.userAvatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(width: 54, height: 54)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(width: 54, height: 54)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // Name and status
                VStack(alignment: .leading, spacing: 4) {
                    Text(chat.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        if let lastMessagePreview = chat.lastMessagePreview, !lastMessagePreview.isEmpty {
                            Text(lastMessagePreview)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                            
                            if !timeAgo.isEmpty {
                                Text("· \(timeAgo)")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        } else if !timeAgo.isEmpty {
                            Text(timeAgo)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                // Unread indicator and camera
                HStack(spacing: 12) {
                    if chat.unreadCount > 0 {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                    
                    Button {
                        // Camera action
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MessagesView()
        .preferredColorScheme(.dark)
}

