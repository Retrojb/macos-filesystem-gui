import Foundation

/// Protocol defining operations for the bulk rename system.
///
/// Conforming types implement rename rule application (preview generation),
/// atomic execution of rename operations, and revert (undo) capabilities.
protocol RenameServiceProtocol {
    /// Applies a rename rule to a list of files and returns the preview of original and resulting names.
    /// - Parameters:
    ///   - rule: The `RenameRule` to apply.
    ///   - files: The list of `FileItem` objects to rename.
    /// - Returns: An array of tuples mapping original filenames to their resulting names after the rule is applied.
    func applyRule(_ rule: RenameRule, to files: [FileItem]) -> [(original: String, result: String)]

    /// Executes a set of rename operations atomically.
    ///
    /// All renames must succeed or the operation is reverted so that no partial changes remain.
    /// - Parameter renames: An array of tuples mapping source URLs to destination URLs.
    /// - Throws: An error if any rename fails, after reverting all previously completed renames in the batch.
    func execute(renames: [(source: URL, destination: URL)]) throws

    /// Reverts a set of previously executed rename operations.
    ///
    /// Restores files from their destination paths back to their original source paths.
    /// - Parameter renames: An array of tuples mapping the original source URLs to the destination URLs (as provided to `execute`).
    /// - Throws: An error if any revert operation fails.
    func revert(renames: [(source: URL, destination: URL)]) throws
}
