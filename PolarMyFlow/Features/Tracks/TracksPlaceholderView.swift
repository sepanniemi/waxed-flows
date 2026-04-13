import SwiftUI

struct TracksPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                HStack(spacing: 40) {
                    VStack(spacing: 8) {
                        Image(systemName: "map")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("Map View")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("GPX Export")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Text("Coming soon")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)

                Text("Track maps and GPX export will be available in a future version.")
                    .multilineTextAlignment(.center)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("Tracks")
        }
    }
}
