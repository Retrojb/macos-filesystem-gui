import Foundation

/// Represents the columns by which FileItems can be sorted.
enum SortColumn: String, Codable, CaseIterable {
    case name
    case dateModified
    case size
    case kind
}

/// Sorts an array of FileItems by the specified column and order.
/// - Parameters:
///   - items: The array of FileItems to sort.
///   - column: The column to sort by.
///   - ascending: Whether to sort in ascending order.
/// - Returns: A new sorted array of FileItems.
func sortFileItems(_ items: [FileItem], by column: SortColumn, ascending: Bool) -> [FileItem] {
    let sorted = items.sorted { lhs, rhs in
        let comparison: ComparisonResult
        switch column {
        case .name:
            comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        case .dateModified:
            comparison = lhs.modificationDate.compare(rhs.modificationDate)
        case .size:
            if lhs.size < rhs.size {
                comparison = .orderedAscending
            } else if lhs.size > rhs.size {
                comparison = .orderedDescending
            } else {
                comparison = .orderedSame
            }
        case .kind:
            comparison = lhs.kind.localizedCaseInsensitiveCompare(rhs.kind)
        }

        return ascending
            ? comparison == .orderedAscending
            : comparison == .orderedDescending
    }
    return sorted
}
