import Foundation

enum AmazonAffiliateURL {
    static let associateTag = "bigdrives-22"
    private static let host = "www.amazon.co.jp"

    /// ISBN-13 から Amazon.co.jp のアフィリエイトタグ付き URL を生成する。
    /// 978 始まりは ISBN-10 に変換して /dp/ 直リンク、
    /// 979 始まりは ISBN-10 換算不可のため検索 URL にフォールバックする。
    static func url(forISBN13 isbn13: String) -> URL? {
        let digits = isbn13.filter(\.isNumber)
        guard digits.count == 13 else { return searchURL(for: isbn13) }

        if digits.hasPrefix("978"), let isbn10 = isbn13ToIsbn10(digits) {
            var components = URLComponents()
            components.scheme = "https"
            components.host = host
            components.path = "/dp/\(isbn10)/"
            components.queryItems = [URLQueryItem(name: "tag", value: associateTag)]
            return components.url
        }

        return searchURL(for: digits)
    }

    private static func searchURL(for keyword: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/s"
        components.queryItems = [
            URLQueryItem(name: "k", value: keyword),
            URLQueryItem(name: "tag", value: associateTag)
        ]
        return components.url
    }

    /// 978 始まりの ISBN-13 を ISBN-10 へ変換する。
    /// 末尾チェックディジットを mod 11 で再計算し、10 のときは "X" を採用する。
    private static func isbn13ToIsbn10(_ isbn13: String) -> String? {
        guard isbn13.count == 13, isbn13.hasPrefix("978") else { return nil }
        let core = isbn13.dropFirst(3).dropLast()    // 9桁
        guard core.count == 9, core.allSatisfy(\.isNumber) else { return nil }

        var sum = 0
        for (index, char) in core.enumerated() {
            guard let digit = char.wholeNumberValue else { return nil }
            sum += digit * (10 - index)
        }
        let remainder = (11 - (sum % 11)) % 11
        let checkDigit = remainder == 10 ? "X" : String(remainder)
        return core + checkDigit
    }
}
