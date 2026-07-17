import Foundation

/// The user's chosen resolution when a name collision occurs during move/copy.
enum CollisionResolution {
    /// Replace the existing file with the new one.
    case replace
    /// Keep both files by appending a numeric suffix to the new item.
    case keepBoth
    /// Cancel the operation entirely.
    case cancel
}

/// Tracks pending collision info for the dialog.
struct CollisionInfo: Identifiable {
    let id = UUID()
    let fileName: String
    let sourceItems: [FileItem]
    let destination: URL
    let isCopy: Bool
}

/// ViewModel managing the primary file browser state and operations.
/// Uses the Observation framework (@Observable) for SwiftUI bindings.
///
/// Requirements: 1.1, 1.2, 1.3, 1.5, 1.6, 1.7, 1.8, 1.10, 1.11, 2.4, 2.5, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8
@Observable
class FileManagerViewModel {

    // MARK: - Published State

    /// The directory currently displayed in the file browser.
    var currentDirectory: URL

    /// The file items in the current directory, sorted by the active sort settings.
    var fileItems: [FileItem] = []

    /// The set of selected file item IDs.
    var selectedItems: Set<UUID> = []

    /// The active view mode (icon grid, list, or column).
    var viewMode: ViewMode {
        didSet { persistViewMode() }
    }

    /// The column used for sorting file items.
    var sortColumn: SortColumn {
        didSet { persistSortPreferences(); resortItems() }
    }

    /// Whether the sort order is ascending.
    var sortAscending: Bool {
        didSet { persistSortPreferences(); resortItems() }
    }

    /// An error message to display to the user, or nil if no error.
    var errorMessage: String?

    // MARK: - Clipboard State

    /// Items copied to the internal clipboard via Cmd+C.
    var clipboardItems: [FileItem] = []

    // MARK: - Inline Rename State

    /// The item currently being renamed inline, or nil if not renaming.
    var renamingItem: FileItem?

    /// The text currently in the inline rename field.
    var renameText: String = ""

    // MARK: - Collision Dialog State

    /// Non-nil when a name collision dialog should be presented.
    var pendingCollision: CollisionInfo?

    // MARK: - Navigation State

    /// Navigation history managing back/forward stacks.
    private var navigationState: NavigationState

    /// Whether backward navigation is available.
    var canGoBack: Bool { navigationState.canGoBack }

    /// Whether forward navigation is available.
    var canGoForward: Bool { navigationState.canGoForward }

    // MARK: - Tag Filter State

    /// The set of tag IDs currently selected for filtering.
    /// When non-empty, only files matching ALL selected tags are displayed.
    var selectedTagIds: Set<UUID> = [] {
        didSet { applyTagFilter() }
    }

    /// All items in the current directory (unfiltered).
    private var allFileItems: [FileItem] = []

    // MARK: - File System Watcher

    /// Watcher that monitors the current directory for changes.
    let fileSystemWatcher = FileSystemWatcher()

    // MARK: - Services

    private let fileSystemService: FileSystemServiceProtocol
    private let tagStorageService: TagStorageServiceProtocol

    // MARK: - UserDefaults Keys

    private enum DefaultsKey {
        static let viewMode = "viewMode"
        static let sortColumn = "sortColumn"
        static let sortAscending = "sortAscending"
    }

    private let defaults: UserDefaults

    // MARK: - Initialization

    /// Creates a new FileManagerViewModel.
    /// - Parameters:
    ///   - fileSystemService: Service for file system operations.
    ///   - tagStorageService: Service for tag persistence.
    ///   - defaults: UserDefaults instance for persisting preferences.
    init(
        fileSystemService: FileSystemServiceProtocol,
        tagStorageService: TagStorageServiceProtocol,
        defaults: UserDefaults = .standard
    ) {
        self.fileSystemService = fileSystemService
        self.tagStorageService = tagStorageService
        self.defaults = defaults

        // Load persisted view mode or default to list
        let savedViewMode = defaults.string(forKey: DefaultsKey.viewMode)
            .flatMap { ViewMode(rawValue: $0) } ?? .list
        self.viewMode = savedViewMode

        // Load persisted sort preferences or default to name ascending
        let savedSortColumn = defaults.string(forKey: DefaultsKey.sortColumn)
            .flatMap { SortColumn(rawValue: $0) } ?? .name
        let savedSortAscending: Bool
        if defaults.object(forKey: DefaultsKey.sortAscending) != nil {
            savedSortAscending = defaults.bool(forKey: DefaultsKey.sortAscending)
        } else {
            savedSortAscending = true
        }
        self.sortColumn = savedSortColumn
        self.sortAscending = savedSortAscending

        // Default to home directory
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        self.currentDirectory = homeDirectory
        self.navigationState = NavigationState(currentDirectory: homeDirectory)

        // Load initial directory contents
        loadContents()

        // Set up file system watcher for automatic refresh
        setupWatcher()
    }

    // MARK: - Navigation

