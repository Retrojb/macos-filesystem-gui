import AVFoundation
import Foundation

/// Manages video playback by wrapping `AVPlayer` and `AVPlayerItem`.
///
/// `VideoPlayerController` handles the full lifecycle of video playback including
/// loading media, detecting audio tracks, observing end-of-playback events, and
/// releasing resources on stop. Video always starts muted.
class VideoPlayerController: VideoPlayerControlling {
    // MARK: - Private Properties

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var endObserver: Any?

    // MARK: - VideoPlayerControlling

    /// Whether the video is currently playing.
    private(set) var isPlaying: Bool = false

    /// Whether audio output is muted. Updates the underlying player immediately when set.
    var isMuted: Bool = true {
        didSet {
            player?.isMuted = isMuted
        }
    }

    /// Whether the loaded video contains at least one audio track.
    private(set) var hasAudioTrack: Bool = false

    /// A closure invoked when playback reaches the end of the video content.
    var onPlaybackEnded: (() -> Void)?

    // MARK: - Lifecycle

    deinit {
        stop()
    }

    // MARK: - VideoPlayerControlling Methods

    /// Loads a video from the given URL and prepares it for playback.
    ///
    /// Creates an `AVPlayerItem` from the URL, detects whether the asset contains
    /// audio tracks, and sets up an observer for end-of-playback notifications.
    /// - Parameter url: The file URL of the video to load.
    /// - Throws: An error if the video's tracks cannot be inspected.
    func load(url: URL) async throws {
        // Stop any existing playback and release resources
        stop()

        let asset = AVURLAsset(url: url)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        hasAudioTrack = !audioTracks.isEmpty

        let item = AVPlayerItem(asset: asset)
        playerItem = item

        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.isMuted = isMuted
        player = newPlayer

        // Observe end-of-playback
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.isPlaying = false
            self?.onPlaybackEnded?()
        }
    }

    /// Begins or resumes video playback.
    func play() {
        player?.play()
        isPlaying = true
    }

    /// Pauses video playback at the current position.
    func pause() {
        player?.pause()
        isPlaying = false
    }

    /// Stops video playback and releases all player resources.
    ///
    /// Removes the end-of-playback observer and sets the player and player item to `nil`.
    func stop() {
        if let endObserver = endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player = nil
        playerItem = nil
        isPlaying = false
        hasAudioTrack = false
    }
}
