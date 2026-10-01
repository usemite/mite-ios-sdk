import Foundation

public struct MiteConfig: Sendable {
    public static let defaultEndpoint = URL(string: "https://usemite.com")!

    public var apiKey: String?
    public var endpoint: URL
    /// Request timeout in seconds.
    public var timeout: TimeInterval
    /// Extra attempts for network faults and 5xx answers. 4xx never retries.
    public var maxRetries: Int
    /// Overrides the automatically generated anonymous identifier.
    public var anonymousId: String?
    /// Starts the SDK in anonymous-only mode. When true, Mite does not send
    /// user ids, contact fields, metadata, or device info. When nil, the
    /// persisted preference (or false) is used.
    public var identificationOptOut: Bool?
    /// Queues bug reports that fail with a network fault, and retries them.
    public var enableOfflineQueue: Bool
    /// Sends the current identity to the server once at startup.
    public var syncIdentityOnStart: Bool
    /// Chains a process-wide uncaught exception handler, so the crash that
    /// ended the last run rides on the next bug report.
    public var captureUncaughtExceptions: Bool
    /// Watches the network path and attaches `network_state` to bug reports.
    public var monitorNetworkState: Bool
    /// Persisted identity storage. Defaults to `UserDefaults.standard`.
    public var identityStorage: MiteIdentityStorage?
    /// Called each time the server refuses a request because the account has
    /// reached a plan limit. The SDK never throws for a quota refusal.
    public var onQuotaExceeded: (@Sendable (MiteQuotaRefusal) -> Void)?

    public init(
        apiKey: String? = nil,
        endpoint: URL = MiteConfig.defaultEndpoint,
        timeout: TimeInterval = 5,
        maxRetries: Int = 0,
        anonymousId: String? = nil,
        identificationOptOut: Bool? = nil,
        enableOfflineQueue: Bool = true,
        syncIdentityOnStart: Bool = true,
        captureUncaughtExceptions: Bool = true,
        monitorNetworkState: Bool = true,
        identityStorage: MiteIdentityStorage? = nil,
        onQuotaExceeded: (@Sendable (MiteQuotaRefusal) -> Void)? = nil
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.anonymousId = anonymousId
        self.identificationOptOut = identificationOptOut
        self.enableOfflineQueue = enableOfflineQueue
        self.syncIdentityOnStart = syncIdentityOnStart
        self.captureUncaughtExceptions = captureUncaughtExceptions
        self.monitorNetworkState = monitorNetworkState
        self.identityStorage = identityStorage
        self.onQuotaExceeded = onQuotaExceeded
    }
}
