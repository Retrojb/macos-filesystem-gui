import SwiftUI

/// A sheet view for adding, editing, and deleting sorting rules for a directory.
/// Requirements: 1.1, 1.4, 1.6
struct SortingRulesEditor: View {
    var viewModel: SortingRulesViewModel

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedRuleType: SortingRuleType = .fileExtension
    @State private var patternText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            formContent
            Divider()
            footerBar
        }
        .frame(minWidth: 400, minHeight: 400)
        .onAppear {
            viewModel.loadRules()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sorting Rules")
                    .font(.headline)
                Text(directoryDisplayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - Form Content

    private var formContent: some View {
        Form {
            addRuleSection
            existingRulesSection
        }
        .formStyle(.grouped)
    }

    // MARK: - Add Rule Section

    private var addRuleSection: some View {
        Section("Add Rule") {
            Picker("Rule Type", selection: $selectedRuleType) {
                Text("File Extension").tag(SortingRuleType.fileExtension)
                Text("Name Pattern").tag(SortingRuleType.namePattern)
                Text("Tag").tag(SortingRuleType.tag)
            }

            TextField(placeholderText, text: $patternText)
                .textFieldStyle(.roundedBorder)

            if let error = viewModel.validationError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button("Add Rule") {
                addRule()
            }
            .disabled(patternText.isEmpty)
        }
    }

    // MARK: - Existing Rules Section

    private var existingRulesSection: some View {
        Section("Existing Rules (\(viewModel.rules.count))") {
            if viewModel.rules.isEmpty {
                Text("No rules configured")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                List {
                    ForEach(viewModel.rules) { rule in
                        ruleRow(rule)
                    }
                    .onDelete(perform: deleteRules)
                }
            }
        }
    }

    // MARK: - Rule Row

    private func ruleRow(_ rule: SortingRule) -> some View {
        HStack {
            Text(ruleTypeLabel(rule.ruleType))
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(4)
            Text(rule.pattern)
                .lineLimit(1)
            Spacer()
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
        }
        .padding()
    }

    // MARK: - Actions

    private func addRule() {
        let result = viewModel.addRule(ruleType: selectedRuleType, pattern: patternText)
        if case .success = result {
            patternText = ""
            viewModel.validationError = nil
        }
    }

    private func deleteRules(at offsets: IndexSet) {
        for index in offsets {
            let rule = viewModel.rules[index]
            viewModel.deleteRule(id: rule.id)
        }
    }

    // MARK: - Helpers

    private var directoryDisplayName: String {
        (viewModel.directoryPath as NSString).lastPathComponent
    }

    private var placeholderText: String {
        switch selectedRuleType {
        case .fileExtension:
            return "e.g. pdf, txt, png"
        case .namePattern:
            return "e.g. *.txt, report-*"
        case .tag:
            return "Tag UUID"
        }
    }

    private func ruleTypeLabel(_ ruleType: SortingRuleType) -> String {
        switch ruleType {
        case .fileExtension:
            return "Extension"
        case .namePattern:
            return "Pattern"
        case .tag:
            return "Tag"
        }
    }
}
