import Foundation

/// Stores the bounded list of announcements dismissed on this device.
/// The storage key and maximum length match the React Native SDK.
struct AnnouncementStore {
    static let storageKey = "@mite/sdk-seen-announcements"
    static let maximumSeenIDs = 100

    private let storage: MiteIdentityStorage

    init(storage: MiteIdentityStorage) {
        self.storage = storage
    }

    func seenIDs() -> [String] {
        guard
            let raw = storage.getItem(Self.storageKey),
            let data = raw.data(using: .utf8),
            let values = try? JSONSerialization.jsonObject(with: data) as? [Any]
        else {
            return []
        }

        return values.compactMap { $0 as? String }
    }

    func markSeen(_ id: String) {
        var ids = seenIDs()
        guard !ids.contains(id) else { return }

        ids.append(id)
        if ids.count > Self.maximumSeenIDs {
            ids.removeFirst(ids.count - Self.maximumSeenIDs)
        }

        guard
            let data = try? JSONEncoder().encode(ids),
            let raw = String(data: data, encoding: .utf8)
        else {
            return
        }
        storage.setItem(Self.storageKey, raw)
    }

    func clear() {
        storage.removeItem(Self.storageKey)
    }
}
