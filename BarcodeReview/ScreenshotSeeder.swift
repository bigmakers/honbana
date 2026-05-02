#if DEBUG
import Foundation
import SwiftData

/// `--seed-screenshots` 起動引数が指定されたときだけ呼び出される、
/// App Store スクリーンショット用のサンプルデータ投入器。
/// 既にデータが入っているときはスキップする。
enum ScreenshotSeeder {
    static func seedIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<SavedBook>()
        if let existing = try? context.fetchCount(descriptor), existing > 0 {
            return
        }

        let books: [(isbn: String, title: String, author: String, publisher: String, memo: String)] = [
            (
                isbn: "9784101001036",
                title: "吾輩は猫である",
                author: "夏目 漱石",
                publisher: "新潮社",
                memo: "教師・苦沙弥先生の家に住み着いた猫の視点で人間社会を描く。冒頭の有名な一文がやはり最高。"
            ),
            (
                isbn: "9784062748032",
                title: "海辺のカフカ (上)",
                author: "村上 春樹",
                publisher: "新潮社",
                memo: "図書館とトラックの場面が好き。再読すると伏線の張り方の細かさに気付く。"
            ),
            (
                isbn: "9784167158064",
                title: "ノルウェイの森 (上)",
                author: "村上 春樹",
                publisher: "講談社",
                memo: "学生時代に読んでから 20 年ぶりの再読。"
            ),
            (
                isbn: "9784101031125",
                title: "雪国",
                author: "川端 康成",
                publisher: "新潮社",
                memo: "「国境の長いトンネルを抜けると雪国であった」"
            )
        ]

        for (i, b) in books.enumerated() {
            let saved = SavedBook(
                isbn13: b.isbn,
                title: b.title,
                author: b.author,
                publisher: b.publisher,
                coverURLString: nil,
                memo: b.memo,
                savedAt: Date().addingTimeInterval(-Double(i) * 86_400)
            )
            context.insert(saved)
        }
        try? context.save()
    }
}
#endif
