import SwiftUI

/// 「みんなの図書館」タブ — 全ユーザー共有のコメントタイムライン。
struct SocialFeedView: View {
    enum Scope: String, CaseIterable, Identifiable {
        case everyone = "全体"
        case following = "フォロー中"
        var id: String { rawValue }
    }

    @State private var scope: Scope = .everyone
    @State private var comments: [BookCommentItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var myUserID: String?
    @State private var myProfile: UserProfile?
    @State private var isShowingNicknameSheet = false
    @State private var accountAvailable = true

    var body: some View {
        VStack(spacing: 0) {
            Picker("表示範囲", selection: $scope) {
                ForEach(Scope.allCases) { s in Text(s.rawValue).tag(s) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            content
        }
        .navigationTitle("みんなの図書館")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingNicknameSheet = true
                } label: {
                    Label(myProfile?.nickname ?? "ニックネーム", systemImage: "person.crop.circle")
                        .labelStyle(.titleAndIcon)
                        .font(.footnote)
                }
            }
        }
        .sheet(isPresented: $isShowingNicknameSheet) {
            NicknameSheet(currentNickname: myProfile?.nickname ?? "") { profile in
                myProfile = profile
                myUserID = profile.userID
            }
        }
        .task { await loadIdentity() }
        .task(id: scope) { await reload() }
        .refreshable { await reload() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && comments.isEmpty {
            Spacer()
            ProgressView("読み込み中…")
            Spacer()
        } else if let errorMessage, comments.isEmpty {
            emptyState(
                icon: "exclamationmark.icloud",
                title: "読み込めませんでした",
                message: errorMessage
            )
        } else if comments.isEmpty {
            switch scope {
            case .everyone:
                emptyState(
                    icon: "building.columns",
                    title: "まだ投稿がありません",
                    message: "本の詳細画面からコメントを投稿すると、ここに全員の投稿が流れます。最初の一冊を置いてみましょう。"
                )
            case .following:
                if !accountAvailable {
                    emptyState(
                        icon: "icloud.slash",
                        title: "iCloud サインインが必要です",
                        message: "フォロー機能を使うには、設定アプリで iCloud にサインインしてください。"
                    )
                } else {
                    emptyState(
                        icon: "person.2",
                        title: "フォロー中のユーザーがいません",
                        message: "「全体」タブでコメントの投稿者名をタップすると、そのユーザーをフォローできます。"
                    )
                }
            }
        } else {
            List {
                ForEach(comments) { comment in
                    CommentRow(
                        comment: comment,
                        showsBookTitle: true,
                        myUserID: myUserID,
                        onChanged: { Task { await reload() } }
                    )
                }
            }
            .listStyle(.plain)
        }
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func loadIdentity() async {
        accountAvailable = await SocialService.shared.isAccountAvailable()
        guard accountAvailable else { return }
        myUserID = try? await SocialService.shared.currentUserID()
        myProfile = try? await SocialService.shared.myProfile()
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            switch scope {
            case .everyone:
                comments = try await SocialService.shared.recentComments()
            case .following:
                accountAvailable = await SocialService.shared.isAccountAvailable()
                guard accountAvailable else {
                    comments = []
                    return
                }
                comments = try await SocialService.shared.followingComments()
            }
        } catch {
            comments = []
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

/// SocialRoute のナビゲーション先登録（各 NavigationStack のルートに 1 回適用する）。
extension View {
    func withSocialDestinations(selectedTab: Binding<AppTab>? = nil) -> some View {
        navigationDestination(for: SocialRoute.self) { route in
            switch route {
            case .user(let id, let nickname):
                UserProfileView(userID: id, nickname: nickname)
            case .book(let isbn13):
                BookDetailView(isbn13: isbn13, selectedTab: selectedTab)
            }
        }
    }
}
