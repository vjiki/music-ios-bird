//
//  CommentsView.swift
//  byrdio
//
//  Created by Nikolai Golubkin on 14. 1. 2026..
//

import SwiftUI

struct CommentsView: View {
    let trackId: String
    let userId: String
    @Environment(\.dismiss) var dismiss
    @StateObject private var commentsService = CommentsService()
    @State private var comments: [CommentModel] = []
    @State private var newCommentText: String = ""
    @State private var replyingToComment: CommentModel? = nil
    @State private var replyText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Comments list
                    if isLoading && comments.isEmpty {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                        Text("Loading comments...")
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.top, 16)
                        Spacer()
                    } else if comments.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "bubble.right")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.5))
                            Text("No comments yet")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.7))
                            Text("Be the first to comment!")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 16) {
                                ForEach($comments) { $comment in
                                    CommentRow(
                                        comment: $comment,
                                        userId: userId,
                                        onLike: { comment in
                                            await toggleLike(comment: comment)
                                        },
                                        onReply: { comment in
                                            replyingToComment = comment
                                            replyText = ""
                                        },
                                        onDelete: { comment in
                                            await deleteComment(comment: comment)
                                        }
                                    )
                                    
                                    // Show replies
                                    if !comment.replies.isEmpty {
                                        ForEach($comment.replies) { $reply in
                                            CommentRow(
                                                comment: $reply,
                                                userId: userId,
                                                isReply: true,
                                                onLike: { comment in
                                                    await toggleLike(comment: comment)
                                                },
                                                onReply: { comment in
                                                    replyingToComment = comment
                                                    replyText = ""
                                                },
                                                onDelete: { comment in
                                                    await deleteComment(comment: comment)
                                                }
                                            )
                                            .padding(.leading, 40)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        }
                    }
                    
                    // Reply input (when replying to a comment)
                    if let replyingTo = replyingToComment {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Replying to \(replyingTo.userNickname)")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Button {
                                    replyingToComment = nil
                                    replyText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            
                            HStack(spacing: 12) {
                                TextField("Write a reply...", text: $replyText, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(.white)
                                    .padding(12)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .lineLimit(1...4)
                                
                                Button {
                                    Task {
                                        await addReply(to: replyingTo, content: replyText)
                                    }
                                } label: {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .white.opacity(0.3) : .blue)
                                }
                                .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                        .background(Color.black.opacity(0.8))
                    }
                    
                    // New comment input
                    HStack(spacing: 12) {
                        TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .lineLimit(1...4)
                        
                        Button {
                            Task {
                                await addComment(content: newCommentText)
                            }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .white.opacity(0.3) : .blue)
                        }
                        .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.8))
                }
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .task {
                await loadComments()
            }
            .refreshable {
                await loadComments()
            }
        }
    }
    
    // MARK: - Load Comments
    private func loadComments() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedComments = try await commentsService.fetchComments(trackId: trackId, userId: userId)
            await MainActor.run {
                comments = fetchedComments
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
            print("Failed to load comments: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Add Comment
    private func addComment(content: String) async {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }
        
        do {
            let newComment = try await commentsService.addComment(
                trackId: trackId,
                userId: userId,
                content: trimmedContent
            )
            await MainActor.run {
                comments.insert(newComment, at: 0)
                newCommentText = ""
            }
        } catch {
            print("Failed to add comment: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Add Reply
    private func addReply(to parentComment: CommentModel, content: String) async {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }
        
        do {
            let newReply = try await commentsService.addReply(
                trackId: trackId,
                userId: userId,
                content: trimmedContent,
                parentId: parentComment.id
            )
            await MainActor.run {
                // Find the parent comment and add the reply
                if let index = comments.firstIndex(where: { $0.id == parentComment.id }) {
                    comments[index].replies.append(newReply)
                    comments[index].repliesCount += 1
                }
                replyingToComment = nil
                replyText = ""
            }
        } catch {
            print("Failed to add reply: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Toggle Like
    private func toggleLike(comment: CommentModel) async {
        let wasLiked = comment.isLiked
        
        // Optimistically update UI
        await MainActor.run {
            updateCommentLikeStatus(commentId: comment.id, isLiked: !wasLiked)
        }
        
        do {
            if wasLiked {
                try await commentsService.removeReaction(commentId: comment.id, userId: userId)
            } else {
                try await commentsService.addReaction(commentId: comment.id, userId: userId)
            }
        } catch {
            print("Failed to toggle like: \(error.localizedDescription)")
            // Revert on error
            await MainActor.run {
                updateCommentLikeStatus(commentId: comment.id, isLiked: wasLiked)
            }
        }
    }
    
    // MARK: - Delete Comment
    private func deleteComment(comment: CommentModel) async {
        do {
            try await commentsService.removeComment(commentId: comment.id)
            await MainActor.run {
                // Remove from comments list
                if let index = comments.firstIndex(where: { $0.id == comment.id }) {
                    comments.remove(at: index)
                } else {
                    // It's a reply, find and remove from parent
                    for i in comments.indices {
                        if let replyIndex = comments[i].replies.firstIndex(where: { $0.id == comment.id }) {
                            comments[i].replies.remove(at: replyIndex)
                            comments[i].repliesCount = max(0, comments[i].repliesCount - 1)
                            break
                        }
                    }
                }
            }
        } catch {
            print("Failed to delete comment: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Update Comment Like Status
    private func updateCommentLikeStatus(commentId: String, isLiked: Bool) {
        // Update in main comments
        if let index = comments.firstIndex(where: { $0.id == commentId }) {
            var updatedComment = comments[index]
            let previousLiked = updatedComment.isLiked
            updatedComment.isLiked = isLiked
            
            // Adjust likes count
            if isLiked && !previousLiked {
                updatedComment.likesCount += 1
            } else if !isLiked && previousLiked {
                updatedComment.likesCount = max(0, updatedComment.likesCount - 1)
            }
            
            comments[index] = updatedComment
        } else {
            // Update in replies
            for i in comments.indices {
                if let replyIndex = comments[i].replies.firstIndex(where: { $0.id == commentId }) {
                    var updatedReply = comments[i].replies[replyIndex]
                    let previousLiked = updatedReply.isLiked
                    updatedReply.isLiked = isLiked
                    
                    // Adjust likes count
                    if isLiked && !previousLiked {
                        updatedReply.likesCount += 1
                    } else if !isLiked && previousLiked {
                        updatedReply.likesCount = max(0, updatedReply.likesCount - 1)
                    }
                    
                    comments[i].replies[replyIndex] = updatedReply
                    break
                }
            }
        }
    }
}

// MARK: - Comment Row
struct CommentRow: View {
    @Binding var comment: CommentModel
    let userId: String
    var isReply: Bool = false
    let onLike: (CommentModel) async -> Void
    let onReply: (CommentModel) -> Void
    let onDelete: (CommentModel) async -> Void
    
    init(
        comment: Binding<CommentModel>,
        userId: String,
        isReply: Bool = false,
        onLike: @escaping (CommentModel) async -> Void,
        onReply: @escaping (CommentModel) -> Void,
        onDelete: @escaping (CommentModel) async -> Void
    ) {
        self._comment = comment
        self.userId = userId
        self.isReply = isReply
        self.onLike = onLike
        self.onReply = onReply
        self.onDelete = onDelete
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            CachedAsyncImage(url: URL(string: comment.userAvatarUrl ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                // User name and content
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(comment.userNickname)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        
                        Text(comment.content)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    // Delete button (only for own comments)
                    if comment.userId == userId {
                        Button {
                            Task {
                                await onDelete(comment)
                            }
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                
                // Actions
                HStack(spacing: 16) {
                    // Like button
                    Button {
                        Task {
                            await onLike(comment)
                        }
                    } label: {
                            HStack(spacing: 4) {
                                Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                                    .font(.caption)
                                    .foregroundStyle(comment.isLiked ? .pink : .white.opacity(0.7))
                                Text("\(comment.likesCount)")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                    }
                    
                    // Reply button
                    if !isReply {
                        Button {
                            onReply(comment)
                        } label: {
                            Text("Reply")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    
                    // Time
                    Text(formatDate(comment.createdAt))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d"
        }
    }
}
