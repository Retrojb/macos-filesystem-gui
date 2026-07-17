import AppKit

/// Errors that can occur during thumbnail generation.
enum ThumbnailError: Error {
    /// The thumbnail generation exceeded the allowed time limit.
    case timeout
    /// The underlying `AVAssetImageGenerator` failed to produce an image.
    case generationFailed(underlying: Error)
}

/// Protocol for generating thumbnail images from video files.
///
/// Conforming types produce a static preview image (typically from the first frame)
/// for a given video URL.
protocol ThumbnailGenerating {
    /// Generates a thumbnail image for the video at the given URL.
    /// - Parameter url: The file URL of the video to generate a thumbnail for.
    /// - Returns: An `NSImage` representing the video's thumbnail.
    /// - Throws: `ThumbnailError.timeout` if generation exceeds 5 seconds.
    /// - Throws: `ThumbnailError.generationFailed` if the image generator fails.
    func generateThumbnail(for url: URL) async throws -> NSImage
}
