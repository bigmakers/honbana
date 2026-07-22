import Foundation
import CloudKit

enum SocialError: LocalizedError {
    case iCloudAccountRequired
    case nicknameRequired
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .iCloudAccountRequired:
            return "投稿・フォローには iCloud サインインが必要です。設定アプリで iCloud にサインインしてください。"
        case .nicknameRequired:
            return "投稿するにはニックネームを設定してください。"
        case .underlying(let error):
            if let ck = error as? CKError {
                switch ck.code {
                case .networkUnavailable, .networkFailure:
                    return "ネットワークに接続できません。"
                case .notAuthenticated:
                    return "iCloud にサインインしていません。"
                case .requestRateLimited:
                    return "アクセスが集中しています。しばらくしてからお試しください。"
                default: break
                }
            }
            return error.localizedDescription
        }
    }
}

/// CloudKit パブリックDBを使ったソーシャル機能（コメント / フォロー / プロフィール）。
final class SocialService: @unchecked Sendable {
    static let shared = SocialService()

    private let container: CKContainer
    private var db: CKDatabase { container.publicCloudDatabase }

    private let lock = NSLock()
    private var cachedUserID: String?
    private var cachedProfile: UserProfile?

    private init() {
        container = CKContainer(identifier: SocialSchema.containerID)
    }

    // MARK: - Account / Profile

    /// iCloud アカウントの有無だけを確認（読み取り専用機能の分岐用）。
    func isAccountAvailable() async -> Bool {
        (try? await container.accountStatus()) == .available
    }

    /// 自分のユーザーID（recordName）。iCloud 未サインインなら throw。
    func currentUserID() async throws -> String {
        if let id = withLock({ cachedUserID }) { return id }
        let status: CKAccountStatus
        do { status = try await container.accountStatus() }
        catch { throw SocialError.underlying(error) }
        guard status == .available else { throw SocialError.iCloudAccountRequired }
        do {
            let recordID = try await container.userRecordID()
            withLock { cachedUserID = recordID.recordName }
            return recordID.recordName
        } catch { throw SocialError.underlying(error) }
    }

    /// 自分のプロフィール（未作成なら nil）。
    func myProfile() async throws -> UserProfile? {
        if let p = withLock({ cachedProfile }) { return p }
        let uid = try await currentUserID()
        let profile = try await fetchProfile(userID: uid)
        withLock { cachedProfile = profile }
        return profile
    }

    func fetchProfile(userID: String) async throws -> UserProfile? {
        do {
            let record = try await db.record(for: SocialSchema.Profile.recordID(for: userID))
            return UserProfile(record: record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        } catch {
            throw SocialError.underlying(error)
        }
    }

    @discardableResult
    func saveNickname(_ nickname: String) async throws -> UserProfile {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SocialError.nicknameRequired }
        let uid = try await currentUserID()
        let recordID = SocialSchema.Profile.recordID(for: uid)
        let record: CKRecord
        if let existing = try? await db.record(for: recordID) {
            record = existing
        } else {
            record = CKRecord(recordType: SocialSchema.profileType, recordID: recordID)
            record[SocialSchema.Profile.userID] = uid
        }
        record[SocialSchema.Profile.nickname] = String(trimmed.prefix(20))
        do {
            let saved = try await db.save(record)
            let profile = UserProfile(record: saved) ?? UserProfile(userID: uid, nickname: trimmed)
            withLock { cachedProfile = profile }
            return profile
        } catch { throw SocialError.underlying(error) }
    }

    // MARK: - Comments

