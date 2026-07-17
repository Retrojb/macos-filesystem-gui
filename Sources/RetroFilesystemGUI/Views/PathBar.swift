import SwiftUI

/// Breadcrumb path bar displaying the current directory as clickable path components.
/// Clicking the bar switches to an editable text field; pressing Return navigates.
/// Requirements: 1.10
struct PathBar: View {
    var viewModel: FileManagerViewModel

    @State private var isEditing = false
    @State private var editedPath: String = ""
    @FocusState private var textFieldFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            if isEditing {
                editablePathField
            } else {
                breadcrumbBar
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
        .onChange(of: viewModel.currentDirectory) {
            // Reset editing state when directory changes externally
            isEditing = false
        }
    }

    // MARK: - Breadcrumb Mode

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(Array(pathComponents.enumerated()), id: \.offset) { index, component in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        navigateToComponent(at: index)
                    } label: {
                        Text(component.name)
                            .font(.callout)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(index == pathComponents.count - 1 ? .primary : .secondary)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            enterEditMode()
        }
    }

    // MARK: - Edit Mode

    private var editablePathField: some View {
        TextField("Path", text: $editedPath)
            .textFieldStyle(.plain)
            .font(.callout)
            .focused($textFieldFocused)
            .onSubmit {
                navigateToEditedPath()
            }
            .onExitCommand {
                isEditing = false
            }
            .onAppear {
                textFieldFocused = true
            }
    }

    // MARK: - Helpers

    private struct PathComponent {
        let name: String
        let url: URL
    }

    private var pathComponents: [PathComponent] {
        var components: [PathComponent] = []
        var url = viewModel.currentDirectory.standardizedFileURL

        // Build path from root to current directory
        var urls: [URL] = []
        while url.path != "/" {
            urls.insert(url, at: 0)
            url = url.deletingLastPathComponent()
        }
        // Add root
        urls.insert(URL(fileURLWithPath: "/"), at: 0)

        for u in urls {
            let name = u.path == "/" ? "/" : u.lastPathComponent
            components.append(PathComponent(name: name, url: u))
        }

        return components
    }

    private func navigateToComponent(at index: Int) {
        let components = pathComponents
        guard index < components.count else { return }
        let target = components[index].url
        if target != viewModel.currentDirectory {
            viewModel.navigateTo(target)
        }
    }

    private func enterEditMode() {
        editedPath = viewModel.currentDirectory.path
        isEditing = true
    }

    private func navigateToEditedPath() {
        let trimmed = editedPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isEditing = false
            return
        }

        let expandedPath = NSString(string: trimmed).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            viewModel.navigateTo(url)
        }

        isEditing = false
    }
}
