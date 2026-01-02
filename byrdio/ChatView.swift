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
    @State private var messageText: String = ""
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
                            if isLoading {
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
                                    MessageBubble(message: message, isCurrentUser: message.senderId == authService.currentUserId)
                                        .id(message.id)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: messages.count) { _, _ in
                        // Scroll to bottom when new messages arrive
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
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
                    
                    TextField("Message", text: $messageText)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .focused($isTextFieldFocused)
                    
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: messageText.isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(messageText.isEmpty ? .white.opacity(0.7) : .blue)
                    }
                    .disabled(messageText.isEmpty)
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
            }
        }
    }
    
    // MARK: - Load Messages
    private func loadMessages() async {
        let currentUserId = authService.currentUserId
        guard let otherUserId = otherParticipant?.userId else {
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let fetchedMessages = try await messagesService.fetchMessages(
                chatId: chat.chatId,
                userId1: currentUserId,
                userId2: otherUserId
            )
            await MainActor.run {
                messages = fetchedMessages
                isLoading = false
            }
        } catch {
            print("Failed to fetch messages: \(error.localizedDescription)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    // MARK: - Send Message
    private func sendMessage() {
        // TODO: Implement send message API call
        // For now, just clear the text field
        messageText = ""
    }
}

// MARK: - Message Bubble
private struct MessageBubble: View {
    let message: MessageResponse
    let isCurrentUser: Bool
    
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
                
                Text(formatTime(message.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            if isCurrentUser {
                Spacer()
            }
        }
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

