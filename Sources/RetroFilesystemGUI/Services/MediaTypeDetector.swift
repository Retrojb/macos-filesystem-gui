import Foundation
import UniformTypeIdentifiers

/// Classifies files by their Uniform Type Identifier conformance to determine
/// whether they are supported photo, video, or unsupported media types.
struct MediaTypeDetector: MediaTypeDetecting {

    /// Supported image UTTypes for photo classification.
    static let supportedImageTypes: Set<UTType> = [
        .jpeg,
        .png,
        .heic,
        .tiff,
        .gif,
        .webP
    ]

    /// Supported video UTTypes for video classification.
    static let supportedVideoTypes: Set<UTType> = [
        .mpeg4Movie,
        .quickTimeMovie,
        .avi,
        UTType("public.webm") ?? .data
    ]

    /// Classifies the file at the given URL as a photo, video, or unsupported type.
    ///
    /// Classification is based solely on the URL's path extension and the UTI conformance
    /// hierarchy. No filesystem access is performed.
    ///
    /// - Parameter url: The URL of the file to classify.
    /// - Returns: The `MediaType` classification for the file.
    func classifyFile(at url: URL) -> MediaType {
        let pathExtension = url.pathExtension
        guard !pathExtension.isEmpty,
              let utType = UTType(filenameExtension: pathExtension) else {
            return .unsupported
        }

        for imageType in Self.supportedImageTypes {
            if utType.conforms(to: imageType) {
                return .photo
            }
        }

        for videoType in Self.supportedVideoTypes {
            if utType.conforms(to: videoType) {
                return .video
            }
        }

        return .unsupported
    }
}
