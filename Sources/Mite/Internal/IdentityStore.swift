import Foundation

/// Persisted identity state storage. The default implementation uses
/// `UserDefaults`. Provide your own to store identity elsewhere, for
/// example in an app group.
public protocol MiteIdentityStorage: Sendable {
    func getItem(_ key: String) -> String?
    func setItem(_ key: String, _ value: String)
    func removeItem(_ key: String)
}

/// `UserDefaults`-backed storage. `UserDefaults` is thread-safe.
public struct UserDefaultsIdentityStorage: MiteIdentityStorage, @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func getItem(_ key: String) -> String? {
        defaults.string(forKey: key)
    }

    public func setItem(_ key: String, _ value: String) {
        defaults.set(value, forKey: key)
    }

    public func removeItem(_ key: String) {
        defaults.removeObject(forKey: key)
    }
}

struct PersistedIdentityState: Codable {
    var anonymousId: String
    var userIdentifier: String?
    var identificationOptOut: Bool
}

/// Reads and writes the persisted identity state under one JSON key.
/// The key matches the React Native SDK.
struct IdentityStore {
    static let storageKey = "@mite/sdk-identity"

    private let storage: MiteIdentityStorage

    init(storage: MiteIdentityStorage) {
        self.storage = storage
    }

    func load() -> PersistedIdentityState? {
        guard
            let raw = storage.getItem(Self.storageKey),
            let data = raw.data(using: .utf8)
        else {
            return nil
        }
        return try? JSONDecoder().decode(PersistedIdentityState.self, from: data)
    }

    func save(_ state: PersistedIdentityState) {
        guard
            let data = try? JSONEncoder().encode(state),
            let raw = String(data: data, encoding: .utf8)
        else {
            return
        }
        storage.setItem(Self.storageKey, raw)
    }
}

func generateAnonymousId() -> String {
    "anon_\(UUID().uuidString.lowercased())"
}
