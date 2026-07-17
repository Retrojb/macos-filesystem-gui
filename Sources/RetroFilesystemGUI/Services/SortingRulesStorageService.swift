import Foundation
import OSLog

/// Protocol defining persistence operations for sorting rules.
///
/// Conforming types handle serialization and deserialization of directory sorting rules
/// to/from persistent storage.
protocol SortingRulesStorageServiceProtocol {
    /// Loads the sorting rules store from persistent storage.
    /// - Returns: A `SortingRulesStore` containing all directory sorting rules.
    /// - Throws: An error if the stored data cannot be read or parsed.
    func load() throws -> SortingRulesStore

    /// Saves the sorting rules store to persistent storage.
    /// - Parameter store: The `SortingRulesStore` to persist.
    /// - Throws: An error if the data cannot be written to storage.
    func save(_ store: SortingRulesStore) throws
}

/// Concrete implementation of `SortingRulesStorageServiceProtocol` that persists sorting rules
/// as JSON at `~/Library/Application Support/RetroFilesystemGUI/sorting-rules.json`.
final class SortingRulesStorageService: SortingRulesStorageServiceProtocol {

    private static let logger = Logger(
        subsystem: "com.retrostudio.RetroFilesystemGUI",
        category: "SortingRulesStorage"
    )

    /// The file URL where sorting rules data is stored.
    let storageURL: URL

    /// Creates a new SortingRulesStorageService with the default storage path.
    ///
    /// The default path is `~/Library/Application Support/RetroFilesystemGUI/sorting-rules.json`.
    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let appDirectory = appSupport.appendingPathComponent("RetroFilesystemGUI")
        self.storageURL = appDirectory.appendingPathComponent("sorting-rules.json")
    }

    /// Creates a SortingRulesStorageService with a custom storage URL (useful for testing).
    init(storageURL: URL) {
        self.storageURL = storageURL
    }

    /// Loads the sorting rules store from disk.
    ///
    /// - If the file does not exist, creates an empty file and returns an empty `SortingRulesStore`.
    /// - If the file contains malformed JSON, logs a descriptive error and returns an empty `SortingRulesStore`.
    /// - Returns: A `SortingRulesStore` containing all persisted sorting rules.
    func load() throws -> SortingRulesStore {
        let fileManager = FileManager.default

        // If file doesn't exist, create an empty one (first launch)
        if !fileManager.fileExists(atPath: storageURL.path) {
            let emptyStore = SortingRulesStore(directories: [])
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
                "Failed to read sorting rules data file at \(self.storageURL.path): \(error.localizedDescription)"
            )
            return SortingRulesStore(directories: [])
        }

        do {
            let decoder = JSONDecoder()
            let store = try decoder.decode(SortingRulesStore.self, from: data)
            return store
        } catch {
            Self.logger.error(
                "Malformed JSON in sorting rules data file at \(self.storageURL.path): \(error.localizedDescription)"
            )
            return SortingRulesStore(directories: [])
        }
    }

    /// Saves the sorting rules store to disk as JSON.
    ///
    /// Creates the parent directory if it does not exist.
    /// - Parameter store: The `SortingRulesStore` to persist.
    /// - Throws: An error if the data cannot be written.
    func save(_ store: SortingRulesStore) throws {
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
    private func writeStore(_ store: SortingRulesStore) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(store)
        try data.write(to: storageURL, options: .atomic)
    }
}
