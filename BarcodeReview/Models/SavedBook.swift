import Foundation
import SwiftData

@Model
final class SavedBook {
    @Attribute(.unique) var isbn13: String
    var title: String
    var author: String?
    var publisher: String?
    var coverURLString: String?
    var memo: String
    var savedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \MemoImage.book)
    var images: [MemoImage] = []

    init(
        isbn13: String,
        title: String,
        author: String? = nil,
        publisher: String? = nil,
        coverURLString: String? = nil,
        memo: String = "",
        savedAt: Date = .now
    ) {
        self.isbn13 = isbn13
        self.title = title
        self.author = author
        self.publisher = publisher
        self.coverURLString = coverURLString
        self.memo = memo
        self.savedAt = savedAt
    }

    var coverURL: URL? {
        coverURLString.flatMap(URL.init(string:))
    }

    convenience init(from book: Book, memo: String = "") {
        self.init(
            isbn13: book.isbn13,
            title: book.title,
            author: book.author,
            publisher: book.publisher,
            coverURLString: book.coverURL?.absoluteString,
            memo: memo
        )
    }
}
