import SwiftUI

struct SearchView: View {
    @State private var query: String = ""
    @State private var submitted: String = ""
    @State private var state: SearchState = .idle
    @State private var task: Task<Void, Never>?

    var body: some View {
        List {
            switch state {
            case .idle:
                ContentUnavailableView(
                    "本を検索",
                    systemImage: "magnifyingglass",
                    description: Text("書名・著者などで検索できます")
                )
                .listRowSeparator(.hidden)
            case .loading:
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowSeparator(.hidden)
            case .empty:
                ContentUnavailableView(
                    "見つかりませんでした",
                    systemImage: "books.vertical",
                    description: Text("「\(submitted)」に一致する書籍はありません")
                )
                .listRowSeparator(.hidden)
            case .failed(let message):
                ContentUnavailableView(
                    "検索に失敗しました",
                    systemImage: "wifi.exclamationmark",
                    description: Text(message)
                )
                .listRowSeparator(.hidden)
            case .loaded(let items):
                ForEach(items, id: \.isbn13) { item in
                    NavigationLink(value: item.isbn13) {
                        SearchRow(item: item)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("検索")
        .searchable(text: $query, prompt: "書名 / 著者")
        .onSubmit(of: .search) { runSearch() }
        .navigationDestination(for: String.self) { isbn in
            BookDetailView(isbn13: isbn)
        }
    }

    private func runSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        submitted = trimmed
        task?.cancel()
        state = .loading
        task = Task {
            do {
                let ndlResults = try await NDLSearchService.shared.search(query: trimmed)
                if Task.isCancelled { return }
                guard !ndlResults.isEmpty else {
                    await MainActor.run { state = .empty }
                    return
                }

                // openBD で詳細(書影)を一括取得し、NDLの結果順を維持しつつ書影をマージ
                let isbns = ndlResults.map(\.isbn13)
                let openBDBooks = (try? await BookService.shared.fetchMany(isbns: isbns)) ?? []
                let coverByISBN: [String: URL] = Dictionary(
                    uniqueKeysWithValues: openBDBooks.compactMap { book in
                        book.coverURL.map { (book.isbn13, $0) }
                    }
                )
                let merged = ndlResults.map { result in
                    SearchRowItem(
                        isbn13: result.isbn13,
                        title: result.title,
                        author: result.author,
                        coverURL: coverByISBN[result.isbn13]
                    )
                }
                if Task.isCancelled { return }
                await MainActor.run { state = .loaded(merged) }
            } catch let error as BookServiceError {
                if Task.isCancelled { return }
                await MainActor.run { state = .failed(error.errorDescription ?? "検索に失敗しました") }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run { state = .failed(error.localizedDescription) }
            }
        }
    }

    enum SearchState {
        case idle
        case loading
        case empty
        case failed(String)
        case loaded([SearchRowItem])
    }
}

struct SearchRowItem: Hashable {
    let isbn13: String
    let title: String
    let author: String?
    let coverURL: URL?
}

private struct SearchRow: View {
    let item: SearchRowItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let url = item.coverURL {
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
            .frame(width: 48, height: 68)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                if let author = item.author {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(item.isbn13)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
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
