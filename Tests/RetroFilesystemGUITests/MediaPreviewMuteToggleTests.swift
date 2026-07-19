// Feature: media-preview-viewer, Property 6: Mute Toggle Inverts State

import Testing
import Foundation
import AppKit
import AVFoundation
@testable import RetroFilesystemGUI

/// **Validates: Requirements 4.2, 4.3**
///
/// Property 6: Mute Toggle Inverts State
/// For any video in the `.playing` state where the video has an audio track,
/// calling `toggleMute()` shall invert the current `isMuted` value: if `isMuted`
/// was `true`, it becomes `false`, and vice versa.
@Suite("MediaPreviewMuteToggle Tests")
@MainActor
struct MediaPreviewMuteToggleTests {

    // MARK: - Mock Implementations

    /// Mock MediaTypeDetector that always returns .video.
    final class MockVideoDetector: MediaTypeDetecting {
        func classifyFile(at url: URL) -> MediaType {
            return .video
        }
    }

    /// Mock ThumbnailGenerator that returns a valid NSImage.
    final class MockThumbnailGenerator: ThumbnailGenerating {
        func generateThumbnail(for url: URL) async throws -> NSImage {
            return NSImage(size: NSSize(width: 100, height: 100))
        }
    }

    /// Mock VideoPlayerController that tracks mute and play state.
    final class MockVideoPlayerController: VideoPlayerControlling {
        var isPlaying: Bool = false
        var isMuted: Bool = true
        var hasAudioTrack: Bool = true
        var avPlayer: AVPlayer? { nil }
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

    /// Generates a random video FileItem.
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

    /// Sets up a view model in the `.playing` state with the given hasAudioTrack value.
    private func makePlayingViewModel(hasAudioTrack: Bool) async -> (MediaPreviewViewModel, MockVideoPlayerController) {
        let detector = MockVideoDetector()
        let thumbnailGenerator = MockThumbnailGenerator()
        let playerController = MockVideoPlayerController()
        playerController.hasAudioTrack = hasAudioTrack

        let viewModel = MediaPreviewViewModel(
            mediaTypeDetector: detector,
            thumbnailGenerator: thumbnailGenerator,
            playerController: playerController
        )

        // Select a video file to get to .thumbnail state
        let videoFile = randomVideoFileItem()
        viewModel.selectFile(videoFile)

        // Wait for thumbnail loading
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Play the video to get to .playing state
        viewModel.playVideo()

        // Wait for playVideo async task to complete
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        return (viewModel, playerController)
    }

    // MARK: - Property 6: Mute Toggle Inverts State

    @Test("Property 6: toggleMute inverts isMuted for playing video with audio track")
    func toggleMuteInvertsState() async {
        for _ in 0..<100 {
            let (viewModel, _) = await makePlayingViewModel(hasAudioTrack: true)

            // Confirm we are in playing state
            #expect(viewModel.state == .playing,
                "Expected .playing state but got \(viewModel.state)")

            // After playVideo(), isMuted starts as true
            #expect(viewModel.isMuted == true,
                "isMuted should start as true after playVideo()")

            // Generate a random number of toggleMute() calls (1-10)
            let toggleCount = Int.random(in: 1...10)
            var expectedMuted = true

            for _ in 0..<toggleCount {
                let previousMuted = viewModel.isMuted
                viewModel.toggleMute()
                expectedMuted.toggle()

                // Verify isMuted flipped from previous value
                #expect(viewModel.isMuted == !previousMuted,
                    "toggleMute() should invert isMuted: was \(previousMuted), expected \(!previousMuted), got \(viewModel.isMuted)")
                #expect(viewModel.isMuted == expectedMuted,
                    "After \(toggleCount) toggles, isMuted should be \(expectedMuted) but got \(viewModel.isMuted)")
            }
        }
    }

    @Test("Property 6: toggleMute is no-op when hasAudioTrack is false")
    func toggleMuteNoOpWithoutAudioTrack() async {
        for _ in 0..<100 {
            let (viewModel, _) = await makePlayingViewModel(hasAudioTrack: false)

            // Confirm we are in playing state
            #expect(viewModel.state == .playing,
                "Expected .playing state but got \(viewModel.state)")

            // After playVideo(), isMuted starts as true
            #expect(viewModel.isMuted == true,
                "isMuted should start as true after playVideo()")

            // Generate a random number of toggleMute() calls (1-10)
            let toggleCount = Int.random(in: 1...10)

            for _ in 0..<toggleCount {
                viewModel.toggleMute()

                // isMuted should remain true since there's no audio track
                #expect(viewModel.isMuted == true,
                    "toggleMute() should be a no-op when hasAudioTrack is false, but isMuted changed to \(viewModel.isMuted)")
            }
        }
    }
}
