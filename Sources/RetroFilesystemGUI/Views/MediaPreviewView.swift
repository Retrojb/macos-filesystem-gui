import AVKit
import SwiftUI

/// Top-level container view for media previews.
///
/// Switches on the view model's state to render the appropriate content:
/// empty area, loading indicator, photo, video thumbnail, video playback, or error.
/// Ensures resource cleanup when the view disappears via `.onDisappear`.
struct MediaPreviewView: View {
    let viewModel: MediaPreviewViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .empty:
                emptyView

            case .loadingPhoto, .loadingThumbnail:
                loadingView

            case .photo(let image):
                photoView(image: image)

            case .thumbnail(let image):
                thumbnailView(image: image)

            case .playing:
                videoPlaybackView(showPauseButton: true)

            case .paused:
                videoPlaybackView(showPauseButton: false)

            case .error(let message):
                errorView(message: message)

            case .text(let content):
                textView(content: content)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .onDisappear {
            viewModel.stopAndCleanup()
        }
    }

    // MARK: - Subviews

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Select a file to preview")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var loadingView: some View {
        ProgressView()
            .progressViewStyle(.circular)
    }

    private func photoView(image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(8)
    }

    private func thumbnailView(image: NSImage) -> some View {
        ZStack {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(8)

            Button(action: { viewModel.playVideo() }) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(radius: 4)
            }
            .buttonStyle(.plain)
        }
    }

    private func videoPlaybackView(showPauseButton: Bool) -> some View {
        ZStack {
            if let player = viewModel.avPlayer {
                VideoPlayerRepresentable(player: player)
            } else {
                Color.black
            }

            playbackControlsOverlay(isPlaying: showPauseButton)
        }
    }

    private func playbackControlsOverlay(isPlaying: Bool) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                // Play/Pause button
                Button(action: {
                    if isPlaying {
                        viewModel.pauseVideo()
                    } else {
                        viewModel.resumeVideo()
                    }
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Spacer()

                // Mute/Unmute button
                Button(action: { viewModel.toggleMute() }) {
                    Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.black.opacity(0.5))
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func textView(content: String) -> some View {
        ScrollView {
            Text(content)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .textSelection(.enabled)
        }
    }
}

// MARK: - AVPlayerView NSViewRepresentable Wrapper

/// Wraps `AVPlayerView` for use in SwiftUI, rendering video content from an `AVPlayer`.
struct VideoPlayerRepresentable: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.controlsStyle = .none
        playerView.showsFullScreenToggleButton = false
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}
