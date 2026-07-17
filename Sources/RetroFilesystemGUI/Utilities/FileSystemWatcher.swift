import Foundation

/// Monitors a directory for file system changes using timer-based polling.
/// When changes are detected, the `onChange` handler is called.
/// Smart Folder contents update within 5 seconds of file system changes (Requirement 4.4).
///
/// Requirements: 4.4
@Observable
class FileSystemWatcher {

    /// The directory currently being watched.
    private(set) var watchedURL: URL?

    /// Callback invoked when a change is detected in the watched directory.
    var onChange: (() -> Void)?

    // MARK: - Private State

    /// Timer that polls for changes.
    private var timer: Timer?

    /// Snapshot of directory contents for change detection.
    private var lastSnapshot: DirectorySnapshot?

    /// Polling interval in seconds (≤ 5 seconds per Requirement 4.4).
    private let pollInterval: TimeInterval

    // MARK: - Initialization

    /// Creates a FileSystemWatcher with the specified polling interval.
    /// - Parameter pollInterval: How frequently to check for changes (default 3 seconds to stay within 5s requirement).
    init(pollInterval: TimeInterval = 3.0) {
        self.pollInterval = pollInterval
    }

    deinit {
        stopWatching()
    }

    // MARK: - Public API

    /// Starts watching the specified directory for changes.
    /// Replaces any previous watch target.
    /// - Parameter url: The directory URL to monitor.
    func watch(_ url: URL) {
        stopWatching()
        watchedURL = url
        lastSnapshot = takeSnapshot(of: url)
        startTimer()
    }

    /// Stops watching the current directory.
    func stopWatching() {
        timer?.invalidate()
        timer = nil
        watchedURL = nil
        lastSnapshot = nil
    }

    // MARK: - Private Helpers

    /// Starts the polling timer on the main run loop.
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    /// Compares current directory state to the last snapshot and fires onChange if different.
    private func checkForChanges() {
        guard let url = watchedURL else { return }

        let currentSnapshot = takeSnapshot(of: url)
        if currentSnapshot != lastSnapshot {
            lastSnapshot = currentSnapshot
            DispatchQueue.main.async { [weak self] in
                self?.onChange?()
            }
        }
    }

    /// Takes a lightweight snapshot of a directory's contents for comparison.
    private func takeSnapshot(of url: URL) -> DirectorySnapshot {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return DirectorySnapshot(entries: [])
        }

        let entries: [DirectorySnapshot.Entry] = contents.compactMap { itemURL in
            guard let values = try? itemURL.resourceValues(
                forKeys: [.contentModificationDateKey, .fileSizeKey]
            ) else {
                return DirectorySnapshot.Entry(
                    name: itemURL.lastPathComponent,
                    modDate: nil,
                    size: nil
                )
            }
            return DirectorySnapshot.Entry(
                name: itemURL.lastPathComponent,
                modDate: values.contentModificationDate,
                size: values.fileSize.map { Int64($0) }
            )
        }

        return DirectorySnapshot(entries: entries.sorted { $0.name < $1.name })
    }
}

// MARK: - Directory Snapshot

/// A lightweight representation of a directory's contents for change detection.
private struct DirectorySnapshot: Equatable {
    struct Entry: Equatable {
        let name: String
        let modDate: Date?
        let size: Int64?
    }

    let entries: [Entry]
}
