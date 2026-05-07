import XCTest
@testable import ShadowingApp

final class PlaylistSnapshotTests: XCTestCase {
    func test_writeAndRead_roundtripsSnapshots() throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let snapshots = [
            PlaylistSnapshot(id: UUID(), name: "A", trackCount: 3,
                            lastPlayedAt: .now, createdAt: .now),
            PlaylistSnapshot(id: UUID(), name: "B", trackCount: 0,
                            lastPlayedAt: nil, createdAt: .now)
        ]

        PlaylistSnapshotStore.write(snapshots, to: defaults)
        let read = PlaylistSnapshotStore.read(from: defaults)
        XCTAssertEqual(read, snapshots)
    }

    func test_read_emptyWhenKeyAbsent() {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(PlaylistSnapshotStore.read(from: defaults), [])
    }
}
