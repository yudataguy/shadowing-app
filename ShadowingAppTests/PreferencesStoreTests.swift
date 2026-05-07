import XCTest
@testable import ShadowingApp

final class PreferencesStoreTests: XCTestCase {
    var defaults: UserDefaults!
    var store: PreferencesStore!

    override func setUp() {
        defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        store = PreferencesStore(defaults: defaults)
    }

    func test_defaults() {
        XCTAssertEqual(store.playbackRate, 1.0)
        XCTAssertEqual(store.loopMode, .off)
        XCTAssertFalse(store.shuffleEnabled)
    }

    func test_persistRate() {
        store.playbackRate = 0.75
        let store2 = PreferencesStore(defaults: defaults)
        XCTAssertEqual(store2.playbackRate, 0.75)
    }

    func test_loopModeRoundtrip() {
        store.loopMode = .playlist
        XCTAssertEqual(PreferencesStore(defaults: defaults).loopMode, .playlist)
    }
}
