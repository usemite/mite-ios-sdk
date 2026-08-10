import SwiftUI
import Mite

struct ReleasesView: View {
    @State private var releases: [Release] = []
    @State private var errorText: String?
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            List {
                if let errorText {
                    Text(errorText)
                        .foregroundColor(.red)
                }
                ForEach(releases, id: \.id) { release in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(release.version)
                            .font(.headline)
                        Text(release.platform.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let notes = release.notes {
                            Text(notes)
                                .font(.subheadline)
                        }
                    }
                }
                if releases.isEmpty && errorText == nil && !isLoading {
                    Text("No releases. Pull to refresh.")
                        .foregroundColor(.secondary)
                }
            }
            .refreshable { await load() }
            .task { await load() }
            .navigationTitle("Releases")
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        errorText = nil
        do {
            releases = try await Mite.shared.getReleases(platform: .ios, limit: 20)
        } catch {
            errorText = String(describing: error)
        }
    }
}
