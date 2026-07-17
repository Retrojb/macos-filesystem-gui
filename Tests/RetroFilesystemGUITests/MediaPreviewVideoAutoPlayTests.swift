// Feature: media-preview-viewer, Property 3: Video Never Auto-Plays

import Testing
import Foundation
import AppKit
@testable import RetroFilesystemGUI

/// **Validates: Requirements 2.2**
///
/// Property 3: Video Never Auto-Plays
/// For any video file selection event, the preview state shall transition to `.thumbnail`
/// or `.loadingThumbnail` and shall NOT transition to `.playing` without an explicit
/// user `playVideo()` call.
@Suite("MediaPreviewVideoAutoPlay Tests")
struct MediaPreviewVideoAutoPlayTests {

    // MARK: - Mock Implementations

    /// Mock MediaTypeDetector that always returns .video for this test.
    final class MockVideoDetector: MediaTypeDetecting {
        func classifyFile(at url: URL) -> MediaType {
            return .video
        }
    }

    /// Mock ThumbnailGenerator that returns a valid NSImage.
    final class MockThumbnailGenerator: ThumbnailGenerating {
        func generateThumbnail(for url: URL) async throws -> NSImage {
            // Return a small valid image
            return NSImage(size: NSSize(width: 100, height: 100))
        }
    }

    /// Mock VideoPlayerController that tracks state properly.
    final class MockVideoPlayerController: VideoPlayerControlling {
        var isPlaying: Bool = false
        var isMuted: Bool = true
        var hasAudioTrack: Bool = true
        var onPlaybackEnded: (() -> Void)?

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
        }
    }

    // MARK: - Helpers

    /// Generates a random video FileItem with randomized properties.
    private func randomVideoFileItem() -> FileItem {
        let videoExtensions = ["mp4", "mov", "avi", "webm"]
        let ext = videoExtensions.randomElement()!
        let nameLength = Int.random(in: 3...30)
        let nameChars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        let name = String((0..<nameLength).map { _ in nameChars.randomElement()! }) + ".\(ext)"

        let randomPath = "/tmp/videos/\(name)"
        return FileItem(
            id: UUID(),
            url: URL(fileURLWithPath: randomPath),
            name: name,
            isDirectory: false,
            size: Int64.random(in: 1024...1_073_741_824),
            modificationDate: Date(timeIntervalSince1970: Double.random(in: 0...Date().timeIntervalSince1970)),
            creationDate: Date(timeIntervalSince1970: Double.random(in: 0...Date().timeIntervalSince1970)),
            kind: "public.mpeg-4",
            isHidden: Bool.random()
        )
    }

    // MARK: - Property 3: Video Never Auto-Plays

    @Test("Property 3: selecting a video file never auto-transitions to .playing state")
    func videoSelectionNeverAutoPlays() async {
        for _ in 0..<100 {
            let detector = MockVideoDetector()
            let thumbnailGenerator = MockThumbnailGenerator()
            let playerController = MockVideoPlayerController()

            let viewModel = MediaPreviewViewModel(
                mediaTypeDetector: detector,
                thumbnailGenerator: thumbnailGenerator,
                playerController: playerController
            )

            // Generate a random video file and select it
            let videoFile = randomVideoFileItem()
            viewModel.selectFile(videoFile)

            // Allow the async thumbnail loading task to complete
            // We need a small delay for the async task to finish
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

            // After selecting a video file, state should be .loadingThumbnail or .thumbnail
            // It must NEVER be .playing without an explicit playVideo() call
            let state = viewModel.state

            #expect(state != .playing,
                "State should never be .playing after selectFile without explicit playVideo() call, but got: \(state)")

            // Verify state is one of the expected video preview states
            switch state {
            case .loadingThumbnail, .thumbnail:
                break // Expected states after video selection
            default:
                Issue.record("After selecting a video file, state should be .loadingThumbnail or .thumbnail, but got: \(state)")
            }

            // Verify the player controller never started playing
            #expect(playerController.isPlaying == false,
                "Player should not be playing after file selection without playVideo()")
        }
    }

    @Test("Property 3: multiple sequential video selections never auto-play")
    func multipleVideoSelectionsNeverAutoPlay() async {
        let detector = MockVideoDetector()
        let thumbnailGenerator = MockThumbnailGenerator()
        let playerController = MockVideoPlayerController()

        let viewModel = MediaPreviewViewModel(
            mediaTypeDetector: detector,
            thumbnailGenerator: thumbnailGenerator,
            playerController: playerController
        )

        for _ in 0..<100 {
            // Generate a random video file and select it
            let videoFile = randomVideoFileItem()
            viewModel.selectFile(videoFile)

            // Allow the async thumbnail loading task to complete
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

            // After each selection, state must never be .playing
            let state = viewModel.state

            #expect(state != .playing,
                "State should never be .playing after selectFile without explicit playVideo() call")

            // Verify the player controller is not playing
            #expect(playerController.isPlaying == false,
                "Player should not be playing after file selection without playVideo()")
        }
    }
}
