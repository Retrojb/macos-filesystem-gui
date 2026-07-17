# Implementation Plan: Media Preview Viewer

## Overview

Implement inline media preview capability for the RetroFilesystemGUI application. The implementation follows the existing MVVM architecture with protocol-based services, adding a `MediaPreviewViewModel`, media type detection, thumbnail generation, video playback control, and SwiftUI views integrated into the existing `ContentView` layout.

## Tasks

- [x] 1. Define core protocols, data models, and media type detection
  - [x] 1.1 Create MediaType enum and MediaTypeDetecting protocol
    - Create `Sources/RetroFilesystemGUI/Models/MediaType.swift` with the `MediaType` enum (`.photo`, `.video`, `.unsupported`)
    - Create `Sources/RetroFilesystemGUI/Services/MediaTypeDetecting.swift` with the `MediaTypeDetecting` protocol
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [x] 1.2 Implement MediaTypeDetector using UTI conformance
    - Create `Sources/RetroFilesystemGUI/Services/MediaTypeDetector.swift`
    - Implement `classifyFile(at:)` using `UTType(filenameExtension:)` and `conforms(to:)` for supported image types (public.jpeg, public.png, public.heic, public.tiff, com.compuserve.gif, public.webp) and video types (public.mpeg-4, com.apple.quicktime-movie, public.avi, public.webm)
    - Return `.unsupported` for files that don't match or can't be accessed
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

  - [ ]* 1.3 Write property test for UTI Classification Correctness
    - **Property 1: UTI Classification Correctness**
    - Generate random UTIs from supported image, video, and unsupported pools; verify the classification forms a complete partition where every file maps to exactly one category
    - **Validates: Requirements 6.2, 6.3, 6.4**

- [x] 2. Implement ThumbnailGenerator and VideoPlayerController services
  - [x] 2.1 Create ThumbnailGenerating protocol and ThumbnailGenerator implementation
    - Create `Sources/RetroFilesystemGUI/Services/ThumbnailGenerating.swift` with the protocol and `ThumbnailError` enum
    - Create `Sources/RetroFilesystemGUI/Services/ThumbnailGenerator.swift` using `AVAssetImageGenerator` to generate thumbnail from first frame
    - Implement 5-second timeout that throws `ThumbnailError.timeout`
    - _Requirements: 2.1, 2.4_

  - [x] 2.2 Create VideoPlayerControlling protocol and VideoPlayerController implementation
    - Create `Sources/RetroFilesystemGUI/Services/VideoPlayerControlling.swift` with the protocol (isPlaying, isMuted, hasAudioTrack, onPlaybackEnded, load/play/pause/stop)
    - Create `Sources/RetroFilesystemGUI/Services/VideoPlayerController.swift` wrapping `AVPlayer`
    - Implement end-of-playback observation via `NSNotification.Name.AVPlayerItemDidPlayToEndTime`
    - Implement audio track detection on load
    - Ensure `stop()` releases AVPlayer and AVPlayerItem resources
    - _Requirements: 3.1, 3.5, 4.5, 5.1, 5.4, 5.5_

