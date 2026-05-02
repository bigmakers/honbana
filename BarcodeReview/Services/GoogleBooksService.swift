import Foundation

/// openBD で見つからなかった ISBN を Google Books API に問い合わせるフォールバック。
/// API キー不要・無料枠あり。https://www.googleapis.com/books/v1/volumes?q=isbn:...
struct GoogleBooksService {
    static let shared = GoogleBooksService()

    private let session: URLSession
    private let endpoint = URL(string: "https://www.googleapis.com/books/v1/volumes")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(isbn13: String) async throws -> Book? {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: "isbn:\(isbn13)"),
            URLQueryItem(name: "maxResults", value: "1")
        ]
        guard let url = components.url else { return nil }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch let error as URLError {
            throw BookServiceError.network(error)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw BookServiceError.http(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(VolumesResponse.self, from: data)
        guard let item = decoded.items?.first else { return nil }
        let info = item.volumeInfo
        let cover = info.imageLinks?.bestURL
        let authors = info.authors?.joined(separator: " / ")
        return Book(
            isbn13: isbn13,
            title: info.title ?? "",
            author: authors,
            publisher: info.publisher,
            pubdate: info.publishedDate,
            coverURL: cover,
            description: info.description
        )
    }
}

private struct VolumesResponse: Decodable {
    let items: [Item]?

    struct Item: Decodable {
        let volumeInfo: VolumeInfo
    }

    struct VolumeInfo: Decodable {
        let title: String?
        let authors: [String]?
        let publisher: String?
        let publishedDate: String?
        let description: String?
        let imageLinks: ImageLinks?
    }

    struct ImageLinks: Decodable {
        let smallThumbnail: String?
        let thumbnail: String?
        let small: String?
        let medium: String?
        let large: String?
        let extraLarge: String?

        var bestURL: URL? {
            // Prefer larger sizes; force https.
            let candidates = [extraLarge, large, medium, small, thumbnail, smallThumbnail]
            for raw in candidates {
                guard let raw, !raw.isEmpty else { continue }
                let secured = raw.replacingOccurrences(of: "http://", with: "https://")
                if let url = URL(string: secured) { return url }
            }
            return nil
        }
    }
}
