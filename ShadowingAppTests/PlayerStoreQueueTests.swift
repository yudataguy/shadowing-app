import XCTest
import SwiftData
@testable import ShadowingApp

@MainActor
final class PlayerStoreQueueTests: XCTestCase {
    var engine: FakePlayerEngine!
    var prefs: PreferencesStore!
    var store: PlayerStore!

    override func setUp() async throws {
        engine = FakePlayerEngine()
        prefs = PreferencesStore(defaults: UserDefaults(suiteName: "test-\(UUID())")!)
        store = PlayerStore(engine: engine, preferences: prefs, persistence: NoopPersistence())
    }

    private func makeQueue(_ count: Int) -> [Track] {
        let folderID = UUID()
        return (0..<count).map { Track(folderID: folderID, relativePath: "\($0).mp3", url: URL(fileURLWithPath: "/tmp/\($0).mp3")) }
    }

    func test_play_loadsFirstTrackAndPlays() {
        let queue = makeQueue(3)
        store.play(queue: queue, startIndex: 0)
        XCTAssertEqual(engine.loadedURLs.count, 1)
        XCTAssertEqual(engine.loadedURLs.first?.lastPathComponent, "0.mp3")
        XCTAssertEqual(engine.didCallPlay, 1)
    }

    func test_trackEnded_loopOff_advances() {
        prefs.loopMode = .off
        let queue = makeQueue(3)
        store.play(queue: queue, startIndex: 0)
        engine.simulateTrackEnded()
        XCTAssertEqual(engine.loadedURLs.last?.lastPathComponent, "1.mp3")
    }

    func test_trackEnded_loopOff_atEnd_stops() {
        prefs.loopMode = .off
        let queue = makeQueue(2)
        store.play(queue: queue, startIndex: 1)
        engine.simulateTrackEnded()
        XCTAssertEqual(engine.didCallPause, 1)
        XCTAssertEqual(store.currentIndex, 1)
    }

    func test_trackEnded_loopTrack_seeksToZero() {
        prefs.loopMode = .track
        let queue = makeQueue(2)
        store.play(queue: queue, startIndex: 0)
        engine.simulateTrackEnded()
        XCTAssertEqual(engine.seekTimes, [0])
        XCTAssertEqual(engine.loadedURLs.count, 1) // didn't reload
    }

    func test_trackEnded_loopPlaylist_wrapsToStart() {
        prefs.loopMode = .playlist
        let queue = makeQueue(2)
        store.play(queue: queue, startIndex: 1)
        engine.simulateTrackEnded()
        XCTAssertEqual(engine.loadedURLs.last?.lastPathComponent, "0.mp3")
    }

    func test_shuffle_visitsAllBeforeRepeating() {
        prefs.shuffleEnabled = true
        prefs.loopMode = .playlist
        let queue = makeQueue(4)
        store.play(queue: queue, startIndex: 0)

        var visited = Set<String>()
        visited.insert(engine.loadedURLs.last!.lastPathComponent)
        for _ in 0..<3 {
            engine.simulateTrackEnded()
            visited.insert(engine.loadedURLs.last!.lastPathComponent)
        }
        XCTAssertEqual(visited.count, 4)
    }

    func test_playPlaylist_updatesLastPlayedAt() async throws {
        let schema = Schema([Playlist.self, PlaylistEntry.self, PlaybackState.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let playlist = Playlist(name: "Test")
        context.insert(playlist)
        try context.save()

        let track = Track(folderID: UUID(),
                          relativePath: "x.mp3",
                          url: URL(fileURLWithPath: "/tmp/x.mp3"))

        XCTAssertNil(playlist.lastPlayedAt)
        store.playPlaylist(playlist, tracks: [track], fromIndex: 0)
        XCTAssertNotNil(playlist.lastPlayedAt)
    }
}

final class NoopPersistence: PlaybackStatePersisting {
    func lastPosition(for stableID: String) -> TimeInterval? { nil }
    func savePosition(_ position: TimeInterval, for stableID: String) {}
}
