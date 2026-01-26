import SwiftUI

struct ExplicitBadge: View {
    var body: some View {
        Image(systemName: "e.square.fill")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Explicit content")
    }
}
