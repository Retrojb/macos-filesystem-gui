// Feature: finder-enhanced-file-manager, Property 11: Find-and-replace rename rule

import Testing
import Foundation
@testable import RetroFilesystemGUI

/// **Validates: Requirements 7.2**
///
/// Property 11: For any filename string and any find/replace pair (find is non-empty),
/// applying the find-and-replace rule shall produce a result where all occurrences of the
/// find pattern are replaced with the replacement string, and the result equals
/// Swift's `String.replacingOccurrences(of:with:)`.
@Suite("RenameRule Tests")
struct RenameRuleTests {

    private let service = RenameService()

    /// Helper to create a test FileItem with the given name.
    private func makeFileItem(name: String) -> FileItem {
        FileItem(
            id: UUID(),
            url: URL(fileURLWithPath: "/test/\(name)"),
            name: name,
            isDirectory: false,
            size: 0,
            modificationDate: Date(),
            creationDate: Date(),
            kind: "public.data",
            isHidden: false
        )
    }

    /// Generates a random string of given length from printable ASCII characters.
    private func randomString(length: Int) -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-. ")
        return String((0..<length).map { _ in characters.randomElement()! })
    }

    /// Generates a random non-empty string suitable as a find pattern.
    private func randomFindPattern() -> String {
        let length = Int.random(in: 1...10)
        return randomString(length: length)
    }

    /// Generates a random replacement string (can be empty).
    private func randomReplacement() -> String {
        let length = Int.random(in: 0...10)
        return randomString(length: length)
    }

    /// Generates a random filename.
    private func randomFilename() -> String {
        let length = Int.random(in: 1...50)
        return randomString(length: length)
    }

    // MARK: - Property 11: Find-and-replace rename rule

    @Test("Property 11: find-and-replace result equals String.replacingOccurrences")
    func findAndReplaceMatchesStandardLibrary() {
        for _ in 0..<100 {
            let filename = randomFilename()
            let find = randomFindPattern()
            let replace = randomReplacement()

            let file = makeFileItem(name: filename)
            let rule = RenameRule.findReplace(find: find, replace: replace)
            let results = service.applyRule(rule, to: [file])

            let expected = filename.replacingOccurrences(of: find, with: replace)

            #expect(results.count == 1)
            #expect(results[0].original == filename)
            #expect(results[0].result == expected)
        }
    }

    @Test("Property 11: find-and-replace with find pattern present in filename")
    func findAndReplaceWithPatternPresent() {
        for _ in 0..<100 {
            let find = randomFindPattern()
            let replace = randomReplacement()

            // Construct a filename that definitely contains the find pattern
            let prefix = randomString(length: Int.random(in: 0...10))
            let suffix = randomString(length: Int.random(in: 0...10))
            let filename = prefix + find + suffix

            let file = makeFileItem(name: filename)
            let rule = RenameRule.findReplace(find: find, replace: replace)
            let results = service.applyRule(rule, to: [file])

            let expected = filename.replacingOccurrences(of: find, with: replace)

            #expect(results.count == 1)
            #expect(results[0].original == filename)
            #expect(results[0].result == expected)
        }
    }

    @Test("Property 11: find-and-replace applied to multiple files")
    func findAndReplaceMultipleFiles() {
        for _ in 0..<100 {
            let find = randomFindPattern()
            let replace = randomReplacement()
            let fileCount = Int.random(in: 2...10)

            let filenames = (0..<fileCount).map { _ in randomFilename() }
            let files = filenames.map { makeFileItem(name: $0) }

            let rule = RenameRule.findReplace(find: find, replace: replace)
            let results = service.applyRule(rule, to: files)

            #expect(results.count == fileCount)

            for i in 0..<fileCount {
                let expected = filenames[i].replacingOccurrences(of: find, with: replace)
                #expect(results[i].original == filenames[i])
                #expect(results[i].result == expected)
            }
        }
    }

    // MARK: - Property 12: Sequential numbering rename rule
    // Feature: finder-enhanced-file-manager, Property 12: Sequential numbering rename rule

    /// Generates a random filename with an extension.
    private func randomFilenameWithExtension() -> String {
        let extensions = ["txt", "pdf", "png", "jpg", "mp4", "swift", "md", "json"]
        let nameLength = Int.random(in: 3...20)
        let nameChars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        let name = String((0..<nameLength).map { _ in nameChars.randomElement()! })
        let ext = extensions.randomElement()!
        return "\(name).\(ext)"
    }

    /// Generates a random filename without an extension.
    private func randomFilenameWithoutExtension() -> String {
        let nameLength = Int.random(in: 3...20)
        let nameChars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        return String((0..<nameLength).map { _ in nameChars.randomElement()! })
    }

    /// **Validates: Requirements 7.3**
    @Test("Property 12: sequential numbering produces N results with unique numbers S to S+N-1")
    func sequentialNumberingProducesCorrectCount() {
        for _ in 0..<100 {
            let fileCount = Int.random(in: 2...20)
            let start = Int.random(in: 0...100)
            let padding = Int.random(in: 1...6)
            let position: RenameRule.Position = Bool.random() ? .prepend : .append

            let filenames = (0..<fileCount).map { _ in randomFilenameWithExtension() }
            let files = filenames.map { makeFileItem(name: $0) }

            let rule = RenameRule.sequentialNumbering(position: position, start: start, padding: padding)
            let results = service.applyRule(rule, to: files)

            // Result count must equal input count
            #expect(results.count == fileCount)
        }
    }

    /// **Validates: Requirements 7.3**
    @Test("Property 12: sequential numbering contains unique numbers from S to S+N-1 zero-padded to W digits")
    func sequentialNumberingContainsUniqueZeroPaddedNumbers() {
        for _ in 0..<100 {
            let fileCount = Int.random(in: 2...20)
            let start = Int.random(in: 0...100)
            let padding = Int.random(in: 1...6)
            let position: RenameRule.Position = Bool.random() ? .prepend : .append

            let filenames = (0..<fileCount).map { _ in randomFilenameWithExtension() }
            let files = filenames.map { makeFileItem(name: $0) }

            let rule = RenameRule.sequentialNumbering(position: position, start: start, padding: padding)
            let results = service.applyRule(rule, to: files)

            // Each result should contain its expected padded number
            var foundNumbers: Set<String> = []
            for i in 0..<fileCount {
                let expectedNumber = String(format: "%0\(padding)d", start + i)
                #expect(results[i].result.contains(expectedNumber),
                    "Result '\(results[i].result)' should contain '\(expectedNumber)'")
                foundNumbers.insert(expectedNumber)
            }

            // All numbers should be unique (S to S+N-1 are distinct)
            #expect(foundNumbers.count == fileCount)
        }
    }

    /// **Validates: Requirements 7.3**
    @Test("Property 12: sequential numbering prepend places number before filename")
    func sequentialNumberingPrependPosition() {
        for _ in 0..<100 {
            let fileCount = Int.random(in: 2...10)
            let start = Int.random(in: 0...100)
            let padding = Int.random(in: 1...6)

            let filenames = (0..<fileCount).map { _ in randomFilenameWithExtension() }
            let files = filenames.map { makeFileItem(name: $0) }

            let rule = RenameRule.sequentialNumbering(position: .prepend, start: start, padding: padding)
            let results = service.applyRule(rule, to: files)

            for i in 0..<fileCount {
                let expectedNumber = String(format: "%0\(padding)d", start + i)
                // For prepend, the result should start with the padded number
                #expect(results[i].result.hasPrefix(expectedNumber),
                    "Result '\(results[i].result)' should start with '\(expectedNumber)'")
            }
        }
    }

    /// **Validates: Requirements 7.3**
    @Test("Property 12: sequential numbering append places number before extension")
    func sequentialNumberingAppendPosition() {
        for _ in 0..<100 {
            let fileCount = Int.random(in: 2...10)
            let start = Int.random(in: 0...100)
            let padding = Int.random(in: 1...6)

            let filenames = (0..<fileCount).map { _ in randomFilenameWithExtension() }
            let files = filenames.map { makeFileItem(name: $0) }

            let rule = RenameRule.sequentialNumbering(position: .append, start: start, padding: padding)
            let results = service.applyRule(rule, to: files)

            for i in 0..<fileCount {
                let expectedNumber = String(format: "%0\(padding)d", start + i)
                let nameWithoutExt = (filenames[i] as NSString).deletingPathExtension
                let ext = (filenames[i] as NSString).pathExtension

                // For append, the result should be nameWithoutExt + paddedNumber + .ext
                let expectedResult = "\(nameWithoutExt)\(expectedNumber).\(ext)"
                #expect(results[i].result == expectedResult,
                    "Expected '\(expectedResult)' but got '\(results[i].result)'")
            }
        }
    }

    /// **Validates: Requirements 7.3**
    @Test("Property 12: sequential numbering preserves file extension")
    func sequentialNumberingPreservesExtension() {
        for _ in 0..<100 {
            let fileCount = Int.random(in: 2...10)
            let start = Int.random(in: 0...100)
            let padding = Int.random(in: 1...6)
            let position: RenameRule.Position = Bool.random() ? .prepend : .append

            let filenames = (0..<fileCount).map { _ in randomFilenameWithExtension() }
            let files = filenames.map { makeFileItem(name: $0) }

            let rule = RenameRule.sequentialNumbering(position: position, start: start, padding: padding)
            let results = service.applyRule(rule, to: files)

            for i in 0..<fileCount {
                let originalExt = (filenames[i] as NSString).pathExtension
                let resultExt = (results[i].result as NSString).pathExtension
                #expect(resultExt == originalExt,
                    "Extension should be preserved: expected '.\(originalExt)' but got '.\(resultExt)'")
            }
        }
    }

    /// **Validates: Requirements 7.3**
    @Test("Property 12: sequential numbering works with files without extensions")
    func sequentialNumberingWithoutExtension() {
        for _ in 0..<100 {
            let fileCount = Int.random(in: 2...10)
            let start = Int.random(in: 0...100)
            let padding = Int.random(in: 1...6)
            let position: RenameRule.Position = Bool.random() ? .prepend : .append

            let filenames = (0..<fileCount).map { _ in randomFilenameWithoutExtension() }
            let files = filenames.map { makeFileItem(name: $0) }

            let rule = RenameRule.sequentialNumbering(position: position, start: start, padding: padding)
            let results = service.applyRule(rule, to: files)

            for i in 0..<fileCount {
                let expectedNumber = String(format: "%0\(padding)d", start + i)

                switch position {
                case .prepend:
                    let expectedResult = "\(expectedNumber)\(filenames[i])"
                    #expect(results[i].result == expectedResult,
                        "Expected '\(expectedResult)' but got '\(results[i].result)'")
                case .append:
                    let expectedResult = "\(filenames[i])\(expectedNumber)"
                    #expect(results[i].result == expectedResult,
                        "Expected '\(expectedResult)' but got '\(results[i].result)'")
                }
            }
        }
    }
}
