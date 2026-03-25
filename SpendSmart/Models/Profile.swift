import Foundation

struct Profile: Identifiable, Codable {
    var id: UUID
    var full_name: String?
    var created_at: Date?
    var updated_at: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case full_name
        case created_at
        case updated_at
    }
}
