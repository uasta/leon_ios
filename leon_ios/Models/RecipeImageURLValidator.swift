import Foundation

enum RecipeImageURLValidator {
    static func validImageURL(from rawValue: String?) -> URL? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }

        let path = url.path.lowercased()
        let host = (url.host ?? "").lowercased()

        if path.hasSuffix(".html") || path.hasSuffix(".htm") || path.hasSuffix(".php") || path.hasSuffix("/") {
            return nil
        }

        if host.contains("meishichina.com") || host.contains("xiachufang.com") {
            return nil
        }

        if host.contains("oss-cn-") || path.contains("/recipes/") {
            return url
        }

        if [".jpg", ".jpeg", ".png", ".webp", ".gif"].contains(where: { path.hasSuffix($0) }) {
            return url
        }

        return nil
    }
}
