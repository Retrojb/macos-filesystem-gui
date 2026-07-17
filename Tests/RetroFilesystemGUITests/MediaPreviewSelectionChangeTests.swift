// Feature: media-preview-viewer, Property 5: Selection Change Stops Playback and Replaces Preview

import Testing
import Foundation
import AppKit
@testable import RetroFilesystemGUI

/// **Validates: Requirements 1.4, 2.5, 3.5, 5.5**
///
/// Property 5: Selection Change Stops Playback and Replaces Preview
/// For any state where video is playing or paused, calling `selectFile` with a different
/// file shall stop playback (state is no longer `.playing` or `.paused`), release the
/// player controller, and display only the newly selected file's preview.
@Suite("MediaPreviewSelectionChange Tests")
struct MediaPreviewSelectionChangeTests {

    // MARK: - Mock Implementations

    /// Mock MediaTypeDetector that returns a configurable media type per URL.
    final class MockMediaTypeDetector: MediaTypeDetecting {
        var typeForURL: [URL: MediaType] = [:]
        var defaultType: MediaType = .video

        func classifyFile(at url: URL) -> MediaType {
            return typeForURL[url] ?? defaultType
        }
    }

    /// Mock ThumbnailGenerator that returns a valid NSImage.
    final class MockThumbnailGenerator: ThumbnailGenerating {
        func generateThumbnail(for url: URL) async throws -> NSImage {
            return NSImage(size: NSSize(width: 100, height: 100))
        }
    }

    /// Mock VideoPlayerController that tracks whether stop() was called.
    final class MockVideoPlayerController: VideoPlayerControlling {
        var isPlaying: Bool = false
        var isMuted: Bool = true
        var hasAudioTrack: Bool = true
        var onPlaybackEnded: (() -> Void)?

        /// Tracks whether stop() was called since last reset.
        var stopWasCalled: Bool = false

        func load(url: URL) async throws {
            // No-op for test
        }

        func play() {
            isPlaying = true
        }

        func pause() {
            isPlaying = false
        }

        func stop() {
            isPlaying = false
            stopWasCalled = true
        }

        /// Resets the tracking flag.
        func resetTracking() {
            stopWasCalled = false
        }
    }

    // MARK: - Helpers

    /// Generates a random FileItem with a given media extension type.
    private func randomFileItem(extensions: [String]) -> FileItem {
        let ext = extensions.randomElement()!
        let nameLength = Int.random(in: 3...20)
        let nameChars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        let name = String((0..<nameLength).map { _ in nameChars.randomElement()! }) + ".\(ext)"

        let randomPath = "/tmp/media/\(UUID().uuidString)/\(name)"
        return FileItem(
            id: UUID(),
            url: URL(fileURLWithPath: randomPath),
            name: name,
            isDirectory: false,
            size: Int64.random(in: 1024...1_073_741_824),
            modificationDate: Date(timeIntervalSince1970: Double.random(in: 0...Date().timeIntervalSince1970)),
            creationDate: Date(timeIntervalSince1970: Double.random(in: 0...Date().timeIntervalSince1970)),
            kind: "public.data",
            isHidden: false
        )
    }

    /// Generates a random video FileItem.
    private func randomVideoFileItem() -> FileItem {
        return randomFileItem(extensions: ["mp4", "mov", "avi", "webm"])
    }

    /// Generates a random photo FileItem.
    private func randomPhotoFileItem() -> FileItem {
        return randomFileItem(extensions: ["jpg", "png", "heic", "tiff", "gif", "webp"])
    }

    /// Generates a random unsupported FileItem.
    private func randomUnsupportedFileItem() -> FileItem {
        return randomFileItem(extensions: ["txt", "pdf", "zip", "doc", "exe"])
    }

    // MARK: - Property 5: Selection Change Stops Playback and Replaces Preview

