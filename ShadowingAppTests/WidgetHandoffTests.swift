import XCTest
@testable import ShadowingApp

@MainActor
final class WidgetHandoffTests: XCTestCase {
    func test_handle_callsPlayWithLookedUpPlaylistAndClearsKey() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("uuid-abc", forKey: PlayPlaylistIntent.pendingIDKey)

        var resolvedID: String?
        let handoff = WidgetHandoff(
            defaults: defaults,
            lookupAndPlay: { id in resolvedID = id; return true }
        )
        handoff.handle()

        XCTAssertEqual(resolvedID, "uuid-abc")
        XCTAssertNil(defaults.string(forKey: PlayPlaylistIntent.pendingIDKey))
    }

    func test_handle_doesNothingWhenKeyAbsent() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var called = false
        let handoff = WidgetHandoff(
            defaults: defaults,
            lookupAndPlay: { _ in called = true; return true }
        )
        handoff.handle()
        XCTAssertFalse(called)
    }

    func test_handle_doesNotClearKeyOnFailure() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("uuid-abc", forKey: PlayPlaylistIntent.pendingIDKey)

        let handoff = WidgetHandoff(
            defaults: defaults,
            lookupAndPlay: { _ in false }
        )
        handoff.handle()

        XCTAssertEqual(defaults.string(forKey: PlayPlaylistIntent.pendingIDKey), "uuid-abc")
    }
}
