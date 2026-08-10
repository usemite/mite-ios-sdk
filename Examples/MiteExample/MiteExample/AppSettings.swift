import Foundation
import Mite

/// App-side configuration. Persists to UserDefaults and applies the
/// values to the SDK through Mite.configure.
@MainActor
final class AppSettings: ObservableObject {
    @Published var apiKey: String
    @Published var endpoint: String
    @Published var offlineQueueEnabled: Bool
    /// One line per onQuotaExceeded callback, newest last.
    @Published var quotaLog: [String] = []

    private let defaults = UserDefaults.standard

    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init() {
        apiKey = defaults.string(forKey: "example.apiKey") ?? ""
        endpoint = defaults.string(forKey: "example.endpoint")
            ?? MiteConfig.defaultEndpoint.absoluteString
        offlineQueueEnabled = defaults.object(forKey: "example.offlineQueue") as? Bool ?? true
        apply()
    }

    /// Saves the current values and replaces the shared SDK client.
    func apply() {
        defaults.set(apiKey, forKey: "example.apiKey")
        defaults.set(endpoint, forKey: "example.endpoint")
        defaults.set(offlineQueueEnabled, forKey: "example.offlineQueue")

        let key = apiKey.trimmingCharacters(in: .whitespaces)
        Mite.configure(MiteConfig(
            apiKey: key.isEmpty ? nil : key,
            endpoint: URL(string: endpoint) ?? MiteConfig.defaultEndpoint,
            enableOfflineQueue: offlineQueueEnabled,
            onQuotaExceeded: { [weak self] refusal in
                Task { @MainActor in
                    self?.quotaLog.append("\(refusal.code.rawValue): \(refusal.message)")
                }
            }
        ))
    }
}