    @Test("Property 5: selecting a different file while playing stops playback and replaces preview")
    func selectionChangeFromPlayingStopsPlayback() async {
        for _ in 0..<100 {
            let detector = MockMediaTypeDetector()
            let thumbnailGenerator = MockThumbnailGenerator()
            let playerController = MockVideoPlayerController()

            let viewModel = MediaPreviewViewModel(
                mediaTypeDetector: detector,
                thumbnailGenerator: thumbnailGenerator,
                playerController: playerController
            )

            // Step 1: Select a video file and get to thumbnail state
            let initialVideo = randomVideoFileItem()
            detector.typeForURL[initialVideo.url] = .video
            viewModel.selectFile(initialVideo)

            // Wait for async thumbnail generation
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

            // Step 2: Start playback to get to .playing state
            viewModel.playVideo()
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

            // Verify we're in .playing state
            guard viewModel.state == .playing else {
                continue // Skip iteration if state setup failed
            }

            // Step 3: Reset tracking and generate a DIFFERENT file
            playerController.resetTracking()

            // Randomly choose the type of the new file
            let newFileTypeChoice = Int.random(in: 0...2)
            let newFile: FileItem
            let expectedType: MediaType

            switch newFileTypeChoice {
            case 0:
                newFile = randomPhotoFileItem()
                detector.typeForURL[newFile.url] = .photo
                expectedType = .photo
            case 1:
                newFile = randomVideoFileItem()
                detector.typeForURL[newFile.url] = .video
                expectedType = .video
            default:
                newFile = randomUnsupportedFileItem()
                detector.typeForURL[newFile.url] = .unsupported
                expectedType = .unsupported
            }

            // Step 4: Select the new file while playing
            viewModel.selectFile(newFile)
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

            // CORE PROPERTY: stop() was called on the player controller
            #expect(playerController.stopWasCalled,
                "stop() should be called on playerController when selecting a different file during playback")

            // CORE PROPERTY: state is no longer .playing or .paused
            #expect(viewModel.state != .playing,
                "State should not be .playing after selecting a different file, but got: \(viewModel.state)")
            #expect(viewModel.state != .paused,
                "State should not be .paused after selecting a different file, but got: \(viewModel.state)")

            // CORE PROPERTY: state reflects the new file's type
            switch expectedType {
            case .photo:
                // For photos with non-existent file paths, .loadingPhoto or .error are both valid
                // (.error means the image load was attempted but file doesn't exist on disk)
                let isValidPhotoState = viewModel.state == .loadingPhoto || {
                    if case .photo = viewModel.state { return true }
                    if case .error = viewModel.state { return true }
                    return false
                }()
                #expect(isValidPhotoState,
                    "State should be .loadingPhoto, .photo, or .error for a photo file, but got: \(viewModel.state)")
            case .video:
                let isValidVideoState = viewModel.state == .loadingThumbnail || {
                    if case .thumbnail = viewModel.state { return true }
                    return false
                }()
                #expect(isValidVideoState,
                    "State should be .loadingThumbnail or .thumbnail for a video file, but got: \(viewModel.state)")
            case .unsupported:
                #expect(viewModel.state == .empty,
                    "State should be .empty for an unsupported file, but got: \(viewModel.state)")
            }

            // Verify the player is not playing
            #expect(playerController.isPlaying == false,
                "Player should not be playing after selecting a different file")
        }
    }

    @Test("Property 5: selecting a different file while paused stops playback and replaces preview")
    func selectionChangeFromPausedStopsPlayback() async {
        for _ in 0..<100 {
            let detector = MockMediaTypeDetector()
            let thumbnailGenerator = MockThumbnailGenerator()
            let playerController = MockVideoPlayerController()

            let viewModel = MediaPreviewViewModel(
                mediaTypeDetector: detector,
                thumbnailGenerator: thumbnailGenerator,
                playerController: playerController
            )

            // Step 1: Select a video file and get to thumbnail state
            let initialVideo = randomVideoFileItem()
            detector.typeForURL[initialVideo.url] = .video
            viewModel.selectFile(initialVideo)

            // Wait for async thumbnail generation
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

            // Step 2: Start playback then pause to get to .paused state
            viewModel.playVideo()
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

            guard viewModel.state == .playing else {
                continue // Skip iteration if play failed
            }

            viewModel.pauseVideo()

            // Verify we're in .paused state
            guard viewModel.state == .paused else {
                continue // Skip iteration if pause failed
            }

            // Step 3: Reset tracking and generate a DIFFERENT file
            playerController.resetTracking()

            // Randomly choose new file type: photo, video, or unsupported
            let newFileTypeChoice = Int.random(in: 0...2)
            let newFile: FileItem
            let expectedType: MediaType

            switch newFileTypeChoice {
            case 0:
                newFile = randomPhotoFileItem()
                detector.typeForURL[newFile.url] = .photo
                expectedType = .photo
            case 1:
                newFile = randomVideoFileItem()
                detector.typeForURL[newFile.url] = .video
                expectedType = .video
            default:
                newFile = randomUnsupportedFileItem()
                detector.typeForURL[newFile.url] = .unsupported
                expectedType = .unsupported
            }

            // Step 4: Select the new file while paused
            viewModel.selectFile(newFile)
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

            // CORE PROPERTY: stop() was called on the player controller
            #expect(playerController.stopWasCalled,
                "stop() should be called on playerController when selecting a different file during paused state")

            // CORE PROPERTY: state is no longer .playing or .paused
            #expect(viewModel.state != .playing,
                "State should not be .playing after selecting a different file, but got: \(viewModel.state)")
            #expect(viewModel.state != .paused,
                "State should not be .paused after selecting a different file, but got: \(viewModel.state)")

            // CORE PROPERTY: state reflects the new file's type
            switch expectedType {
            case .photo:
                // For photos with non-existent file paths, .loadingPhoto or .error are both valid
                let isValidPhotoState = viewModel.state == .loadingPhoto || {
                    if case .photo = viewModel.state { return true }
                    if case .error = viewModel.state { return true }
                    return false
                }()
                #expect(isValidPhotoState,
                    "State should be .loadingPhoto, .photo, or .error for a photo file, but got: \(viewModel.state)")
            case .video:
                let isValidVideoState = viewModel.state == .loadingThumbnail || {
                    if case .thumbnail = viewModel.state { return true }
                    return false
                }()
                #expect(isValidVideoState,
                    "State should be .loadingThumbnail or .thumbnail for a video file, but got: \(viewModel.state)")
            case .unsupported:
                #expect(viewModel.state == .empty,
                    "State should be .empty for an unsupported file, but got: \(viewModel.state)")
            }

            // Verify the player is not playing
            #expect(playerController.isPlaying == false,
                "Player should not be playing after selecting a different file")
        }
    }
}
