import Foundation

/// Protocol defining persistence operations for the tag system.
///
/// Conforming types handle serialization and deserialization of tag definitions
/// and file-tag associations to/from persistent storage.
protocol TagStorageServiceProtocol {
    /// Loads the tag store from persistent storage.
    /// - Returns: A `TagStore` containing all tag definitions and associations.
    /// - Throws: An error if the stored data cannot be read or parsed.
    func load() throws -> TagStore

    /// Saves the tag store to persistent storage.
    /// - Parameter store: The `TagStore` to persist.
    /// - Throws: An error if the data cannot be written to storage.
    func save(_ store: TagStore) throws
}
