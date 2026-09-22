import Foundation

/// Triage signals collected outside a bug report, sent as named keys inside
/// the report's flat `environment` map.
///
/// Lock-based rather than actor-isolated because the uncaught exception
/// handler runs synchronously on a dying process and cannot await.
final class TriageContext: @unchecked Sendable {
    static let lastErrorKey = "@mite/sdk-last-error"

    /// The wire limit for one `environment` value.
    static let maxValueLength = 2000

    struct RecordedError: Codable {
        var message: String
        var stack: String?
    }

    private let storage: MiteIdentityStorage
    private let lock = NSLock()
    private var currentRoute: String?
    private var lastError: RecordedError?
    private var networkState: String?

    init(storage: MiteIdentityStorage) {
        self.storage = storage
        self.lastError = Self.loadPersistedError(from: storage)
    }

    func recordScreen(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lock.lock()
        currentRoute = trimmed
        lock.unlock()
    }

    func recordError(_ error: Error) {
        record(RecordedError(
            message: Self.message(for: error),
            stack: Thread.callStackSymbols.joined(separator: "\n")
        ))
    }

    func record(_ error: RecordedError) {
        lock.lock()
        lastError = error
        lock.unlock()
        persist(error)
    }

    func recordNetworkState(_ state: String) {
        lock.lock()
        networkState = state
        lock.unlock()
    }

    func snapshot() -> [String: String] {
        lock.lock()
        let route = currentRoute
        let error = lastError
        let network = networkState
        lock.unlock()

        var keys: [String: String] = [:]
        insert("current_route", route, into: &keys)
        insert("last_error_message", error?.message, into: &keys)
        insert("last_error_stack", error?.stack, into: &keys)
        insert("network_state", network, into: &keys)
        return keys
    }

    private func insert(_ key: String, _ value: String?, into keys: inout [String: String]) {
        guard let value, !value.isEmpty else { return }
        keys[key] = String(value.prefix(Self.maxValueLength))
    }

    private static func message(for error: Error) -> String {
        let described = String(describing: error)
        let localized = error.localizedDescription
        return described == localized ? described : "\(described): \(localized)"
    }

    private func persist(_ error: RecordedError) {
        guard
            let data = try? JSONEncoder().encode(error),
            let raw = String(data: data, encoding: .utf8)
        else {
            return
        }
        storage.setItem(Self.lastErrorKey, raw)
    }

    private static func loadPersistedError(from storage: MiteIdentityStorage) -> RecordedError? {
        guard
            let raw = storage.getItem(lastErrorKey),
            let data = raw.data(using: .utf8)
        else {
            return nil
        }
        return try? JSONDecoder().decode(RecordedError.self, from: data)
    }
}

#if canImport(ObjectiveC)
/// Chains one process-wide `NSSetUncaughtExceptionHandler`. The process dies
/// after the handler returns, so the record is persisted, not kept in memory.
enum UncaughtExceptionTrap {
    private static let lock = NSLock()
    private static var installed = false
    private static var previousHandler: (@convention(c) (NSException) -> Void)?
    private static var contexts: [TriageContext] = []

    static func install(recordingInto context: TriageContext) {
        lock.lock()
        contexts.append(context)
        let needsHandler = !installed
        installed = true
        if needsHandler {
            previousHandler = NSGetUncaughtExceptionHandler()
        }
        lock.unlock()

        guard needsHandler else { return }

        NSSetUncaughtExceptionHandler(handle)
    }

    private static let handle: @convention(c) (NSException) -> Void = { exception in
        UncaughtExceptionTrap.lock.lock()
        let targets = UncaughtExceptionTrap.contexts
        let previous = UncaughtExceptionTrap.previousHandler
        UncaughtExceptionTrap.lock.unlock()

        let message = [exception.name.rawValue, exception.reason]
            .compactMap { $0 }
            .joined(separator: ": ")
        let record = TriageContext.RecordedError(
            message: message,
            stack: exception.callStackSymbols.joined(separator: "\n")
        )
        for target in targets {
            target.record(record)
        }

        previous?(exception)
    }
}
#endif

#if canImport(Network)
import Network

/// Watches the network path and pushes a short state string into the context.
final class NetworkStateMonitor: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.usemite.sdk.network", qos: .utility)

    init(context: TriageContext) {
        monitor.pathUpdateHandler = { path in
            context.recordNetworkState(Self.describe(path))
        }
        monitor.start(queue: queue)
    }

    func cancel() {
        monitor.cancel()
    }

    private static func describe(_ path: NWPath) -> String {
        let interface: String?
        if path.usesInterfaceType(.wifi) {
            interface = "wifi"
        } else if path.usesInterfaceType(.cellular) {
            interface = "cellular"
        } else if path.usesInterfaceType(.wiredEthernet) {
            interface = "wired"
        } else if path.status == .satisfied {
            interface = "other"
        } else {
            interface = nil
        }

        guard let interface else { return "none" }
        return path.status == .satisfied ? interface : "\(interface)/offline"
    }
}
#endif
