import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum MemoShareComposer {
    /// SNS 投稿用テキスト。アフィリエイトタグ付き Amazon URL を必ず末尾に含める。
    static func text(title: String, author: String?, memo: String, amazonURL: URL?) -> String {
        var parts: [String] = []
        parts.append("📚 \(title)")
        if let author, !author.isEmpty { parts.append(author) }
        let trimmed = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { parts.append(trimmed) }
        if let amazonURL { parts.append(amazonURL.absoluteString) }
        return parts.joined(separator: "\n\n")
    }
}

/// `ShareLink` で UIImage を画像として共有するためのラッパー。
struct ShareableImage: Transferable {
    let data: Data
    let suggestedName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .jpeg) { item in
            item.data
        }
        .suggestedFileName { $0.suggestedName }
    }
}
