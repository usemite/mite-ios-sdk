import Foundation

/// Static entry point for the app-wide client.
///
/// ```swift
/// Mite.configure(MiteConfig(apiKey: "mite_..."))
/// let result = try await Mite.shared.submitBug(
///     BugReportPayload(title: "Crash on login", description: "…")
/// )
/// ```
public enum Mite {
    private static let lock = NSLock()
    private static var _shared: MiteClient?

    /// Creates the shared client. Call once, early in the app's life.
    /// A second call replaces the shared client.
    @discardableResult
    public static func configure(_ config: MiteConfig) -> MiteClient {
        let client = MiteClient(config: config)
        lock.lock()
        _shared = client
        lock.unlock()
        return client
    }

    /// The shared client. Traps when `configure(_:)` has not been called;
    /// use `sharedIfConfigured` to probe safely.
    public static var shared: MiteClient {
        lock.lock()
        defer { lock.unlock() }
        guard let client = _shared else {
            preconditionFailure("[Mite] Call Mite.configure(_:) before Mite.shared.")
        }
        return client
    }

    /// The shared client, or nil when `configure(_:)` has not been called.
    public static var sharedIfConfigured: MiteClient? {
        lock.lock()
        defer { lock.unlock() }
        return _shared
    }

    /// Removes the shared client. Intended for tests.
    public static func reset() {
        lock.lock()
        _shared = nil
        lock.unlock()
    }
}
