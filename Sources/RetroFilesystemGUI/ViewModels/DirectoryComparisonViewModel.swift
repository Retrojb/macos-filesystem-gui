import Foundation

/// ViewModel managing directory comparison state and results.
/// Uses the Observation framework (@Observable) for SwiftUI bindings.
///
/// Requirements: 3.1, 3.5, 3.6, 3.9
@Observable
class DirectoryComparisonViewModel {

    // MARK: - Published State

    /// The result of the most recent directory comparison, or nil if no comparison has been performed.
    var comparisonResult: DirectoryComparisonResult?

    /// Whether a comparison operation is currently in progress.
    var isComparing: Bool = false

    /// A user-facing error message, or nil if no error.
    var errorMessage: String?

    // MARK: - Services

    private let comparatorService: DirectoryComparatorServiceProtocol
    private let fileSystemService: FileSystemServiceProtocol

    // MARK: - Initialization

    /// Creates a new DirectoryComparisonViewModel.
    /// - Parameters:
    ///   - comparatorService: Service for performing directory comparisons.
    ///   - fileSystemService: Service for file system operations and accessibility checks.
    init(
        comparatorService: DirectoryComparatorServiceProtocol,
        fileSystemService: FileSystemServiceProtocol
    ) {
        self.comparatorService = comparatorService
        self.fileSystemService = fileSystemService
    }

    // MARK: - Comparison

    /// Compares two directories and updates the comparison result.
    ///
    /// Validates that both URLs point to accessible directories before performing the comparison.
    /// Sets `isComparing` to true during the operation and populates `errorMessage` on failure.
    ///
    /// - Parameters:
    ///   - directory1: The URL of the first directory to compare.
    ///   - directory2: The URL of the second directory to compare.
    func compare(directory1: URL, directory2: URL) {
        errorMessage = nil
        comparisonResult = nil

        // Validate that both directories exist
        guard fileSystemService.itemExists(at: directory1) else {
            errorMessage = "Directory '\(directory1.lastPathComponent)' no longer exists"
            return
        }

        guard fileSystemService.itemExists(at: directory2) else {
            errorMessage = "Directory '\(directory2.lastPathComponent)' no longer exists"
            return
        }

        isComparing = true

        do {
            let result = try comparatorService.compare(
                directory1: directory1,
                directory2: directory2,
                fileSystemService: fileSystemService
            )
            comparisonResult = result
            errorMessage = nil
        } catch let error as DirectoryComparisonError {
            switch error {
            case .directoryNotFound(let name):
                errorMessage = "Directory '\(name)' no longer exists"
            case .accessDenied(let name):
                errorMessage = "Cannot read directory '\(name)' due to insufficient permissions"
            case .readFailed(let name, _):
                errorMessage = "Failed to read directory '\(name)'"
            }
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }

        isComparing = false
    }
}
