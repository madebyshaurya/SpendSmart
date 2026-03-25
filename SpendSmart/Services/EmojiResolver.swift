import Foundation

actor EmojiResolver {
    static let shared = EmojiResolver()
    private var cache: [String: String] = [:]

    func cachedEmoji(for key: String) -> String? {
        cache[key]
    }

    func setEmoji(_ emoji: String, for key: String) {
        cache[key] = emoji
    }

    static func firstEmoji(in text: String) -> String? {
        for character in text {
            if character.isEmoji {
                return String(character)
            }
        }
        return nil
    }
}

private extension Character {
    var isEmoji: Bool {
        unicodeScalars.contains { scalar in
            scalar.properties.isEmojiPresentation || scalar.properties.isEmoji
        }
    }
}
