import XCTest
@testable import Mite

final class OfflineQueueTests: XCTestCase {
    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
    }

    private func makeAPIClient() -> APIClient {
        APIClient(
            baseURL: URL(string: "https://example.test")!,
            timeout: 5,
            maxRetries: 0,
            apiKey: "key",
            session: makeStubSession()
        )
    }

    func testFlushSendsAndClearsQueue() async {
        StubURLProtocol.responder = { _ in .success((200, Data("{}".utf8))) }
        let queue = OfflineQueue(apiClient: makeAPIClient())

        await queue.enqueue(path: "/api/v1/bug-reports", body: Data(#"{"a":1}"#.utf8))
        await queue.enqueue(path: "/api/v1/bug-reports", body: Data(#"{"a":2}"#.utf8))
        await queue.flush()

        let pending = await queue.pendingCount
        XCTAssertEqual(pending, 0)
        XCTAssertEqual(StubURLProtocol.recorded.count, 2)
        await queue.shutdown()
    }

    func testQuotaRefusalDropsItemAndCallsBack() async {
        StubURLProtocol.responder = { _ in
            .success((402, quotaRefusalBody(code: "REPORT_QUOTA_EXCEEDED", resetsAt: 1)))
        }

        let received = Box<MiteQuotaRefusal>()
        let queue = OfflineQueue(apiClient: makeAPIClient()) { refusal in
            received.set(refusal)
        }

        await queue.enqueue(path: "/api/v1/bug-reports", body: Data("{}".utf8))
        await queue.flush()

        // A refusal cannot succeed on a retry, so the item is gone.
        let pending = await queue.pendingCount
        XCTAssertEqual(pending, 0)
        XCTAssertEqual(received.get()?.code, .reportQuotaExceeded)
        await queue.shutdown()
    }

    func testTransientErrorRetriesUntilLimitThenDrops() async {
        StubURLProtocol.responder = { _ in .success((500, Data("{}".utf8))) }
        let queue = OfflineQueue(apiClient: makeAPIClient(), maxRetries: 2)

        await queue.enqueue(path: "/api/v1/bug-reports", body: Data("{}".utf8))

        await queue.flush()
        var pending = await queue.pendingCount
        XCTAssertEqual(pending, 1, "One failure is below the retry limit")

        await queue.flush()
        pending = await queue.pendingCount
        XCTAssertEqual(pending, 0, "The retry limit drops the item")
        await queue.shutdown()
    }

    func testOverflowDropsOldestItem() async {
        StubURLProtocol.responder = { _ in .success((500, Data("{}".utf8))) }
        let queue = OfflineQueue(apiClient: makeAPIClient())

        for index in 0...OfflineQueue.maxQueueSize {
            await queue.enqueue(path: "/p", body: Data("\(index)".utf8))
        }

        let pending = await queue.pendingCount
        XCTAssertEqual(pending, OfflineQueue.maxQueueSize)
        await queue.shutdown()
    }
}

final class Box<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T?

    func set(_ newValue: T) {
        lock.lock(); value = newValue; lock.unlock()
    }

    func get() -> T? {
        lock.lock(); defer { lock.unlock() }; return value
    }
}
