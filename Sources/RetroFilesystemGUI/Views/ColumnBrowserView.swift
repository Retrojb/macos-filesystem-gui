import AppKit
import SwiftUI

/// Column browser view displaying directories as horizontally-scrollable columns.
/// Selecting a folder expands its contents in the next column; selecting a file
/// shows a preview panel in the rightmost position.
///
/// Requirements: 2.3, 2.8, 4.2, 4.3, 4.4
struct ColumnBrowserView: View {
    var fileManagerVM: FileManagerViewModel
    var tagManagerVM: TagManagerViewModel
    var onAliasEdit: ((FileItem) -> Void)?
    var onEditSortingRules: ((FileItem) -> Void)?

    /// Each element is the list of FileItems for one directory level.
    /// The first column always reflects `fileManagerVM.fileItems`.
    @State private var columns: [[FileItem]] = []

    /// Tracks which item is selected in each column (by column index).
    @State private var selectedItemPerColumn: [Int: UUID] = [:]

    /// The file selected for preview (non-directory), if any.
    @State private var previewFile: FileItem?

    /// Service used to load subdirectory contents for deeper columns.
    private let fileSystemService = FileSystemService()

    /// Fixed width for each directory column.
    private let columnWidth: CGFloat = 220

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(columns.enumerated()), id: \.offset) { index, items in
                    columnView(items: items, columnIndex: index)
                        .frame(width: columnWidth)
                }

                if let file = previewFile {
                    filePreviewPanel(file: file)
                        .frame(width: columnWidth)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            initializeColumns()
        }
        .onChange(of: fileManagerVM.fileItems) { _, newItems in
            initializeColumns()
        }
    }

    // MARK: - Column View

    @ViewBuilder
    private func columnView(items: [FileItem], columnIndex: Int) -> some View {
        List(selection: Binding(
            get: { selectedItemPerColumn[columnIndex] },
            set: { newValue in
                handleSelection(newValue, inColumn: columnIndex)
            }
        )) {
            ForEach(items) { item in
                columnRow(item: item, columnIndex: columnIndex)
                    .tag(item.id)
            }
        }
        .listStyle(.plain)
        .border(Color(nsColor: .separatorColor), width: 0.5)
    }

    @ViewBuilder
    private func columnRow(item: FileItem, columnIndex: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundStyle(item.isDirectory ? .blue : .secondary)
                .frame(width: 16)

            Text(fileManagerVM.displayName(for: item))
                .italic(fileManagerVM.isAliased(item))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .overlay {
            if item.isDirectory, let count = fileManagerVM.unsortedCounts[item.url.path], count > 0 {
                SortStatusBadge(count: count) {
                    fileManagerVM.toggleUnsortedFilter(for: item.url)
                }
            }
        }
        .draggable(item.url)
        .onTapGesture(count: 2) {
            handleDoubleClick(item: item)
        }
        .onTapGesture(count: 1) {
            handleSelection(item.id, inColumn: columnIndex)
        }
        .tagContextMenu(item: item, fileManagerVM: fileManagerVM, tagManagerVM: tagManagerVM, onAliasEdit: onAliasEdit, onEditSortingRules: onEditSortingRules)
    }

    // MARK: - File Preview Panel

    @ViewBuilder
    private func filePreviewPanel(file: FileItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer()

            Image(systemName: "doc.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 8) {
                previewRow(label: "Name", value: file.name)
                previewRow(label: "Kind", value: file.kind)
                previewRow(label: "Size", value: formatFileSize(file.size))
                previewRow(label: "Modified", value: formattedDate(file.modificationDate))
            }
            .padding(.horizontal, 12)

            Spacer()
        }
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .border(Color(nsColor: .separatorColor), width: 0.5)
    }

    @ViewBuilder
    private func previewRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }

    // MARK: - Selection Handling

    private func handleSelection(_ itemId: UUID?, inColumn columnIndex: Int) {
        selectedItemPerColumn[columnIndex] = itemId

        // Clear selections in all columns after this one
        for key in selectedItemPerColumn.keys where key > columnIndex {
            selectedItemPerColumn.removeValue(forKey: key)
        }

        // Remove columns beyond the current one
        if columns.count > columnIndex + 1 {
            columns.removeSubrange((columnIndex + 1)...)
        }

        // Clear preview
        previewFile = nil

        guard let itemId = itemId,
              let item = columns[columnIndex].first(where: { $0.id == itemId }) else {
            return
        }

        if item.isDirectory {
            loadSubdirectory(item.url, afterColumn: columnIndex)
        } else {
            previewFile = item
        }
    }

    private func handleDoubleClick(item: FileItem) {
        if item.isDirectory {
            fileManagerVM.navigateTo(item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    // MARK: - Data Loading

    private func initializeColumns() {
        columns = [fileManagerVM.fileItems]
        selectedItemPerColumn = [:]
        previewFile = nil
    }

    private func loadSubdirectory(_ url: URL, afterColumn columnIndex: Int) {
        do {
            let items = try fileSystemService.contentsOfDirectory(at: url, showHidden: false)
            let sorted = items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            columns.append(sorted)
        } catch {
            // If we can't load the subdirectory, show an empty column
            columns.append([])
        }
    }

    // MARK: - Formatting

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
