import Foundation

struct Tag: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var color: TagColor
}

enum TagColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, gray, pink
}

struct TagAssociation: Codable, Equatable {
    let filePath: String
    let tagId: UUID
}

struct TagStore: Codable, Equatable {
    var tags: [Tag]
    var associations: [TagAssociation]
}