- [x] 3. Implement MediaPreviewViewModel with state machine
  - [x] 3.1 Create MediaPreviewViewModel with PreviewState and core logic
    - Create `Sources/RetroFilesystemGUI/ViewModels/MediaPreviewViewModel.swift`
    - Define `PreviewState` enum (empty, loadingPhoto, photo, loadingThumbnail, thumbnail, playing, paused, error)
    - Implement `selectFile(_:)` — classify file, cancel in-progress tasks, stop playback if active, load photo or generate thumbnail
    - Implement `stopAndCleanup()` — stop player, cancel tasks, reset to `.empty`
    - Use dependency injection for `MediaTypeDetecting`, `ThumbnailGenerating`, `VideoPlayerControlling`
    - _Requirements: 1.1, 1.3, 1.4, 2.1, 2.2, 2.4, 2.5, 6.1_

  - [x] 3.2 Implement video playback actions (play, pause, resume, toggleMute)
    - Implement `playVideo()` — set `isMuted = true`, load URL into player, play, transition to `.playing`
    - Implement `pauseVideo()` — pause player, transition to `.paused`
    - Implement `resumeVideo()` — resume from paused position preserving mute state, transition to `.playing`
    - Implement `toggleMute()` — invert `isMuted` only if `hasAudioTrack` is true; no-op otherwise
    - Wire `onPlaybackEnded` to transition back to `.thumbnail` state
    - _Requirements: 3.1, 3.2, 3.4, 4.1, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3, 5.4_

  - [x] 3.3 Write property test for Video Never Auto-Plays
    - **Property 3: Video Never Auto-Plays**
    - Generate random video file selection events; verify preview state transitions to `.thumbnail` or `.loadingThumbnail` and never reaches `.playing` without explicit `playVideo()` call
    - **Validates: Requirements 2.2**

  - [x] 3.4 Write property test for Every Playback Session Starts Muted
    - **Property 4: Every Playback Session Starts Muted**
    - Generate sequences of play/unmute/select-new-video/play actions; verify each `playVideo()` invocation sets `isMuted` to `true`
    - **Validates: Requirements 3.1, 4.4**

  - [x] 3.5 Write property test for Selection Change Stops Playback
    - **Property 5: Selection Change Stops Playback and Replaces Preview**
    - Generate random playing/paused states followed by `selectFile` with a different file; verify playback is stopped and new preview replaces old
    - **Validates: Requirements 1.4, 2.5, 3.5, 5.5**

  - [x] 3.6 Write property test for Mute Toggle Inverts State
    - **Property 6: Mute Toggle Inverts State**
    - Generate random mute values for playing videos with audio tracks; verify `toggleMute()` inverts `isMuted`
    - **Validates: Requirements 4.2, 4.3**

  - [ ]* 3.7 Write property test for Pause and Resume Preserve Mute State
    - **Property 7: Pause and Resume Preserve Mute State**
    - Generate random mute states; pause then resume; verify `isMuted` is unchanged and state transitions through `.paused` back to `.playing`
    - **Validates: Requirements 5.2, 5.3**

  - [ ]* 3.8 Write property test for End of Playback Returns to Thumbnail
    - **Property 8: End of Playback Returns to Thumbnail State**
    - Simulate end-of-playback notification for random video states; verify state transitions to `.thumbnail` with original thumbnail
    - **Validates: Requirements 5.4**

- [~] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Implement image scaling utility
  - [~] 5.1 Create computeScaledSize utility function
    - Create `Sources/RetroFilesystemGUI/Utilities/ImageScaling.swift`
    - Implement `computeScaledSize(imageSize:containerSize:) -> CGSize` that preserves aspect ratio and fits within container bounds
    - Ensure neither output dimension exceeds the corresponding container dimension
    - _Requirements: 1.2, 2.1_

  - [ ]* 5.2 Write property test for Aspect Ratio Preservation
    - **Property 2: Aspect Ratio Preservation**
    - Generate random image dimensions and container dimensions (both > 0); verify output maintains original aspect ratio within floating-point tolerance and fits within container bounds
    - **Validates: Requirements 1.2, 2.1**

