import Foundation
import Darwin

/// Evaluates which files in a directory are unsorted based on sorting rules.
///
/// A file is considered "sorted" if it matches at least one sorting rule.
/// A file is "unsorted" if it matches none of the rules.
/// If no rules exist, all files are considered sorted.
enum UnsortedFileEvaluator {

    /// Returns the subset of files that are unsorted (match no sorting rule).
    ///
    /// - Parameters:
    ///   - files: The list of file items to evaluate.
    ///   - rules: The sorting rules defined for the directory.
    ///   - tagStorageService: Service for loading tag associations.
    /// - Returns: An array of `FileItem` that match none of the provided rules.
    ///            Returns an empty array if rules is empty (all files considered sorted).
    static func unsortedFiles(
        from files: [FileItem],
        rules: [SortingRule],
        tagStorageService: TagStorageServiceProtocol
    ) -> [FileItem] {
        // If no rules exist, all files are considered sorted
        guard !rules.isEmpty else {
            return []
        }

        // Only evaluate non-directory items
        let nonDirectoryFiles = files.filter { !$0.isDirectory }

        // Lazy-load tag associations only if there are tag rules
        let tagRules = rules.filter { $0.ruleType == .tag }
        let tagStore: TagStore? = tagRules.isEmpty ? nil : (try? tagStorageService.load())

        return nonDirectoryFiles.filter { file in
            !matchesAnyRule(file: file, rules: rules, tagStore: tagStore)
        }
    }

    // MARK: - Private

    /// Checks whether a file matches at least one sorting rule.
    private static func matchesAnyRule(
        file: FileItem,
        rules: [SortingRule],
        tagStore: TagStore?
    ) -> Bool {
        for rule in rules {
            switch rule.ruleType {
            case .fileExtension:
                if matchesExtension(file: file, pattern: rule.pattern) {
                    return true
                }
            case .namePattern:
                if matchesNamePattern(file: file, pattern: rule.pattern) {
                    return true
                }
            case .tag:
                if matchesTag(file: file, tagIdString: rule.pattern, tagStore: tagStore) {
                    return true
                }
            }
        }
        return false
    }

    /// Extension matching: compares file extension case-insensitively (without dot).
    private static func matchesExtension(file: FileItem, pattern: String) -> Bool {
        let fileExtension = file.url.pathExtension
        return fileExtension.caseInsensitiveCompare(pattern) == .orderedSame
    }

    /// Name pattern matching: glob matching via `fnmatch`.
    private static func matchesNamePattern(file: FileItem, pattern: String) -> Bool {
        return fnmatch(pattern, file.name, 0) == 0
    }

    /// Tag matching: checks if the file has an association with the specified tag ID.
    private static func matchesTag(
        file: FileItem,
        tagIdString: String,
        tagStore: TagStore?
    ) -> Bool {
        guard let tagStore = tagStore,
              let tagId = UUID(uuidString: tagIdString) else {
            return false
        }

        let filePath = file.url.path
        return tagStore.associations.contains { association in
            association.filePath == filePath && association.tagId == tagId
        }
    }
}
