import SwiftUI

/// フィード・書籍詳細・ユーザーページで共用するコメント行。
struct CommentRow: View {
    let comment: BookCommentItem
    var showsBookTitle = false
    var enablesAuthorLink = true
    var myUserID: String?
    /// 通報・ブロック・削除でリストの再読込が必要になったとき呼ばれる
    var onChanged: () -> Void = {}

    @State private var isShowingReportDialog = false
    @State private var isShowingBlockConfirm = false
    @State private var errorMessage: String?

    private var isMine: Bool { myUserID != nil && myUserID == comment.authorID }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if enablesAuthorLink {
                    NavigationLink(value: SocialRoute.user(id: comment.authorID, nickname: comment.authorNickname)) {
                        authorLabel
                    }
                    .buttonStyle(.plain)
                } else {
                    authorLabel
                }
                Spacer(minLength: 0)
                Text(comment.createdAt, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if showsBookTitle {
                NavigationLink(value: SocialRoute.book(isbn13: comment.isbn)) {
                    HStack(spacing: 6) {
                        Image(systemName: "book.closed")
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(comment.bookTitle)
                                .font(.footnote.weight(.semibold))
                                .lineLimit(1)
                            if let author = comment.bookAuthor {
                                Text(author)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(8)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Text(comment.text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
        .contextMenu { menuItems }
        .confirmationDialog("このコメントを通報しますか？", isPresented: $isShowingReportDialog, titleVisibility: .visible) {
            Button("不適切な内容として通報", role: .destructive) { report(reason: "不適切な内容") }
            Button("スパムとして通報", role: .destructive) { report(reason: "スパム") }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("通報するとこのコメントは非表示になり、運営が確認します。")
        }
        .confirmationDialog("\(comment.authorNickname) さんをブロックしますか？", isPresented: $isShowingBlockConfirm, titleVisibility: .visible) {
            Button("ブロック", role: .destructive) {
                ModerationStore.block(userID: comment.authorID)
                onChanged()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("このユーザーの投稿がすべて非表示になります。")
        }
    }

    private var authorLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.circle.fill")
                .foregroundStyle(.secondary)
            Text(comment.authorNickname)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isMine ? Color.accentColor : .primary)
            if isMine {
                Text("自分")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
            }
        }
    }

    @ViewBuilder
    private var menuItems: some View {
        if isMine {
            Button(role: .destructive) { deleteOwn() } label: {
                Label("コメントを削除", systemImage: "trash")
            }
        } else {
            Button { isShowingReportDialog = true } label: {
                Label("通報する", systemImage: "flag")
            }
            Button(role: .destructive) { isShowingBlockConfirm = true } label: {
                Label("このユーザーをブロック", systemImage: "hand.raised")
            }
        }
    }

    private func report(reason: String) {
        Task {
            do {
                try await SocialService.shared.report(comment: comment, reason: reason)
                await MainActor.run { onChanged() }
            } catch {
                // 未サインインでもローカルでは非表示にする
                ModerationStore.hide(commentID: comment.id)
                await MainActor.run { onChanged() }
            }
        }
    }

    private func deleteOwn() {
        Task {
            do {
                try await SocialService.shared.deleteComment(comment)
                await MainActor.run { onChanged() }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }
}

/// ソーシャル画面共通のナビゲーション先。
enum SocialRoute: Hashable {
    case user(id: String, nickname: String)
    case book(isbn13: String)
}
