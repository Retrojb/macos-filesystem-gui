import Foundation

/// Filters file paths from a TagStore based on selected tag IDs.
///
/// - Parameters:
///   - store: The TagStore containing tags and associations.
///   - selectedTagIds: The set of tag IDs to filter by.
/// - Returns: An array of unique file paths whose associated tags are a superset of the selected tag IDs.
///            If `selectedTagIds` is empty, returns all unique file paths that have any association.
func filterFilesByTags(store: TagStore, selectedTagIds: Set<UUID>) -> [String] {
    if selectedTagIds.isEmpty {
        // Return all unique file paths that have any association
        let uniquePaths = Set(store.associations.map(\.filePath))
        return Array(uniquePaths)
    }

    // Group associations by file path to get each file's set of tag IDs
    var tagsByFile: [String: Set<UUID>] = [:]
    for association in store.associations {
        tagsByFile[association.filePath, default: []].insert(association.tagId)
    }

    // Return file paths where the file's tag set is a superset of selectedTagIds
    return tagsByFile.compactMap { filePath, tagIds in
        tagIds.isSuperset(of: selectedTagIds) ? filePath : nil
    }
}
