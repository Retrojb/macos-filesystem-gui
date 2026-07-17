import AppKit
import AVFoundation

/// Generates thumbnail images from video files using `AVAssetImageGenerator`.
///
/// The generator extracts the first frame of the video and returns it as an `NSImage`.
/// A 5-second timeout is enforced to prevent indefinite resource consumption.
struct ThumbnailGenerator: ThumbnailGenerating {
    /// Generates a thumbnail from the first frame of a video file.
    ///
    /// Uses `AVAssetImageGenerator` to extract the image at time `.zero`.
    /// If generation takes longer than 5 seconds, a `ThumbnailError.timeout` is thrown.
    ///
    /// - Parameter url: The file URL of the video to generate a thumbnail for.
    /// - Returns: An `NSImage` representing the first frame of the video.
    /// - Throws: `ThumbnailError.timeout` if generation exceeds 5 seconds.
    /// - Throws: `ThumbnailError.generationFailed` if `AVAssetImageGenerator` fails.
    func generateThumbnail(for url: URL) async throws -> NSImage {
        try await withThrowingTaskGroup(of: NSImage.self) { group in
            group.addTask {
                try await self.extractThumbnail(from: url)
            }

            group.addTask {
                try await Task.sleep(nanoseconds: 5_000_000_000)
                throw ThumbnailError.timeout
            }

            guard let result = try await group.next() else {
                throw ThumbnailError.timeout
            }

            group.cancelAll()
            return result
        }
    }

    /// Extracts a thumbnail image from the first frame of the video at the given URL.
    /// - Parameter url: The file URL of the video.
    /// - Returns: An `NSImage` of the first frame.
    /// - Throws: `ThumbnailError.generationFailed` if image extraction fails.
    private func extractThumbnail(from url: URL) async throws -> NSImage {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        do {
            let (cgImage, _) = try await generator.image(at: .zero)
            let size = NSSize(width: cgImage.width, height: cgImage.height)
            return NSImage(cgImage: cgImage, size: size)
        } catch {
            throw ThumbnailError.generationFailed(underlying: error)
        }
    }
}
