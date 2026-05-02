import Foundation

struct NDLSearchResult: Hashable, Sendable {
    let title: String
    let author: String?
    let isbn13: String
}

struct NDLSearchService {
    static let shared = NDLSearchService()

    private let session: URLSession
    private let endpoint = URL(string: "https://ndlsearch.ndl.go.jp/api/opensearch")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String, limit: Int = 30) async throws -> [NDLSearchResult] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "any", value: q),
            URLQueryItem(name: "cnt", value: String(limit))
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("BarcodeReview/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/xml", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw BookServiceError.network(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw BookServiceError.http(http.statusCode)
        }

        return await Task.detached(priority: .userInitiated) {
            let parser = XMLParser(data: data)
            let delegate = NDLOpenSearchParser()
            parser.delegate = delegate
            parser.shouldProcessNamespaces = false
            _ = parser.parse()

            // 同一 ISBN を重複させない（NDL は版違い等で同 ISBN を返すことがある）
            var seen = Set<String>()
            return delegate.results.filter { seen.insert($0.isbn13).inserted }
        }.value
    }
}

private final class NDLOpenSearchParser: NSObject, XMLParserDelegate {
    private(set) var results: [NDLSearchResult] = []

    private struct ItemBuf {
        var title: String?
        var author: String?
        var creators: [String] = []
        var isbn13: String?
    }

    private var currentItem: ItemBuf?
    private var currentText = ""
    private var currentXsiType: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        currentText = ""
        currentXsiType = attributeDict["xsi:type"]
        if elementName == "item" {
            currentItem = ItemBuf()
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        defer { currentXsiType = nil }
        guard var item = currentItem else { return }

        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "title", "dc:title":
            if !trimmed.isEmpty, item.title == nil || elementName == "dc:title" {
                item.title = trimmed
            }
        case "author":
            if !trimmed.isEmpty, item.author == nil {
                item.author = trimmed
            }
        case "dc:creator", "dcterms:creator", "dcndl:creator":
            if !trimmed.isEmpty {
                item.creators.append(trimmed)
            }
        case "dc:identifier":
            if (currentXsiType ?? "").contains("ISBN"),
               let normalized = ISBNNormalizer.toISBN13(trimmed) {
                item.isbn13 = normalized
            }
        case "item":
            if let isbn = item.isbn13, let title = item.title {
                let author = item.creators.isEmpty
                    ? item.author
                    : item.creators.joined(separator: " / ")
                results.append(NDLSearchResult(title: title, author: author, isbn13: isbn))
            }
            currentItem = nil
            return
        default:
            break
        }
        currentItem = item
    }
}

enum ISBNNormalizer {
    static func toISBN13(_ raw: String) -> String? {
        let digits = raw.uppercased().filter { $0.isNumber || $0 == "X" }
        if digits.count == 13, digits.allSatisfy(\.isNumber) {
            return digits
        }
        if digits.count == 10 {
            return isbn10ToIsbn13(digits)
        }
        return nil
    }

    private static func isbn10ToIsbn13(_ isbn10: String) -> String? {
        guard isbn10.count == 10 else { return nil }
        let core = isbn10.dropLast()
        guard core.allSatisfy(\.isNumber) else { return nil }
        let body = "978" + core
        var sum = 0
        for (index, char) in body.enumerated() {
            guard let digit = char.wholeNumberValue else { return nil }
            sum += (index % 2 == 0 ? digit : digit * 3)
        }
        let check = (10 - (sum % 10)) % 10
        return body + String(check)
    }
}