    @discardableResult
    func postComment(isbn: String, bookTitle: String, bookAuthor: String?, text: String) async throws -> BookCommentItem? {
        let body = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000))
        guard !body.isEmpty else { return nil }
        guard let profile = try await myProfile() else { throw SocialError.nicknameRequired }

        let record = CKRecord(recordType: SocialSchema.commentType)
        record[SocialSchema.Comment.isbn] = isbn
        record[SocialSchema.Comment.bookTitle] = bookTitle
        record[SocialSchema.Comment.bookAuthor] = bookAuthor
        record[SocialSchema.Comment.text] = body
        record[SocialSchema.Comment.authorID] = profile.userID
        record[SocialSchema.Comment.authorNickname] = profile.nickname
        do {
            let saved = try await db.save(record)
            return BookCommentItem(record: saved)
        } catch { throw SocialError.underlying(error) }
    }

    /// ある本へのコメント一覧（新しい順）。
    func comments(isbn: String, limit: Int = 50) async throws -> [BookCommentItem] {
        try await queryComments(NSPredicate(format: "%K == %@", SocialSchema.Comment.isbn, isbn), limit: limit)
    }

    /// 全体タイムライン（新しい順）。
    func recentComments(limit: Int = 50) async throws -> [BookCommentItem] {
        try await queryComments(NSPredicate(value: true), limit: limit)
    }

    /// 特定ユーザーの投稿一覧。
    func comments(authorID: String, limit: Int = 50) async throws -> [BookCommentItem] {
        try await queryComments(NSPredicate(format: "%K == %@", SocialSchema.Comment.authorID, authorID), limit: limit)
    }

    /// フォロー中ユーザーのタイムライン。
    func followingComments(limit: Int = 50) async throws -> [BookCommentItem] {
        let followees = try await followeeIDs()
        guard !followees.isEmpty else { return [] }
        // CloudKit の IN 述語はメンバ数に上限があるため先頭 50 名まで
        let ids = Array(followees.prefix(50))
        return try await queryComments(
            NSPredicate(format: "%K IN %@", SocialSchema.Comment.authorID, ids),
            limit: limit
        )
    }

    /// 自分のコメントを削除。
    func deleteComment(_ comment: BookCommentItem) async throws {
        do {
            _ = try await db.deleteRecord(withID: CKRecord.ID(recordName: comment.id))
        } catch { throw SocialError.underlying(error) }
    }

    private func queryComments(_ predicate: NSPredicate, limit: Int) async throws -> [BookCommentItem] {
        let query = CKQuery(recordType: SocialSchema.commentType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        do {
            let (results, _) = try await db.records(matching: query, resultsLimit: limit)
            let items = results.compactMap { _, result in
                (try? result.get()).flatMap(BookCommentItem.init(record:))
            }
            return ModerationStore.filter(items)
        } catch let error as CKError where error.code == .unknownItem {
            // レコード型が未作成（誰もまだ投稿していない）場合は空扱い
            return []
        } catch {
            throw SocialError.underlying(error)
        }
    }

    // MARK: - Follow

    func follow(userID: String) async throws {
        let me = try await currentUserID()
        guard me != userID else { return }
        let record = CKRecord(
            recordType: SocialSchema.followType,
            recordID: SocialSchema.Follow.recordID(follower: me, followee: userID)
        )
        record[SocialSchema.Follow.followerID] = me
        record[SocialSchema.Follow.followeeID] = userID
        do {
            _ = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
        } catch { throw SocialError.underlying(error) }
    }

    func unfollow(userID: String) async throws {
        let me = try await currentUserID()
        do {
            _ = try await db.deleteRecord(withID: SocialSchema.Follow.recordID(follower: me, followee: userID))
        } catch let error as CKError where error.code == .unknownItem {
            return
        } catch { throw SocialError.underlying(error) }
    }

    func isFollowing(userID: String) async throws -> Bool {
        let me = try await currentUserID()
        do {
            _ = try await db.record(for: SocialSchema.Follow.recordID(follower: me, followee: userID))
            return true
        } catch let error as CKError where error.code == .unknownItem {
            return false
        } catch { throw SocialError.underlying(error) }
    }

    /// 自分がフォローしているユーザーIDの一覧。
    func followeeIDs() async throws -> [String] {
        let me = try await currentUserID()
        let query = CKQuery(
            recordType: SocialSchema.followType,
            predicate: NSPredicate(format: "%K == %@", SocialSchema.Follow.followerID, me)
        )
        do {
            let (results, _) = try await db.records(matching: query, resultsLimit: 200)
            return results.compactMap { _, result in
                (try? result.get())?[SocialSchema.Follow.followeeID] as? String
            }
        } catch let error as CKError where error.code == .unknownItem {
            return []
        } catch { throw SocialError.underlying(error) }
    }

    // MARK: - Moderation (通報)

    func report(comment: BookCommentItem, reason: String) async throws {
        let me = try await currentUserID()
        let record = CKRecord(recordType: SocialSchema.reportType)
        record[SocialSchema.Report.commentID] = comment.id
        record[SocialSchema.Report.commentAuthorID] = comment.authorID
        record[SocialSchema.Report.reporterID] = me
        record[SocialSchema.Report.reason] = String(reason.prefix(200))
        do {
            _ = try await db.save(record)
        } catch { throw SocialError.underlying(error) }
        ModerationStore.hide(commentID: comment.id)
    }

    // MARK: - Helpers

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }
}

/// ブロック・非表示のローカル管理（App Review の UGC 要件: 通報とブロック）。
enum ModerationStore {
    private static let blockedKey = "social.blockedUserIDs"
    private static let hiddenKey = "social.hiddenCommentIDs"

    static var blockedUserIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: blockedKey) ?? [])
    }

    static var hiddenCommentIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: hiddenKey) ?? [])
    }

    static func block(userID: String) {
        var set = blockedUserIDs
        set.insert(userID)
        UserDefaults.standard.set(Array(set), forKey: blockedKey)
    }

    static func unblock(userID: String) {
        var set = blockedUserIDs
        set.remove(userID)
        UserDefaults.standard.set(Array(set), forKey: blockedKey)
    }

    static func isBlocked(userID: String) -> Bool {
        blockedUserIDs.contains(userID)
    }

    static func hide(commentID: String) {
        var set = hiddenCommentIDs
        set.insert(commentID)
        UserDefaults.standard.set(Array(set), forKey: hiddenKey)
    }

    static func filter(_ items: [BookCommentItem]) -> [BookCommentItem] {
        let blocked = blockedUserIDs
        let hidden = hiddenCommentIDs
        return items.filter { !blocked.contains($0.authorID) && !hidden.contains($0.id) }
    }
}
