import Foundation

/// Errors that can occur during bulk rename workflow operations.
enum BulkRenameError: Error, LocalizedError {
    case noRuleConfigured
    case validationFailed(String)
    case executionFailed(String)
    case undoUnavailable
    case undoFailed(String)

    var errorDescription: String? {
        switch self {
        case .noRuleConfigured:
            return "No rename rule configured"
        case .validationFailed(let reason):
            return "Validation failed: \(reason)"
        case .executionFailed(let reason):
            return "Rename failed: \(reason)"
        case .undoUnavailable:
            return "No rename operation available to undo"
        case .undoFailed(let reason):
            return "Undo failed: \(reason)"
        }
    }
}

/// Represents a completed bulk rename operation that can be undone.
struct RenameTransaction {
    let renames: [(source: URL, destination: URL)]
    let timestamp: Date
}

/// ViewModel for the bulk rename dialog.
///
/// Manages rename rule application, live preview generation with debouncing,
/// confirmation with validation, and single-level undo support.
@Observable
final class BulkRenameViewModel {

    // MARK: - Public State

    var selectedFiles: [FileItem] = []

    var rule: RenameRule? {
        didSet { schedulePreviewUpdate() }
    }

    private(set) var previews: [(original: String, result: String, hasConflict: Bool)] = []
    private(set) var canConfirm: Bool = false
    var errorMessage: String?

    // MARK: - Private State

    private let renameService: RenameServiceProtocol
    private var lastTransaction: RenameTransaction?
    private var debounceTask: Task<Void, Never>?

    /// Maximum allowed filename length (macOS HFS+/APFS limit).
    private let maxFilenameLength = 255

    // MARK: - Initialization

    init(renameService: RenameServiceProtocol) {
        self.renameService = renameService
    }

    // MARK: - Preview

    /// Schedules a debounced preview update. Cancels any pending update task.
    func schedulePreviewUpdate() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
                self.updatePreview()
            } catch {
                // Task was cancelled — no action needed
            }
        }
    }

    /// Applies the current rule to selectedFiles and updates previews + canConfirm.
    func updatePreview() {
        guard let rule else {
            previews = []
            canConfirm = false
            return
        }

        let results = renameService.applyRule(rule, to: selectedFiles)

        // Detect conflicts: duplicate result names
        var nameCounts: [String: Int] = [:]
        for result in results {
            nameCounts[result.result, default: 0] += 1
        }

        previews = results.map { item in
            let hasConflict = item.result.count > maxFilenameLength
                || (nameCounts[item.result] ?? 0) > 1
            return (original: item.original, result: item.result, hasConflict: hasConflict)
        }

        // canConfirm is false if any result exceeds 255 chars, has conflicts, or results are empty
        let hasAnyConflict = previews.contains(where: { $0.hasConflict })
        canConfirm = !previews.isEmpty && !hasAnyConflict
    }

    // MARK: - Confirm

    /// Executes the bulk rename operation.
    ///
    /// Builds source→destination URL tuples from selectedFiles and previews,
    /// then calls execute on the rename service. On success, stores the transaction for undo.
    func confirm() -> Result<Void, BulkRenameError> {
        guard rule != nil else {
            return .failure(.noRuleConfigured)
        }

        guard canConfirm else {
            return .failure(.validationFailed("One or more filenames are invalid or have conflicts"))
        }

        guard selectedFiles.count == previews.count else {
            return .failure(.validationFailed("Preview count does not match selected files"))
        }

        // Build rename tuples: source URL → destination URL (same parent directory, new name)
        var renames: [(source: URL, destination: URL)] = []
        for (index, file) in selectedFiles.enumerated() {
            let newName = previews[index].result
            let destination = file.url.deletingLastPathComponent().appendingPathComponent(newName)
            renames.append((source: file.url, destination: destination))
        }

        do {
            try renameService.execute(renames: renames)
            // Store the transaction for undo
            lastTransaction = RenameTransaction(renames: renames, timestamp: Date())
            errorMessage = nil
            return .success(())
        } catch {
            errorMessage = error.localizedDescription
            return .failure(.executionFailed(error.localizedDescription))
        }
    }

    // MARK: - Undo

    /// Reverts the most recent bulk rename operation.
    ///
    /// Only the last successful batch can be undone. After a successful undo,
    /// the transaction is cleared and cannot be undone again.
    func undo() -> Result<Void, BulkRenameError> {
        guard let transaction = lastTransaction else {
            return .failure(.undoUnavailable)
        }

        do {
            try renameService.revert(renames: transaction.renames)
            lastTransaction = nil
            errorMessage = nil
            return .success(())
        } catch {
            errorMessage = error.localizedDescription
            return .failure(.undoFailed(error.localizedDescription))
        }
    }

    /// Whether an undo operation is available.
    var canUndo: Bool {
        lastTransaction != nil
    }
}
