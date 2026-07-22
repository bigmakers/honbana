import SwiftUI

/// 書籍詳細画面に埋め込む「みんなのコメント」セクション（閲覧 + 投稿）。
struct BookCommentsSection: View {
    let isbn13: String
    let bookTitle: String
    let bookAuthor: String?

    @State private var comments: [BookCommentItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var myUserID: String?

    @State private var draft = ""
    @State private var isPosting = false
    @State private var isShowingNicknameSheet = false
    @State private var postErrorMessage: String?
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("みんなのコメント", systemImage: "building.columns")
                    .font(.headline)
                Spacer()
                if !comments.isEmpty {
                    Text("\(comments.count) 件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            composer

            if isLoading {
                HStack { ProgressView(); Text("読み込み中…").foregroundStyle(.secondary).font(.footnote) }
                    .padding(.vertical, 8)
            } else if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.icloud")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding(.vertical, 8)
            } else if comments.isEmpty {
                Text("この本にはまだコメントがありません。最初の感想を残しましょう。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(comments) { comment in
                        CommentRow(
                            comment: comment,
                            myUserID: myUserID,
                            onChanged: { Task { await reload() } }
                        )
                        if comment.id != comments.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .task(id: isbn13) {
            myUserID = try? await SocialService.shared.currentUserID()
            await reload()
        }
        .sheet(isPresented: $isShowingNicknameSheet) {
            NicknameSheet { profile in
                myUserID = profile.userID
                Task { await post() }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("この本の感想をみんなに公開…", text: $draft, axis: .vertical)
                    .lineLimit(2...5)
                    .focused($isComposerFocused)
                    .padding(8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                Button {
                    Task { await postTapped() }
                } label: {
                    if isPosting {
                        ProgressView()
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPosting || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let postErrorMessage {
                Label(postErrorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Text("コメントは全ユーザーに公開されます。不適切な投稿は通報・削除の対象になります。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func postTapped() async {
        postErrorMessage = nil
        do {
            guard await SocialService.shared.isAccountAvailable() else {
                throw SocialError.iCloudAccountRequired
            }
            if try await SocialService.shared.myProfile() == nil {
                isShowingNicknameSheet = true
                return
            }
            await post()
        } catch {
            postErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func post() async {
        isPosting = true
        defer { isPosting = false }
        do {
            try await SocialService.shared.postComment(
                isbn: isbn13,
                bookTitle: bookTitle,
                bookAuthor: bookAuthor,
                text: draft
            )
            draft = ""
            isComposerFocused = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await reload()
        } catch {
            postErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func reload() async {
        isLoading = comments.isEmpty
        errorMessage = nil
        defer { isLoading = false }
        do {
            comments = try await SocialService.shared.comments(isbn: isbn13)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
