import Foundation

/// Validation result for filename checks.
enum FilenameValidationResult: Equatable {
    case valid
    case invalid(FilenameValidationError)
}

/// Describes why a filename is invalid.
enum FilenameValidationError: Equatable {
    case empty
    case tooLong
    case containsInvalidCharacter(Character)
}

/// Validates filenames according to macOS naming rules.
enum FilenameValidator {
    /// Characters that are not allowed in filenames.
    static let invalidCharacters: Set<Character> = [":", "/"]

    /// Maximum allowed filename length.
    static let maxLength = 255

    /// Validates a proposed filename.
    ///
    /// A filename is valid if and only if:
    /// - Its length is between 1 and 255 inclusive
    /// - It does not contain `:` or `/`
    ///
    /// - Parameter name: The proposed filename string.
    /// - Returns: A `FilenameValidationResult` indicating validity or the specific error.
    static func validate(_ name: String) -> FilenameValidationResult {
        guard !name.isEmpty else {
            return .invalid(.empty)
        }

        guard name.count <= maxLength else {
            return .invalid(.tooLong)
        }

        for character in name {
            if invalidCharacters.contains(character) {
                return .invalid(.containsInvalidCharacter(character))
            }
        }

        return .valid
    }

    /// Convenience check that returns a simple Boolean.
    ///
    /// - Parameter name: The proposed filename string.
    /// - Returns: `true` if the filename is valid, `false` otherwise.
    static func isValid(_ name: String) -> Bool {
        validate(name) == .valid
    }
}
