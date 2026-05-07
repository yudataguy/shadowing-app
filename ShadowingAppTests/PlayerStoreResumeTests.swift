import XCTest
@testable import ShadowingApp

@MainActor
final class PlayerStoreResumeTests: XCTestCase {
    func test_resume_seeksToLastPosition_whenAvailable() {
        let engine = FakePlayerEngine()
        let prefs = PreferencesStore(defaults: UserDefaults(suiteName: "t-\(UUID())")!)
        let persistence = MemoryPersistence()

        let track = Track(folderID: UUID(), relativePath: "x.mp3", url: URL(fileURLWithPath: "/tmp/x.mp3"))
        let store = PlayerStore(engine: engine, preferences: prefs, persistence: persistence)
        // seed persistence with the actual stableID
        persistence.savePosition(42, for: track.stableID)

        store.play(queue: [track], startIndex: 0)
        XCTAssertEqual(engine.seekTimes, [42])
    }

    func test_resume_doesNotSeek_whenNearEnd() {
        let engine = FakePlayerEngine()
        let prefs = PreferencesStore(defaults: UserDefaults(suiteName: "t-\(UUID())")!)
        let persistence = MemoryPersistence()
        let track = Track(folderID: UUID(), relativePath: "x.mp3", url: URL(fileURLWithPath: "/tmp/x.mp3"))
        let store = PlayerStore(engine: engine, preferences: prefs, persistence: persistence)

        // simulate persistence reporting near-end position; PlayerStore should skip the seek.
        engine.durationSubject.send(60)
        persistence.savePosition(58, for: track.stableID) // within last 5s

        store.play(queue: [track], startIndex: 0)
        XCTAssertEqual(engine.seekTimes, [])
    }
}

final class MemoryPersistence: PlaybackStatePersisting {
    private var dict: [String: TimeInterval] = [:]
    func lastPosition(for stableID: String) -> TimeInterval? { dict[stableID] }
    func savePosition(_ position: TimeInterval, for stableID: String) { dict[stableID] = position }
}
