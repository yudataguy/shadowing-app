import XCTest
import AppIntents
@testable import ShadowingApp

final class PlayPlaylistIntentTests: XCTestCase {
    func test_perform_writesPendingIDToSharedDefaults() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var intent = PlayPlaylistIntent()
        intent.playlistID = "test-uuid-abc-123"

        _ = try await intent.perform(defaults: defaults)

        XCTAssertEqual(
            defaults.string(forKey: PlayPlaylistIntent.pendingIDKey),
            "test-uuid-abc-123"
        )
    }
}
