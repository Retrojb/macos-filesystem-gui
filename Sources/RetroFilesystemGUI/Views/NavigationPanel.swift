import SwiftUI

/// Sidebar navigation panel displaying Favorites, Smart Folders, and Tags sections.
/// Requirements: 1.3, 1.4, 4.2, 4.6, 6.5, 6.7
struct NavigationPanel: View {
    var fileManagerVM: FileManagerViewModel
    var tagManagerVM: TagManagerViewModel

    @State private var smartFolders: [SmartFolder] = []
    @State private var highlightedTagId: UUID?
    private let smartFolderService: SmartFolderStorageServiceProtocol = SmartFolderStorageService()

    var body: some View {
        List {
            favoritesSection
            smartFoldersSection
            tagsSection
        }
        .listStyle(.sidebar)
        .onAppear {
            loadSmartFolders()
        }
    }

    // MARK: - Favorites Section

    private var favoritesSection: some View {
        Section("Favorites") {
            NavigationLink(value: desktopURL) {
                Label("Desktop", systemImage: "menubar.dock.rectangle")
            }
            .onTapGesture { navigateTo(desktopURL) }

            NavigationLink(value: documentsURL) {
                Label("Documents", systemImage: "doc.fill")
            }
            .onTapGesture { navigateTo(documentsURL) }

            NavigationLink(value: downloadsURL) {
                Label("Downloads", systemImage: "arrow.down.circle.fill")
            }
            .onTapGesture { navigateTo(downloadsURL) }

            ForEach(mountedVolumes, id: \.self) { volume in
                NavigationLink(value: volume) {
                    Label(volume.lastPathComponent, systemImage: "externaldrive.fill")
                }
                .onTapGesture { navigateTo(volume) }
            }
        }
    }

    // MARK: - Smart Folders Section

    private var smartFoldersSection: some View {
        Section("Smart Folders") {
            if smartFolders.isEmpty {
                Text("No Smart Folders")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(smartFolders) { folder in
                    Label(folder.name, systemImage: "folder.badge.gearshape")
                        .contextMenu {
                            Button("Edit") {
                                // Edit action placeholder
                            }
                            Button("Rename") {
                                // Rename action placeholder
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                deleteSmartFolder(folder)
                            }
                        }
                }
            }
        }
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        Section("Tags") {
            if tagManagerVM.tags.isEmpty {
                Text("No Tags")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(tagManagerVM.tags) { tag in
                    Label {
                        Text(tag.name)
                    } icon: {
                        Circle()
                            .fill(colorForTag(tag.color))
                            .frame(width: 10, height: 10)
                    }
                    .background(
                        fileManagerVM.selectedTagIds.contains(tag.id)
                            ? Color.accentColor.opacity(0.15)
                            : Color.clear
                    )
                    .cornerRadius(4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleTagSelection(tag.id)
                    }
                    .scaleEffect(highlightedTagId == tag.id ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 0.25), value: highlightedTagId)
                    .dropDestination(for: URL.self) { urls, _ in
                        let filePaths = urls.map { $0.path }
                        tagManagerVM.assignTag(tag.id, to: filePaths)
                        showDropConfirmation(for: tag.id)
                        return true
                    }
                }
            }
        }
    }

    /// Toggles a tag's selection for filtering.
    private func toggleTagSelection(_ tagId: UUID) {
        if fileManagerVM.selectedTagIds.contains(tagId) {
            fileManagerVM.selectedTagIds.remove(tagId)
        } else {
            fileManagerVM.selectedTagIds.insert(tagId)
        }
    }

    /// Briefly highlights the tag label after a successful drop.
    private func showDropConfirmation(for tagId: UUID) {
        highlightedTagId = tagId
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            highlightedTagId = nil
        }
    }

    // MARK: - Helpers

    private var desktopURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    }

    private var documentsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
    }

    private var downloadsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    }

    private var mountedVolumes: [URL] {
        let volumeURLs = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        ) ?? []
        // Filter out the root volume since it's already accessible
        return volumeURLs.filter { $0.path != "/" }
    }

    private func navigateTo(_ url: URL) {
        fileManagerVM.navigateTo(url)
    }

    private func loadSmartFolders() {
        do {
            let store = try smartFolderService.load()
            smartFolders = store.smartFolders
        } catch {
            smartFolders = []
        }
    }

    private func deleteSmartFolder(_ folder: SmartFolder) {
        smartFolders.removeAll { $0.id == folder.id }
        let store = SmartFolderStore(smartFolders: smartFolders)
        try? smartFolderService.save(store)
    }

    /// Maps a TagColor to a SwiftUI Color for display.
    private func colorForTag(_ tagColor: TagColor) -> Color {
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
