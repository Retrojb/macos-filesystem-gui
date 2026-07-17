import SwiftUI

/// A compact sheet for assigning, editing, or removing an alias name for a file or folder.
/// Requirements: 4.1, 4.4, 4.8
struct AliasEditSheet: View {
    var viewModel: FileManagerViewModel
    var item: FileItem

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var aliasName: String = ""
    @State private var validationError: String?

    private var isExistingAlias: Bool {
        viewModel.isAliased(item)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            formContent
            Divider()
            footerBar
        }
        .frame(minWidth: 300, minHeight: 200)
        .onAppear {
            populateExistingAlias()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text(isExistingAlias ? "Edit Alias" : "Set Alias")
                .font(.headline)
            Spacer()
        }
        .padding()
    }

    // MARK: - Form Content

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Original filesystem name (read-only context)
            VStack(alignment: .leading, spacing: 4) {
                Text("Original Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            // Alias name text field
            VStack(alignment: .leading, spacing: 4) {
                Text("Alias Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Enter alias name", text: $aliasName)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: aliasName) {
                        validationError = nil
                    }

                if let validationError {
                    Text(validationError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            // Remove alias button (only when alias already exists)
            if isExistingAlias {
                Button(role: .destructive) {
                    removeAlias()
                } label: {
                    Text("Remove Alias")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
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

    private func populateExistingAlias() {
        if isExistingAlias {
            aliasName = viewModel.displayName(for: item)
        }
    }

    private func save() {
        validationError = nil

        let result = viewModel.setAlias(for: item, name: aliasName)
        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            validationError = errorMessage(for: error)
        }
    }

    private func removeAlias() {
        viewModel.removeAlias(for: item)
        dismiss()
    }

    private func errorMessage(for error: AliasValidationError) -> String {
        switch error {
        case .empty:
            return "Alias name cannot be empty."
        case .tooLong:
            return "Alias name must be 255 characters or fewer."
        case .containsSlash:
            return "Alias name cannot contain '/'."
        case .containsColon:
            return "Alias name cannot contain ':'."
        }
    }
}
