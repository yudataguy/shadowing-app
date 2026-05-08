import XCTest
import AppIntents
@testable import ShadowingApp

final class PlaylistEntityQueryTests: XCTestCase {
    func test_suggestedEntities_returnsAllSnapshots() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let id1 = UUID(); let id2 = UUID()
        let snapshots = [
            PlaylistSnapshot(id: id1, name: "Morning",   trackCount: 5, lastPlayedAt: nil, createdAt: .now),
            PlaylistSnapshot(id: id2, name: "Evening",   trackCount: 3, lastPlayedAt: nil, createdAt: .now)
        ]
        PlaylistSnapshotStore.write(snapshots, to: defaults)

        let query = PlaylistEntityQuery(defaults: defaults)
        let entities = try await query.suggestedEntities()

        XCTAssertEqual(Set(entities.map(\.id)), Set([id1, id2]))
        XCTAssertEqual(Set(entities.map(\.name)), ["Morning", "Evening"])
    }

    func test_entitiesFor_returnsOnlyMatchingIDs() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let id1 = UUID(); let id2 = UUID(); let id3 = UUID()
        let snapshots = [
            PlaylistSnapshot(id: id1, name: "A", trackCount: 0, lastPlayedAt: nil, createdAt: .now),
            PlaylistSnapshot(id: id2, name: "B", trackCount: 0, lastPlayedAt: nil, createdAt: .now),
            PlaylistSnapshot(id: id3, name: "C", trackCount: 0, lastPlayedAt: nil, createdAt: .now)
        ]
        PlaylistSnapshotStore.write(snapshots, to: defaults)

        let query = PlaylistEntityQuery(defaults: defaults)
        let entities = try await query.entities(for: [id1, id3])

        XCTAssertEqual(Set(entities.map(\.name)), ["A", "C"])
    }

    func test_emptyWhenSnapshotEmpty() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let query = PlaylistEntityQuery(defaults: defaults)
        let count = try await query.suggestedEntities().count
        XCTAssertEqual(count, 0)
    }
}
