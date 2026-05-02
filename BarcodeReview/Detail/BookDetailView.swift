import SwiftUI
import SwiftData
import PhotosUI

struct BookDetailView: View {
    let isbn13: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query private var savedMatches: [SavedBook]

    @State private var loadState: LoadState = .loading
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var isShowingCamera = false
    @State private var isShowingPhotoPicker = false

    @State private var manualTitle: String = ""
    @State private var manualAuthor: String = ""
    @State private var manualPublisher: String = ""

    init(isbn13: String) {
        self.isbn13 = isbn13
        let target = isbn13
        _savedMatches = Query(filter: #Predicate<SavedBook> { $0.isbn13 == target })
    }

    private var savedBook: SavedBook? { savedMatches.first }

    private var amazonURL: URL? { AmazonAffiliateURL.url(forISBN13: isbn13) }

    private var displayTitle: String {
        if case .loaded(let book) = loadState { return book.title }
        return savedBook?.title ?? "ISBN \(isbn13)"
    }

    private var displayAuthor: String? {
        if case .loaded(let book) = loadState { return book.author }
        return savedBook?.author
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                metadata
                if case .notFound = loadState, savedBook == nil {
                    manualEntrySection
                }
                memoSection
                if let saved = savedBook { imagesSection(saved) }
                actionButtons
                if case .loaded(let book) = loadState, let description = book.description {
                    descriptionSection(description)
                }
            }
            .padding(20)
        }
        .navigationTitle("詳細")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: isbn13) { await load() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var header: some View {
        switch loadState {
        case .loading:
            HStack { ProgressView(); Text("書誌情報を取得中…").foregroundStyle(.secondary) }
                .frame(maxWidth: .infinity, alignment: .leading)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                fallbackHeader
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.footnote)
            }
        case .notFound:
            VStack(alignment: .leading, spacing: 8) {
                fallbackHeader
                Label("書誌情報が見つかりませんでした。下のフォームから手動で登録できます。",
                      systemImage: "questionmark.circle")
                    .foregroundStyle(.orange)
                    .font(.footnote)
            }
        case .loaded(let book):
            HStack(alignment: .top, spacing: 16) {
                cover(url: book.coverURL)
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title).font(.title3).bold()
                    if let author = book.author {
                        Text(author).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("ISBN: \(book.isbn13)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var fallbackHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            cover(url: savedBook?.coverURL)
            VStack(alignment: .leading, spacing: 4) {
                Text(savedBook?.title ?? "ISBN \(isbn13)")
                    .font(.title3).bold()
                if let author = savedBook?.author {
                    Text(author).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var metadata: some View {
        if case .loaded(let book) = loadState {
            VStack(alignment: .leading, spacing: 4) {
                if let publisher = book.publisher {
                    Label(publisher, systemImage: "building.columns")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let pubdate = book.pubdate {
                    Label(formattedDate(pubdate), systemImage: "calendar")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var memoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("メモ").font(.headline)
                Spacer()
                libraryToggleButton
            }
            if let saved = savedBook {
                TextEditor(text: Binding(
                    get: { saved.memo },
                    set: { saved.memo = $0 }
                ))
                .frame(minHeight: 140)
                .padding(8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    if saved.memo.isEmpty {
                        Text("感想やメモを書く…")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
            } else {
                Text("「ライブラリに追加」するとメモを書けます")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    @ViewBuilder
    private func imagesSection(_ saved: SavedBook) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("画像").font(.headline)
                Spacer()
                Menu {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            isShowingCamera = true
                        } label: {
                            Label("カメラで撮影", systemImage: "camera")
                        }
                    }
                    Button {
                        isShowingPhotoPicker = true
                    } label: {
                        Label("写真から選択", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Label(isImporting ? "読込中…" : "画像を追加", systemImage: "photo.badge.plus")
                        .labelStyle(.titleAndIcon)
                        .font(.footnote)
                }
                .disabled(isImporting)
                .buttonStyle(.bordered)
                .photosPicker(
                    isPresented: $isShowingPhotoPicker,
                    selection: $pickerItems,
                    maxSelectionCount: 5,
                    matching: .images,
                    photoLibrary: .shared()
                )
                .fullScreenCover(isPresented: $isShowingCamera) {
                    CameraPicker { data in
                        Task { await importCapturedImage(into: saved, data: data) }
                    }
                    .ignoresSafeArea()
                }
            }

            let sortedImages = saved.images.sorted { $0.addedAt < $1.addedAt }
            if sortedImages.isEmpty {
                Text("写真ライブラリから画像を追加できます")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(sortedImages) { memoImage in
                            imageThumbnail(memoImage)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .onChange(of: pickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await importPickedImages(into: saved, items: newItems) }
        }
    }

    @ViewBuilder
    private func imageThumbnail(_ memoImage: MemoImage) -> some View {
        if let ui = UIImage(data: memoImage.data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contextMenu {
                    ShareLink(
                        item: ShareableImage(
                            data: memoImage.data,
                            suggestedName: "memo-\(Int(memoImage.addedAt.timeIntervalSince1970)).jpg"
                        ),
                        preview: SharePreview(displayTitle, image: Image(uiImage: ui))
                    ) {
                        Label("画像をシェア", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        modelContext.delete(memoImage)
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
        }
    }

    @ViewBuilder
    private var libraryToggleButton: some View {
        if let saved = savedBook {
            Button(role: .destructive) {
                modelContext.delete(saved)
            } label: {
                Label("削除", systemImage: "trash")
                    .labelStyle(.titleAndIcon)
                    .font(.footnote)
            }
        } else if case .loaded(let book) = loadState {
            Button {
                let newBook = SavedBook(from: book)
                modelContext.insert(newBook)
            } label: {
                Label("ライブラリに追加", systemImage: "bookmark")
                    .labelStyle(.titleAndIcon)
                    .font(.footnote)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("手動で書籍情報を登録").font(.headline)
            Text("ISBN: \(isbn13)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                TextField("書名 (必須)", text: $manualTitle)
                    .textFieldStyle(.roundedBorder)
                TextField("著者", text: $manualAuthor)
                    .textFieldStyle(.roundedBorder)
                TextField("出版社", text: $manualPublisher)
                    .textFieldStyle(.roundedBorder)
            }

            Button {
                let trimmed = manualTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                let book = SavedBook(
                    isbn13: isbn13,
                    title: trimmed,
                    author: manualAuthor.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    publisher: manualPublisher.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
                modelContext.insert(book)
            } label: {
                Label("ライブラリに追加", systemImage: "bookmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(manualTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button {
                if let url = amazonURL { openURL(url) }
            } label: {
                Label("Amazon を Safari で開く", systemImage: "safari")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            ShareLink(
                item: shareText,
                subject: Text(displayTitle),
                message: Text(displayTitle)
            ) {
                Label("SNS にシェア", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var shareText: String {
        MemoShareComposer.text(
            title: displayTitle,
            author: displayAuthor,
            memo: savedBook?.memo ?? "",
            amazonURL: amazonURL
        )
    }

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("内容紹介").font(.headline)
            Text(description)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Helpers

    private func cover(url: URL?) -> some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty: ProgressView()
                    case .success(let image): image.resizable().scaledToFit()
                    case .failure: placeholderCover
                    @unknown default: placeholderCover
                    }
                }
            } else {
                placeholderCover
            }
        }
        .frame(width: 96, height: 140)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 6))
    }

    private var placeholderCover: some View {
        Image(systemName: "book.closed")
            .font(.system(size: 40))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formattedDate(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        guard digits.count >= 6 else { return raw }
        let y = digits.prefix(4)
        let m = digits.dropFirst(4).prefix(2)
        if digits.count >= 8 {
            let d = digits.dropFirst(6).prefix(2)
            return "\(y)/\(m)/\(d)"
        }
        return "\(y)/\(m)"
    }

    private func load() async {
        loadState = .loading
        do {
            let book = try await BookService.shared.fetchOne(isbn: isbn13)
            loadState = .loaded(book)
        } catch BookServiceError.notFound {
            loadState = .notFound
        } catch let error as BookServiceError {
            loadState = .failed(error.errorDescription ?? "読み込みに失敗しました")
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    @MainActor
    private func importPickedImages(into book: SavedBook, items: [PhotosPickerItem]) async {
        isImporting = true
        defer {
            isImporting = false
            pickerItems = []
        }
        for item in items {
            guard let raw = try? await item.loadTransferable(type: Data.self) else { continue }
            let processed = ImageDownscaler.downscaleToJPEG(raw) ?? raw
            let image = MemoImage(data: processed)
            book.images.append(image)
        }
    }

    @MainActor
    private func importCapturedImage(into book: SavedBook, data: Data) async {
        isImporting = true
        defer { isImporting = false }
        let processed = ImageDownscaler.downscaleToJPEG(data) ?? data
        let image = MemoImage(data: processed)
        book.images.append(image)
    }

    enum LoadState {
        case loading
        case loaded(Book)
        case notFound
        case failed(String)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
