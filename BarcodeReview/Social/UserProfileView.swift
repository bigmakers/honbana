import SwiftUI

/// 他ユーザー（または自分）のプロフィールページ。投稿一覧とフォロー/ブロック操作。
struct UserProfileView: View {
    let userID: String
    let nickname: String

    @State private var comments: [BookCommentItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var myUserID: String?
    @State private var isFollowing: Bool?
    @State private var isMutatingFollow = false
    @State private var isBlocked = false

    private var isMe: Bool { myUserID != nil && myUserID == userID }

    var body: some View {
        List {
            Section {
                header
            }

            Section("投稿したコメント") {
                if isLoading {
                    HStack { ProgressView(); Text("読み込み中…").foregroundStyle(.secondary) }
                } else if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.footnote)
                } else if comments.isEmpty {
                    Text(isBlocked ? "ブロック中のため投稿は非表示です" : "まだ投稿がありません")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                } else {
                    ForEach(comments) { comment in
                        CommentRow(
                            comment: comment,
                            showsBookTitle: true,
                            enablesAuthorLink: false,
                            myUserID: myUserID,
                            onChanged: { Task { await reload() } }
                        )
                    }
                }
            }
        }
        .navigationTitle(nickname)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isMe {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if isBlocked {
                            Button {
                                ModerationStore.unblock(userID: userID)
                                isBlocked = false
                                Task { await reload() }
                            } label: {
                                Label("ブロックを解除", systemImage: "hand.raised.slash")
                            }
                        } else {
                            Button(role: .destructive) {
                                ModerationStore.block(userID: userID)
                                isBlocked = true
                                comments = []
                            } label: {
                                Label("このユーザーをブロック", systemImage: "hand.raised")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task { await load() }
        .refreshable { await reload() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(nickname).font(.headline)
                Text(isMe ? "自分のページ" : "\(comments.count) 件の投稿")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !isMe && !isBlocked {
                followButton
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var followButton: some View {
        if let isFollowing {
            if isFollowing {
                Button {
                    toggleFollow(currently: true)
                } label: {
                    Text("フォロー中").font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .disabled(isMutatingFollow)
            } else {
                Button {
                    toggleFollow(currently: false)
                } label: {
                    Text("フォロー").font(.footnote.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(isMutatingFollow)
            }
        } else if myUserID != nil {
            ProgressView()
        }
    }

    private func toggleFollow(currently: Bool) {
        isMutatingFollow = true
        Task {
            defer { isMutatingFollow = false }
            do {
                if currently {
                    try await SocialService.shared.unfollow(userID: userID)
                    isFollowing = false
                } else {
                    try await SocialService.shared.follow(userID: userID)
                    isFollowing = true
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func load() async {
        isBlocked = ModerationStore.isBlocked(userID: userID)
        myUserID = try? await SocialService.shared.currentUserID()
        if !isMe, myUserID != nil {
            isFollowing = (try? await SocialService.shared.isFollowing(userID: userID)) ?? false
        }
        await reload()
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard !ModerationStore.isBlocked(userID: userID) else {
            isBlocked = true
            comments = []
            return
        }
        isBlocked = false
        do {
            comments = try await SocialService.shared.comments(authorID: userID)
        } catch {
            comments = []
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
