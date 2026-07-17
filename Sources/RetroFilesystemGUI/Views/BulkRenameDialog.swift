import SwiftUI

/// Dialog for configuring and previewing bulk rename operations.
/// Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.9
struct BulkRenameDialog: View {
    var bulkRenameVM: BulkRenameViewModel

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedRuleType: RuleType = .findReplace

    // Find-and-Replace fields
    @State private var findText = ""
    @State private var replaceText = ""

    // Sequential Numbering fields
    @State private var numberPosition: RenameRule.Position = .prepend
    @State private var startNumber: String = "1"
    @State private var padding: Int = 1

    // Date Insertion fields
    @State private var datePosition: RenameRule.Position = .prepend
    @State private var dateSource: RenameRule.DateSource = .creation
    @State private var dateFormat: String = "yyyy-MM-dd"

    // MARK: - Rule Type Enum

    enum RuleType: String, CaseIterable, Identifiable {
        case findReplace = "Find & Replace"
        case sequentialNumbering = "Sequential Numbering"
        case dateInsertion = "Date Insertion"

        var id: String { rawValue }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            ruleConfiguration
            Divider()
            previewSection
            Divider()
            footerBar
        }
        .frame(minWidth: 560, minHeight: 480)
        .onChange(of: selectedRuleType) { _, _ in
            updateRule()
        }
        .onChange(of: findText) { _, _ in updateRule() }
        .onChange(of: replaceText) { _, _ in updateRule() }
        .onChange(of: numberPosition) { _, _ in updateRule() }
        .onChange(of: startNumber) { _, _ in updateRule() }
        .onChange(of: padding) { _, _ in updateRule() }
        .onChange(of: datePosition) { _, _ in updateRule() }
        .onChange(of: dateSource) { _, _ in updateRule() }
        .onChange(of: dateFormat) { _, _ in updateRule() }
        .onAppear {
            updateRule()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text("Bulk Rename")
                .font(.headline)
            Spacer()
            Text("\(bulkRenameVM.selectedFiles.count) files selected")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .padding()
    }

    // MARK: - Rule Configuration

    private var ruleConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Rule Type:", selection: $selectedRuleType) {
                ForEach(RuleType.allCases) { ruleType in
                    Text(ruleType.rawValue).tag(ruleType)
                }
            }
            .pickerStyle(.segmented)

            switch selectedRuleType {
            case .findReplace:
                findReplaceFields
            case .sequentialNumbering:
                sequentialNumberingFields
            case .dateInsertion:
                dateInsertionFields
            }
        }
        .padding()
    }

    private var findReplaceFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Find:")
                    .frame(width: 60, alignment: .trailing)
                TextField("Text to find", text: $findText)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("Replace:")
                    .frame(width: 60, alignment: .trailing)
                TextField("Replacement text", text: $replaceText)
                    .textFieldStyle(.roundedBorder)
            }
            if findText.count > 255 {
                Text("Find pattern must be 1–255 characters.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if replaceText.count > 255 {
                Text("Replacement must be 0–255 characters.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var sequentialNumberingFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Position:")
                    .frame(width: 80, alignment: .trailing)
                Picker("Position", selection: $numberPosition) {
                    Text("Prepend").tag(RenameRule.Position.prepend)
                    Text("Append").tag(RenameRule.Position.append)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            HStack {
                Text("Start at:")
                    .frame(width: 80, alignment: .trailing)
                TextField("1", text: $startNumber)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }
            HStack {
                Text("Padding:")
                    .frame(width: 80, alignment: .trailing)
                Stepper("\(padding) digit\(padding == 1 ? "" : "s")", value: $padding, in: 1...6)
            }
        }
    }

    private var dateInsertionFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Position:")
                    .frame(width: 80, alignment: .trailing)
                Picker("Position", selection: $datePosition) {
                    Text("Prepend").tag(RenameRule.Position.prepend)
                    Text("Append").tag(RenameRule.Position.append)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            HStack {
                Text("Source:")
                    .frame(width: 80, alignment: .trailing)
                Picker("Date Source", selection: $dateSource) {
                    Text("Creation Date").tag(RenameRule.DateSource.creation)
                    Text("Modification Date").tag(RenameRule.DateSource.modification)
                }
                .labelsHidden()
            }
            HStack {
                Text("Format:")
                    .frame(width: 80, alignment: .trailing)
                TextField("yyyy-MM-dd", text: $dateFormat)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Preview")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if bulkRenameVM.previews.contains(where: { $0.hasConflict }) {
                    Label("Conflicts detected", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if bulkRenameVM.previews.isEmpty {
                Text("Configure a rule above to see the preview.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                previewTable
            }
        }
    }

    private var previewTable: some View {
        List {
            // Header row
            HStack {
                Text("Original")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("→")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Result")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ForEach(Array(bulkRenameVM.previews.enumerated()), id: \.offset) { _, preview in
                previewRow(preview)
            }
        }
        .listStyle(.inset)
    }

    private func previewRow(_ preview: (original: String, result: String, hasConflict: Bool)) -> some View {
        HStack {
            Text(preview.original)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text(preview.result)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(preview.hasConflict ? .red : .primary)
                    .fontWeight(preview.hasConflict ? .semibold : .regular)

                if preview.hasConflict {
                    if preview.result.count > 255 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .help("Filename exceeds 255 characters")
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .help("Duplicate filename conflict")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .background(preview.hasConflict ? Color.red.opacity(0.05) : Color.clear)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            if let errorMessage = bulkRenameVM.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            Spacer()

            Button("Undo") {
                _ = bulkRenameVM.undo()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!bulkRenameVM.canUndo)

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Rename") {
                let result = bulkRenameVM.confirm()
                if case .success = result {
                    dismiss()
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!bulkRenameVM.canConfirm)
        }
        .padding()
    }

    // MARK: - Rule Update

    /// Builds a RenameRule from the current UI state and assigns it to the ViewModel.
    private func updateRule() {
        switch selectedRuleType {
        case .findReplace:
            guard !findText.isEmpty, findText.count <= 255, replaceText.count <= 255 else {
                bulkRenameVM.rule = nil
                return
            }
            bulkRenameVM.rule = .findReplace(find: findText, replace: replaceText)

        case .sequentialNumbering:
            let start = Int(startNumber) ?? 1
            bulkRenameVM.rule = .sequentialNumbering(
                position: numberPosition,
                start: start,
                padding: padding
            )

        case .dateInsertion:
            guard !dateFormat.isEmpty else {
                bulkRenameVM.rule = nil
                return
            }
            bulkRenameVM.rule = .dateInsertion(
                position: datePosition,
                dateSource: dateSource,
                format: dateFormat
            )
        }
    }
}
