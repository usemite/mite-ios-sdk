import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var showApplied = false

    var body: some View {
        NavigationView {
            Form {
                Section("Server") {
                    TextField("API key (mite_...)", text: $settings.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Endpoint URL", text: $settings.endpoint)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Toggle("Offline queue", isOn: $settings.offlineQueueEnabled)
                    Button("Apply") {
                        settings.apply()
                        showApplied = true
                    }
                }
                Section("Quota callbacks") {
                    if settings.quotaLog.isEmpty {
                        Text("No quota refusals yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(settings.quotaLog.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.caption.monospaced())
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Configuration applied", isPresented: $showApplied) {
                Button("OK", role: .cancel) {}
            }
        }
    }
}
