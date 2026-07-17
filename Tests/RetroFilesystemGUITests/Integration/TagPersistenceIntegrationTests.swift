import Testing
import Foundation
@testable import RetroFilesystemGUI

@Suite("Tag Persistence Integration Tests")
struct TagPersistenceIntegrationTests {

    /// Creates an isolated temporary directory for each test and returns the storage URL within it.
    private func makeTempStorageURL() throws -> (directory: URL, storageURL: URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TagPersistenceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let storageURL = tempDir.appendingPathComponent("tags.json")
        return (tempDir, storageURL)
    }

    /// Cleans up the temporary directory after the test.
    private func cleanup(directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Round-trip: save then load

    @Test("Save and load round-trip preserves tags and associations")
    func saveLoadRoundTrip() throws {
        let (tempDir, storageURL) = try makeTempStorageURL()
        defer { cleanup(directory: tempDir) }

        let service = TagStorageService(storageURL: storageURL)

        let tag1 = Tag(id: UUID(), name: "Work", color: .blue)
        let tag2 = Tag(id: UUID(), name: "Personal", color: .green)
        let association1 = TagAssociation(filePath: "/Users/test/document.pdf", tagId: tag1.id)
        let association2 = TagAssociation(filePath: "/Users/test/photo.jpg", tagId: tag2.id)

        let store = TagStore(tags: [tag1, tag2], associations: [association1, association2])

        try service.save(store)
        let loaded = try service.load()

        #expect(loaded == store)
        #expect(loaded.tags.count == 2)
        #expect(loaded.associations.count == 2)
    }

    // MARK: - First-launch file creation

    @Test("First launch creates empty tag file and returns empty TagStore")
    func firstLaunchFileCreation() throws {
        let (tempDir, storageURL) = try makeTempStorageURL()
        defer { cleanup(directory: tempDir) }

        // Ensure file does not exist before calling load
        #expect(FileManager.default.fileExists(atPath: storageURL.path) == false)

        let service = TagStorageService(storageURL: storageURL)
        let loaded = try service.load()

        // Should return empty store
        #expect(loaded.tags.isEmpty)
        #expect(loaded.associations.isEmpty)

        // Should have created the file on disk
        #expect(FileManager.default.fileExists(atPath: storageURL.path) == true)

        // The created file should contain valid JSON for an empty store
        let data = try Data(contentsOf: storageURL)
        let decoded = try JSONDecoder().decode(TagStore.self, from: data)
        #expect(decoded.tags.isEmpty)
        #expect(decoded.associations.isEmpty)
    }

    // MARK: - Malformed JSON recovery

    @Test("Malformed JSON returns empty TagStore without crashing")
    func malformedJSONRecovery() throws {
        let (tempDir, storageURL) = try makeTempStorageURL()
        defer { cleanup(directory: tempDir) }

        // Write invalid JSON to the file
        let malformedData = Data("{ this is not valid json [[[".utf8)
        try malformedData.write(to: storageURL)

        let service = TagStorageService(storageURL: storageURL)
        let loaded = try service.load()

        // Should recover gracefully with an empty store
        #expect(loaded.tags.isEmpty)
        #expect(loaded.associations.isEmpty)
    }

    @Test("Partially valid JSON with wrong schema returns empty TagStore")
    func wrongSchemaRecovery() throws {
        let (tempDir, storageURL) = try makeTempStorageURL()
        defer { cleanup(directory: tempDir) }

        // Write valid JSON but wrong schema
        let wrongSchema = Data(#"{"name": "not a tag store", "value": 42}"#.utf8)
        try wrongSchema.write(to: storageURL)

        let service = TagStorageService(storageURL: storageURL)
        let loaded = try service.load()

        #expect(loaded.tags.isEmpty)
        #expect(loaded.associations.isEmpty)
    }

    // MARK: - Write persistence verification

    @Test("Save creates file on disk with valid JSON content")
    func writePersistence() throws {
        let (tempDir, storageURL) = try makeTempStorageURL()
        defer { cleanup(directory: tempDir) }

        let service = TagStorageService(storageURL: storageURL)

        let tag = Tag(id: UUID(), name: "Important", color: .red)
        let association = TagAssociation(filePath: "/path/to/file.txt", tagId: tag.id)
        let store = TagStore(tags: [tag], associations: [association])

        try service.save(store)

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: storageURL.path) == true)

        // Verify file contains valid JSON that decodes to the same store
        let data = try Data(contentsOf: storageURL)
        let decoded = try JSONDecoder().decode(TagStore.self, from: data)
        #expect(decoded == store)
    }

    // MARK: - Multiple save/load cycles

    @Test("Multiple save and load cycles preserve latest state")
    func multipleSaveLoadCycles() throws {
        let (tempDir, storageURL) = try makeTempStorageURL()
        defer { cleanup(directory: tempDir) }

        let service = TagStorageService(storageURL: storageURL)

        // First save
        let tag1 = Tag(id: UUID(), name: "Draft", color: .yellow)
        let store1 = TagStore(tags: [tag1], associations: [])
        try service.save(store1)

        // Verify first save
        let loaded1 = try service.load()
        #expect(loaded1 == store1)

        // Second save with modifications
        let tag2 = Tag(id: UUID(), name: "Final", color: .green)
        let association = TagAssociation(filePath: "/docs/report.pdf", tagId: tag1.id)
        let store2 = TagStore(tags: [tag1, tag2], associations: [association])
        try service.save(store2)

        // Verify latest state is loaded
        let loaded2 = try service.load()
        #expect(loaded2 == store2)
        #expect(loaded2.tags.count == 2)
        #expect(loaded2.associations.count == 1)

        // Third save: remove a tag and its associations
        let store3 = TagStore(tags: [tag2], associations: [])
        try service.save(store3)

        let loaded3 = try service.load()
        #expect(loaded3 == store3)
        #expect(loaded3.tags.count == 1)
        #expect(loaded3.associations.isEmpty)
    }
}
