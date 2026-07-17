import SwiftUI
import UniformTypeIdentifiers

/// Container view that switches between icon grid, list, and column browser views
/// based on the current view mode, and shows empty state placeholders when appropriate.
/// Also provides keyboard shortcuts and drag-and-drop at the browser level.
///
/// Requirements: 2.1, 2.2, 2.3, 1.12, 4.8, 6.6, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.8
struct FileBrowser: View {
    @Bindable var fileManagerVM: FileManagerViewModel
    var tagManagerVM: TagManagerViewModel

    /// Whether the current empty state is due to a tag filter (vs. an empty directory).
    var isTagFilterActive: Bool = false

    var body: some View {
        Group {
            if fileManagerVM.fileItems.isEmpty {
                emptyStateView
            } else {
                viewForCurrentMode
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .center) {
            if fileManagerVM.renamingItem != nil {
                inlineRenameOverlay
            }
        }
        // MARK: - Keyboard Shortcuts (Delete → Trash)
        .onDeleteCommand {
            fileManagerVM.deleteSelected()
        }
        // Cmd+C: Copy selected items to clipboard
        .onCopyCommand {
            fileManagerVM.copySelectedToClipboard()
            return selectedItemProviders()
        }
        // Cmd+V: Paste clipboard items into current directory
        .onPasteCommand(of: [UTType.fileURL]) { providers in
            fileManagerVM.pasteFromClipboard()
        }
        // Cmd+N: New Folder, Enter: Begin rename, Escape: Cancel rename
        .onKeyPress(.return) {
            if fileManagerVM.renamingItem != nil {
                fileManagerVM.commitRename()
            } else {
                fileManagerVM.beginRename()
            }
            return .handled
        }
        .onKeyPress(.escape) {
            if fileManagerVM.renamingItem != nil {
                fileManagerVM.cancelRename()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(phases: .down) { keyPress in
            if keyPress.characters == "n" && keyPress.modifiers == .command {
                fileManagerVM.createNewFolder()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.delete) {
            fileManagerVM.deleteSelected()
            return .handled
        }
        // Drop destination for drag-and-drop moves/copies
        .dropDestination(for: URL.self) { urls, _ in
            handleDrop(urls: urls)
            return true
        }
        // Name collision alert
        .alert(
            "Name Collision",
            isPresented: Binding(
                get: { fileManagerVM.pendingCollision != nil },
                set: { if !$0 { fileManagerVM.pendingCollision = nil } }
            ),
            presenting: fileManagerVM.pendingCollision
        ) { _ in
            Button("Replace") {
                fileManagerVM.resolveCollision(.replace)
            }
            Button("Keep Both") {
                fileManagerVM.resolveCollision(.keepBoth)
            }
            Button("Cancel", role: .cancel) {
                fileManagerVM.resolveCollision(.cancel)
            }
        } message: { collision in
            Text("An item named \"\(collision.fileName)\" already exists in the destination. What would you like to do?")
        }
    }

    // MARK: - View Mode Switching

    @ViewBuilder
    private var viewForCurrentMode: some View {
        switch fileManagerVM.viewMode {
        case .iconGrid:
            IconGridView(fileManagerVM: fileManagerVM, tagManagerVM: tagManagerVM)
        case .list:
            ListTableView(fileManagerVM: fileManagerVM, tagManagerVM: tagManagerVM)
        case .column:
            ColumnBrowserView(fileManagerVM: fileManagerVM, tagManagerVM: tagManagerVM)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(emptyStateMessage)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var emptyStateIcon: String {
        isTagFilterActive ? "tag.slash" : "folder"
    }

    private var emptyStateMessage: String {
        isTagFilterActive
            ? "No files match the selected tags"
            : "This folder is empty"
    }

    // MARK: - Inline Rename Overlay

    @ViewBuilder
    private var inlineRenameOverlay: some View {
        VStack {
            TextField("Name", text: $fileManagerVM.renameText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .onSubmit {
                    fileManagerVM.commitRename()
                }
                .onExitCommand {
                    fileManagerVM.cancelRename()
                }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .shadow(radius: 4)
        )
    }

    // MARK: - Drag-and-Drop Handling

    private func handleDrop(urls: [URL]) {
        // Check if Option key is currently held (copy mode)
        let optionHeld = NSEvent.modifierFlags.contains(.option)

        // Attempt to find matching FileItems from the current view
        let droppedItems = urls.compactMap { url -> FileItem? in
            fileManagerVM.fileItems.first(where: { $0.url == url })
        }

        guard !droppedItems.isEmpty else {
            // External URLs dropped – create temporary FileItem representations
            let externalItems = urls.map { url in
                FileItem(
                    id: UUID(),
                    url: url,
                    name: url.lastPathComponent,
                    isDirectory: false,
                    size: 0,
                    modificationDate: Date(),
                    creationDate: Date(),
                    kind: "Document",
                    isHidden: false
                )
            }
            if optionHeld {
                fileManagerVM.performCopyWithCollisionCheck(items: externalItems, to: fileManagerVM.currentDirectory)
            } else {
                fileManagerVM.moveItemsWithCollisionCheck(externalItems, to: fileManagerVM.currentDirectory)
            }
            return
        }

        // Option held = copy, otherwise move
        if optionHeld {
            fileManagerVM.performCopyWithCollisionCheck(items: droppedItems, to: fileManagerVM.currentDirectory)
        } else {
            fileManagerVM.moveItemsWithCollisionCheck(droppedItems, to: fileManagerVM.currentDirectory)
        }
    }

    /// Creates NSItemProvider representations for selected items (used by onCopyCommand).
    private func selectedItemProviders() -> [NSItemProvider] {
        let selectedFileItems = fileManagerVM.fileItems.filter {
            fileManagerVM.selectedItems.contains($0.id)
        }
        return selectedFileItems.map { item in
            NSItemProvider(object: item.url as NSURL)
        }
    }
}
