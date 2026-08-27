import Foundation

struct RecipeStep: Identifiable, Hashable, Codable {
    let index: Int
    let text: String
    var imageURL: String?

    var id: Int { index }

    enum CodingKeys: String, CodingKey {
        case index
        case text
        case imageURL = "image_url"
        case imageFilename = "image_filename"
    }

    init(index: Int, text: String, imageURL: String? = nil) {
        self.index = index
        self.text = text
        self.imageURL = imageURL
    }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let text = try? single.decode(String.self) {
            self.index = 0
            self.text = text
            self.imageURL = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let index = try container.decodeIfPresent(Int.self, forKey: .index) ?? 0
        let text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        let imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
            ?? try container.decodeIfPresent(String.self, forKey: .imageFilename)
        self.index = index
        self.text = text
        self.imageURL = imageURL
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
    }
}
