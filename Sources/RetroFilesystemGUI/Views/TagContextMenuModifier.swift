import SwiftUI

/// A reusable view modifier that attaches a tag assignment context menu to file items.
/// The context menu shows a "Tags" submenu listing all available tags, with checkmarks
/// indicating which tags are already assigned to the selected file(s).
///
/// Requirements: 6.1, 6.3, 6.7
struct TagContextMenuModifier: ViewModifier {
    var item: FileItem
    var fileManagerVM: FileManagerViewModel
    var tagManagerVM: TagManagerViewModel

    func body(content: Content) -> some View {
        content.contextMenu {
            tagSubmenu
        }
    }

    // MARK: - Tags Submenu

    @ViewBuilder
    private var tagSubmenu: some View {
        Menu("Tags") {
            if tagManagerVM.tags.isEmpty {
                Text("No Tags Available")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tagManagerVM.tags) { tag in
                    Button {
                        toggleTag(tag)
                    } label: {
                        HStack {
                            if isTagAssigned(tag) {
                                Image(systemName: "checkmark")
                            }
                            Label {
                                Text(tag.name)
                            } icon: {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(swiftUIColor(for: tag.color))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Logic

    /// Returns the file paths of all currently selected items (including the right-clicked item).
    private var affectedFilePaths: [String] {
        var selectedIds = fileManagerVM.selectedItems
        // Ensure the right-clicked item is included even if not already selected
        selectedIds.insert(item.id)

        return fileManagerVM.fileItems
            .filter { selectedIds.contains($0.id) }
            .map { $0.url.path }
    }

    /// Checks if a tag is assigned to ALL affected items.
    private func isTagAssigned(_ tag: Tag) -> Bool {
        let paths = affectedFilePaths
        return paths.allSatisfy { path in
            tagManagerVM.tagsForFile(path).contains(where: { $0.id == tag.id })
        }
    }

    /// Toggles tag assignment: removes if assigned to all affected items, assigns otherwise.
    private func toggleTag(_ tag: Tag) {
        let paths = affectedFilePaths
        if isTagAssigned(tag) {
            tagManagerVM.removeTag(tag.id, from: paths)
        } else {
            tagManagerVM.assignTag(tag.id, to: paths)
        }
    }

    /// Converts a `TagColor` enum value to a SwiftUI `Color`.
    private func swiftUIColor(for tagColor: TagColor) -> Color {
        switch tagColor {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .gray: return .gray
        case .pink: return .pink
        }
    }
}

// MARK: - View Extension

extension View {
    /// Attaches a tag context menu to a file item view, operating on all selected items.
    func tagContextMenu(
        item: FileItem,
        fileManagerVM: FileManagerViewModel,
        tagManagerVM: TagManagerViewModel
    ) -> some View {
        modifier(TagContextMenuModifier(
            item: item,
            fileManagerVM: fileManagerVM,
            tagManagerVM: tagManagerVM
        ))
    }
}
