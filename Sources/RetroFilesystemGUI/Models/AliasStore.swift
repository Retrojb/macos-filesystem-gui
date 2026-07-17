import Foundation

/// Maps file paths to their alias display names.
struct AliasStore: Codable, Equatable {
    /// Dictionary: file absolute path -> alias name string
    var aliases: [String: String]

    /// Maximum allowed alias name length.
    static let maxAliasLength = 255

    /// Validates a proposed alias name.
    ///
    /// An alias name is valid if and only if:
    /// - It is not empty
    /// - Its length does not exceed 255 characters
    /// - It does not contain '/'
    /// - It does not contain ':'
    ///
    /// - Parameter name: The proposed alias name string.
    /// - Returns: An `AliasValidationError` if invalid, or `nil` if valid.
    static func validateAlias(_ name: String) -> AliasValidationError? {
        guard !name.isEmpty else {
            return .empty
        }

        guard name.count <= maxAliasLength else {
            return .tooLong
        }

        if name.contains("/") {
            return .containsSlash
        }

        if name.contains(":") {
            return .containsColon
        }

        return nil
    }
}

enum AliasValidationError: Error, Equatable {
    case empty
    case tooLong
    case containsSlash
    case containsColon
}
