import Foundation

enum BookServiceError: LocalizedError {
    case network(URLError)
    case http(Int)
    case decoding(Error)
    case notFound

    var errorDescription: String? {
        switch self {
        case .network: return "ネットワークに接続できません"
        case .http(let code): return "サーバーエラー (\(code))"
        case .decoding: return "書誌データの解析に失敗しました"
        case .notFound: return "書誌情報が見つかりませんでした"
        }
    }
}

struct BookService {
    static let shared = BookService()

    private let session: URLSession
    private let endpoint = URL(string: "https://api.openbd.jp/v1/get")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchOne(isbn: String) async throws -> Book {
        let books = try await fetch(isbns: [isbn])
        if let book = books.first { return book }

        // openBD に無い場合は Google Books にフォールバック
        if let book = try? await GoogleBooksService.shared.fetch(isbn13: isbn) {
            return book
        }
        throw BookServiceError.notFound
    }

    func fetchMany(isbns: [String]) async throws -> [Book] {
        guard !isbns.isEmpty else { return [] }
        return try await fetch(isbns: isbns)
    }

    private func fetch(isbns: [String]) async throws -> [Book] {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "isbn", value: isbns.joined(separator: ","))]
        guard let url = components.url else { throw BookServiceError.notFound }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch let error as URLError {
            throw BookServiceError.network(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw BookServiceError.http(http.statusCode)
        }

        do {
            return try OpenBDDecoder.decode(data)
        } catch {
            throw BookServiceError.decoding(error)
        }
    }
}
