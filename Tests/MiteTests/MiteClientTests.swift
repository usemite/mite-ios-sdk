import XCTest
@testable import Mite

final class MiteClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
    }

    private func makeClient(
        config: MiteConfig = makeTestConfig()
    ) -> MiteClient {
        MiteClient(config: config, session: makeStubSession())
    }

    private func successResponder(_ request: URLRequest) -> Result<(Int, Data), URLError> {
        .success((200, Data(#"{"id":"r1","status":"NEEDS_TRIAGE"}"#.utf8)))
    }

    // MARK: - Bug reports

    func testSubmitBugSuccessSendsIdentityAndDeviceInfo() async throws {
        StubURLProtocol.responder = successResponder
        let client = makeClient()

        let result = try await client.submitBug(
            BugReportPayload(title: "Crash", description: "It crashed")
        )

        guard case let .success(report, dropped) = result else {
            return XCTFail("Expected success, got \(result)")
        }
        XCTAssertEqual(report.id, "r1")
        XCTAssertNil(dropped)

        let body = StubURLProtocol.recorded.last?.bodyJSON
        XCTAssertEqual(body?["title"] as? String, "Crash")
        XCTAssertNotNil(body?["anonymous_id"])
        XCTAssertNotNil(body?["device_info"])
    }

    func testTriageContextRidesOnTheReportEnvironment() async throws {
        StubURLProtocol.responder = successResponder
        let client = makeClient()

        client.recordScreen("CheckoutScreen")
        client.recordError(MiteError.invalidResponse)

        _ = try await client.submitBug(BugReportPayload(title: "t", description: "d"))

        let environment = StubURLProtocol.recorded.last?.bodyJSON?["environment"] as? [String: String]
        XCTAssertEqual(environment?["current_route"], "CheckoutScreen")
        XCTAssertEqual(environment?["last_error_message"]?.contains("invalidResponse"), true)
        XCTAssertNotNil(environment?["last_error_stack"])
    }

    func testAppEnvironmentOverridesCollectedTriageKeys() async throws {
        StubURLProtocol.responder = successResponder
        let client = makeClient()

        client.recordScreen("CheckoutScreen")

        _ = try await client.submitBug(BugReportPayload(
            title: "t",
            description: "d",
            environment: ["current_route": "AppSuppliedScreen", "build": "42"]
        ))

        let environment = StubURLProtocol.recorded.last?.bodyJSON?["environment"] as? [String: String]
        XCTAssertEqual(environment?["current_route"], "AppSuppliedScreen")
        XCTAssertEqual(environment?["build"], "42")
    }

    func testEnvironmentIsAbsentWhenNothingWasRecorded() async throws {
        StubURLProtocol.responder = successResponder
        let client = makeClient()

        _ = try await client.submitBug(BugReportPayload(title: "t", description: "d"))

        XCTAssertNil(StubURLProtocol.recorded.last?.bodyJSON?["environment"])
    }

    func testSubmitBugWithoutAPIKeyThrows() async {
        let client = makeClient(config: makeTestConfig(apiKey: nil))

        do {
            _ = try await client.submitBug(BugReportPayload(title: "t", description: "d"))
            XCTFail("Expected a thrown error")
        } catch {
            guard case MiteError.missingAPIKey = error else {
                return XCTFail("Expected missingAPIKey, got \(error)")
            }
        }
    }

    func testQuotaRefusalGatesNextSubmitLocally() async throws {
        let resetsAt = (Date().timeIntervalSince1970 + 3600) * 1000
        StubURLProtocol.responder = { _ in
            .success((402, quotaRefusalBody(code: "REPORT_QUOTA_EXCEEDED", resetsAt: resetsAt)))
        }
        let client = makeClient()
        let payload = BugReportPayload(title: "t", description: "d")

        let first = try await client.submitBug(payload)
        guard case .refused = first else {
            return XCTFail("Expected refusal, got \(first)")
        }
        let requestsAfterFirst = StubURLProtocol.recorded.count
        XCTAssertEqual(requestsAfterFirst, 1)

        // The gate is closed. The second call sends nothing.
        let second = try await client.submitBug(payload)
        guard case let .refused(refusal) = second else {
            return XCTFail("Expected refusal, got \(second)")
        }
        XCTAssertEqual(refusal.code, .reportQuotaExceeded)
        XCTAssertEqual(StubURLProtocol.recorded.count, requestsAfterFirst)
    }

    func testRefusalWithoutResetTimeDoesNotGate() async throws {
        StubURLProtocol.responder = { _ in
            .success((402, quotaRefusalBody(code: "REPORT_QUOTA_EXCEEDED")))
        }
        let client = makeClient()
        let payload = BugReportPayload(title: "t", description: "d")

        _ = try await client.submitBug(payload)
        _ = try await client.submitBug(payload)

        // No reset time, so the gate never closes; both calls reach the server.
        XCTAssertEqual(StubURLProtocol.recorded.count, 2)
    }

    func testOptOutStripsIdentifiedData() async throws {
        StubURLProtocol.responder = successResponder
        let client = makeClient(config: makeTestConfig(identificationOptOut: true))

        _ = try await client.submitBug(BugReportPayload(
            title: "t",
            description: "d",
            reporterName: "Ann",
            reporterEmail: "ann@example.com"
        ))

        let body = StubURLProtocol.recorded.last?.bodyJSON
        XCTAssertNotNil(body?["anonymous_id"])
        XCTAssertNil(body?["user_identifier"])
        XCTAssertNil(body?["reporter_name"])
        XCTAssertNil(body?["reporter_email"])
        XCTAssertNil(body?["device_info"])
    }

    func testNetworkFaultQueuesReportAndRethrows() async throws {
        StubURLProtocol.responder = { _ in .failure(URLError(.notConnectedToInternet)) }
        let client = makeClient(config: makeTestConfig(enableOfflineQueue: true))

        do {
            _ = try await client.submitBug(BugReportPayload(title: "t", description: "d"))
            XCTFail("Expected a thrown error")
        } catch {
            guard case MiteError.network = error else {
                return XCTFail("Expected network error, got \(error)")
            }
        }

        let pending = await client.pendingRequestCount
        XCTAssertEqual(pending, 1)

        // The network is back. A manual flush empties the queue.
        StubURLProtocol.responder = successResponder
        await client.flushOfflineQueue()
        let afterFlush = await client.pendingRequestCount
        XCTAssertEqual(afterFlush, 0)
    }

    func testStorageRefusalDropsAttachmentsButSendsReport() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mite-test-\(UUID().uuidString).txt")
        try Data("hello".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        StubURLProtocol.responder = { request in
            if request.url!.path.contains("upload-url") {
                return .success((402, quotaRefusalBody(code: "STORAGE_QUOTA_EXCEEDED")))
            }
            return .success((200, Data(#"{"id":"r1","status":"NEEDS_TRIAGE"}"#.utf8)))
        }
        let client = makeClient()

        let result = try await client.submitBug(BugReportPayload(
            title: "t",
            description: "d",
            attachments: [MiteAttachment(fileURL: fileURL)]
        ))

        guard case let .success(_, dropped) = result else {
            return XCTFail("Expected success, got \(result)")
        }
        XCTAssertEqual(dropped?.count, 1)
        XCTAssertEqual(dropped?.refusal.code, .storageQuotaExceeded)

        let body = StubURLProtocol.recorded.last?.bodyJSON
        XCTAssertNil(body?["attachments"])
    }

    // MARK: - Identity

    func testIdentifyPersistsAcrossClients() async throws {
        StubURLProtocol.responder = { _ in
            .success((200, Data(#"{"id":"u1","created":true}"#.utf8)))
        }
        let storage = MemoryIdentityStorage()
        let client = makeClient(config: makeTestConfig(storage: storage))

        _ = try await client.identify(IdentifyPayload(userIdentifier: "user-1"))
        let identifier = await client.userIdentifier
        XCTAssertEqual(identifier, "user-1")
        let anonymousId = await client.anonymousId

        // A new client with the same storage restores the same identity.
        let restored = makeClient(config: makeTestConfig(storage: storage))
        let restoredIdentifier = await restored.userIdentifier
        let restoredAnonymousId = await restored.anonymousId
        XCTAssertEqual(restoredIdentifier, "user-1")
        XCTAssertEqual(restoredAnonymousId, anonymousId)
    }

    func testLogoutClearsUserButKeepsAnonymousId() async throws {
        StubURLProtocol.responder = { _ in
            .success((200, Data(#"{"id":"u1","created":true}"#.utf8)))
        }
        let client = makeClient()

        _ = try await client.identify(IdentifyPayload(userIdentifier: "user-1"))
        let anonymousBefore = await client.anonymousId

        await client.logout()

        let identifier = await client.userIdentifier
        let anonymousAfter = await client.anonymousId
        XCTAssertNil(identifier)
        XCTAssertEqual(anonymousBefore, anonymousAfter)
    }

    // MARK: - Releases

    func testGetReleasesSendsQueryAndDecodes() async throws {
        StubURLProtocol.responder = { _ in
            .success((200, Data("""
            {"releases":[{"id":"rel1","version":"1.2.0","versionCode":42,
            "platform":"ios","notes":"Fixes","createdAt":1700000000000}]}
            """.utf8)))
        }
        let client = makeClient()

        let releases = try await client.getReleases(platform: .ios, limit: 5)

        XCTAssertEqual(releases.count, 1)
        XCTAssertEqual(releases.first?.version, "1.2.0")
        XCTAssertEqual(releases.first?.platform, .ios)

        let url = StubURLProtocol.recorded.last?.url
        XCTAssertEqual(url?.query?.contains("platform=ios"), true)
        XCTAssertEqual(url?.query?.contains("limit=5"), true)
    }

    // MARK: - Announcements

    func testGetAnnouncementsSendsQueryAndDecodes() async throws {
        StubURLProtocol.responder = { _ in
            .success((200, Data("""
            {"announcements":[{"id":"ann1","title":"Scheduled maintenance",
            "content":"**Tonight** at 9 PM.","platform":"ios",
            "ctaLabel":"Status","ctaUrl":"https://status.example.com",
            "publishedAt":1700000000000,"updatedAt":1700000001000,
            "createdAt":1699999999000}]}
            """.utf8)))
        }
        let client = makeClient()

        let announcements = try await client.getAnnouncements(platform: .ios, limit: 5)

        XCTAssertEqual(announcements.count, 1)
        XCTAssertEqual(announcements.first?.id, "ann1")
        XCTAssertEqual(announcements.first?.title, "Scheduled maintenance")
        XCTAssertEqual(announcements.first?.content, "**Tonight** at 9 PM.")
        XCTAssertEqual(announcements.first?.platform, .ios)
        XCTAssertEqual(announcements.first?.ctaLabel, "Status")
        XCTAssertEqual(announcements.first?.ctaUrl, "https://status.example.com")

        let request = StubURLProtocol.recorded.last
        XCTAssertEqual(request?.url.path, "/api/v1/announcements")
        XCTAssertEqual(request?.url.query?.contains("platform=ios"), true)
        XCTAssertEqual(request?.url.query?.contains("limit=5"), true)
    }

    func testGetAnnouncementsWithoutAPIKeyThrows() async {
        let client = makeClient(config: makeTestConfig(apiKey: nil))

        do {
            _ = try await client.getAnnouncements()
            XCTFail("Expected a thrown error")
        } catch {
            guard case MiteError.missingAPIKey = error else {
                return XCTFail("Expected missingAPIKey, got \(error)")
            }
        }
    }

    func testSeenAnnouncementsPersistWithoutDuplicatesAndCanBeCleared() async {
        let storage = MemoryIdentityStorage()
        let client = makeClient(config: makeTestConfig(storage: storage))

        await client.markAnnouncementSeen("ann_1")
        await client.markAnnouncementSeen("ann_2")
        await client.markAnnouncementSeen("ann_1")

        var seen = await client.getSeenAnnouncementIds()
        XCTAssertEqual(seen, ["ann_1", "ann_2"])

        await client.clearSeenAnnouncements()
        seen = await client.getSeenAnnouncementIds()
        XCTAssertEqual(seen, [])
    }

    func testSeenAnnouncementsKeepNewestOneHundredIDs() async {
        let client = makeClient()

        for index in 0..<105 {
            await client.markAnnouncementSeen("ann_\(index)")
        }

        let seen = await client.getSeenAnnouncementIds()
        XCTAssertEqual(seen.count, 100)
        XCTAssertEqual(seen.first, "ann_5")
        XCTAssertEqual(seen.last, "ann_104")
    }

    func testSeenAnnouncementsIgnoreCorruptAndNonStringValues() async {
        let storage = MemoryIdentityStorage()
        let client = makeClient(config: makeTestConfig(storage: storage))

        storage.setItem(AnnouncementStore.storageKey, "not json")
        var seen = await client.getSeenAnnouncementIds()
        XCTAssertEqual(seen, [])

        storage.setItem(
            AnnouncementStore.storageKey,
            #"["ann_1",42,null,"ann_2"]"#
        )
        seen = await client.getSeenAnnouncementIds()
        XCTAssertEqual(seen, ["ann_1", "ann_2"])
    }
}
