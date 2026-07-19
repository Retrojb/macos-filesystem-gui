import SwiftUI

/// Sidebar navigation panel displaying Favorites, Smart Folders, and Tags sections.
/// Requirements: 1.3, 1.4, 4.2, 4.6, 6.5, 6.7
struct NavigationPanel: View {
    var fileManagerVM: FileManagerViewModel
    var tagManagerVM: TagManagerViewModel

    @State private var smartFolders: [SmartFolder] = []
    @State private var highlightedTagId: UUID?
    @State private var expandedFavorites: Set<URL> = []
    @State private var childDirectories: [URL: [URL]] = [:]
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
            collapsibleFavoriteItem(
                url: desktopURL,
                label: "Desktop",
                icon: "menubar.dock.rectangle"
            )

            collapsibleFavoriteItem(
                url: documentsURL,
                label: "Documents",
                icon: "doc.fill"
            )

            collapsibleFavoriteItem(
                url: downloadsURL,
                label: "Downloads",
                icon: "arrow.down.circle.fill"
            )

            ForEach(mountedVolumes, id: \.self) { volume in
                collapsibleFavoriteItem(
                    url: volume,
                    label: volume.lastPathComponent,
                    icon: "externaldrive.fill"
                )
            }
        }
    }

    /// A favorite item with a disclosure triangle to show/hide child directories.
    @ViewBuilder
    private func collapsibleFavoriteItem(url: URL, label: String, icon: String) -> some View {
        let isExpanded = expandedFavorites.contains(url)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                // Disclosure triangle
                Button(action: { toggleExpansion(for: url) }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)

                Label(label, systemImage: icon)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                navigateTo(url)
            }

            if isExpanded, let children = childDirectories[url] {
                ForEach(children, id: \.self) { childURL in
                    HStack(spacing: 4) {
                        Spacer().frame(width: 16)
                        Label(childURL.lastPathComponent, systemImage: "folder")
                            .font(.callout)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        navigateTo(childURL)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    /// Toggles expansion state for a favorite and loads child directories if needed.
    private func toggleExpansion(for url: URL) {
        if expandedFavorites.contains(url) {
            expandedFavorites.remove(url)
        } else {
            expandedFavorites.insert(url)
            loadChildDirectories(for: url)
        }
    }

    /// Loads immediate child directories for the given URL.
    private func loadChildDirectories(for url: URL) {
        guard childDirectories[url] == nil else { return }

        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            let directories = contents.filter { childURL in
                let resourceValues = try? childURL.resourceValues(forKeys: [.isDirectoryKey])
                return resourceValues?.isDirectory == true
            }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            childDirectories[url] = directories
        } catch {
            childDirectories[url] = []
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
