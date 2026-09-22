import XCTest
@testable import Mite

final class TriageContextTests: XCTestCase {
    private func makeSuite() -> (UserDefaultsIdentityStorage, String) {
        let name = "com.usemite.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (UserDefaultsIdentityStorage(defaults: defaults), name)
    }

    func testSnapshotOmitsUnknownKeys() {
        let context = TriageContext(storage: MemoryIdentityStorage())

        XCTAssertEqual(context.snapshot(), [:])

        context.recordScreen("  ")
        XCTAssertEqual(context.snapshot(), [:])

        context.recordScreen("  Checkout  ")
        XCTAssertEqual(context.snapshot(), ["current_route": "Checkout"])
    }

    func testStackIsTruncatedToTheHead() {
        let context = TriageContext(storage: MemoryIdentityStorage())
        let stack = String(repeating: "a", count: 2500) + "TAIL"

        context.record(TriageContext.RecordedError(message: "boom", stack: stack))

        let snapshot = context.snapshot()
        XCTAssertEqual(snapshot["last_error_stack"]?.count, 2000)
        XCTAssertEqual(snapshot["last_error_stack"], String(repeating: "a", count: 2000))
    }

    func testRecordedErrorMessageCombinesDescriptions() {
        let context = TriageContext(storage: MemoryIdentityStorage())

        context.recordError(MiteError.invalidResponse)

        let message = context.snapshot()["last_error_message"]
        XCTAssertEqual(message?.contains("invalidResponse"), true)
        XCTAssertEqual(message?.contains(MiteError.invalidResponse.localizedDescription), true)
        XCTAssertNotNil(context.snapshot()["last_error_stack"])
    }

    func testPersistedErrorSurvivesANewInstance() {
        let (storage, suiteName) = makeSuite()
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        TriageContext(storage: storage).record(
            TriageContext.RecordedError(message: "crashed at launch", stack: "frame0\nframe1")
        )

        let reloaded = TriageContext(storage: storage).snapshot()
        XCTAssertEqual(reloaded["last_error_message"], "crashed at launch")
        XCTAssertEqual(reloaded["last_error_stack"], "frame0\nframe1")
        XCTAssertNil(reloaded["current_route"])
    }

    func testNetworkStateIsSnapshotted() {
        let context = TriageContext(storage: MemoryIdentityStorage())
        context.recordNetworkState("wifi/offline")

        XCTAssertEqual(context.snapshot()["network_state"], "wifi/offline")
    }
}
