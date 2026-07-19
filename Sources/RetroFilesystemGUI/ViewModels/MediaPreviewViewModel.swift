import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

/// ViewModel managing the media preview lifecycle and coordinating sub-components.
///
/// Observes file selection and determines whether to display a photo, video thumbnail,
/// text content, or empty state. Manages async loading, cancellation, and resource cleanup.
@MainActor
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
        case text(String)
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

    /// The AVPlayer instance for use by the video playback view.
    var avPlayer: AVPlayer? { playerController.avPlayer }

    // MARK: - Internal State

    /// The URL of the currently selected file, used for playback loading.
    private(set) var currentFileURL: URL?

    /// The most recently generated thumbnail for the current video file.
    private(set) var currentThumbnail: NSImage?

    /// The in-progress async load task, cancelled when a new file is selected.
    private var loadTask: Task<Void, Never>?

    // MARK: - Text file extensions

    /// File extensions treated as text files for preview purposes.
    private static let textExtensions: Set<String> = [
        "txt", "md", "markdown", "json", "xml", "html", "htm", "css", "js", "ts",
        "swift", "py", "rb", "java", "c", "cpp", "h", "hpp", "m", "mm",
        "sh", "bash", "zsh", "fish", "yml", "yaml", "toml", "ini", "cfg",
        "log", "csv", "tsv", "sql", "r", "rs", "go", "kt", "scala",
        "php", "pl", "lua", "vim", "el", "ex", "exs", "erl", "hs",
        "dockerfile", "makefile", "cmake", "gradle", "plist", "strings",
        "gitignore", "env", "conf"
    ]

    // MARK: - Initialization

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

        let url = fileItem.url
        let mediaType = mediaTypeDetector.classifyFile(at: url)

        switch mediaType {
        case .photo:
            currentFileURL = url
            currentThumbnail = nil
            state = .loadingPhoto
            loadTask = Task {
                await loadPhoto(from: url)
            }

        case .video:
            currentFileURL = url
            currentThumbnail = nil
            state = .loadingThumbnail
            loadTask = Task {
                await loadThumbnail(from: url)
            }

        case .unsupported:
            // Check if it's a text file we can preview
            if Self.isTextFile(url: url) {
                currentFileURL = url
                currentThumbnail = nil
                loadTask = Task {
                    await loadText(from: url)
                }
            } else {
                currentFileURL = nil
                currentThumbnail = nil
                state = .empty
            }
        }
    }

    /// Stops playback, cancels any in-progress tasks, and resets to the empty state.
    func stopAndCleanup() {
        loadTask?.cancel()
        loadTask = nil
        playerController.stop()
        currentFileURL = nil
        currentThumbnail = nil
        state = .empty
    }

    /// Begins video playback for the currently selected video file.
    func playVideo() {
        guard let url = currentFileURL, case .thumbnail = state else {
            return
        }

        isMuted = true
        playerController.isMuted = true

        playerController.onPlaybackEnded = { [weak self] in
            Task { @MainActor in
                self?.handlePlaybackEnded()
            }
        }

        loadTask = Task {
            do {
                try await playerController.load(url: url)
                guard !Task.isCancelled else { return }
                playerController.play()
                state = .playing
            } catch {
                guard !Task.isCancelled else { return }
                state = .error("Unable to play video")
            }
        }
    }

    /// Pauses active video playback.
    func pauseVideo() {
        guard state == .playing else { return }
        playerController.pause()
        state = .paused
    }

    /// Resumes video playback from the paused position.
    func resumeVideo() {
        guard state == .paused else { return }
        playerController.play()
        state = .playing
    }

    /// Toggles the mute state during video playback.
    func toggleMute() {
        guard state == .playing || state == .paused else { return }
        guard playerController.hasAudioTrack else { return }
        isMuted.toggle()
        playerController.isMuted = isMuted
    }

    // MARK: - Private Helpers

    private func handlePlaybackEnded() {
        playerController.stop()
        let thumbnail = currentThumbnail ?? Self.genericVideoIcon
        state = .thumbnail(thumbnail)
    }

    /// Loads a photo from the given URL.
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

    /// Generates a thumbnail for the video at the given URL.
    private func loadThumbnail(from url: URL) async {
        guard !Task.isCancelled else { return }

        do {
            let image = try await thumbnailGenerator.generateThumbnail(for: url)
            guard !Task.isCancelled else { return }
            currentThumbnail = image
            state = .thumbnail(image)
        } catch {
            guard !Task.isCancelled else { return }
            let genericIcon = Self.genericVideoIcon
            currentThumbnail = genericIcon
            state = .thumbnail(genericIcon)
        }
    }

    /// Loads text content from a file for preview.
    private func loadText(from url: URL) async {
        guard !Task.isCancelled else { return }

        do {
            let data = try Data(contentsOf: url)
            guard !Task.isCancelled else { return }

            // Limit preview to first 10KB to avoid memory issues with huge files
            let previewData = data.prefix(10_240)
            if let content = String(data: previewData, encoding: .utf8) {
                let displayText = data.count > 10_240
                    ? content + "\n\n… (file truncated)"
                    : content
                state = .text(displayText)
            } else {
                // Binary data, not actually text
                state = .empty
            }
        } catch {
            guard !Task.isCancelled else { return }
            // File can't be read — treat as unsupported rather than showing an error
            state = .empty
        }
    }

    /// Determines if a URL points to a text-based file.
    private static func isTextFile(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()

        // Check known text extensions
        if textExtensions.contains(ext) {
            return true
        }

        // Check if file has no extension but known text filename
        let filename = url.lastPathComponent.lowercased()
        let textFilenames: Set<String> = [
            "makefile", "dockerfile", "rakefile", "gemfile", "podfile",
            "license", "readme", "changelog", "authors", "contributing"
        ]
        if textFilenames.contains(filename) {
            return true
        }

        // Use UTType to check if it conforms to plain text
        if let utType = UTType(filenameExtension: ext) {
            return utType.conforms(to: .plainText) || utType.conforms(to: .sourceCode)
        }

        return false
    }

    private static var genericVideoIcon: NSImage {
        NSImage(systemSymbolName: "film", accessibilityDescription: "Video file") ?? NSImage()
    }
}
