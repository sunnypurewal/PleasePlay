import SwiftUI

struct DiscoverView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Discover")
                .font(.title2.weight(.semibold))
            Text("Find new music and curated picks here soon.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

#Preview {
    DiscoverView()
}
