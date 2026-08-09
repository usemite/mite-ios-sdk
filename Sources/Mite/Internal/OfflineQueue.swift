import Foundation

/// In-memory queue that retries failed bug report requests. Requests are
/// queued when they fail with a network fault, and retried on a timer with
/// the drop rules below. The queue does not survive an app restart.
actor OfflineQueue {
    struct Item {
        let id: String
        let path: String
        let body: Data
        let timestamp: Date
        var retries: Int
    }

    static let flushInterval: TimeInterval = 30
    static let maxQueueSize = 100
    static let maxAge: TimeInterval = 24 * 60 * 60

    private let apiClient: APIClient
    private let maxRetries: Int
    /// Called when a queued request is dropped because the account is over a
    /// plan limit. The queue itself does not act on a refusal; the owner
    /// decides what to report and what to remember.
    private let onQuotaRefusal: (@Sendable (MiteQuotaRefusal) -> Void)?

    private var items: [Item] = []
    private var timerTask: Task<Void, Never>?
    private var isFlushing = false

    init(
        apiClient: APIClient,
        maxRetries: Int = 5,
        onQuotaRefusal: (@Sendable (MiteQuotaRefusal) -> Void)? = nil
    ) {
        self.apiClient = apiClient
        self.maxRetries = maxRetries
        self.onQuotaRefusal = onQuotaRefusal
    }

    var pendingCount: Int {
        items.count
    }

    func enqueue(path: String, body: Data) {
        if items.count >= Self.maxQueueSize {
            // Drop the oldest item to make room.
            items.removeFirst()
        }

        items.append(Item(
            id: UUID().uuidString,
            path: path,
            body: body,
            timestamp: Date(),
            retries: 0
        ))

        startTimer()
    }

    func flush() async {
        if isFlushing || items.isEmpty { return }
        isFlushing = true
        defer { isFlushing = false }

        var completed: Set<String> = []

        for item in items {
            // Drop stale requests.
            if Date().timeIntervalSince(item.timestamp) > Self.maxAge {
                completed.insert(item.id)
                continue
            }

            do {
                try await apiClient.postRaw(item.path, bodyData: item.body)
                completed.insert(item.id)
            } catch {
                // A plan quota refusal cannot succeed on a retry. Drop it now,
                // so the queue does not grow while the app stays over quota.
                if let refusal = QuotaRefusalParser.parse(error) {
                    completed.insert(item.id)
                    onQuotaRefusal?(refusal)
                    continue
                }

                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index].retries += 1
                    if items[index].retries >= maxRetries {
                        completed.insert(item.id)
                    }
                }
            }
        }

        items.removeAll { completed.contains($0.id) }

        if items.isEmpty {
            stopTimer()
        }
    }

    func shutdown() {
        stopTimer()
        items = []
    }

    private func startTimer() {
        guard timerTask == nil else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.flushInterval * 1_000_000_000))
                guard let self else { return }
                await self.flush()
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}
