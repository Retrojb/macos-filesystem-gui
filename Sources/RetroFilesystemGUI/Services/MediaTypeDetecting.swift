import Foundation

/// Protocol for classifying files by their media type using UTI conformance.
///
/// Conforming types inspect a file's Uniform Type Identifier to determine whether
/// it is a supported photo, video, or unsupported file type.
protocol MediaTypeDetecting {
    /// Classifies the file at the given URL as a photo, video, or unsupported type.
    /// - Parameter url: The URL of the file to classify.
    /// - Returns: The `MediaType` classification for the file.
    func classifyFile(at url: URL) -> MediaType
}
