import Foundation
import OSLog

/// Concrete implementation of `TagStorageServiceProtocol` that persists tag data
/// as JSON at `~/Library/Application Support/RetroFilesystemGUI/tags.json`.
final class TagStorageService: TagStorageServiceProtocol {

    private static let logger = Logger(
        subsystem: "com.retrostudio.RetroFilesystemGUI",
        category: "TagStorage"
    )

    /// The file URL where tag data is stored.
    let storageURL: URL

    /// Creates a new TagStorageService with the default storage path.
    ///
    /// The default path is `~/Library/Application Support/RetroFilesystemGUI/tags.json`.
    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let appDirectory = appSupport.appendingPathComponent("RetroFilesystemGUI")
        self.storageURL = appDirectory.appendingPathComponent("tags.json")
    }

    /// Creates a TagStorageService with a custom storage URL (useful for testing).
    init(storageURL: URL) {
        self.storageURL = storageURL
    }

    /// Loads the tag store from disk.
    ///
    /// - If the file does not exist, creates an empty tag file and returns an empty `TagStore`.
    /// - If the file contains malformed JSON, logs a descriptive error and returns an empty `TagStore`.
    /// - Returns: A `TagStore` containing all persisted tags and associations.
    func load() throws -> TagStore {
        let fileManager = FileManager.default

        // If file doesn't exist, create an empty one (first launch)
        if !fileManager.fileExists(atPath: storageURL.path) {
            let emptyStore = TagStore(tags: [], associations: [])
            try createDirectoryIfNeeded()
            try writeStore(emptyStore)
            return emptyStore
        }

        // Read and decode the existing file
        let data: Data
        do {
            data = try Data(contentsOf: storageURL)
        } catch {
            Self.logger.error(
                "Failed to read tag data file at \(self.storageURL.path): \(error.localizedDescription)"
            )
            return TagStore(tags: [], associations: [])
        }

        do {
            let decoder = JSONDecoder()
            let store = try decoder.decode(TagStore.self, from: data)
            return store
        } catch {
            Self.logger.error(
                "Malformed JSON in tag data file at \(self.storageURL.path): \(error.localizedDescription)"
            )
            return TagStore(tags: [], associations: [])
        }
    }

    /// Saves the tag store to disk as JSON.
    ///
    /// Creates the parent directory if it does not exist.
    /// - Parameter store: The `TagStore` to persist.
    /// - Throws: An error if the data cannot be written.
    func save(_ store: TagStore) throws {
        try createDirectoryIfNeeded()
        try writeStore(store)
    }

    // MARK: - Private Helpers

    /// Ensures the parent directory for the storage file exists.
    private func createDirectoryIfNeeded() throws {
        let directory = storageURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    /// Encodes and writes the store to disk.
    private func writeStore(_ store: TagStore) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(store)
        try data.write(to: storageURL, options: .atomic)
    }
}
