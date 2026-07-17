import Foundation

/// Truncates file paths for display in the metadata panel header.
///
/// Rules:
/// - If the path is 80 characters or fewer, it is returned unchanged.
/// - If the path exceeds 80 characters, it is truncated to exactly 80 characters:
///   "…" (U+2026, 1 character) followed by the rightmost 79 characters of the path.
enum PathTruncation {
    static func truncate(path: String) -> String {
        if path.count <= 80 {
            return path
        }
        let suffix = String(path.suffix(79))
        return "\u{2026}" + suffix
    }
}
