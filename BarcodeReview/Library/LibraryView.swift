import SwiftUI
import SwiftData

enum LibraryDisplayMode: String {
    case shelf, list
}

struct LibraryView: View {
    @Binding var selectedTab: AppTab

    @Query(sort: \SavedBook.savedAt, order: .reverse)
    private var books: [SavedBook]
    @Environment(\.modelContext) private var modelContext

    @AppStorage("libraryDisplayMode") private var displayMode: LibraryDisplayMode = .shelf
    @State private var query: String = ""

    private var filtered: [SavedBook] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return books }
        let q = trimmed.lowercased()
        return books.filter { book in
            book.title.lowercased().contains(q)
            || (book.author ?? "").lowercased().contains(q)
            || book.memo.lowercased().contains(q)
        }
    }

    var body: some View {
        Group {
            if books.isEmpty {
                emptyState
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                switch displayMode {
                case .shelf: shelfGrid
                case .list:  listView
                }
            }
        }
        .navigationTitle("ライブラリ")
        .navigationBarTitleDisplayMode(books.isEmpty ? .inline : .large)
        .toolbar {
            if !books.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(books.count)冊")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("表示", selection: $displayMode) {
                        Image(systemName: "square.grid.2x2").tag(LibraryDisplayMode.shelf)
                        Image(systemName: "list.bullet").tag(LibraryDisplayMode.list)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 110)
                }
            }
        }
        .searchable(text: $query, prompt: "書名 / 著者 / メモを検索")
        .navigationDestination(for: String.self) { isbn in
            BookDetailView(isbn13: isbn)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("ライブラリは空です", systemImage: "books.vertical")
        } description: {
            Text("バーコードを読み取って、最初の1冊を追加しましょう")
        } actions: {
            VStack(spacing: 8) {
                Button {
                    selectedTab = .scan
                } label: {
                    Label("バーコードをスキャン", systemImage: "barcode.viewfinder")
                        .frame(maxWidth: 240)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    selectedTab = .search
                } label: {
                    Label("書名・著者で検索", systemImage: "magnifyingglass")
                        .frame(maxWidth: 240)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    // MARK: - Shelf grid (本棚ビュー)

    private var shelfGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100, maximum: 130), spacing: 16)],
                alignment: .leading,
                spacing: 24
            ) {
                ForEach(filtered) { book in
                    NavigationLink(value: book.isbn13) {
                        ShelfCell(book: book)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            modelContext.delete(book)
                        } label: {
                            Label("ライブラリから削除", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - List view (リストビュー)

    private var listView: some View {
        List {
            ForEach(filtered) { book in
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

// MARK: - Shelf cell

private struct ShelfCell: View {
    let book: SavedBook

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            cover
                .aspectRatio(2/3, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(spineGradient,
                            in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 4, x: 1, y: 3)
                .overlay(alignment: .topTrailing) {
                    if !book.memo.isEmpty {
                        Image(systemName: "note.text")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(.black.opacity(0.55), in: Circle())
                            .padding(4)
                    }
                }

            Text(book.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let author = book.author {
                Text(author)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var cover: some View {
        if let url = book.coverURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .empty:
                    coverFallback
                        .overlay(ProgressView().scaleEffect(0.7))
                default:
                    coverFallback
                }
            }
        } else {
            coverFallback
        }
    }

    /// 書影が無い時のフォールバック: 背表紙風にタイトルを縦に表示
    private var coverFallback: some View {
        ZStack {
            spineGradient
            VStack {
                Text(book.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 12)
                Spacer(minLength: 0)
            }
        }
    }

    /// タイトル文字列から決定的に色を割り当てる
    private var spineGradient: LinearGradient {
        let palette: [(Color, Color)] = [
            (.init(red: 0.78, green: 0.30, blue: 0.30), .init(red: 0.55, green: 0.18, blue: 0.18)),
            (.init(red: 0.20, green: 0.45, blue: 0.65), .init(red: 0.10, green: 0.30, blue: 0.50)),
            (.init(red: 0.30, green: 0.55, blue: 0.40), .init(red: 0.18, green: 0.40, blue: 0.28)),
            (.init(red: 0.85, green: 0.60, blue: 0.25), .init(red: 0.65, green: 0.42, blue: 0.10)),
            (.init(red: 0.50, green: 0.32, blue: 0.55), .init(red: 0.32, green: 0.18, blue: 0.40)),
            (.init(red: 0.42, green: 0.30, blue: 0.22), .init(red: 0.28, green: 0.18, blue: 0.12))
        ]
        let idx = abs(book.isbn13.hashValue) % palette.count
        let (a, b) = palette[idx]
        return LinearGradient(colors: [a, b], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - List row

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
