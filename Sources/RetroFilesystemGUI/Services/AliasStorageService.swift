import Foundation
import OSLog

/// Protocol defining persistence operations for the alias system.
///
/// Conforming types handle serialization and deserialization of file path
/// to alias name mappings to/from persistent storage.
protocol AliasStorageServiceProtocol {
    /// Loads the alias store from persistent storage.
    /// - Returns: An `AliasStore` containing all path-to-alias mappings.
    /// - Throws: An error if the stored data cannot be read or parsed.
    func load() throws -> AliasStore

    /// Saves the alias store to persistent storage.
    /// - Parameter store: The `AliasStore` to persist.
    /// - Throws: An error if the data cannot be written to storage.
    func save(_ store: AliasStore) throws
}

/// Concrete implementation of `AliasStorageServiceProtocol` that persists alias data
/// as JSON at `~/Library/Application Support/RetroFilesystemGUI/aliases.json`.
final class AliasStorageService: AliasStorageServiceProtocol {

    private static let logger = Logger(
        subsystem: "com.retrostudio.RetroFilesystemGUI",
        category: "AliasStorage"
    )

    /// The file URL where alias data is stored.
    let storageURL: URL

    /// Creates a new AliasStorageService with the default storage path.
    ///
    /// The default path is `~/Library/Application Support/RetroFilesystemGUI/aliases.json`.
    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let appDirectory = appSupport.appendingPathComponent("RetroFilesystemGUI")
        self.storageURL = appDirectory.appendingPathComponent("aliases.json")
    }

    /// Creates an AliasStorageService with a custom storage URL (useful for testing).
    init(storageURL: URL) {
        self.storageURL = storageURL
    }

    /// Loads the alias store from disk.
    ///
    /// - If the file does not exist, creates an empty alias file and returns an empty `AliasStore`.
    /// - If the file contains malformed JSON, logs a descriptive error and returns an empty `AliasStore`.
    /// - Returns: An `AliasStore` containing all persisted aliases.
    func load() throws -> AliasStore {
        let fileManager = FileManager.default

        // If file doesn't exist, create an empty one (first launch)
        if !fileManager.fileExists(atPath: storageURL.path) {
            let emptyStore = AliasStore(aliases: [:])
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
                "Failed to read alias data file at \(self.storageURL.path): \(error.localizedDescription)"
            )
            return AliasStore(aliases: [:])
        }

        do {
            let decoder = JSONDecoder()
            let store = try decoder.decode(AliasStore.self, from: data)
            return store
        } catch {
            Self.logger.error(
                "Malformed JSON in alias data file at \(self.storageURL.path): \(error.localizedDescription)"
            )
            return AliasStore(aliases: [:])
        }
    }

    /// Saves the alias store to disk as JSON.
    ///
    /// Creates the parent directory if it does not exist.
    /// - Parameter store: The `AliasStore` to persist.
    /// - Throws: An error if the data cannot be written.
    func save(_ store: AliasStore) throws {
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
    private func writeStore(_ store: AliasStore) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(store)
        try data.write(to: storageURL, options: .atomic)
    }
}
