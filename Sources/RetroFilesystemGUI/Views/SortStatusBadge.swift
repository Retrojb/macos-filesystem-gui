import SwiftUI

/// Overlay badge displaying the count of unsorted files in a directory.
///
/// Uses `BadgeFormatter` to determine display text. Shows nothing when count is 0.
/// Designed to be used as an `.overlay()` on directory items across all view modes
/// (icon grid, list, and column browser).
///
/// Requirements: 2.1, 2.3, 2.4, 2.7
struct SortStatusBadge: View {
    let count: Int
    let onTap: () -> Void

    var body: some View {
        if let text = BadgeFormatter.format(count: count) {
            Text(text)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.orange)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(2)
                .onTapGesture {
                    onTap()
                }
                .accessibilityLabel("\(count) unsorted files")
                .accessibilityHint("Tap to toggle unsorted file filter")
                .accessibilityAddTraits(.isButton)
        }
    }
}
