import SwiftUI
import SwiftData

struct SearchView: View {
    @Binding var selectedTab: AppTab

    @State private var query: String = ""
    @State private var submitted: String = ""
    @State private var state: SearchState = .idle
    @State private var task: Task<Void, Never>?

    @State private var showingISBNSheet = false
    @State private var manualISBN = ""
    @State private var pushedISBN: String?

    @Query private var savedBooks: [SavedBook]

    private var savedISBNs: Set<String> {
        Set(savedBooks.map(\.isbn13))
    }

    private var launchSearchQuery: String? {
        for arg in ProcessInfo.processInfo.arguments {
            if arg.hasPrefix("--launch-search=") {
                return String(arg.dropFirst("--launch-search=".count))
            }
        }
        return nil
    }

    var body: some View {
        List {
            switch state {
            case .idle:
                idleSection
            case .loading:
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowSeparator(.hidden)
            case .empty:
                emptySection
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
                        SearchRow(item: item, isInLibrary: savedISBNs.contains(item.isbn13))
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("検索")
        .searchable(text: $query, prompt: "書名 / 著者")
        .onSubmit(of: .search) { runSearch() }
        .navigationDestination(for: String.self) { isbn in
            BookDetailView(isbn13: isbn, selectedTab: $selectedTab)
        }
        .navigationDestination(item: $pushedISBN) { isbn in
            BookDetailView(isbn13: isbn, selectedTab: $selectedTab)
        }
        .task {
            if let q = launchSearchQuery, query.isEmpty {
                query = q
                runSearch()
            }
        }
        .sheet(isPresented: $showingISBNSheet) {
            ISBNInputSheet(initialValue: manualISBN) { isbn in
                showingISBNSheet = false
                pushedISBN = isbn
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Idle (検索前)

    @ViewBuilder
    private var idleSection: some View {
        ContentUnavailableView {
            Label("本を検索", systemImage: "magnifyingglass")
        } description: {
            Text("書名・著者などで検索できます")
        } actions: {
            Button {
                showingISBNSheet = true
            } label: {
                Label("ISBN を直接入力", systemImage: "barcode")
            }
            .buttonStyle(.bordered)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    // MARK: - Empty (結果0件)

    @ViewBuilder
    private var emptySection: some View {
        ContentUnavailableView {
            Label("見つかりませんでした", systemImage: "books.vertical")
        } description: {
            Text("「\(submitted)」に一致する書籍はありません")
        } actions: {
            VStack(spacing: 8) {
                Button {
                    showingISBNSheet = true
                } label: {
                    Label("ISBN を直接入力", systemImage: "barcode")
                        .frame(maxWidth: 240)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    selectedTab = .scan
                } label: {
                    Label("バーコードをスキャン", systemImage: "barcode.viewfinder")
                        .frame(maxWidth: 240)
                }
                .buttonStyle(.bordered)
            }
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
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
                await MainActor.run {
                    state = .failed(error.errorDescription ?? "検索に失敗しました")
                }
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
    let isInLibrary: Bool

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
            .frame(width: 52, height: 72)
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
                if isInLibrary {
                    Label("ライブラリにあり", systemImage: "checkmark.seal.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
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

// MARK: - ISBN 直接入力シート

private struct ISBNInputSheet: View {
    let initialValue: String
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var input = ""

    private var normalized: String { input.filter(\.isNumber) }
    private var isValid: Bool {
        normalized.count == 13 && (normalized.hasPrefix("978") || normalized.hasPrefix("979"))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("978...", text: $input)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .font(.body.monospaced())
                } header: {
                    Text("ISBN-13 (13桁)")
                } footer: {
                    Text("978 または 979 で始まる13桁の数字を入力してください。")
                }
            }
            .navigationTitle("ISBN を入力")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("詳細を表示") {
                        onSubmit(normalized)
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear { input = initialValue }
        }
    }
}
