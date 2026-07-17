import SwiftUI

/// Main content view using NavigationSplitView with sidebar and detail panels.
/// Requirements: 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 3.1, 3.4, 3.5, 3.6
struct ContentView: View {
    @State private var fileManagerVM = FileManagerViewModel(
        fileSystemService: FileSystemService(),
        tagStorageService: TagStorageService()
    )
    @State private var tagManagerVM = TagManagerViewModel(
        storageService: TagStorageService()
    )

    var body: some View {
        NavigationSplitView {
            NavigationPanel(
                fileManagerVM: fileManagerVM,
                tagManagerVM: tagManagerVM
            )
        } detail: {
            VStack(spacing: 0) {
                PathBar(viewModel: fileManagerVM)
                FileBrowser(
                    fileManagerVM: fileManagerVM,
                    tagManagerVM: tagManagerVM,
                    isTagFilterActive: !fileManagerVM.selectedTagIds.isEmpty
                )
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
}
