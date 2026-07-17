import AppKit
import Foundation

/// ViewModel managing the media preview lifecycle and coordinating sub-components.
///
/// Observes file selection and determines whether to display a photo, video thumbnail,
/// or empty state. Manages async loading, cancellation, and resource cleanup.
@Observable
class MediaPreviewViewModel {

    // MARK: - Preview State

    /// Represents the current state of the media preview panel.
    enum PreviewState: Equatable {
        case empty
        case loadingPhoto
        case photo(NSImage)
        case loadingThumbnail
        case thumbnail(NSImage)
        case playing
        case paused
        case error(String)
    }

    // MARK: - Published State

    /// The current preview state displayed by the view.
    private(set) var state: PreviewState = .empty

    /// Whether audio output is currently muted during video playback.
    private(set) var isMuted: Bool = true

    // MARK: - Dependencies

    private let mediaTypeDetector: MediaTypeDetecting
    private let thumbnailGenerator: ThumbnailGenerating
    private let playerController: VideoPlayerControlling

    // MARK: - Internal State

    /// The URL of the currently selected file, used for playback loading.
    private(set) var currentFileURL: URL?

    /// The most recently generated thumbnail for the current video file.
    private(set) var currentThumbnail: NSImage?

    /// The in-progress async load task, cancelled when a new file is selected.
    private var loadTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates a new MediaPreviewViewModel.
    ///
    /// - Parameters:
    ///   - mediaTypeDetector: Service for classifying files by UTI conformance.
    ///   - thumbnailGenerator: Service for generating video thumbnails.
    ///   - playerController: Service for managing video playback.
    init(
        mediaTypeDetector: MediaTypeDetecting,
        thumbnailGenerator: ThumbnailGenerating,
        playerController: VideoPlayerControlling
    ) {
        self.mediaTypeDetector = mediaTypeDetector
        self.thumbnailGenerator = thumbnailGenerator
        self.playerController = playerController
    }

    // MARK: - Actions

    /// Selects a file for preview, determining the appropriate display based on media type.
    ///
    /// Cancels any in-progress loading tasks and stops active playback before
    /// transitioning to the new file's preview state.
    ///
    /// - Parameter fileItem: The file to preview, or nil to clear the preview.
    func selectFile(_ fileItem: FileItem?) {
        // Cancel any in-progress async work
        loadTask?.cancel()
        loadTask = nil

        // Stop playback if active
        if playerController.isPlaying || state == .playing || state == .paused {
            playerController.stop()
        }

        guard let fileItem = fileItem else {
            currentFileURL = nil
            currentThumbnail = nil
            state = .empty
            return
        }

        let mediaType = mediaTypeDetector.classifyFile(at: fileItem.url)

        switch mediaType {
        case .photo:
            currentFileURL = fileItem.url
            currentThumbnail = nil
            state = .loadingPhoto
            loadTask = Task { [weak self] in
                await self?.loadPhoto(from: fileItem.url)
            }

        case .video:
            currentFileURL = fileItem.url
            currentThumbnail = nil
            state = .loadingThumbnail
            loadTask = Task { [weak self] in
                await self?.loadThumbnail(from: fileItem.url)
            }

        case .unsupported:
            currentFileURL = nil
            currentThumbnail = nil
            state = .empty
        }
    }

    /// Stops playback, cancels any in-progress tasks, and resets to the empty state.
    ///
    /// Call this when the preview panel is being dismissed or the view disappears.
    func stopAndCleanup() {
        loadTask?.cancel()
        loadTask = nil
        playerController.stop()
        currentFileURL = nil
        currentThumbnail = nil
        state = .empty
    }

    /// Begins video playback for the currently selected video file.
    ///
    /// Each new playback session starts muted regardless of prior mute state.
    /// Loads the video URL into the player controller and transitions to `.playing`.
    /// If loading or playback fails, transitions to `.error`.
    func playVideo() {
        guard let url = currentFileURL, case .thumbnail = state else {
            return
        }

        isMuted = true
        playerController.isMuted = true

        // Wire end-of-playback callback before starting playback
        playerController.onPlaybackEnded = { [weak self] in
            self?.handlePlaybackEnded()
        }

        loadTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.playerController.load(url: url)
                guard !Task.isCancelled else { return }
                self.playerController.play()
                self.state = .playing
            } catch {
                guard !Task.isCancelled else { return }
                self.state = .error("Unable to play video")
            }
        }
    }

    /// Pauses active video playback.
    ///
    /// Only takes effect if the current state is `.playing`.
    /// Transitions state to `.paused`.
    func pauseVideo() {
        guard state == .playing else { return }
        playerController.pause()
        state = .paused
    }

    /// Resumes video playback from the paused position.
    ///
    /// Preserves the current mute state — no changes to `isMuted`.
    /// Transitions state from `.paused` back to `.playing`.
    func resumeVideo() {
        guard state == .paused else { return }
        playerController.play()
        state = .playing
    }

    /// Toggles the mute state during video playback.
    ///
    /// Only works during `.playing` or `.paused` states.
    /// If the video has no audio track, this is a no-op (stays muted).
    func toggleMute() {
        guard state == .playing || state == .paused else { return }
        guard playerController.hasAudioTrack else { return }
        isMuted.toggle()
        playerController.isMuted = isMuted
    }

    // MARK: - Private Helpers

    /// Handles end-of-playback by transitioning back to the thumbnail state.
    ///
    /// Uses the stored `currentThumbnail` if available, otherwise falls back
    /// to the generic video icon.
    private func handlePlaybackEnded() {
        playerController.stop()
        let thumbnail = currentThumbnail ?? Self.genericVideoIcon
        state = .thumbnail(thumbnail)
    }

    /// Loads a photo from the given URL asynchronously.
    ///
    /// Transitions to `.photo(image)` on success or `.error` on failure.
    /// Respects task cancellation — if the task is cancelled before completion,
    /// no state transition occurs.
    @MainActor
    private func loadPhoto(from url: URL) async {
        guard !Task.isCancelled else { return }

        if let image = NSImage(contentsOf: url) {
            guard !Task.isCancelled else { return }
            state = .photo(image)
        } else {
            guard !Task.isCancelled else { return }
            state = .error("Unable to load image")
        }
    }

    /// Generates a thumbnail for the video at the given URL asynchronously.
    ///
    /// Transitions to `.thumbnail(image)` on success. On timeout or other errors,
    /// displays a generic video icon.
    @MainActor
    private func loadThumbnail(from url: URL) async {
        guard !Task.isCancelled else { return }

        do {
            let image = try await thumbnailGenerator.generateThumbnail(for: url)
            guard !Task.isCancelled else { return }
            currentThumbnail = image
            state = .thumbnail(image)
        } catch {
            guard !Task.isCancelled else { return }
            // On timeout or generation failure, use a generic video icon
            let genericIcon = Self.genericVideoIcon
            currentThumbnail = genericIcon
            state = .thumbnail(genericIcon)
        }
    }

    /// A generic video file icon used when thumbnail generation fails or times out.
    private static var genericVideoIcon: NSImage {
        NSImage(systemSymbolName: "film", accessibilityDescription: "Video file") ?? NSImage()
    }
}
