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
                playingView

            case .paused:
                pausedView

            case .error(let message):
                errorView(message: message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear {
            viewModel.stopAndCleanup()
        }
    }

    // MARK: - Subviews

    private var emptyView: some View {
        Color.clear
    }

    private var loadingView: some View {
        ProgressView()
            .progressViewStyle(.circular)
    }

    private func photoView(image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }

    private func thumbnailView(image: NSImage) -> some View {
        ZStack {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)

            Button(action: { viewModel.playVideo() }) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(radius: 4)
            }
            .buttonStyle(.plain)
        }
    }

    private var playingView: some View {
        ZStack {
            Color.black

            playbackControlsOverlay(isPlaying: true)
        }
    }

    private var pausedView: some View {
        ZStack {
            Color.black

            playbackControlsOverlay(isPlaying: false)
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
}
