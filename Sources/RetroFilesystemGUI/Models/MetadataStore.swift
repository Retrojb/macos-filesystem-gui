import Foundation

/// Represents an arbitrary JSON value for metadata storage.
enum JSONValue: Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

// MARK: - JSONValue + Codable

extension JSONValue: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        // Try bool before numeric types to avoid Int/Double catching true/false
        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
            return
        }

        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
            return
        }

        if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
            return
        }

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }

        if let arrayValue = try? container.decode([JSONValue].self) {
            self = .array(arrayValue)
            return
        }

        if let objectValue = try? container.decode([String: JSONValue].self) {
            self = .object(objectValue)
            return
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unable to decode JSONValue"
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

// MARK: - MetadataStore

/// Maps file paths to their JSON metadata.
struct MetadataStore: Codable, Equatable {
    /// Dictionary: file absolute path -> JSON metadata value
    var entries: [String: JSONValue]

    /// Maximum allowed metadata size in bytes (1 MB).
    static let maxMetadataSize = 1_048_576

    /// Validates a JSON text string for use as file metadata.
    ///
    /// Checks performed in order:
    /// 1. Size check: the UTF-8 encoded content must not exceed 1 MB (1,048,576 bytes).
    /// 2. Parse check: the content must be valid JSON. If parsing fails, the line and
    ///    character position of the first error are reported.
    ///
    /// - Parameter text: The JSON text string to validate.
    /// - Returns: A `MetadataValidationError` if invalid, or `nil` if valid.
    static func validateMetadataJSON(_ text: String) -> MetadataValidationError? {
        let data = Data(text.utf8)

        // Check size limit
        guard data.count <= maxMetadataSize else {
            return .tooLarge
        }

        // Attempt JSON parsing
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
            return nil
        } catch {
            // Extract error position from the JSON parsing failure
            let (line, character) = errorPosition(in: text, from: error)
            return .malformedJSON(line: line, character: character)
        }
    }

    /// Computes the line number and character position of a JSON parse error.
    ///
    /// Attempts to extract a byte offset from the `NSError` userInfo or error description,
    /// then translates that offset into a 1-based line and character position within the text.
    ///
    /// - Parameters:
    ///   - text: The original JSON text that failed to parse.
    ///   - error: The error thrown by `JSONSerialization`.
    /// - Returns: A tuple of (line, character), both 1-based.
    private static func errorPosition(in text: String, from error: Error) -> (line: Int, character: Int) {
        let nsError = error as NSError

        // Try to get the byte offset from the error's debug description.
        // NSJSONSerialization errors typically include a phrase like "around character N" or
        // "around line N" in the debug description. We try to extract a character offset.
        var byteOffset: Int?

        // Check the error description for "character" offset
        let description = nsError.debugDescription
        if let range = description.range(of: "character ") {
            let afterCharacter = description[range.upperBound...]
            let digits = afterCharacter.prefix(while: { $0.isNumber })
            if let offset = Int(digits) {
                byteOffset = offset
            }
        }

        // If we couldn't extract an offset, try "around character" pattern
        if byteOffset == nil, let range = description.range(of: "around character ") {
            let afterCharacter = description[range.upperBound...]
            let digits = afterCharacter.prefix(while: { $0.isNumber })
            if let offset = Int(digits) {
                byteOffset = offset
            }
        }

        // Fallback: scan for "index " pattern (some error formats)
        if byteOffset == nil, let range = description.range(of: "index ") {
            let afterIndex = description[range.upperBound...]
            let digits = afterIndex.prefix(while: { $0.isNumber })
            if let offset = Int(digits) {
                byteOffset = offset
            }
        }

        guard let offset = byteOffset else {
            // If we can't determine the position, report line 1, character 1
            return (line: 1, character: 1)
        }

        // Convert byte offset to line and character position (1-based)
        return lineAndCharacter(in: text, byteOffset: offset)
    }

    /// Translates a byte offset into a 1-based line number and character position.
    ///
    /// - Parameters:
    ///   - text: The source text.
    ///   - byteOffset: The byte offset (0-based) into the UTF-8 representation.
    /// - Returns: A tuple of (line, character), both 1-based.
    private static func lineAndCharacter(in text: String, byteOffset: Int) -> (line: Int, character: Int) {
        let utf8 = text.utf8
        let clampedOffset = min(byteOffset, utf8.count)

        var line = 1
        var characterInLine = 1
        var currentByte = 0

        for char in text {
            let charByteCount = String(char).utf8.count
            if currentByte >= clampedOffset {
                break
            }
            if char == "\n" {
                line += 1
                characterInLine = 1
            } else {
                characterInLine += 1
            }
            currentByte += charByteCount
        }

        return (line: line, character: characterInLine)
    }
}

// MARK: - MetadataValidationError

enum MetadataValidationError: Error, Equatable {
    case malformedJSON(line: Int, character: Int)
    case tooLarge
}
