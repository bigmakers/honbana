import Foundation

struct Book: Identifiable, Hashable, Sendable {
    let isbn13: String
    let title: String
    let author: String?
    let publisher: String?
    let pubdate: String?
    let coverURL: URL?
    let description: String?

    var id: String { isbn13 }
}

enum OpenBDDecoder {
    static func decode(_ data: Data) throws -> [Book] {
        let raws = try JSONDecoder().decode([RawItem?].self, from: data)
        return raws.compactMap { $0?.toBook() }
    }
}

private struct RawItem: Decodable {
    let summary: Summary?
    let onix: Onix?

    struct Summary: Decodable {
        let isbn: String?
        let title: String?
        let author: String?
        let publisher: String?
        let pubdate: String?
        let cover: String?
    }

    struct Onix: Decodable {
        let CollateralDetail: CollateralDetail?

        struct CollateralDetail: Decodable {
            let TextContent: [TextContent]?

            struct TextContent: Decodable {
                let TextType: String?
                let Text: String?
            }
        }
    }

    func toBook() -> Book? {
        guard let isbn = summary?.isbn, !isbn.isEmpty,
              let title = summary?.title, !title.isEmpty else { return nil }

        let cover = (summary?.cover).flatMap { $0.isEmpty ? nil : URL(string: $0) }

        // openBD's onix description: TextType "03" is the typical 内容紹介
        let texts = onix?.CollateralDetail?.TextContent ?? []
        let description = texts.first { $0.TextType == "03" }?.Text
            ?? texts.first { $0.TextType == "23" }?.Text
            ?? texts.first?.Text

        return Book(
            isbn13: isbn,
            title: title,
            author: summary?.author?.nilIfEmpty,
            publisher: summary?.publisher?.nilIfEmpty,
            pubdate: summary?.pubdate?.nilIfEmpty,
            coverURL: cover,
            description: description?.nilIfEmpty
        )
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