- [ ] 6. Implement SwiftUI views
  - [~] 6.1 Create PhotoPreviewView
    - Create `Sources/RetroFilesystemGUI/Views/PhotoPreviewView.swift`
    - Render `NSImage` using `Image(nsImage:)` scaled to fit with `.aspectRatio(contentMode: .fit)`
    - Use `computeScaledSize` for layout calculations
    - _Requirements: 1.1, 1.2_

  - [~] 6.2 Create VideoThumbnailView with play button overlay
    - Create `Sources/RetroFilesystemGUI/Views/VideoThumbnailView.swift`
    - Display thumbnail image scaled to fit with aspect ratio preserved
    - Overlay a centered play button (SF Symbol `play.circle.fill`) on the thumbnail
    - Wire play button tap to `viewModel.playVideo()`
    - _Requirements: 2.1, 2.3, 3.1_

  - [~] 6.3 Create VideoPlaybackView with NSViewRepresentable AVPlayerView
    - Create `Sources/RetroFilesystemGUI/Views/VideoPlaybackView.swift`
    - Wrap `AVPlayerView` using `NSViewRepresentable` for SwiftUI integration
    - Pass the `AVPlayer` from `VideoPlayerController` to the `AVPlayerView`
    - Hide default AVPlayerView controls (use custom overlay instead)
    - _Requirements: 3.2_

  - [~] 6.4 Create PlaybackControlsOverlay
    - Create `Sources/RetroFilesystemGUI/Views/PlaybackControlsOverlay.swift`
    - Implement semi-transparent bar with play/pause toggle button and mute/unmute toggle button
    - Use SF Symbols: `play.fill`/`pause.fill` for playback, `speaker.slash.fill`/`speaker.wave.2.fill` for audio
    - Visually indicate current mute state; disable unmute for videos without audio track
    - _Requirements: 3.3, 4.1, 4.2, 4.3, 5.1, 5.2_

  - [~] 6.5 Create MediaPreviewView container and integrate into ContentView
    - Create `Sources/RetroFilesystemGUI/Views/MediaPreviewView.swift`
    - Switch on `viewModel.state` to render: empty area, loading indicator, `PhotoPreviewView`, `VideoThumbnailView`, `VideoPlaybackView` + `PlaybackControlsOverlay`, or error indicator (SF Symbol `exclamationmark.triangle` with message)
    - Integrate `MediaPreviewView` into existing `ContentView` layout alongside the file browser
    - Instantiate `MediaPreviewViewModel` with concrete service implementations
    - Wire file selection observation from `FileManagerViewModel.selectedItems` to `MediaPreviewViewModel.selectFile(_:)`
    - _Requirements: 1.1, 1.3, 2.2, 2.4, 3.4, 6.4_

- [~] 7. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Integration and resource management
  - [x] 8.1 Implement async task cancellation and resource cleanup
    - Ensure `loadTask` is cancelled when a new file is selected (prevent stale results from appearing)
    - Ensure `AVPlayer` and `AVPlayerItem` are released in `stopAndCleanup()` and when the view disappears
    - Add `.onDisappear` modifier to `MediaPreviewView` to call `stopAndCleanup()`
    - _Requirements: 1.4, 3.5, 5.5_

  - [ ]* 8.2 Write unit tests for error handling and edge cases
    - Test corrupted photo file → `.error` state with appropriate message
    - Test thumbnail timeout → generic video icon displayed
    - Test playback failure → `.error` state, no blank/loading state
    - Test rapid file selection changes → only final selection is displayed
    - Test video with no audio track → unmute is no-op
    - _Requirements: 1.3, 2.4, 3.4, 4.5_

  - [ ]* 8.3 Write integration tests for end-to-end flows
    - Test loading a real JPEG file → verify `NSImage` produced and state is `.photo`
    - Test loading a real MP4 → verify thumbnail generated and state is `.thumbnail`
    - Test play → verify playback starts muted
    - Test resource cleanup → verify AVPlayer is deallocated after `stopAndCleanup()`
    - _Requirements: 1.1, 2.1, 3.1, 5.5_

- [~] 9. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- The implementation uses Swift with SwiftUI, following the project's existing MVVM pattern with `@Observable` view models
- Protocol-based services (`MediaTypeDetecting`, `ThumbnailGenerating`, `VideoPlayerControlling`) enable mock injection for testing

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "5.1"] },
    { "id": 1, "tasks": ["1.2", "2.1", "2.2", "5.2"] },
    { "id": 2, "tasks": ["1.3", "3.1"] },
    { "id": 3, "tasks": ["3.2"] },
    { "id": 4, "tasks": ["3.3", "3.4", "3.5", "3.6", "3.7", "3.8", "6.1", "6.2", "6.3"] },
    { "id": 5, "tasks": ["6.4", "6.5"] },
    { "id": 6, "tasks": ["8.1"] },
    { "id": 7, "tasks": ["8.2", "8.3"] }
  ]
}
```
