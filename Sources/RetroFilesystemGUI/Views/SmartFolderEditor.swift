import SwiftUI

/// A sheet/form view for creating or editing a Smart Folder.
/// Requirements: 4.1, 4.7
struct SmartFolderEditor: View {
    var tagManagerVM: TagManagerViewModel

    /// Optional existing folder for edit mode. If nil, creates a new folder.
    var existingFolder: SmartFolder?

    /// Called with the saved SmartFolder on successful save.
    var onSave: ((SmartFolder) -> Void)?

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var name: String = ""
    @State private var selectedTagIds: Set<UUID> = []
    @State private var fileType: String = ""
    @State private var useDateRange: Bool = false
    @State private var dateRangeStart: Date = Date()
    @State private var dateRangeEnd: Date = Date()
    @State private var validationError: String?

    private let smartFolderService: SmartFolderStorageServiceProtocol = SmartFolderStorageService()

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            formContent
            Divider()
            footerBar
        }
        .frame(minWidth: 400, minHeight: 450)
        .onAppear {
            populateFromExisting()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text(existingFolder == nil ? "New Smart Folder" : "Edit Smart Folder")
                .font(.headline)
            Spacer()
        }
        .padding()
    }

    // MARK: - Form Content

    private var formContent: some View {
        Form {
            nameSection
            tagSelectionSection
            fileTypeSection
            dateRangeSection

            if let validationError {
                Section {
                    Text(validationError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Name Section

    private var nameSection: some View {
        Section("Name") {
            TextField("Smart Folder name", text: $name)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Tag Selection Section

    private var tagSelectionSection: some View {
        Section("Tags") {
            if tagManagerVM.tags.isEmpty {
                Text("No tags available")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(tagManagerVM.tags) { tag in
                    HStack {
                        Circle()
                            .fill(colorForTag(tag.color))
                            .frame(width: 10, height: 10)
                        Text(tag.name)
                        Spacer()
                        if selectedTagIds.contains(tag.id) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleTag(tag.id)
                    }
                }
            }
        }
    }

    // MARK: - File Type Section

    private var fileTypeSection: some View {
        Section("File Type (UTI)") {
            TextField("e.g. public.image, public.movie", text: $fileType)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Date Range Section

    private var dateRangeSection: some View {
        Section("Date Range") {
            Toggle("Filter by date range", isOn: $useDateRange)

            if useDateRange {
                DatePicker("Start date", selection: $dateRangeStart, displayedComponents: .date)
                DatePicker("End date", selection: $dateRangeEnd, displayedComponents: .date)
            }
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Save") {
                save()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }

    // MARK: - Actions

    private func toggleTag(_ tagId: UUID) {
        if selectedTagIds.contains(tagId) {
            selectedTagIds.remove(tagId)
        } else {
            selectedTagIds.insert(tagId)
        }
    }

    private func save() {
        validationError = nil

        let criteria = SmartFolderCriteria(
            requiredTagIds: Array(selectedTagIds),
            fileType: fileType.trimmingCharacters(in: .whitespaces).isEmpty ? nil : fileType.trimmingCharacters(in: .whitespaces),
            dateRangeStart: useDateRange ? dateRangeStart : nil,
            dateRangeEnd: useDateRange ? dateRangeEnd : nil
        )

        // Load existing folders for duplicate check
        let existingFolders: [SmartFolder]
        do {
            let store = try smartFolderService.load()
            // Exclude the current folder being edited from duplicate checks
            if let editing = existingFolder {
                existingFolders = store.smartFolders.filter { $0.id != editing.id }
            } else {
                existingFolders = store.smartFolders
            }
        } catch {
            validationError = "Failed to load smart folders."
            return
        }

        // Validate using the service
        if let error = smartFolderService.validate(name: name, criteria: criteria, existingFolders: existingFolders) {
            switch error {
            case .invalidName:
                validationError = "Name must be 1-64 characters"
            case .duplicateName:
                validationError = "A smart folder with this name already exists"
            case .noCriteria:
                validationError = "At least one filter criterion is required"
            }
            return
        }

        // Create or update the smart folder
        let folder: SmartFolder
        if let existing = existingFolder {
            folder = SmartFolder(id: existing.id, name: name, criteria: criteria)
        } else {
            folder = SmartFolder(id: UUID(), name: name, criteria: criteria)
        }

        // Persist
        do {
            var store = try smartFolderService.load()
            if let existingIndex = store.smartFolders.firstIndex(where: { $0.id == folder.id }) {
                store.smartFolders[existingIndex] = folder
            } else {
                store.smartFolders.append(folder)
            }
            try smartFolderService.save(store)
        } catch {
            validationError = "Failed to save smart folder."
            return
        }

        onSave?(folder)
        dismiss()
    }

    private func populateFromExisting() {
        guard let folder = existingFolder else { return }
        name = folder.name
        selectedTagIds = Set(folder.criteria.requiredTagIds)
        fileType = folder.criteria.fileType ?? ""
        if folder.criteria.dateRangeStart != nil || folder.criteria.dateRangeEnd != nil {
            useDateRange = true
            dateRangeStart = folder.criteria.dateRangeStart ?? Date()
            dateRangeEnd = folder.criteria.dateRangeEnd ?? Date()
        }
    }

    // MARK: - Helpers

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
