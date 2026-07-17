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

    // MARK: - Alias State

    /// The loaded alias store mapping file paths to display names.
    var aliasStore: AliasStore = AliasStore(aliases: [:])

    // MARK: - Metadata Panel State

    /// Whether the metadata panel is currently visible.
    var metadataPanelVisible: Bool = false

    /// The pretty-printed JSON text for the metadata editor.
    var selectedItemMetadata: String = "{}"

    /// Inline error message for metadata validation failures.
    var metadataValidationError: String? = nil

    /// The previous metadata state for single-level undo support.
    var previousMetadataState: String? = nil

    // MARK: - Unsorted File Tracking State

    /// Dictionary mapping directory paths to their unsorted file counts.
    var unsortedCounts: [String: Int] = [:]

    /// Whether the unsorted filter is currently active for the current directory.
    var unsortedFilterActive: Bool = false

    /// Cached unsorted items for the current directory when filter is active.
    private var unsortedItems: [FileItem] = []

    // MARK: - Services

    private let fileSystemService: FileSystemServiceProtocol
    private let tagStorageService: TagStorageServiceProtocol
    private let aliasStorageService: AliasStorageServiceProtocol?
    private let metadataStorageService: MetadataStorageServiceProtocol?
    private let sortingRulesService: SortingRulesStorageServiceProtocol?

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
    ///   - aliasStorageService: Service for alias persistence (optional).
    ///   - metadataStorageService: Service for metadata persistence (optional).
    ///   - sortingRulesService: Service for sorting rules persistence (optional).
    ///   - defaults: UserDefaults instance for persisting preferences.
    init(
        fileSystemService: FileSystemServiceProtocol,
        tagStorageService: TagStorageServiceProtocol,
        aliasStorageService: AliasStorageServiceProtocol? = nil,
        metadataStorageService: MetadataStorageServiceProtocol? = nil,
        sortingRulesService: SortingRulesStorageServiceProtocol? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.fileSystemService = fileSystemService
        self.tagStorageService = tagStorageService
        self.aliasStorageService = aliasStorageService
        self.metadataStorageService = metadataStorageService
        self.sortingRulesService = sortingRulesService
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

        // Load alias store if service is available
        if let aliasService = aliasStorageService {
            self.aliasStore = (try? aliasService.load()) ?? AliasStore(aliases: [:])
        }

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

    // MARK: - Alias Operations

    /// Assigns an alias display name to a file item.
    /// - Parameters:
    ///   - item: The file item to alias.
    ///   - name: The alias name to assign.
    /// - Returns: A `Result` indicating success or an `AliasValidationError`.
    @discardableResult
    func setAlias(for item: FileItem, name: String) -> Result<Void, AliasValidationError> {
        if let error = AliasStore.validateAlias(name) {
            return .failure(error)
        }

        aliasStore.aliases[item.url.path] = name

        if let service = aliasStorageService {
            try? service.save(aliasStore)
        }

        return .success(())
    }

    /// Removes the alias for a file item, reverting to the filesystem name.
    /// - Parameter item: The file item whose alias should be removed.
    func removeAlias(for item: FileItem) {
        aliasStore.aliases.removeValue(forKey: item.url.path)

        if let service = aliasStorageService {
            try? service.save(aliasStore)
        }
    }

    /// Returns the display name for a file item: alias if present, otherwise the filesystem name.
    /// - Parameter item: The file item to get the display name for.
    /// - Returns: The alias name if one exists, otherwise the item's filesystem name.
    func displayName(for item: FileItem) -> String {
        aliasStore.aliases[item.url.path] ?? item.name
    }

    /// Returns whether a file item has an alias assigned, for italic styling decisions.
    /// - Parameter item: The file item to check.
    /// - Returns: `true` if the item has an alias, `false` otherwise.
    func isAliased(_ item: FileItem) -> Bool {
        aliasStore.aliases[item.url.path] != nil
    }

    // MARK: - Metadata Operations

    /// Loads metadata for the given file path and populates the editor state.
    /// - Parameter path: The absolute path of the file to load metadata for.
    func loadMetadata(for path: String) {
        guard let service = metadataStorageService else {
            selectedItemMetadata = "{}"
            previousMetadataState = nil
            return
        }

        let store: MetadataStore
        do {
            store = try service.load()
        } catch {
            selectedItemMetadata = "{}"
            previousMetadataState = nil
            return
        }

        let jsonValue = store.entries[path] ?? .object([:])

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(jsonValue)
            selectedItemMetadata = String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            selectedItemMetadata = "{}"
        }

        // New selection clears undo state
        previousMetadataState = nil
    }

    /// Saves metadata JSON text for the given file path after validation.
    /// - Parameters:
    ///   - jsonText: The JSON text to validate and save.
    ///   - path: The absolute path of the file to save metadata for.
    /// - Returns: A `Result` indicating success or a `MetadataValidationError`.
    @discardableResult
    func saveMetadata(jsonText: String, for path: String) -> Result<Void, MetadataValidationError> {
        // Validate the JSON text
        if let validationError = MetadataStore.validateMetadataJSON(jsonText) {
            switch validationError {
            case .malformedJSON(let line, let character):
                metadataValidationError = "Invalid JSON at line \(line), character \(character)"
            case .tooLarge:
                metadataValidationError = "Metadata must be smaller than 1 MB"
            }
            return .failure(validationError)
        }

        guard let service = metadataStorageService else {
            return .failure(.malformedJSON(line: 1, character: 1))
        }

        // Save previous state for undo (current state before save)
        previousMetadataState = selectedItemMetadata

        // Parse jsonText into JSONValue via JSONSerialization then JSONDecoder
        let jsonData = Data(jsonText.utf8)
        let parsedValue: JSONValue
        do {
            let anyObject = try JSONSerialization.jsonObject(with: jsonData, options: .fragmentsAllowed)
            let reEncodedData = try JSONSerialization.data(withJSONObject: anyObject, options: .fragmentsAllowed)
            let decoder = JSONDecoder()
            parsedValue = try decoder.decode(JSONValue.self, from: reEncodedData)
        } catch {
            metadataValidationError = "Failed to parse JSON"
            return .failure(.malformedJSON(line: 1, character: 1))
        }

        // Update the store
        do {
            var store = try service.load()
            store.entries[path] = parsedValue
            try service.save(store)
        } catch {
            metadataValidationError = "Failed to save metadata"
            return .failure(.malformedJSON(line: 1, character: 1))
        }

        // Re-format the saved value for display
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let formattedData = try? encoder.encode(parsedValue),
           let formattedString = String(data: formattedData, encoding: .utf8) {
            selectedItemMetadata = formattedString
        } else {
            selectedItemMetadata = jsonText
        }

        // Clear validation error on success
        metadataValidationError = nil

        return .success(())
    }

    /// Restores the previous metadata state (single-level undo).
    /// - Parameter path: The absolute path of the file to undo metadata for.
    func undoMetadata(for path: String) {
        guard let previous = previousMetadataState else { return }

        // Restore the previous state to the editor
        selectedItemMetadata = previous

        // Save the previous state to the store (without updating previousMetadataState)
        guard let service = metadataStorageService else { return }

        let jsonData = Data(previous.utf8)
        do {
            let anyObject = try JSONSerialization.jsonObject(with: jsonData, options: .fragmentsAllowed)
            let reEncodedData = try JSONSerialization.data(withJSONObject: anyObject, options: .fragmentsAllowed)
            let decoder = JSONDecoder()
            let parsedValue = try decoder.decode(JSONValue.self, from: reEncodedData)

            var store = try service.load()
            store.entries[path] = parsedValue
            try service.save(store)
        } catch {
            // If undo persistence fails, we still restore the UI state
        }

        // Only single-level undo
        previousMetadataState = nil
    }

    // MARK: - Unsorted File Operations

    /// Evaluates which files in the given directory are unsorted based on sorting rules.
    /// Updates the `unsortedCounts` dictionary and caches unsorted items if the directory
    /// is the current directory.
    /// - Parameter directory: The directory URL to evaluate.
    func evaluateUnsortedFiles(in directory: URL) {
        guard let service = sortingRulesService else { return }

        let store: SortingRulesStore
        do {
            store = try service.load()
        } catch {
            return
        }

        // Find rules for this directory
        let directoryPath = directory.path
        guard let directoryRules = store.directories.first(where: { $0.directoryPath == directoryPath }) else {
            // No rules for this directory — remove count entry and return
            unsortedCounts.removeValue(forKey: directoryPath)
            if directory == currentDirectory {
                unsortedItems = []
            }
            return
        }

        // Get the file items for the directory
        let items: [FileItem]
        if directory == currentDirectory {
            items = allFileItems
        } else {
            // Load items for a different directory
            items = (try? fileSystemService.contentsOfDirectory(at: directory, showHidden: false)) ?? []
        }

        // Evaluate unsorted files
        let result = UnsortedFileEvaluator.unsortedFiles(
            from: items,
            rules: directoryRules.rules,
            tagStorageService: tagStorageService
        )

        unsortedCounts[directoryPath] = result.count

        // Cache unsorted items if this is the current directory
        if directory == currentDirectory {
            unsortedItems = result
        }
    }

    /// Toggles the unsorted filter for the given directory.
    /// When active, only unsorted files are shown. When inactive, normal filtering is restored.
    /// - Parameter directory: The directory URL to toggle filtering for.
    func toggleUnsortedFilter(for directory: URL) {
        guard directory == currentDirectory else { return }

        unsortedFilterActive.toggle()

        if unsortedFilterActive {
            // Filter fileItems to show only unsorted items
            let unsortedIds = Set(unsortedItems.map { $0.id })
            fileItems = fileItems.filter { unsortedIds.contains($0.id) }
        } else {
            // Re-apply normal filtering (tag filter resets the view)
            applyTagFilter()
        }
    }

    // MARK: - Private Helpers

    /// Loads and sorts the contents of the current directory.
    private func loadContents() {
        do {
            let items = try fileSystemService.contentsOfDirectory(at: currentDirectory, showHidden: false)
            allFileItems = sortFileItems(items, by: sortColumn, ascending: sortAscending)
            applyTagFilter()
            evaluateUnsortedFiles(in: currentDirectory)
            errorMessage = nil
        } catch {
            allFileItems = []
            fileItems = []
            errorMessage = error.localizedDescription
        }
    }

    /// Refreshes the current directory contents. Called by the file system watcher.
    func refreshContents() {
        // Clean up stale alias entries (paths that no longer exist on disk)
        cleanupStaleAliases()

        // Clean up stale metadata entries (paths that no longer exist on disk)
        cleanupStaleMetadata()

        loadContents()
    }

    /// Removes alias entries whose paths no longer exist on disk.
    private func cleanupStaleAliases() {
        var didRemove = false
        for path in aliasStore.aliases.keys {
            if !FileManager.default.fileExists(atPath: path) {
                aliasStore.aliases.removeValue(forKey: path)
                didRemove = true
            }
        }

        if didRemove, let service = aliasStorageService {
            try? service.save(aliasStore)
        }
    }

    /// Removes metadata entries whose paths no longer exist on disk.
    private func cleanupStaleMetadata() {
        guard let service = metadataStorageService else { return }

        guard var store = try? service.load() else { return }

        var didRemove = false
        for path in store.entries.keys {
            if !FileManager.default.fileExists(atPath: path) {
                store.entries.removeValue(forKey: path)
                didRemove = true
            }
        }

        if didRemove {
            try? service.save(store)
        }
    }

    /// Applies tag filtering to allFileItems and updates fileItems.
    /// Also respects the unsorted filter if active.
    private func applyTagFilter() {
        guard !selectedTagIds.isEmpty else {
            fileItems = allFileItems
            // Apply unsorted filter if active
            if unsortedFilterActive {
                let unsortedIds = Set(unsortedItems.map { $0.id })
                fileItems = fileItems.filter { unsortedIds.contains($0.id) }
            }
            return
        }

        // Load current tag associations for filtering
        let store: TagStore
        do {
            store = try tagStorageService.load()
        } catch {
            fileItems = allFileItems
            if unsortedFilterActive {
                let unsortedIds = Set(unsortedItems.map { $0.id })
                fileItems = fileItems.filter { unsortedIds.contains($0.id) }
            }
            return
        }

        let matchingPaths = Set(filterFilesByTags(store: store, selectedTagIds: selectedTagIds))
        fileItems = allFileItems.filter { matchingPaths.contains($0.url.path) }

        // Apply unsorted filter if active
        if unsortedFilterActive {
            let unsortedIds = Set(unsortedItems.map { $0.id })
            fileItems = fileItems.filter { unsortedIds.contains($0.id) }
        }
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
