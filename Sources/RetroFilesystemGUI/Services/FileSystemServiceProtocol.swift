import Foundation

/// Protocol defining file system operations for directory browsing and file management.
///
/// Conforming types provide access to the underlying file system for listing contents,
/// moving, copying, trashing, creating directories, renaming items, and checking existence.
protocol FileSystemServiceProtocol {
    /// Returns the contents of a directory at the given URL.
    /// - Parameters:
    ///   - url: The URL of the directory to list.
    ///   - showHidden: Whether to include hidden files in the results.
    /// - Returns: An array of `FileItem` representing the directory contents.
    /// - Throws: An error if the directory cannot be read (e.g., permissions, not found).
    func contentsOfDirectory(at url: URL, showHidden: Bool) throws -> [FileItem]

    /// Moves a file or directory from one location to another.
    /// - Parameters:
    ///   - source: The current URL of the item.
    ///   - destination: The target URL to move the item to.
    /// - Throws: An error if the move fails (e.g., permissions, name collision, disk full).
    func moveItem(at source: URL, to destination: URL) throws

    /// Copies a file or directory from one location to another.
    /// - Parameters:
    ///   - source: The URL of the item to copy.
    ///   - destination: The target URL for the copy.
    /// - Throws: An error if the copy fails (e.g., permissions, name collision, disk full).
    func copyItem(at source: URL, to destination: URL) throws

    /// Moves a file or directory to the Trash.
    /// - Parameter url: The URL of the item to trash.
    /// - Throws: An error if the item cannot be trashed (e.g., permissions).
    func trashItem(at url: URL) throws

    /// Creates a new directory at the specified location.
    /// - Parameters:
    ///   - url: The parent directory URL where the new folder should be created.
    ///   - name: The name of the new directory.
    /// - Returns: The URL of the newly created directory.
    /// - Throws: An error if the directory cannot be created.
    @discardableResult
    func createDirectory(at url: URL, name: String) throws -> URL

    /// Renames a file or directory.
    /// - Parameters:
    ///   - url: The current URL of the item to rename.
    ///   - newName: The new name for the item.
    /// - Returns: The URL of the item at its new location.
    /// - Throws: An error if the rename fails (e.g., invalid name, permissions, collision).
    @discardableResult
    func renameItem(at url: URL, to newName: String) throws -> URL

    /// Checks whether an item exists at the given URL.
    /// - Parameter url: The URL to check.
    /// - Returns: `true` if an item exists at the URL, `false` otherwise.
    func itemExists(at url: URL) -> Bool
}
