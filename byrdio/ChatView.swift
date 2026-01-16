//
//  ChatView.swift
//  music
//
//  Created by Nikolai Golubkin on 11/11/25.
//

import SwiftUI

struct ChatView: View {
    let chat: ChatResponse
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    @StateObject private var messagesService = MessagesService()
    @State private var messages: [MessageResponse] = []
    @State private var isLoading: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var messageText: String = ""
    @State private var isSending: Bool = false
    @State private var selectedMessageForReply: MessageResponse?
    @State private var messageReactions: [String: [MessageReactionResponse]] = [:]
    @State private var showReactionsPicker: String? = nil
    @State private var nextCursor: String? = nil
    @State private var hasMoreMessages: Bool = false
    @State private var replyToMessages: [String: MessageResponse] = [:] // Cache for reply-to messages
    @FocusState private var isTextFieldFocused: Bool
    
    private var otherParticipant: ChatParticipant? {
        let currentUserId = authService.currentUserId
        return chat.participants.first { $0.userId != currentUserId }
    }
    
    private var chatTitle: String {
        otherParticipant?.userNickname ?? chat.title
    }
    
    private var chatAvatarUrl: String? {
        otherParticipant?.userAvatarUrl ?? chat.avatarUrl
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Load more button at top
                            if hasMoreMessages && !isLoadingMore {
                                Button {
                                    Task {
                                        await loadMoreMessages()
                                    }
                                } label: {
                                    Text("Load older messages")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                        .padding(.vertical, 8)
                                }
                            }
                            
                            if isLoading && messages.isEmpty {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.top, 40)
                            } else if messages.isEmpty {
                                Text("No messages yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .padding(.top, 40)
                            } else {
                                ForEach(messages) { message in
                                    MessageBubble(
                                        message: message,
                                        isCurrentUser: message.senderId == authService.currentUserId,
                                        reactions: messageReactions[message.id] ?? [],
                                        replyToMessage: replyToMessages[message.replyToId ?? ""],
                                        onReply: {
                                            selectedMessageForReply = message
                                        },
                                        onDelete: {
                                            Task {
                                                await deleteMessage(message.id)
                                            }
                                        },
                                        onReaction: { emoji in
                                            Task {
                                                await toggleReaction(messageId: message.id, emoji: emoji)
                                            }
                                        },
                                        showReactionsPicker: showReactionsPicker == message.id,
                                        onShowReactionsPicker: {
                                            showReactionsPicker = showReactionsPicker == message.id ? nil : message.id
                                        }
                                    )
                                    .id(message.id)
                                    .contextMenu {
                                        if message.senderId == authService.currentUserId {
                                            Button(role: .destructive) {
                                                Task {
                                                    await deleteMessage(message.id)
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        } else {
                                            Button {
                                                selectedMessageForReply = message
                                            } label: {
                                                Label("Reply", systemImage: "arrowshape.turn.up.left")
                                            }
                                        }
                                        
                                        Button {
                                            showReactionsPicker = showReactionsPicker == message.id ? nil : message.id
                                        } label: {
                                            Label("Add Reaction", systemImage: "face.smiling")
                                        }
                                    }
                                }
                            }
                            
                            if isLoadingMore {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.vertical, 8)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: messages.count) { oldCount, newCount in
                        // Scroll to bottom when new messages arrive (only if we're at the bottom)
                        if newCount > oldCount, let lastMessage = messages.last {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    .onAppear {
                        // Scroll to bottom when view appears
                        if let lastMessage = messages.last {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                
                // Message input
                HStack(spacing: 12) {
                    Button {
                        // Camera action
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    VStack(spacing: 4) {
                        if let replyMessage = selectedMessageForReply {
                            HStack {
                                Text("Replying to \(replyMessage.senderNickname)")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                Spacer()
                                Button {
                                    selectedMessageForReply = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        TextField("Message", text: $messageText)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                sendMessage()
                            }
                    }
                    
                    Button {
                        sendMessage()
                    } label: {
                        if isSending {
                            ProgressView()
                                .tint(.blue)
                        } else {
                            Image(systemName: messageText.isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(messageText.isEmpty ? .white.opacity(0.7) : .blue)
                        }
                    }
                    .disabled(messageText.isEmpty || isSending)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(.white)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        if let avatarUrl = chatAvatarUrl, !avatarUrl.isEmpty {
                            AsyncImage(url: URL(string: avatarUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        Text(chatTitle)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Video call action
                    } label: {
                        Image(systemName: "video.fill")
                            .foregroundStyle(.white)
                    }
                }
            }
            .task {
                await loadMessages()
                await loadReactionsForMessages()
            }
            .refreshable {
                await loadMessages()
                await loadReactionsForMessages()
            }
        }
    }
    
    // MARK: - Load Messages
    private func loadMessages() async {
        let currentUserId = authService.currentUserId
        guard let otherUserId = otherParticipant?.userId else {
            return
        }
        
        let messagesService = self.messagesService
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Try paginated endpoint first
            let page = try await messagesService.fetchMessagesPage(chatId: chat.chatId, limit: 50)
            await MainActor.run {
                messages = page.items.reversed() // Reverse to show oldest first
                nextCursor = page.nextCursor
                hasMoreMessages = page.hasNext
                isLoading = false
            }
            
            // Load reply-to messages
            await loadReplyToMessages()
        } catch {
            // Fallback to non-paginated endpoint
            do {
                let fetchedMessages = try await messagesService.fetchMessages(
                    chatId: chat.chatId,
                    userId1: currentUserId,
                    userId2: otherUserId
                )
                await MainActor.run {
                    messages = fetchedMessages
                    hasMoreMessages = false
                    isLoading = false
                }
                
                // Load reply-to messages
                await loadReplyToMessages()
            } catch {
                print("Failed to fetch messages: \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - Load More Messages (Pagination)
    private func loadMoreMessages() async {
        guard let cursor = nextCursor, hasMoreMessages else {
            return
        }
        
        let messagesService = self.messagesService
        
        await MainActor.run {
            isLoadingMore = true
        }
        
        do {
            let page = try await messagesService.fetchMessagesPage(chatId: chat.chatId, limit: 20, cursor: cursor)
            await MainActor.run {
                // Prepend older messages at the beginning
                messages = page.items.reversed() + messages
                nextCursor = page.nextCursor
                hasMoreMessages = page.hasNext
                isLoadingMore = false
            }
            
            // Load reply-to messages for new messages
            await loadReplyToMessages()
        } catch {
            print("Failed to load more messages: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingMore = false
            }
        }
    }
    
    // MARK: - Load Reply-To Messages
    private func loadReplyToMessages() async {
        var replyToIds: Set<String> = []
        
        for message in messages {
            if let replyToId = message.replyToId {
                replyToIds.insert(replyToId)
            }
        }
        
        // Find reply-to messages in current messages list
        var replyToDict: [String: MessageResponse] = [:]
        for message in messages {
            if replyToIds.contains(message.id) {
                replyToDict[message.id] = message
            }
        }
        
        await MainActor.run {
            replyToMessages = replyToDict
        }
    }
    
    // MARK: - Send Message
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let currentUserId = authService.currentUserId
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let replyToId = selectedMessageForReply?.id
        let messagesService = self.messagesService
        
        Task {
            await MainActor.run {
                isSending = true
            }
            
            do {
                let request = CreateMessageRequest(
                    chatId: chat.chatId,
                    senderId: currentUserId,
                    content: content,
                    messageType: "TEXT",
                    replyToId: replyToId,
                    songId: nil,
                    attachmentCount: nil
                )
                
                let newMessage = try await messagesService.sendMessage(request)
                
                await MainActor.run {
                    messages.append(newMessage)
                    messageText = ""
                    selectedMessageForReply = nil
                    isSending = false
                }
                
                // If this is a reply, cache the reply-to message
                if let replyToId = newMessage.replyToId {
                    if let replyToMessage = messages.first(where: { $0.id == replyToId }) {
                        await MainActor.run {
                            replyToMessages[replyToId] = replyToMessage
                        }
                    }
                }
                
                // Mark message as read and load reactions in background
                Task {
                    try? await messagesService.markMessageAsRead(messageId: newMessage.id, userId: currentUserId)
                    await loadReactionsForMessages()
                }
            } catch {
                print("Failed to send message: \(error.localizedDescription)")
                await MainActor.run {
                    isSending = false
                }
            }
        }
    }
    
    // MARK: - Delete Message
    private func deleteMessage(_ messageId: String) async {
        let messagesService = self.messagesService
        
        do {
            try await messagesService.deleteMessage(messageId)
            await MainActor.run {
                messages.removeAll { $0.id == messageId }
            }
        } catch {
            print("Failed to delete message: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Reactions
    private func loadReactionsForMessages() async {
        let messagesService = self.messagesService
        let currentMessages = self.messages
        var reactionsDict: [String: [MessageReactionResponse]] = [:]
        
        for message in currentMessages {
            do {
                let reactions = try await messagesService.getMessageReactions(message.id)
                reactionsDict[message.id] = reactions
            } catch {
                print("Failed to load reactions for message \(message.id): \(error.localizedDescription)")
            }
        }
        
        await MainActor.run {
            messageReactions = reactionsDict
        }
    }
    
    private func toggleReaction(messageId: String, emoji: String) async {
        let currentUserId = authService.currentUserId
        let messagesService = self.messagesService
        
        // Check if user already has this reaction
        let existingReactions = messageReactions[messageId] ?? []
        let hasReaction = existingReactions.contains { $0.userId == currentUserId && $0.emoji == emoji }
        
        do {
            if hasReaction {
                // Remove reaction
                try await messagesService.removeReaction(messageId: messageId, userId: currentUserId, emoji: emoji)
            } else {
                // Add reaction
                let request = MessageReactionRequest(messageId: messageId, userId: currentUserId, emoji: emoji)
                try await messagesService.addReaction(request)
            }
            
            // Reload reactions for this message
            let updatedReactions = try await messagesService.getMessageReactions(messageId)
            await MainActor.run {
                messageReactions[messageId] = updatedReactions
            }
        } catch {
            print("Failed to toggle reaction: \(error.localizedDescription)")
        }
    }
}

// MARK: - Message Bubble
private struct MessageBubble: View {
    let message: MessageResponse
    let isCurrentUser: Bool
    let reactions: [MessageReactionResponse]
    let replyToMessage: MessageResponse?
    let onReply: () -> Void
    let onDelete: () -> Void
    let onReaction: (String) -> Void
    let showReactionsPicker: Bool
    let onShowReactionsPicker: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isCurrentUser {
                // Other user's avatar
                if let avatarUrl = message.senderAvatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.senderNickname)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                // Reply indicator
                if let replyToMessage = replyToMessage {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(replyToMessage.senderNickname)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.7))
                            
                            Text(replyToMessage.content)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if message.replyToId != nil {
                    // Reply-to message not found, show simple indicator
                    HStack {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                        Text("Replying to a message")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        isCurrentUser
                        ? Color.blue
                        : Color.white.opacity(0.15)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                
                // Reactions
                if !reactions.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(groupedReactions, id: \.emoji) { group in
                            Button {
                                onReaction(group.emoji)
                            } label: {
                                HStack(spacing: 2) {
                                    Text(group.emoji)
                                        .font(.caption)
                                    if group.count > 1 {
                                        Text("\(group.count)")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
                
                // Reactions picker
                if showReactionsPicker {
                    HStack(spacing: 8) {
                        ForEach(["👍", "❤️", "😂", "😮", "😢", "🙏"], id: \.self) { emoji in
                            Button {
                                onReaction(emoji)
                                onShowReactionsPicker()
                            } label: {
                                Text(emoji)
                                    .font(.title2)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                
                HStack(spacing: 4) {
                    Text(formatTime(message.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    
                    if message.isEdited {
                        Text("Edited")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            
            if isCurrentUser {
                Spacer()
            }
        }
    }
    
    private var groupedReactions: [(emoji: String, count: Int)] {
        let grouped = Dictionary(grouping: reactions, by: { $0.emoji })
        return grouped.map { (emoji: $0.key, count: $0.value.count) }
            .sorted { $0.emoji < $1.emoji }
    }
    
    private func formatTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: dateString) else {
            return ""
        }
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        return timeFormatter.string(from: date)
    }
}

#Preview {
    ChatView(chat: ChatResponse(
        chatId: "test",
        chatType: "DIRECT",
        title: "Test Chat",
        avatarUrl: nil,
        lastMessagePreview: "Test message",
        lastMessageAt: nil,
        lastMessageSenderId: nil,
        lastMessageSenderName: nil,
        unreadCount: 0,
        isMuted: false,
        updatedAt: "",
        participants: []
    ))
    .environmentObject(AuthService())
    .preferredColorScheme(.dark)
}

