import XCTest
@testable import Mite

@MainActor
final class AnnouncementControllerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
    }

    func testLoadPresentsOnlyNewestUnseenAnnouncement() async {
        let client = makeClient(announcements: [
            announcementJSON(id: "new", title: "Newest", createdAt: 2),
            announcementJSON(id: "old", title: "Older", createdAt: 1),
        ])
        let controller = MiteAnnouncementController(client: client)

        await controller.load()

        XCTAssertEqual(controller.announcement?.id, "new")
        XCTAssertEqual(controller.presentedAnnouncement?.id, "new")
        XCTAssertTrue(controller.isPresented)
        XCTAssertNil(controller.error)
    }

    func testSeenLatestDoesNotAutomaticallyPresentButShowReopensIt() async {
        let storage = MemoryIdentityStorage()
        let client = makeClient(
            announcements: [announcementJSON(id: "ann_1", title: "Hello", createdAt: 1)],
            storage: storage
        )
        await client.markAnnouncementSeen("ann_1")
        let controller = MiteAnnouncementController(client: client)

        await controller.load()

        XCTAssertEqual(controller.announcement?.id, "ann_1")
        XCTAssertNil(controller.presentedAnnouncement)

        controller.show()
        XCTAssertEqual(controller.presentedAnnouncement?.id, "ann_1")
    }

    func testDismissMarksAnnouncementSeen() async {
        let storage = MemoryIdentityStorage()
        let client = makeClient(
            announcements: [announcementJSON(id: "ann_1", title: "Hello", createdAt: 1)],
            storage: storage
        )
        let controller = MiteAnnouncementController(client: client)
        await controller.load()

        let didDismiss = await controller.dismiss()

        XCTAssertTrue(didDismiss)
        XCTAssertNil(controller.presentedAnnouncement)
        let seen = await client.getSeenAnnouncementIds()
        XCTAssertEqual(seen, ["ann_1"])
        let duplicateDismiss = await controller.dismiss()
        XCTAssertFalse(duplicateDismiss)
    }

    func testDisabledControllerDoesNotAutoPresentAndManualShowWorks() async {
        let client = makeClient(announcements: [
            announcementJSON(id: "ann_1", title: "Hello", createdAt: 1),
        ])
        let controller = MiteAnnouncementController(client: client, enabled: false)

        await controller.load()
        XCTAssertNil(controller.announcement)
        XCTAssertTrue(StubURLProtocol.recorded.isEmpty)

        await controller.refresh()
        XCTAssertEqual(controller.announcement?.id, "ann_1")
        XCTAssertNil(controller.presentedAnnouncement)

        controller.show()
        XCTAssertEqual(controller.presentedAnnouncement?.id, "ann_1")
    }

    private func makeClient(
        announcements: [String],
        storage: MiteIdentityStorage = MemoryIdentityStorage()
    ) -> MiteClient {
        StubURLProtocol.responder = { request in
            if request.url?.path == "/api/v1/announcements" {
                let body = "{\"announcements\":[\(announcements.joined(separator: ","))]}"
                return .success((200, Data(body.utf8)))
            }
            return .success((200, Data("{}".utf8)))
        }
        return MiteClient(
            config: makeTestConfig(storage: storage),
            session: makeStubSession()
        )
    }

    private func announcementJSON(id: String, title: String, createdAt: Double) -> String {
        """
        {"id":"\(id)","title":"\(title)","content":"Body",\
        "platform":"ios","createdAt":\(createdAt)}
        """
    }
}
