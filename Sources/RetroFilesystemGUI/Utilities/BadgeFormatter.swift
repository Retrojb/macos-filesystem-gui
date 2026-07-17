import Foundation

/// Formats a count value for display in a badge overlay.
///
/// Returns:
/// - `nil` if count is 0 (badge should be hidden)
/// - The string representation of the count for values 1–99
/// - `"99+"` for values exceeding 99
enum BadgeFormatter {
    static func format(count: Int) -> String? {
        guard count > 0 else { return nil }
        if count > 99 {
            return "99+"
        }
        return "\(count)"
    }
}
