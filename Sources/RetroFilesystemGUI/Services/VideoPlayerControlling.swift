import AVFoundation
import Foundation

/// Protocol for managing video playback lifecycle and state.
///
/// Conforming types wrap a media player to provide load, play, pause, and stop
/// operations along with mute control and end-of-playback notification.
protocol VideoPlayerControlling: AnyObject {
    /// Whether the video is currently playing.
    var isPlaying: Bool { get }

    /// Whether audio output is muted. Setting this value updates the underlying player immediately.
    var isMuted: Bool { get set }

    /// Whether the loaded video contains at least one audio track.
    var hasAudioTrack: Bool { get }

    /// The underlying AVPlayer instance for use by the video playback view.
    /// Returns nil when no video is loaded.
    var avPlayer: AVPlayer? { get }

    /// A closure invoked when playback reaches the end of the video content.
    var onPlaybackEnded: (() -> Void)? { get set }

    /// Loads a video from the given URL and prepares it for playback.
    ///
    /// This method creates the underlying player item, detects audio tracks,
    /// and sets up end-of-playback observation.
    /// - Parameter url: The file URL of the video to load.
    /// - Throws: An error if the video cannot be loaded or its tracks cannot be inspected.
    func load(url: URL) async throws

    /// Begins or resumes video playback.
    func play()

    /// Pauses video playback at the current position.
    func pause()

    /// Stops video playback and releases all player resources.
    ///
    /// After calling `stop()`, the player and player item are released.
    /// A new call to `load(url:)` is required before playback can resume.
    func stop()
}