    /// Navigates to a new directory, updating the history stacks.
    /// - Parameter url: The directory URL to navigate to.
    func navigateTo(_ url: URL) {
        navigationState.navigateTo(url)
        currentDirectory = navigationState.currentDirectory
        selectedItems.removeAll()
        loadContents()
        fileSystemWatcher.watch(currentDirectory)
    }

    /// Navigates back to the previous directory in history.
    func goBack() {
        navigationState.goBack()
        currentDirectory = navigationState.currentDirectory
        selectedItems.removeAll()
        loadContents()
        fileSystemWatcher.watch(currentDirectory)
    }

    /// Navigates forward to the next directory in history.
    func goForward() {
        navigationState.goForward()
        currentDirectory = navigationState.currentDirectory
        selectedItems.removeAll()
        loadContents()
        fileSystemWatcher.watch(currentDirectory)
    }

    // MARK: - File Operations

    /// Deletes (trashes) the currently selected items.
    func deleteSelected() {
        let itemsToDelete = fileItems.filter { selectedItems.contains($0.id) }
        guard !itemsToDelete.isEmpty else { return }

        for item in itemsToDelete {
            do {
                try fileSystemService.trashItem(at: item.url)
            } catch {
                errorMessage = error.localizedDescription
                break
            }
        }

        selectedItems.removeAll()
        loadContents()
    }

    /// Moves items to a destination directory.
    /// - Parameters:
    ///   - items: The file items to move.
    ///   - destination: The target directory URL.
    func moveItems(_ items: [FileItem], to destination: URL) {
        for item in items {
            let destURL = destination.appendingPathComponent(item.name)
            do {
                try fileSystemService.moveItem(at: item.url, to: destURL)
            } catch {
                errorMessage = error.localizedDescription
                break
            }
        }

        selectedItems.removeAll()
        loadContents()
    }

    /// Copies items to a destination directory.
    /// - Parameters:
    ///   - items: The file items to copy.
    ///   - destination: The target directory URL.
    func copyItems(_ items: [FileItem], to destination: URL) {
        for item in items {
            let destURL = destination.appendingPathComponent(item.name)
            do {
                try fileSystemService.copyItem(at: item.url, to: destURL)
            } catch {
                errorMessage = error.localizedDescription
                break
            }
        }

        loadContents()
    }

    /// Creates a new folder in the current directory with a default name.
    func createNewFolder() {
        let baseName = "untitled folder"
        var folderName = baseName
        var counter = 2

        // Find a unique name if the base name already exists
        while fileSystemService.itemExists(
            at: currentDirectory.appendingPathComponent(folderName)
        ) {
            folderName = "\(baseName) \(counter)"
            counter += 1
        }

        do {
            try fileSystemService.createDirectory(at: currentDirectory, name: folderName)
        } catch {
            errorMessage = error.localizedDescription
        }

        loadContents()
    }

    /// Renames a file item to a new name.
    /// - Parameters:
    ///   - item: The file item to rename.
    ///   - newName: The desired new name.
    /// - Returns: A `Result` indicating success or a `RenameError`.
    @discardableResult
    func renameItem(_ item: FileItem, to newName: String) -> Result<Void, RenameError> {
        do {
            try fileSystemService.renameItem(at: item.url, to: newName)
            loadContents()
            return .success(())
        } catch let error as RenameError {
            errorMessage = error.localizedDescription
            return .failure(error)
        } catch {
            let renameError = RenameError.renameFailed(
                source: item.url,
                destination: item.url.deletingLastPathComponent().appendingPathComponent(newName),
                underlying: error
            )
            errorMessage = renameError.localizedDescription
            return .failure(renameError)
        }
    }

    // MARK: - Clipboard Operations

    /// Copies the currently selected items to the internal clipboard.
    func copySelectedToClipboard() {
        clipboardItems = fileItems.filter { selectedItems.contains($0.id) }
    }

    /// Pastes clipboard items into the current directory, handling collisions.
    func pasteFromClipboard() {
        guard !clipboardItems.isEmpty else { return }
        performCopyWithCollisionCheck(items: clipboardItems, to: currentDirectory)
    }

    // MARK: - Inline Rename

    /// Begins inline renaming of the single selected item.
    func beginRename() {
        guard selectedItems.count == 1,
              let item = fileItems.first(where: { selectedItems.contains($0.id) }) else { return }
        renamingItem = item
        renameText = item.name
    }

    /// Commits the current inline rename operation.
    func commitRename() {
        guard let item = renamingItem else { return }
        let newName = renameText.trimmingCharacters(in: .whitespaces)
        if !newName.isEmpty && newName != item.name {
            renameItem(item, to: newName)
        }
        renamingItem = nil
        renameText = ""
    }

    /// Cancels the current inline rename operation.
    func cancelRename() {
        renamingItem = nil
        renameText = ""
    }

    // MARK: - Collision-Aware Move/Copy

