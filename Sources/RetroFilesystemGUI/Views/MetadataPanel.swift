import SwiftUI

/// Side panel for viewing and editing JSON metadata associated with a file item.
/// Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 6.1, 6.2, 6.4
struct MetadataPanel: View {
    var viewModel: FileManagerViewModel
    var selectedItem: FileItem?

    var body: some View {
        VStack(spacing: 0) {
            if let item = selectedItem {
                headerSection(for: item)
                Divider()
                editorSection(for: item)
            } else {
                placeholderView
            }
        }
        .frame(minWidth: 200, idealWidth: 300, maxWidth: 400)
    }

    // MARK: - Placeholder

    private var placeholderView: some View {
        VStack {
            Spacer()
            Text("No item selected")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Header

    private func headerSection(for item: FileItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name)
                .font(.headline)
                .bold()
                .lineLimit(1)
            Text(PathTruncation.truncate(path: item.url.path))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Editor

    private func editorSection(for item: FileItem) -> some View {
        VStack(spacing: 8) {
            TextEditor(text: Binding(
                get: { viewModel.selectedItemMetadata },
                set: { viewModel.selectedItemMetadata = $0 }
            ))
            .font(.system(.body, design: .monospaced))

            if let error = viewModel.metadataValidationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            buttonBar(for: item)
        }
        .padding()
    }

    // MARK: - Button Bar

    private func buttonBar(for item: FileItem) -> some View {
        HStack {
            Button("Save") {
                _ = viewModel.saveMetadata(
                    jsonText: viewModel.selectedItemMetadata,
                    for: item.url.path
                )
            }

            Button("Undo") {
                viewModel.undoMetadata(for: item.url.path)
            }
            .disabled(viewModel.previousMetadataState == nil)

            Spacer()
        }
    }
}
