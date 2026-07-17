import SwiftUI

/// List view displaying file items in a sortable table with columns for
/// name, date modified, size, and kind. Supports multi-selection and
/// displays tag color indicators on tagged items.
///
/// Requirements: 2.2, 2.6, 2.7, 6.2, 6.8, 4.2, 4.3, 4.4
struct ListTableView: View {
    @Bindable var fileManagerVM: FileManagerViewModel
    var tagManagerVM: TagManagerViewModel
    var onAliasEdit: ((FileItem) -> Void)?
    var onEditSortingRules: ((FileItem) -> Void)?

    @State private var sortOrder: [KeyPathComparator<FileItem>] = [
        KeyPathComparator(\.name, order: .forward)
    ]

    var body: some View {
        Table(fileManagerVM.fileItems, selection: $fileManagerVM.selectedItems, sortOrder: $sortOrder) {
            TableColumn("Name", sortUsing: KeyPathComparator(\.name)) { item in
                nameCell(for: item)
                    .tagContextMenu(item: item, fileManagerVM: fileManagerVM, tagManagerVM: tagManagerVM, onAliasEdit: onAliasEdit, onEditSortingRules: onEditSortingRules)
            }
            .width(min: 200)

            TableColumn("Date Modified", sortUsing: KeyPathComparator(\.modificationDate)) { item in
                Text(item.modificationDate, style: .date)
                    .foregroundStyle(.secondary)
            }
            .width(min: 120)

            TableColumn("Size", sortUsing: KeyPathComparator(\.size)) { item in
                Text(item.isDirectory ? "--" : formatFileSize(item.size))
                    .foregroundStyle(.secondary)
            }
            .width(min: 80)

            TableColumn("Kind", sortUsing: KeyPathComparator(\.kind)) { item in
                Text(item.kind)
                    .foregroundStyle(.secondary)
            }
            .width(min: 100)
        }
        .onChange(of: sortOrder) { _, newOrder in
            guard let firstComparator = newOrder.first else { return }
            let ascending = firstComparator.order == .forward

            let column: SortColumn
            switch firstComparator.keyPath {
            case \FileItem.name:
                column = .name
            case \FileItem.modificationDate:
                column = .dateModified
            case \FileItem.size:
                column = .size
            case \FileItem.kind:
                column = .kind
            default:
                column = .name
            }

            fileManagerVM.sortColumn = column
            fileManagerVM.sortAscending = ascending
        }
    }

    // MARK: - Name Cell

    @ViewBuilder
    private func nameCell(for item: FileItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                    .foregroundStyle(item.isDirectory ? .blue : .secondary)
                    .frame(width: 16)

                Text(fileManagerVM.displayName(for: item))
                    .italic(fileManagerVM.isAliased(item))
                    .lineLimit(1)

                tagIndicators(for: item)
            }

            // Video metadata placeholder for video files
            if isVideoFile(item) {
                Text("Video metadata: duration, resolution")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .overlay {
            if item.isDirectory, let count = fileManagerVM.unsortedCounts[item.url.path], count > 0 {
                SortStatusBadge(count: count) {
                    fileManagerVM.toggleUnsortedFilter(for: item.url)
                }
            }
        }
        .draggable(item.url)
    }

    // MARK: - Tag Indicators

    @ViewBuilder
    private func tagIndicators(for item: FileItem) -> some View {
        let tags = tagManagerVM.tagsForFile(item.url.path)
        if !tags.isEmpty {
            HStack(spacing: 3) {
                ForEach(tags) { tag in
                    Circle()
                        .fill(swiftUIColor(for: tag.color))
                        .frame(width: 8, height: 8)
                }
            }
        }
    }

    // MARK: - Helpers

    /// Determines if a file item is a video file based on its kind.
    private func isVideoFile(_ item: FileItem) -> Bool {
        let kind = item.kind.lowercased()
        return kind.contains("movie") || kind.contains("video")
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
