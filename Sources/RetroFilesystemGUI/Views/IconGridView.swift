import AppKit
import SwiftUI

/// Icon grid view displaying file items as thumbnail icons in a responsive grid.
///
/// Requirements: 2.1, 1.2, 4.2, 4.3, 4.4
struct IconGridView: View {
    var fileManagerVM: FileManagerViewModel
    var tagManagerVM: TagManagerViewModel
    var onAliasEdit: ((FileItem) -> Void)?
    var onEditSortingRules: ((FileItem) -> Void)?

    private let columns = [
        GridItem(.adaptive(minimum: 100))
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(fileManagerVM.fileItems) { item in
                    IconGridItemView(
                        item: item,
                        isSelected: fileManagerVM.selectedItems.contains(item.id),
                        fileManagerVM: fileManagerVM,
                        tagManagerVM: tagManagerVM,
                        onAliasEdit: onAliasEdit,
                        onEditSortingRules: onEditSortingRules,
                        onSelect: { modifiers in
                            handleSelection(item: item, modifiers: modifiers)
                        },
                        onDoubleClick: {
                            handleDoubleClick(item: item)
                        }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Selection

    private func handleSelection(item: FileItem, modifiers: EventModifiers) {
        if modifiers.contains(.command) {
            // Command-click: toggle selection
            if fileManagerVM.selectedItems.contains(item.id) {
                fileManagerVM.selectedItems.remove(item.id)
            } else {
                fileManagerVM.selectedItems.insert(item.id)
            }
        } else {
            // Regular click: single select
            fileManagerVM.selectedItems = [item.id]
        }
    }

    // MARK: - Double-Click Navigation

    private func handleDoubleClick(item: FileItem) {
        if item.isDirectory {
            fileManagerVM.navigateTo(item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }
}

// MARK: - Grid Item View

/// Individual grid item showing an icon and file name.
struct IconGridItemView: View {
    let item: FileItem
    let isSelected: Bool
    var fileManagerVM: FileManagerViewModel
    var tagManagerVM: TagManagerViewModel
    var onAliasEdit: ((FileItem) -> Void)?
    var onEditSortingRules: ((FileItem) -> Void)?
    let onSelect: (EventModifiers) -> Void
    let onDoubleClick: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                .font(.system(size: 40))
                .foregroundStyle(item.isDirectory ? .blue : .gray)

            Text(fileManagerVM.displayName(for: item))
                .font(.caption)
                .italic(fileManagerVM.isAliased(item))
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .contentShape(Rectangle())
        .draggable(item.url)
        .onTapGesture(count: 2) {
            onDoubleClick()
        }
        .onTapGesture(count: 1) {
            onSelect(EventModifiers())
        }
        .simultaneousGesture(
            TapGesture(count: 1).modifiers(.command).onEnded {
                onSelect(.command)
            }
        )
        .overlay {
            if item.isDirectory, let count = fileManagerVM.unsortedCounts[item.url.path], count > 0 {
                SortStatusBadge(count: count) {
                    fileManagerVM.toggleUnsortedFilter(for: item.url)
                }
            }
        }
        .tagContextMenu(item: item, fileManagerVM: fileManagerVM, tagManagerVM: tagManagerVM, onAliasEdit: onAliasEdit, onEditSortingRules: onEditSortingRules)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(fileManagerVM.displayName(for: item))
        .accessibilityHint(item.isDirectory ? "Folder. Double-tap to open." : "File.")
    }
}
