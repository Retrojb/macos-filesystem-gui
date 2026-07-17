import Foundation

struct SmartFolder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var criteria: SmartFolderCriteria
}

struct SmartFolderCriteria: Codable, Equatable {
    var requiredTagIds: [UUID]
    var fileType: String?         // UTI filter, nil = any
    var dateRangeStart: Date?
    var dateRangeEnd: Date?
}
