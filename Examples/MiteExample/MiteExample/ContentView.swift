import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        TabView {
            ReportView()
                .tabItem { Label("Report", systemImage: "ladybug") }
            ReleasesView()
                .tabItem { Label("Releases", systemImage: "shippingbox") }
            IdentityView()
                .tabItem { Label("Identity", systemImage: "person.crop.circle") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .safeAreaInset(edge: .top) {
            if !settings.isConfigured {
                Text("No API key set. Open the Settings tab.")
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(.yellow.opacity(0.3))
            }
        }
    }
}
