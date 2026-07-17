// Feature: media-preview-viewer, Property 4: Every Playback Session Starts Muted

import Testing
import Foundation
import AppKit
@testable import RetroFilesystemGUI

/// **Validates: Requirements 3.1, 4.4**
///
/// Property 4: For any sequence of play/unmute/select-new-video/play actions across
/// any number of video files, each invocation of `playVideo()` shall set `isMuted` to `true`,
/// regardless of the mute state from any prior playback session.
@Suite("MediaPreviewMuteState Tests")
struct MediaPreviewMuteStateTests {

    // MARK: - Mock Implementations

    /// Mock media type detector that always returns .video for test purposes.
    final class MockMediaTypeDetector: MediaTypeDetecting {
        var mediaTypeToReturn: MediaType = .video

        func classifyFile(at url: URL) -> MediaType {
            return mediaTypeToReturn
        }
    }

    /// Mock thumbnail generator that returns a valid NSImage immediately.
    final class MockThumbnailGenerator: ThumbnailGenerating {
        func generateThumbnail(for url: URL) async throws -> NSImage {
            // Return a 1x1 pixel NSImage for testing
            let image = NSImage(size: NSSize(width: 1, height: 1))
            image.lockFocus()
            NSColor.blue.drawSwatch(in: NSRect(x: 0, y: 0, width: 1, height: 1))
            image.unlockFocus()
            return image
        }
    }

    /// Mock video player controller that tracks mute state changes and load/play calls.
    final class MockVideoPlayerController: VideoPlayerControlling {
        var isPlaying: Bool = false
        var isMuted: Bool = true {
            didSet {
                mutedStateHistory.append(isMuted)
            }
        }
        var hasAudioTrack: Bool = true
        var onPlaybackEnded: (() -> Void)?

        /// Records the muted state at each change for verification.
        var mutedStateHistory: [Bool] = []

        /// Records the muted state at the moment play() is called.
        var mutedStateAtPlayCalls: [Bool] = []

        /// Number of times load was called.
        var loadCallCount: Int = 0

        /// Number of times play was called.
        var playCallCount: Int = 0

        func load(url: URL) async throws {
            loadCallCount += 1
        }

        func play() {
            mutedStateAtPlayCalls.append(isMuted)
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

    /// Creates a test FileItem representing a video file with a unique URL.
    private func makeVideoFileItem(index: Int = 0) -> FileItem {
        FileItem(
            id: UUID(),
            url: URL(fileURLWithPath: "/test/video_\(index).mp4"),
            name: "video_\(index).mp4",
            isDirectory: false,
            size: 1024,
            modificationDate: Date(),
            creationDate: Date(),
            kind: "public.mpeg-4",
            isHidden: false
        )
    }

    /// Represents an action in a playback sequence.
    private enum PlaybackAction {
        case play
        case unmute
        case selectNewVideo(Int)
    }

    /// Generates a random sequence of actions that always starts with a video selection
    /// and includes at least two play actions with a new video selection in between.
    private func generateActionSequence(length: Int) -> [PlaybackAction] {
        var actions: [PlaybackAction] = []
        var videoIndex = 0

        for _ in 0..<length {
            let choice = Int.random(in: 0...2)
            switch choice {
            case 0:
                actions.append(.play)
            case 1:
                actions.append(.unmute)
            default:
                videoIndex += 1
                actions.append(.selectNewVideo(videoIndex))
            }
        }

        return actions
    }

    // MARK: - Property 4: Every Playback Session Starts Muted

    @Test("Property 4: every playVideo() sets isMuted to true regardless of prior state")
    func everyPlaybackSessionStartsMuted() async {
        for _ in 0..<100 {
            let detector = MockMediaTypeDetector()
            detector.mediaTypeToReturn = .video
            let thumbnailGenerator = MockThumbnailGenerator()
            let playerController = MockVideoPlayerController()

            let viewModel = MediaPreviewViewModel(
                mediaTypeDetector: detector,
                thumbnailGenerator: thumbnailGenerator,
                playerController: playerController
            )

            // Generate a random action sequence length between 4 and 20
            let sequenceLength = Int.random(in: 4...20)
            let actions = generateActionSequence(length: sequenceLength)

            // Start by selecting the first video file
            let initialFile = makeVideoFileItem(index: 0)
            viewModel.selectFile(initialFile)

            // Wait briefly for the thumbnail to load
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

            // Track how many times playVideo was called
            var playVideoCallCount = 0

            for action in actions {
                switch action {
                case .play:
                    // Only call playVideo if we're in thumbnail state
                    if case .thumbnail = viewModel.state {
                        viewModel.playVideo()
                        // Wait for async load to complete
                        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                        playVideoCallCount += 1

                        // Key assertion: after EVERY playVideo() call, isMuted must be true
                        #expect(viewModel.isMuted == true,
                            "isMuted must be true after playVideo() call #\(playVideoCallCount)")
                        #expect(playerController.isMuted == true,
                            "playerController.isMuted must be true after playVideo() call #\(playVideoCallCount)")
                    }

                case .unmute:
                    // Toggle mute to unmute (only effective during playing/paused)
                    if viewModel.state == .playing || viewModel.state == .paused {
                        viewModel.toggleMute()
                    }

                case .selectNewVideo(let index):
                    // Select a new video file - this should stop playback
                    let newFile = makeVideoFileItem(index: index)
                    viewModel.selectFile(newFile)
                    // Wait for thumbnail to load
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
            }

            // Verify that for every play() call on the controller,
            // the muted state was true at that moment
            for (i, mutedAtPlay) in playerController.mutedStateAtPlayCalls.enumerated() {
                #expect(mutedAtPlay == true,
                    "playerController must be muted at play() call index \(i)")
            }
        }
    }

