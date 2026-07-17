import Foundation
import OSLog

/// Errors that can occur during directory comparison.
enum DirectoryComparisonError: Error, LocalizedError {
    case directoryNotFound(name: String)
    case accessDenied(name: String)
    case readFailed(name: String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .directoryNotFound(let name):
            return "Directory '\(name)' no longer exists"
        case .accessDenied(let name):
            return "Cannot read directory '\(name)' due to insufficient permissions"
        case .readFailed(let name, let underlying):
            return "Failed to read directory '\(name)': \(underlying.localizedDescription)"
        }
    }
}

/// Protocol for directory comparison logic.
///
/// Conforming types analyze two directories and produce a comparison result
/// partitioned into items unique to each directory and items common to both.
protocol DirectoryComparatorServiceProtocol {
    /// Compares the immediate children of two directories.
    /// - Parameters:
    ///   - directory1: The URL of the first directory.
    ///   - directory2: The URL of the second directory.
    ///   - fileSystemService: The file system service used to list directory contents.
    /// - Returns: A `DirectoryComparisonResult` with items partitioned into three categories.
    /// - Throws: A `DirectoryComparisonError` if either directory is missing or unreadable.
    func compare(
        directory1: URL,
        directory2: URL,
        fileSystemService: FileSystemServiceProtocol
    ) throws -> DirectoryComparisonResult
}

/// Concrete implementation of `DirectoryComparatorServiceProtocol` that compares
/// two directories by listing their immediate children and partitioning by name.
final class DirectoryComparatorService: DirectoryComparatorServiceProtocol {

    private static let logger = Logger(
        subsystem: "com.retrostudio.RetroFilesystemGUI",
        category: "DirectoryComparison"
    )

    /// Compares the immediate children of two directories using case-sensitive name matching.
    ///
    /// The comparison partitions items into three categories:
    /// - `uniqueToFirst`: items present only in directory1
    /// - `uniqueToSecond`: items present only in directory2
    /// - `inBoth`: items present in both directories (uses directory1's item data)
    ///
    /// - Parameters:
    ///   - directory1: The URL of the first directory.
    ///   - directory2: The URL of the second directory.
    ///   - fileSystemService: The file system service used to list directory contents.
    /// - Returns: A `DirectoryComparisonResult` containing the partitioned items.
    /// - Throws: A `DirectoryComparisonError` if either directory is missing or unreadable.
    func compare(
        directory1: URL,
        directory2: URL,
        fileSystemService: FileSystemServiceProtocol
    ) throws -> DirectoryComparisonResult {
        Self.logger.info(
            "Comparing directories: '\(directory1.lastPathComponent)' and '\(directory2.lastPathComponent)'"
        )

        // Check that both directories exist
        if !fileSystemService.itemExists(at: directory1) {
            Self.logger.error("Directory not found: \(directory1.path)")
            throw DirectoryComparisonError.directoryNotFound(name: directory1.lastPathComponent)
        }
        if !fileSystemService.itemExists(at: directory2) {
            Self.logger.error("Directory not found: \(directory2.path)")
            throw DirectoryComparisonError.directoryNotFound(name: directory2.lastPathComponent)
        }

        // List contents of both directories (including hidden files)
        let items1 = try listContents(of: directory1, using: fileSystemService)
        let items2 = try listContents(of: directory2, using: fileSystemService)

        // Create name sets for partitioning (case-sensitive)
        let names1 = Set(items1.map(\.name))
        let names2 = Set(items2.map(\.name))

        // Partition items into three categories
        let uniqueToFirst = items1
            .filter { !names2.contains($0.name) }
            .map { makeComparisonItem(from: $0) }

        let uniqueToSecond = items2
            .filter { !names1.contains($0.name) }
            .map { makeComparisonItem(from: $0) }

        let inBoth = items1
            .filter { names2.contains($0.name) }
            .map { makeComparisonItem(from: $0) }

        Self.logger.info(
            "Comparison complete: \(uniqueToFirst.count) unique to first, \(uniqueToSecond.count) unique to second, \(inBoth.count) in both"
        )

        return DirectoryComparisonResult(
            directory1Name: directory1.lastPathComponent,
            directory2Name: directory2.lastPathComponent,
            directory1URL: directory1,
            directory2URL: directory2,
            uniqueToFirst: uniqueToFirst,
            uniqueToSecond: uniqueToSecond,
            inBoth: inBoth
        )
    }

    // MARK: - Private Helpers

    /// Lists the contents of a directory, wrapping errors in `DirectoryComparisonError`.
    private func listContents(
        of directory: URL,
        using fileSystemService: FileSystemServiceProtocol
    ) throws -> [FileItem] {
        do {
            return try fileSystemService.contentsOfDirectory(at: directory, showHidden: true)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain
            && error.code == NSFileReadNoPermissionError {
            Self.logger.error("Access denied for directory: \(directory.path)")
            throw DirectoryComparisonError.accessDenied(name: directory.lastPathComponent)
        } catch {
            Self.logger.error(
                "Failed to read directory '\(directory.lastPathComponent)': \(error.localizedDescription)"
            )
            throw DirectoryComparisonError.readFailed(
                name: directory.lastPathComponent,
                underlying: error
            )
        }
    }

    /// Converts a `FileItem` to a `ComparisonItem`.
    private func makeComparisonItem(from item: FileItem) -> ComparisonItem {
        ComparisonItem(
            id: UUID(),
            name: item.name,
            size: item.size,
            modificationDate: item.modificationDate,
            isDirectory: item.isDirectory,
            sourceURL: item.url
        )
    }
}
