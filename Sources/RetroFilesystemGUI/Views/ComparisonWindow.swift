import SwiftUI

/// A standalone window displaying the results of a directory comparison.
/// Shows three sections: files unique to each directory and files present in both.
///
/// Requirements: 3.3, 3.4, 3.7, 3.8, 3.9
struct ComparisonWindow: View {
    var viewModel: DirectoryComparisonViewModel

    /// Optional callback invoked when a user clicks an item to navigate to it in the main browser.
    var onNavigateToFile: ((URL) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isComparing {
                progressContent
            } else if let errorMessage = viewModel.errorMessage {
                errorContent(message: errorMessage)
            } else if let result = viewModel.comparisonResult {
                comparisonContent(result: result)
            } else {
                placeholderContent
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    // MARK: - Progress

    private var progressContent: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Comparing directories…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error

    private func errorContent(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Placeholder

    private var placeholderContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.questionmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Select two directories and compare to see results.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Comparison Content

    private func comparisonContent(result: DirectoryComparisonResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                comparisonSection(
                    title: "Only in \(result.directory1Name)",
                    items: result.uniqueToFirst
                )
                comparisonSection(
                    title: "Only in \(result.directory2Name)",
                    items: result.uniqueToSecond
                )
                comparisonSection(
                    title: "In Both",
                    items: result.inBoth
                )
            }
            .padding()
        }
    }

    // MARK: - Section

    private func comparisonSection(title: String, items: [ComparisonItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            if items.isEmpty {
                Text("No files found")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .padding(.leading, 4)
            } else {
                ForEach(items) { item in
                    comparisonItemRow(item: item)
                }
            }
        }
    }

    // MARK: - Item Row

    private func comparisonItemRow(item: ComparisonItem) -> some View {
        HStack {
            Image(systemName: item.isDirectory ? "folder" : "doc")
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(item.name)
                .lineLimit(1)

            Spacer()

            Text(formatSize(item.size))
                .foregroundStyle(.secondary)
                .font(.callout)
                .frame(width: 80, alignment: .trailing)

            Text(formatDate(item.modificationDate))
                .foregroundStyle(.secondary)
                .font(.callout)
                .frame(width: 140, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onNavigateToFile?(item.sourceURL)
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.primary.opacity(0.04))
        )
    }

    // MARK: - Formatting

    /// Formats a file size into a human-readable string.
    /// - bytes for < 1024
    /// - KB for < 1 MB (1 decimal place)
    /// - MB for < 1 GB (1 decimal place)
    /// - GB otherwise (1 decimal place)
    static func formatSize(_ bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes) bytes"
        } else if bytes < 1024 * 1024 {
            let kb = Double(bytes) / 1024.0
            return String(format: "%.1f KB", kb)
        } else if bytes < 1024 * 1024 * 1024 {
            let mb = Double(bytes) / (1024.0 * 1024.0)
            return String(format: "%.1f MB", mb)
        } else {
            let gb = Double(bytes) / (1024.0 * 1024.0 * 1024.0)
            return String(format: "%.1f GB", gb)
        }
    }

    private func formatSize(_ bytes: Int64) -> String {
        ComparisonWindow.formatSize(bytes)
    }

    /// Formats a date using the user's locale settings.
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
}
