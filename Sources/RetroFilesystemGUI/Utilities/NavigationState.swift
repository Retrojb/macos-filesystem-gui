import Foundation

/// Manages directory navigation history with back/forward stack semantics.
/// Requirements: 1.5, 1.6, 1.7, 1.8
struct NavigationState {
    /// The directory currently being displayed.
    var currentDirectory: URL

    /// Stack of previously visited directories (most recent at the end). Max 50 entries.
    private(set) var backStack: [URL] = []

    /// Stack of directories available for forward navigation (most recent at the end).
    /// Cleared whenever the user navigates to a new directory.
    private(set) var forwardStack: [URL] = []

    /// Whether the back button should be enabled.
    var canGoBack: Bool { !backStack.isEmpty }

    /// Whether the forward button should be enabled.
    var canGoForward: Bool { !forwardStack.isEmpty }

    /// Maximum number of entries retained in the back stack.
    static let maxBackStackSize = 50

    /// Navigate to a new directory.
    /// Pushes the current directory onto the back stack, clears the forward stack,
    /// and sets the current directory to the provided URL.
    mutating func navigateTo(_ url: URL) {
        backStack.append(currentDirectory)
        if backStack.count > Self.maxBackStackSize {
            backStack.removeFirst()
        }
        forwardStack.removeAll()
        currentDirectory = url
    }

    /// Go back to the previous directory.
    /// Pops the most recent entry from the back stack, pushes the current directory
    /// onto the forward stack, and sets the current directory to the popped entry.
    mutating func goBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(currentDirectory)
        currentDirectory = previous
    }

    /// Go forward to the next directory.
    /// Pops the most recent entry from the forward stack, pushes the current directory
    /// onto the back stack, and sets the current directory to the popped entry.
    mutating func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(currentDirectory)
        currentDirectory = next
    }
}
