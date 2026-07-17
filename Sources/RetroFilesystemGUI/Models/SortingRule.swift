import Foundation

/// A rule type that determines how files are matched.
enum SortingRuleType: String, Codable, Equatable {
    case fileExtension   // matches file extension (without dot), 1–20 chars
    case namePattern     // glob pattern matching, 1–255 chars
    case tag             // matches files with a specific tag ID
}

/// A single sorting rule for a directory.
struct SortingRule: Identifiable, Codable, Equatable {
    let id: UUID
    var ruleType: SortingRuleType
    var pattern: String       // extension string, glob pattern, or tag UUID string
    var createdDate: Date
}

/// Associates a directory path with its sorting rules.
struct DirectorySortingRules: Codable, Equatable {
    let directoryPath: String
    var rules: [SortingRule]  // max 50 per directory
}

/// Top-level store for all sorting rules.
struct SortingRulesStore: Codable, Equatable {
    var directories: [DirectorySortingRules]
}

/// Validation errors for sorting rule creation and editing.
enum SortingRuleValidationError: Error, Equatable {
    case emptyPattern
    case patternTooLong     // extension > 20, name pattern > 255
    case maxRulesReached    // 50 per directory
}
