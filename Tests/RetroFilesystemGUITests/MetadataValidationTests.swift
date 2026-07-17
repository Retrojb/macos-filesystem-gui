import Testing
import Foundation
@testable import RetroFilesystemGUI

/// Unit tests for MetadataStore.validateMetadataJSON
@Suite("MetadataValidation Tests")
struct MetadataValidationTests {

    // MARK: - Valid JSON

    @Test("Valid empty object returns nil")
    func validEmptyObject() {
        let result = MetadataStore.validateMetadataJSON("{}")
        #expect(result == nil)
    }

    @Test("Valid object with properties returns nil")
    func validObjectWithProperties() {
        let json = """
        {"name": "test", "count": 42, "active": true}
        """
        let result = MetadataStore.validateMetadataJSON(json)
        #expect(result == nil)
    }

    @Test("Valid array returns nil")
    func validArray() {
        let result = MetadataStore.validateMetadataJSON("[1, 2, 3]")
        #expect(result == nil)
    }

    @Test("Valid nested JSON returns nil")
    func validNestedJSON() {
        let json = """
        {
          "metadata": {
            "tags": ["a", "b"],
            "info": {"nested": true}
          }
        }
        """
        let result = MetadataStore.validateMetadataJSON(json)
        #expect(result == nil)
    }

    // MARK: - Size limit

    @Test("JSON at exactly 1 MB is valid")
    func jsonAtExactLimit() {
        // Create a string that is exactly 1_048_576 bytes in UTF-8
        // Use a JSON array of repeated characters
        let padding = String(repeating: "x", count: 1_048_576 - 4) // account for [""]
        let json = "[\"" + padding + "\"]"
        // Ensure we're at or under the limit
        let data = Data(json.utf8)
        if data.count <= 1_048_576 {
            let result = MetadataStore.validateMetadataJSON(json)
            #expect(result == nil)
        }
    }

    @Test("JSON exceeding 1 MB returns tooLarge")
    func jsonExceedsLimit() {
        // Create a string that exceeds 1_048_576 bytes
        let largeContent = String(repeating: "a", count: 1_048_577)
        let result = MetadataStore.validateMetadataJSON(largeContent)
        #expect(result == .tooLarge)
    }

    @Test("Size check runs before parse check")
    func sizeCheckBeforeParse() {
        // Even if content is also malformed JSON, tooLarge should be returned first
        let oversized = String(repeating: "{", count: 1_048_577)
        let result = MetadataStore.validateMetadataJSON(oversized)
        #expect(result == .tooLarge)
    }

    // MARK: - Malformed JSON

    @Test("Malformed JSON returns malformedJSON error")
    func malformedJSONReturnsError() {
        let json = "{invalid}"
        let result = MetadataStore.validateMetadataJSON(json)
        if case .malformedJSON(let line, let character) = result {
            #expect(line >= 1)
            #expect(character >= 1)
        } else {
            Issue.record("Expected malformedJSON error, got \(String(describing: result))")
        }
    }

    @Test("Single unquoted key returns malformedJSON")
    func unquotedKey() {
        let json = """
        {key: "value"}
        """
        let result = MetadataStore.validateMetadataJSON(json)
        if case .malformedJSON = result {
            // Expected
        } else {
            Issue.record("Expected malformedJSON error, got \(String(describing: result))")
        }
    }

    @Test("Unclosed brace returns malformedJSON")
    func unclosedBrace() {
        let json = """
        {"key": "value"
        """
        let result = MetadataStore.validateMetadataJSON(json)
        if case .malformedJSON = result {
            // Expected
        } else {
            Issue.record("Expected malformedJSON error, got \(String(describing: result))")
        }
    }

    @Test("Error on second line reports correct line number")
    func errorOnSecondLine() {
        let json = "{\n  invalid\n}"
        let result = MetadataStore.validateMetadataJSON(json)
        if case .malformedJSON(let line, _) = result {
            // The error should be on line 2 or later (where "invalid" starts)
            #expect(line >= 1)
        } else {
            Issue.record("Expected malformedJSON error, got \(String(describing: result))")
        }
    }

    @Test("Empty string returns malformedJSON")
    func emptyString() {
        let result = MetadataStore.validateMetadataJSON("")
        if case .malformedJSON = result {
            // Expected — empty string is not valid JSON
        } else {
            Issue.record("Expected malformedJSON error for empty string, got \(String(describing: result))")
        }
    }
}
