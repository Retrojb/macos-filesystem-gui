import Foundation

/// Errors that can occur during bulk rename operations.
enum RenameError: Error, LocalizedError {
    case destinationAlreadyExists(URL)
    case renameFailed(source: URL, destination: URL, underlying: Error)
    case revertFailed(source: URL, destination: URL, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .destinationAlreadyExists(let url):
            return "A file already exists at \(url.lastPathComponent)"
        case .renameFailed(let source, _, let underlying):
            return "Failed to rename \(source.lastPathComponent): \(underlying.localizedDescription)"
        case .revertFailed(let source, _, let underlying):
            return "Failed to revert \(source.lastPathComponent): \(underlying.localizedDescription)"
        }
    }
}

/// Concrete implementation of the bulk rename service.
///
/// Provides rule-based rename preview generation, atomic batch execution,
/// and revert (undo) capabilities using FileManager.
struct RenameService: RenameServiceProtocol {

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - applyRule

    func applyRule(_ rule: RenameRule, to files: [FileItem]) -> [(original: String, result: String)] {
        switch rule {
        case .findReplace(let find, let replace):
            return applyFindReplace(find: find, replace: replace, to: files)
        case .sequentialNumbering(let position, let start, let padding):
            return applySequentialNumbering(position: position, start: start, padding: padding, to: files)
        case .dateInsertion(let position, let dateSource, let format):
            return applyDateInsertion(position: position, dateSource: dateSource, format: format, to: files)
        }
    }

    // MARK: - execute

    func execute(renames: [(source: URL, destination: URL)]) throws {
        // Phase 1: Validate all destinations don't already exist
        for rename in renames {
            if fileManager.fileExists(atPath: rename.destination.path) {
                throw RenameError.destinationAlreadyExists(rename.destination)
            }
        }

        // Phase 2: Execute renames, tracking completed ones for potential rollback
        var completed: [(source: URL, destination: URL)] = []

        for rename in renames {
            do {
                try fileManager.moveItem(at: rename.source, to: rename.destination)
                completed.append(rename)
            } catch {
                // Revert all completed renames in reverse order
                for completedRename in completed.reversed() {
                    try? fileManager.moveItem(at: completedRename.destination, to: completedRename.source)
                }
                throw RenameError.renameFailed(
                    source: rename.source,
                    destination: rename.destination,
                    underlying: error
                )
            }
        }
    }

    // MARK: - revert

    func revert(renames: [(source: URL, destination: URL)]) throws {
        // Restore files from destination back to source in reverse order
        for rename in renames.reversed() {
            do {
                try fileManager.moveItem(at: rename.destination, to: rename.source)
            } catch {
                throw RenameError.revertFailed(
                    source: rename.source,
                    destination: rename.destination,
                    underlying: error
                )
            }
        }
    }

    // MARK: - Private Helpers

    /// Applies find-and-replace to each file's name.
    private func applyFindReplace(
        find: String,
        replace: String,
        to files: [FileItem]
    ) -> [(original: String, result: String)] {
        return files.map { file in
            let original = file.name
            let result = original.replacingOccurrences(of: find, with: replace)
            return (original: original, result: result)
        }
    }

    /// Applies sequential numbering to each file's name.
    /// For prepend: "001_filename.ext"
    /// For append: "filename001.ext"
    private func applySequentialNumbering(
        position: RenameRule.Position,
        start: Int,
        padding: Int,
        to files: [FileItem]
    ) -> [(original: String, result: String)] {
        return files.enumerated().map { index, file in
            let original = file.name
            let number = start + index
            let paddedNumber = String(format: "%0\(padding)d", number)

            let nameWithoutExtension = (original as NSString).deletingPathExtension
            let ext = (original as NSString).pathExtension

            let result: String
            switch position {
            case .prepend:
                if ext.isEmpty {
                    result = "\(paddedNumber)\(nameWithoutExtension)"
                } else {
                    result = "\(paddedNumber)\(nameWithoutExtension).\(ext)"
                }
            case .append:
                if ext.isEmpty {
                    result = "\(nameWithoutExtension)\(paddedNumber)"
                } else {
                    result = "\(nameWithoutExtension)\(paddedNumber).\(ext)"
                }
            }

            return (original: original, result: result)
        }
    }

    /// Applies date insertion to each file's name using the specified date source and format.
    /// For prepend: "2024-01-15_filename.ext"
    /// For append: "filename2024-01-15.ext"
    private func applyDateInsertion(
        position: RenameRule.Position,
        dateSource: RenameRule.DateSource,
        format: String,
        to files: [FileItem]
    ) -> [(original: String, result: String)] {
        let formatter = DateFormatter()
        formatter.dateFormat = format

        return files.map { file in
            let original = file.name
            let date: Date
            switch dateSource {
            case .creation:
                date = file.creationDate
            case .modification:
                date = file.modificationDate
            }

            let dateString = formatter.string(from: date)
            let nameWithoutExtension = (original as NSString).deletingPathExtension
            let ext = (original as NSString).pathExtension

            let result: String
            switch position {
            case .prepend:
                if ext.isEmpty {
                    result = "\(dateString)\(nameWithoutExtension)"
                } else {
                    result = "\(dateString)\(nameWithoutExtension).\(ext)"
                }
            case .append:
                if ext.isEmpty {
                    result = "\(nameWithoutExtension)\(dateString)"
                } else {
                    result = "\(nameWithoutExtension)\(dateString).\(ext)"
                }
            }

            return (original: original, result: result)
        }
    }
}
