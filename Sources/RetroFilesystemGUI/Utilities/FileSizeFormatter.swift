import Foundation

/// Formats a file size in bytes to a human-readable string using binary units.
///
/// The function selects the appropriate unit (bytes, KB, MB, GB) such that
/// the numeric value is in the range [0, 1024) for its unit.
///
/// - Parameter bytes: A non-negative `Int64` value representing file size in bytes.
/// - Returns: A human-readable string representation (e.g., "0 bytes", "512 bytes", "1.5 KB", "2.3 MB", "1.0 GB").
func formatFileSize(_ bytes: Int64) -> String {
    guard bytes >= 0 else {
        return "0 bytes"
    }

    if bytes == 0 {
        return "0 bytes"
    }

    // Units in ascending order of magnitude
    let units = ["bytes", "KB", "MB", "GB"]
    let divisor: Double = 1024.0

    var value = Double(bytes)
    var unitIndex = 0

    while value >= divisor && unitIndex < units.count - 1 {
        value /= divisor
        unitIndex += 1
    }

    let unit = units[unitIndex]

    if unit == "bytes" {
        // No decimal places for bytes
        return "\(Int(value)) \(unit)"
    } else {
        // One decimal place for KB, MB, GB
        let formatted = String(format: "%.1f", value)
        return "\(formatted) \(unit)"
    }
}
