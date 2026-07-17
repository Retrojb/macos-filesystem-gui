import Foundation
import OSLog

/// Protocol defining persistence operations for the metadata system.
///
/// Conforming types handle serialization and deserialization of file metadata
/// entries to/from persistent storage.
protocol MetadataStorageServiceProtocol {
    /// Loads the metadata store from persistent storage.
    /// - Returns: A `MetadataStore` containing all file metadata entries.
    /// - Throws: An error if the stored data cannot be read or parsed.
    func load() throws -> MetadataStore

    /// Saves the metadata store to persistent storage.
    /// - Parameter store: The `MetadataStore` to persist.
    /// - Throws: An error if the data cannot be written to storage.
    func save(_ store: MetadataStore) throws
}

/// Concrete implementation of `MetadataStorageServiceProtocol` that persists metadata
/// as JSON at `~/Library/Application Support/RetroFilesystemGUI/metadata.json`.
final class MetadataStorageService: MetadataStorageServiceProtocol {

    private static let logger = Logger(
        subsystem: "com.retrostudio.RetroFilesystemGUI",
        category: "MetadataStorage"
    )

    /// The file URL where metadata is stored.
    let storageURL: URL

    /// Creates a new MetadataStorageService with the default storage path.
    ///
    /// The default path is `~/Library/Application Support/RetroFilesystemGUI/metadata.json`.
    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let appDirectory = appSupport.appendingPathComponent("RetroFilesystemGUI")
        self.storageURL = appDirectory.appendingPathComponent("metadata.json")
    }

    /// Creates a MetadataStorageService with a custom storage URL (useful for testing).
    init(storageURL: URL) {
        self.storageURL = storageURL
    }

    /// Loads the metadata store from disk.
    ///
    /// - If the file does not exist, creates an empty metadata file and returns an empty `MetadataStore`.
    /// - If the file contains malformed JSON, logs a descriptive error and returns an empty `MetadataStore`.
    /// - Returns: A `MetadataStore` containing all persisted metadata entries.
    func load() throws -> MetadataStore {
        let fileManager = FileManager.default

        // If file doesn't exist, create an empty one (first launch)
        if !fileManager.fileExists(atPath: storageURL.path) {
            let emptyStore = MetadataStore(entries: [:])
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
                "Failed to read metadata file at \(self.storageURL.path): \(error.localizedDescription)"
            )
            return MetadataStore(entries: [:])
        }

        do {
            let decoder = JSONDecoder()
            let store = try decoder.decode(MetadataStore.self, from: data)
            return store
        } catch {
            Self.logger.error(
                "Malformed JSON in metadata file at \(self.storageURL.path): \(error.localizedDescription)"
            )
            return MetadataStore(entries: [:])
        }
    }

    /// Saves the metadata store to disk as JSON.
    ///
    /// Creates the parent directory if it does not exist.
    /// - Parameter store: The `MetadataStore` to persist.
    /// - Throws: An error if the data cannot be written.
    func save(_ store: MetadataStore) throws {
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
    private func writeStore(_ store: MetadataStore) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(store)
        try data.write(to: storageURL, options: .atomic)
    }
}
