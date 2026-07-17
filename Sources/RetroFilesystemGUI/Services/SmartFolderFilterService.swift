import Foundation

/// Provides filtering logic for Smart Folders.
///
/// Given a set of `FileItem`s, a `SmartFolderCriteria`, and the current tag
/// associations, returns only those items matching ALL specified criteria
/// using AND semantics.
struct SmartFolderFilterService {

    /// Filters file items against smart folder criteria using AND logic.
    ///
    /// A `FileItem` is included in the result if and only if ALL of the
    /// following conditions hold:
    /// - If `criteria.requiredTagIds` is non-empty, the item must have ALL
    ///   required tags (based on tag associations matching `item.url.path`).
    /// - If `criteria.fileType` is non-nil, the item's `kind` must equal
    ///   the specified file type string.
    /// - If `criteria.dateRangeStart` is non-nil, the item's
    ///   `modificationDate` must be >= `dateRangeStart`.
    /// - If `criteria.dateRangeEnd` is non-nil, the item's
    ///   `modificationDate` must be <= `dateRangeEnd`.
    ///
    /// Criteria fields that are nil or empty are not applied (considered satisfied).
    ///
    /// - Parameters:
    ///   - items: The file items to filter.
    ///   - criteria: The smart folder criteria to match against.
    ///   - tagAssociations: The current set of tag-to-file associations.
    /// - Returns: The subset of items satisfying all specified criteria.
    static func filterItems(
        _ items: [FileItem],
        criteria: SmartFolderCriteria,
        tagAssociations: [TagAssociation]
    ) -> [FileItem] {
        items.filter { item in
            matchesTags(item, requiredTagIds: criteria.requiredTagIds, tagAssociations: tagAssociations)
                && matchesFileType(item, fileType: criteria.fileType)
                && matchesDateRange(item, start: criteria.dateRangeStart, end: criteria.dateRangeEnd)
        }
    }

    // MARK: - Private Helpers

    /// Returns true if the item has ALL required tags, or if requiredTagIds is empty.
    private static func matchesTags(
        _ item: FileItem,
        requiredTagIds: [UUID],
        tagAssociations: [TagAssociation]
    ) -> Bool {
        guard !requiredTagIds.isEmpty else { return true }

        let itemPath = item.url.path
        let itemTagIds = Set(
            tagAssociations
                .filter { $0.filePath == itemPath }
                .map { $0.tagId }
        )

        return requiredTagIds.allSatisfy { itemTagIds.contains($0) }
    }

    /// Returns true if the item's kind matches the specified file type, or if fileType is nil.
    private static func matchesFileType(_ item: FileItem, fileType: String?) -> Bool {
        guard let fileType = fileType else { return true }
        return item.kind == fileType
    }

    /// Returns true if the item's modification date falls within the specified range.
    /// Either bound may be nil (unbounded on that side).
    private static func matchesDateRange(_ item: FileItem, start: Date?, end: Date?) -> Bool {
        if let start = start, item.modificationDate < start {
            return false
        }
        if let end = end, item.modificationDate > end {
            return false
        }
        return true
    }
}
