import XCTest
@testable import Mite

final class APIClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
    }

    private struct Pong: Decodable { let ok: Bool }

    private func makeClient(maxRetries: Int = 0) -> APIClient {
        APIClient(
            baseURL: URL(string: "https://example.test")!,
            timeout: 5,
            maxRetries: maxRetries,
            apiKey: "key",
            session: makeStubSession()
        )
    }

    func testRetriesServerErrorThenSucceeds() async throws {
        let counter = Counter()
        StubURLProtocol.responder = { _ in
            if counter.next() == 1 {
                return .success((500, Data("{}".utf8)))
            }
            return .success((200, Data(#"{"ok":true}"#.utf8)))
        }

        let pong: Pong = try await makeClient(maxRetries: 1).get("/ping")
        XCTAssertTrue(pong.ok)
        XCTAssertEqual(StubURLProtocol.recorded.count, 2)
    }

    func testDoesNotRetryClientError() async {
        StubURLProtocol.responder = { _ in .success((400, Data("{}".utf8))) }

        do {
            let _: Pong = try await makeClient(maxRetries: 3).get("/ping")
            XCTFail("Expected a thrown error")
        } catch {
            guard case let MiteError.server(status, _) = error else {
                return XCTFail("Expected MiteError.server, got \(error)")
            }
            XCTAssertEqual(status, 400)
        }
        XCTAssertEqual(StubURLProtocol.recorded.count, 1)
    }

    func testSendsBearerAuthorization() async throws {
        StubURLProtocol.responder = { request in
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Authorization"),
                "Bearer key"
            )
            return .success((200, Data(#"{"ok":true}"#.utf8)))
        }

        let _: Pong = try await makeClient().get("/ping")
    }

    func testQuotaRefusalParsing() {
        let error = MiteError.server(
            status: 402,
            body: quotaRefusalBody(code: "REPORT_QUOTA_EXCEEDED", resetsAt: 123)
        )

        let refusal = QuotaRefusalParser.parse(error)
        XCTAssertEqual(refusal?.code, .reportQuotaExceeded)
        XCTAssertEqual(refusal?.quota.limit, 10)
        XCTAssertEqual(refusal?.quota.resetsAt, 123)
    }

    func testNonQuota402IsNotARefusal() {
        let error = MiteError.server(status: 402, body: Data(#"{"code":"OTHER"}"#.utf8))
        XCTAssertNil(QuotaRefusalParser.parse(error))
    }

    func testNon402IsNotARefusal() {
        let error = MiteError.server(
            status: 500,
            body: quotaRefusalBody(code: "REPORT_QUOTA_EXCEEDED")
        )
        XCTAssertNil(QuotaRefusalParser.parse(error))
    }
}

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func next() -> Int {
        lock.lock(); defer { lock.unlock() }
        value += 1
        return value
    }
}