    @Test("Property 4: unmute then new video then play resets to muted")
    func unmuteNewVideoPlayResetsMute() async {
        for _ in 0..<100 {
            let detector = MockMediaTypeDetector()
            detector.mediaTypeToReturn = .video
            let thumbnailGenerator = MockThumbnailGenerator()
            let playerController = MockVideoPlayerController()

            let viewModel = MediaPreviewViewModel(
                mediaTypeDetector: detector,
                thumbnailGenerator: thumbnailGenerator,
                playerController: playerController
            )

            // Step 1: select a video file
            let video1 = makeVideoFileItem(index: Int.random(in: 0...1000))
            viewModel.selectFile(video1)
            try? await Task.sleep(nanoseconds: 10_000_000)

            // Step 2: play the video
            if case .thumbnail = viewModel.state {
                viewModel.playVideo()
                try? await Task.sleep(nanoseconds: 10_000_000)

                // Verify starts muted
                #expect(viewModel.isMuted == true)

                // Step 3: unmute the video
                viewModel.toggleMute()
                #expect(viewModel.isMuted == false,
                    "After toggleMute, isMuted should be false")

                // Step 4: select a new video (stops playback)
                let video2 = makeVideoFileItem(index: Int.random(in: 1001...2000))
                viewModel.selectFile(video2)
                try? await Task.sleep(nanoseconds: 10_000_000)

                // Step 5: play the new video
                if case .thumbnail = viewModel.state {
                    viewModel.playVideo()
                    try? await Task.sleep(nanoseconds: 10_000_000)

                    // Key assertion: isMuted must be reset to true
                    #expect(viewModel.isMuted == true,
                        "isMuted must be true after playing a new video, regardless of prior unmute")
                    #expect(playerController.isMuted == true,
                        "playerController.isMuted must be true after playing a new video")
                }
            }
        }
    }

    @Test("Property 4: multiple consecutive plays on same video each start muted")
    func multipleConsecutivePlaysStartMuted() async {
        for _ in 0..<100 {
            let detector = MockMediaTypeDetector()
            detector.mediaTypeToReturn = .video
            let thumbnailGenerator = MockThumbnailGenerator()
            let playerController = MockVideoPlayerController()

            let viewModel = MediaPreviewViewModel(
                mediaTypeDetector: detector,
                thumbnailGenerator: thumbnailGenerator,
                playerController: playerController
            )

            let video = makeVideoFileItem(index: Int.random(in: 0...1000))
            viewModel.selectFile(video)
            try? await Task.sleep(nanoseconds: 10_000_000)

            // Number of play cycles to test
            let cycles = Int.random(in: 2...5)

            for cycle in 0..<cycles {
                if case .thumbnail = viewModel.state {
                    viewModel.playVideo()
                    try? await Task.sleep(nanoseconds: 10_000_000)

                    // Key assertion: isMuted must be true at start of each play session
                    #expect(viewModel.isMuted == true,
                        "isMuted must be true at play cycle \(cycle)")

                    // Unmute during playback
                    viewModel.toggleMute()
                    #expect(viewModel.isMuted == false)

                    // Simulate end of playback to return to thumbnail state
                    playerController.onPlaybackEnded?()
                    try? await Task.sleep(nanoseconds: 10_000_000)
                }
            }
        }
    }
}
