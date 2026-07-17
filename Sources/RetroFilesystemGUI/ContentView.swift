import SwiftUI

/// Main content view using NavigationSplitView with sidebar and detail panels.
/// Requirements: 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 3.1, 3.4, 3.5, 3.6, 5.1, 5.5, 6.8
struct ContentView: View {
    @State private var fileManagerVM = FileManagerViewModel(
        fileSystemService: FileSystemService(),
        tagStorageService: TagStorageService(),
        aliasStorageService: AliasStorageService(),
        metadataStorageService: MetadataStorageService(),
        sortingRulesService: SortingRulesStorageService()
    )
    @State private var tagManagerVM = TagManagerViewModel(
        storageService: TagStorageService()
    )

    /// Tracks the currently selected item for the metadata panel.
    @State private var currentMetadataItem: FileItem?

    /// Whether a confirmation dialog is showing for unsaved metadata changes.
    @State private var showUnsavedMetadataAlert: Bool = false

    /// The pending item to switch to after confirming unsaved changes.
    @State private var pendingMetadataItem: FileItem?

    /// Whether the comparison sheet is currently visible.
    @State private var showingComparisonSheet: Bool = false

    /// The view model for the directory comparison sheet.
    @State private var comparisonVM: DirectoryComparisonViewModel?

    /// Error message shown when comparison selection is invalid.
    @State private var comparisonSelectionError: String?

    /// Tracks the metadata text at the time it was last loaded, for dirty detection.
    @State private var lastLoadedMetadata: String = "{}"

