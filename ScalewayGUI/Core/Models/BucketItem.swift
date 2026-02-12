import Foundation

struct BucketItem: Codable, Identifiable, Equatable {
    var id: String { name }
    let name: String
    let createdAt: Date?
}
