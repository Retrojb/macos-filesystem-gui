import SwiftUI

/// A view for managing tags: create, edit, and delete tags with color selection.
/// Requirements: 5.1, 5.2, 5.3, 5.4, 5.5
struct TagManagementView: View {
    var tagManagerVM: TagManagerViewModel

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var isCreating = false
    @State private var editingTagId: UUID?

    // Form fields
    @State private var formName = ""
    @State private var formColor: TagColor = .blue

    // Delete confirmation
    @State private var tagToDelete: Tag?
    @State private var showDeleteConfirmation = false

    // Error display
    @State private var validationError: String?

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            tagList
        }
        .frame(minWidth: 360, minHeight: 400)
        .alert("Delete Tag", isPresented: $showDeleteConfirmation, presenting: tagToDelete) { tag in
            Button("Cancel", role: .cancel) {
                tagToDelete = nil
            }
            Button("Delete", role: .destructive) {
                tagManagerVM.deleteTag(id: tag.id)
                tagToDelete = nil
            }
        } message: { tag in
            let count = affectedFileCount(for: tag.id)
            if count > 0 {
                Text("This will remove the tag \"\(tag.name)\" from \(count) file\(count == 1 ? "" : "s").")
            } else {
                Text("Are you sure you want to delete the tag \"\(tag.name)\"?")
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text("Manage Tags")
                .font(.headline)
            Spacer()
            Button {
                startCreating()
            } label: {
                Label("New Tag", systemImage: "plus")
            }
            .disabled(isCreating)

            Button("Done") {
                dismiss()
            }
        }
        .padding()
    }

    // MARK: - Tag List

    private var tagList: some View {
        List {
            if isCreating {
                tagFormRow(isNew: true)
            }

            ForEach(tagManagerVM.tags) { tag in
                if editingTagId == tag.id {
                    tagFormRow(isNew: false)
                } else {
                    tagRow(tag)
                }
            }

            if tagManagerVM.tags.isEmpty && !isCreating {
                Text("No tags yet. Click \"New Tag\" to create one.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Tag Row (Display)

    private func tagRow(_ tag: Tag) -> some View {
        HStack {
            Circle()
                .fill(colorForTag(tag.color))
                .frame(width: 12, height: 12)

            Text(tag.name)
                .lineLimit(1)

            Spacer()

            Button {
                startEditing(tag)
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Edit tag")

            Button(role: .destructive) {
                tagToDelete = tag
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete tag")
        }
        .contentShape(Rectangle())
    }

    // MARK: - Tag Form Row (Create / Edit)

    private func tagFormRow(isNew: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Tag name", text: $formName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                    .onSubmit {
                        commitForm(isNew: isNew)
                    }
            }

            HStack(spacing: 6) {
                ForEach(TagColor.allCases, id: \.self) { tagColor in
                    Circle()
                        .fill(colorForTag(tagColor))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary, lineWidth: formColor == tagColor ? 2 : 0)
                        )
                        .onTapGesture {
                            formColor = tagColor
                        }
                }
            }

            if let validationError {
                Text(validationError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") {
                    cancelForm()
                }
                .keyboardShortcut(.cancelAction)

                Button(isNew ? "Create" : "Save") {
                    commitForm(isNew: isNew)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(formName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func startCreating() {
        editingTagId = nil
        formName = ""
        formColor = .blue
        validationError = nil
        isCreating = true
    }

    private func startEditing(_ tag: Tag) {
        isCreating = false
        formName = tag.name
        formColor = tag.color
        validationError = nil
        editingTagId = tag.id
    }

    private func cancelForm() {
        isCreating = false
        editingTagId = nil
        validationError = nil
        formName = ""
        formColor = .blue
    }

    private func commitForm(isNew: Bool) {
        let trimmedName = formName.trimmingCharacters(in: .whitespaces)

        // Client-side validation
        guard !trimmedName.isEmpty else {
            validationError = "Tag name cannot be empty."
            return
        }
        guard trimmedName.count <= 64 else {
            validationError = "Tag name cannot exceed 64 characters."
            return
        }

        if isNew {
            let result = tagManagerVM.createTag(name: trimmedName, color: formColor)
            switch result {
            case .success:
                cancelForm()
            case .failure:
                validationError = tagManagerVM.errorMessage
            }
        } else if let tagId = editingTagId {
            let result = tagManagerVM.editTag(id: tagId, name: trimmedName, color: formColor)
            switch result {
            case .success:
                cancelForm()
            case .failure:
                validationError = tagManagerVM.errorMessage
            }
        }
    }

    // MARK: - Helpers

    private func affectedFileCount(for tagId: UUID) -> Int {
        tagManagerVM.associations.filter { $0.tagId == tagId }.count
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