    var body: some View {
        NavigationSplitView {
            NavigationPanel(
                fileManagerVM: fileManagerVM,
                tagManagerVM: tagManagerVM
            )
        } detail: {
            HStack(spacing: 0) {
                if fileManagerVM.metadataPanelVisible {
                    MetadataPanel(
                        viewModel: fileManagerVM,
                        selectedItem: currentMetadataItem
                    )
                    Divider()
                }
                VStack(spacing: 0) {
                    PathBar(viewModel: fileManagerVM)
                    FileBrowser(
                        fileManagerVM: fileManagerVM,
                        tagManagerVM: tagManagerVM,
                        isTagFilterActive: !fileManagerVM.selectedTagIds.isEmpty
                    )
                }
            }
            .onChange(of: fileManagerVM.selectedItems) { _, newSelection in
                handleSelectionChange(newSelection: newSelection)
            }
            .alert(
                "Unsaved Changes",
                isPresented: $showUnsavedMetadataAlert
            ) {
                Button("Save") {
                    if let item = currentMetadataItem {
                        _ = fileManagerVM.saveMetadata(
                            jsonText: fileManagerVM.selectedItemMetadata,
                            for: item.url.path
                        )
                    }
                    commitPendingSelection()
                }
                Button("Discard", role: .destructive) {
                    commitPendingSelection()
                }
                Button("Cancel", role: .cancel) {
                    pendingMetadataItem = nil
                }
            } message: {
                Text("You have unsaved metadata changes. Would you like to save them before switching?")
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: { fileManagerVM.goBack() }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!fileManagerVM.canGoBack)
                .help("Back")

                Button(action: { fileManagerVM.goForward() }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!fileManagerVM.canGoForward)
                .help("Forward")
            }

            ToolbarItem(placement: .principal) {
                viewModePicker
            }

            ToolbarItem(placement: .automatic) {
                Button(action: { invokeDirectoryComparison() }) {
                    Label("Compare Directories", systemImage: "arrow.left.arrow.right")
                }
                .help("Compare two selected directories")
            }

            ToolbarItem(placement: .automatic) {
                Button(action: {
                    fileManagerVM.metadataPanelVisible.toggle()
                    if fileManagerVM.metadataPanelVisible, let item = currentMetadataItem {
                        fileManagerVM.loadMetadata(for: item.url.path)
                        lastLoadedMetadata = fileManagerVM.selectedItemMetadata
                    }
                }) {
                    Image(systemName: "info.circle")
                }
                .help("Toggle Metadata Panel")
            }
        }
        // MARK: - Error Alerts
        .alert(
            "Error",
            isPresented: Binding(
                get: { fileManagerVM.errorMessage != nil },
                set: { if !$0 { fileManagerVM.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                fileManagerVM.errorMessage = nil
            }
        } message: {
            if let message = fileManagerVM.errorMessage {
                Text(message)
            }
        }
        .alert(
            "Tag Error",
            isPresented: Binding(
                get: { tagManagerVM.errorMessage != nil },
                set: { if !$0 { tagManagerVM.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                tagManagerVM.errorMessage = nil
            }
        } message: {
            if let message = tagManagerVM.errorMessage {
                Text(message)
            }
        }
        // MARK: - File Operation Keyboard Shortcuts
        // Comparison selection error alert
        .alert(
            "Compare Directories",
            isPresented: Binding(
                get: { comparisonSelectionError != nil },
                set: { if !$0 { comparisonSelectionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                comparisonSelectionError = nil
            }
        } message: {
            if let message = comparisonSelectionError {
                Text(message)
            }
        }
        // Comparison window sheet
        .sheet(isPresented: $showingComparisonSheet) {
            if let vm = comparisonVM {
                ComparisonWindow(viewModel: vm) { url in
                    showingComparisonSheet = false
                    fileManagerVM.navigateTo(url.deletingLastPathComponent())
                }
                .frame(minWidth: 600, minHeight: 400)
            }
        }
    }

    /// Segmented picker for switching between icon grid, list, and column view modes.
    private var viewModePicker: some View {
        Picker("View Mode", selection: $fileManagerVM.viewMode) {
            Image(systemName: "square.grid.2x2")
                .tag(ViewMode.iconGrid)
                .help("Icon View")
            Image(systemName: "list.bullet")
                .tag(ViewMode.list)
                .help("List View")
            Image(systemName: "rectangle.split.3x1")
                .tag(ViewMode.column)
                .help("Column View")
        }
        .pickerStyle(.segmented)
        .frame(width: 120)
    }

    // MARK: - Metadata Panel Selection Handling

    /// Handles selection change, checking for unsaved metadata edits first.
    private func handleSelectionChange(newSelection: Set<UUID>) {
        let newItem = fileManagerVM.fileItems.first { newSelection.contains($0.id) }

        guard fileManagerVM.metadataPanelVisible else {
            currentMetadataItem = newItem
            if let item = newItem {
                fileManagerVM.loadMetadata(for: item.url.path)
                lastLoadedMetadata = fileManagerVM.selectedItemMetadata
            }
            return
        }

        // Check for unsaved changes
        if hasUnsavedMetadataChanges(), newItem?.id != currentMetadataItem?.id {
            pendingMetadataItem = newItem
            showUnsavedMetadataAlert = true
        } else {
            currentMetadataItem = newItem
            if let item = newItem {
                fileManagerVM.loadMetadata(for: item.url.path)
                lastLoadedMetadata = fileManagerVM.selectedItemMetadata
            }
        }
    }

    /// Returns true if the current metadata text has been modified from the loaded value.
    private func hasUnsavedMetadataChanges() -> Bool {
        guard currentMetadataItem != nil else { return false }
        return fileManagerVM.selectedItemMetadata != lastLoadedMetadata
    }

    /// Commits the pending selection after the user resolves unsaved changes.
    private func commitPendingSelection() {
        currentMetadataItem = pendingMetadataItem
        if let item = pendingMetadataItem {
            fileManagerVM.loadMetadata(for: item.url.path)
            lastLoadedMetadata = fileManagerVM.selectedItemMetadata
        }
        pendingMetadataItem = nil
    }

    // MARK: - Directory Comparison

    /// Validates that exactly 2 directories are selected, then invokes comparison.
    private func invokeDirectoryComparison() {
        let selectedFileItems = fileManagerVM.fileItems.filter {
            fileManagerVM.selectedItems.contains($0.id)
        }
        let selectedDirectories = selectedFileItems.filter { $0.isDirectory }

        guard selectedDirectories.count == 2 else {
            comparisonSelectionError = "Please select exactly two directories to compare."
            return
        }

        let vm = DirectoryComparisonViewModel(
            comparatorService: DirectoryComparatorService(),
            fileSystemService: FileSystemService()
        )
        comparisonVM = vm
        showingComparisonSheet = true

        vm.compare(
            directory1: selectedDirectories[0].url,
            directory2: selectedDirectories[1].url
        )
    }
}
