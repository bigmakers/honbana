import Foundation
import CloudKit

/// パブリックDBに保存される書籍コメント。
struct BookCommentItem: Identifiable, Hashable, Sendable {
    let id: String            // CKRecord.ID.recordName
    let isbn: String
    let bookTitle: String
    let bookAuthor: String?
    let text: String
    let authorID: String      // 投稿者の CKUserRecordID.recordName
    let authorNickname: String
    let createdAt: Date

    init?(record: CKRecord) {
        guard record.recordType == SocialSchema.commentType,
              let isbn = record[SocialSchema.Comment.isbn] as? String,
              let text = record[SocialSchema.Comment.text] as? String,
              let authorID = record[SocialSchema.Comment.authorID] as? String
        else { return nil }
        self.id = record.recordID.recordName
        self.isbn = isbn
        self.bookTitle = (record[SocialSchema.Comment.bookTitle] as? String) ?? "ISBN \(isbn)"
        self.bookAuthor = record[SocialSchema.Comment.bookAuthor] as? String
        self.text = text
        self.authorID = authorID
        self.authorNickname = (record[SocialSchema.Comment.authorNickname] as? String) ?? "名無し"
        self.createdAt = record.creationDate ?? .now
    }
}

/// パブリックDBのユーザープロフィール。recordName = "profile:<userRecordName>"
struct UserProfile: Hashable, Sendable {
    let userID: String
    let nickname: String

    init?(record: CKRecord) {
        guard record.recordType == SocialSchema.profileType,
              let userID = record[SocialSchema.Profile.userID] as? String,
              let nickname = record[SocialSchema.Profile.nickname] as? String
        else { return nil }
        self.userID = userID
        self.nickname = nickname
    }

    init(userID: String, nickname: String) {
        self.userID = userID
        self.nickname = nickname
    }
}

/// CloudKit スキーマ名の一元管理。
enum SocialSchema {
    static let containerID = "iCloud.com.bigdrives.BarcodeReview"

    static let commentType = "BookComment"
    static let profileType = "UserProfile"
    static let followType = "Follow"
    static let reportType = "CommentReport"

    enum Comment {
        static let isbn = "isbn"
        static let bookTitle = "bookTitle"
        static let bookAuthor = "bookAuthor"
        static let text = "text"
        static let authorID = "authorID"
        static let authorNickname = "authorNickname"
    }

    enum Profile {
        static let userID = "userID"
        static let nickname = "nickname"
        static func recordID(for userID: String) -> CKRecord.ID {
            CKRecord.ID(recordName: "profile:\(userID)")
        }
    }

    enum Follow {
        static let followerID = "followerID"
        static let followeeID = "followeeID"
        static func recordID(follower: String, followee: String) -> CKRecord.ID {
            CKRecord.ID(recordName: "follow:\(follower):\(followee)")
        }
    }

    enum Report {
        static let commentID = "commentID"
        static let commentAuthorID = "commentAuthorID"
        static let reporterID = "reporterID"
        static let reason = "reason"
    }
}