    /// Moves items to a destination, checking for name collisions first.
    func moveItemsWithCollisionCheck(_ items: [FileItem], to destination: URL) {
        // Check for any collision
        for item in items {
            let destURL = destination.appendingPathComponent(item.name)
            if fileSystemService.itemExists(at: destURL) {
                // Show collision dialog
                pendingCollision = CollisionInfo(
                    fileName: item.name,
                    sourceItems: items,
                    destination: destination,
                    isCopy: false
                )
                return
            }
        }
        // No collision, proceed directly
        moveItems(items, to: destination)
    }

    /// Copies items to a destination, checking for name collisions first.
    func performCopyWithCollisionCheck(items: [FileItem], to destination: URL) {
        // Check for any collision
        for item in items {
            let destURL = destination.appendingPathComponent(item.name)
            if fileSystemService.itemExists(at: destURL) {
                // Show collision dialog
                pendingCollision = CollisionInfo(
                    fileName: item.name,
                    sourceItems: items,
                    destination: destination,
                    isCopy: true
                )
                return
            }
        }
        // No collision, proceed directly
        copyItems(items, to: destination)
    }

    /// Resolves a name collision based on the user's choice.
    func resolveCollision(_ resolution: CollisionResolution) {
        guard let collision = pendingCollision else { return }
        pendingCollision = nil

        switch resolution {
        case .cancel:
            return
        case .replace:
            // Delete existing items at destination then proceed
            for item in collision.sourceItems {
                let destURL = collision.destination.appendingPathComponent(item.name)
                if fileSystemService.itemExists(at: destURL) {
                    try? fileSystemService.trashItem(at: destURL)
                }
            }
            if collision.isCopy {
                copyItems(collision.sourceItems, to: collision.destination)
            } else {
                moveItems(collision.sourceItems, to: collision.destination)
            }
        case .keepBoth:
            // Append numeric suffix to avoid collision
            for item in collision.sourceItems {
                var destURL = collision.destination.appendingPathComponent(item.name)
                if fileSystemService.itemExists(at: destURL) {
                    destURL = uniqueDestinationURL(for: item.name, in: collision.destination)
                }
                do {
                    if collision.isCopy {
                        try fileSystemService.copyItem(at: item.url, to: destURL)
                    } else {
                        try fileSystemService.moveItem(at: item.url, to: destURL)
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    break
                }
            }
            selectedItems.removeAll()
            loadContents()
        }
    }

    /// Generates a unique destination URL by appending a numeric suffix.
    private func uniqueDestinationURL(for name: String, in directory: URL) -> URL {
        let nsName = name as NSString
        let baseName = nsName.deletingPathExtension
        let ext = nsName.pathExtension
        var counter = 2
        var candidate: URL
        repeat {
            let newName = ext.isEmpty ? "\(baseName) \(counter)" : "\(baseName) \(counter).\(ext)"
            candidate = directory.appendingPathComponent(newName)
            counter += 1
        } while fileSystemService.itemExists(at: candidate)
        return candidate
    }

    // MARK: - Private Helpers

    /// Loads and sorts the contents of the current directory.
    private func loadContents() {
        do {
            let items = try fileSystemService.contentsOfDirectory(at: currentDirectory, showHidden: false)
            allFileItems = sortFileItems(items, by: sortColumn, ascending: sortAscending)
            applyTagFilter()
            errorMessage = nil
        } catch {
            allFileItems = []
            fileItems = []
            errorMessage = error.localizedDescription
        }
    }

    /// Refreshes the current directory contents. Called by the file system watcher.
    func refreshContents() {
        loadContents()
    }

    /// Applies tag filtering to allFileItems and updates fileItems.
    private func applyTagFilter() {
        guard !selectedTagIds.isEmpty else {
            fileItems = allFileItems
            return
        }

        // Load current tag associations for filtering
        let store: TagStore
        do {
            store = try tagStorageService.load()
        } catch {
            fileItems = allFileItems
            return
        }

        let matchingPaths = Set(filterFilesByTags(store: store, selectedTagIds: selectedTagIds))
        fileItems = allFileItems.filter { matchingPaths.contains($0.url.path) }
    }

    /// Sets up the file system watcher to monitor the current directory.
    private func setupWatcher() {
        fileSystemWatcher.onChange = { [weak self] in
            self?.refreshContents()
        }
        fileSystemWatcher.watch(currentDirectory)
    }

    /// Re-sorts the current file items using the active sort settings.
    private func resortItems() {
        allFileItems = sortFileItems(allFileItems, by: sortColumn, ascending: sortAscending)
        applyTagFilter()
    }

    /// Persists the current view mode to UserDefaults.
    private func persistViewMode() {
        defaults.set(viewMode.rawValue, forKey: DefaultsKey.viewMode)
    }

    /// Persists the current sort preferences to UserDefaults.
    private func persistSortPreferences() {
        defaults.set(sortColumn.rawValue, forKey: DefaultsKey.sortColumn)
        defaults.set(sortAscending, forKey: DefaultsKey.sortAscending)
    }
}
