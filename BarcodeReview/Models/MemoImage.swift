import Foundation
import SwiftData

@Model
final class MemoImage {
    @Attribute(.externalStorage) var data: Data
    var addedAt: Date
    var book: SavedBook?

    init(data: Data, addedAt: Date = .now, book: SavedBook? = nil) {
        self.data = data
        self.addedAt = addedAt
        self.book = book
    }
}
