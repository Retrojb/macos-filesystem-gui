import Foundation
import OSLog

/// Wraps an array of SmartFolders for JSON serialization.
struct SmartFolderStore: Codable, Equatable {
    var smartFolders: [SmartFolder]
}

/// Errors that can occur during smart folder creation validation.
enum SmartFolderValidationError: Error, Equatable {
    /// The name is empty or exceeds 64 characters.
    case invalidName
    /// A smart folder with the same name already exists (case-insensitive).
    case duplicateName
    /// No filter criteria were specified (requires at least one).
    case noCriteria
}

/// Protocol defining persistence and validation operations for smart folders.
protocol SmartFolderStorageServiceProtocol {
    /// Loads the smart folder store from persistent storage.
    func load() throws -> SmartFolderStore

    /// Saves the smart folder store to persistent storage.
    func save(_ store: SmartFolderStore) throws

    /// Validates a smart folder creation request.
    /// - Parameters:
    ///   - name: The proposed smart folder name.
    ///   - criteria: The proposed filter criteria.
    ///   - existingFolders: The current list of smart folders to check for duplicates.
    /// - Returns: `nil` if valid, or a `SmartFolderValidationError` describing the issue.
    func validate(name: String, criteria: SmartFolderCriteria, existingFolders: [SmartFolder]) -> SmartFolderValidationError?
}

/// Concrete implementation of `SmartFolderStorageServiceProtocol` that persists smart folder data
/// as JSON at `~/Library/Application Support/RetroFilesystemGUI/smart_folders.json`.
final class SmartFolderStorageService: SmartFolderStorageServiceProtocol {

    private static let logger = Logger(
        subsystem: "com.retrostudio.RetroFilesystemGUI",
        category: "SmartFolderStorage"
    )

    /// The file URL where smart folder data is stored.
    let storageURL: URL

    /// Creates a new SmartFolderStorageService with the default storage path.
    ///
    /// The default path is `~/Library/Application Support/RetroFilesystemGUI/smart_folders.json`.
    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let appDirectory = appSupport.appendingPathComponent("RetroFilesystemGUI")
        self.storageURL = appDirectory.appendingPathComponent("smart_folders.json")
    }

    /// Creates a SmartFolderStorageService with a custom storage URL (useful for testing).
    init(storageURL: URL) {
        self.storageURL = storageURL
    }

    /// Loads the smart folder store from disk.
    ///
    /// - If the file does not exist, creates an empty file and returns an empty `SmartFolderStore`.
    /// - If the file contains malformed JSON, logs a descriptive error and returns an empty `SmartFolderStore`.
    /// - Returns: A `SmartFolderStore` containing all persisted smart folders.
    func load() throws -> SmartFolderStore {
        let fileManager = FileManager.default

        // If file doesn't exist, create an empty one (first launch)
        if !fileManager.fileExists(atPath: storageURL.path) {
            let emptyStore = SmartFolderStore(smartFolders: [])
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
                "Failed to read smart folder data file at \(self.storageURL.path): \(error.localizedDescription)"
            )
            return SmartFolderStore(smartFolders: [])
        }

        do {
            let decoder = JSONDecoder()
            let store = try decoder.decode(SmartFolderStore.self, from: data)
            return store
        } catch {
            Self.logger.error(
                "Malformed JSON in smart folder data file at \(self.storageURL.path): \(error.localizedDescription)"
            )
            return SmartFolderStore(smartFolders: [])
        }
    }

    /// Saves the smart folder store to disk as JSON.
    ///
    /// Creates the parent directory if it does not exist.
    /// - Parameter store: The `SmartFolderStore` to persist.
    /// - Throws: An error if the data cannot be written.
    func save(_ store: SmartFolderStore) throws {
        try createDirectoryIfNeeded()
        try writeStore(store)
    }

    /// Validates a smart folder creation request against the given constraints.
    ///
    /// - Parameters:
    ///   - name: The proposed name (must be 1–64 characters).
    ///   - criteria: The proposed criteria (at least one must be specified).
    ///   - existingFolders: Current smart folders to check for name collisions.
    /// - Returns: `nil` if the request is valid, or the specific validation error.
    func validate(name: String, criteria: SmartFolderCriteria, existingFolders: [SmartFolder]) -> SmartFolderValidationError? {
        // Validate name length: 1–64 characters
        let trimmedName = name
        guard trimmedName.count >= 1, trimmedName.count <= 64 else {
            return .invalidName
        }

        // Validate no duplicate names (case-insensitive)
        let lowercasedName = trimmedName.lowercased()
        let hasDuplicate = existingFolders.contains { $0.name.lowercased() == lowercasedName }
        if hasDuplicate {
            return .duplicateName
        }

        // Validate at least one criterion is specified
        let hasTagCriteria = !criteria.requiredTagIds.isEmpty
        let hasFileTypeCriteria = criteria.fileType != nil
        let hasDateStartCriteria = criteria.dateRangeStart != nil
        let hasDateEndCriteria = criteria.dateRangeEnd != nil

        if !hasTagCriteria && !hasFileTypeCriteria && !hasDateStartCriteria && !hasDateEndCriteria {
            return .noCriteria
        }

        return nil
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
    private func writeStore(_ store: SmartFolderStore) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(store)
        try data.write(to: storageURL, options: .atomic)
    }
}
