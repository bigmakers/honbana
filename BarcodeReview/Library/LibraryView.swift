import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \SavedBook.savedAt, order: .reverse)
    private var books: [SavedBook]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if books.isEmpty {
                ContentUnavailableView(
                    "ライブラリは空です",
                    systemImage: "books.vertical",
                    description: Text("スキャンや検索から本を追加するとここに表示されます")
                )
            } else {
                List {
                    ForEach(books) { book in
                        NavigationLink(value: book.isbn13) {
                            LibraryRow(book: book)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                modelContext.delete(book)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("ライブラリ")
        .navigationDestination(for: String.self) { isbn in
            BookDetailView(isbn13: isbn)
        }
    }
}

private struct LibraryRow: View {
    let book: SavedBook

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let url = book.coverURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFit()
                        default: placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .frame(width: 52, height: 74)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                if let author = book.author {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !book.memo.isEmpty {
                    Text(book.memo)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .padding(.top, 2)
                } else {
                    Text("メモなし")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var placeholder: some View {
        Image(systemName: "book.closed")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
