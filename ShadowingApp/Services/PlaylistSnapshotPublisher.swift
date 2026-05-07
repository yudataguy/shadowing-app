import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class PlaylistSnapshotPublisher {
    private let context: ModelContext
    private let defaults: UserDefaults?

    init(context: ModelContext, defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)) {
        self.context = context
        self.defaults = defaults
    }

    /// Reads all playlists, sorts them, and writes a snapshot to App Group defaults.
    /// Call this after any mutation that affects playlist names, counts, or lastPlayedAt.
    func publish() {
        let descriptor = FetchDescriptor<Playlist>(
            sortBy: [
                SortDescriptor(\.lastPlayedAt, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse)
            ]
        )
        let playlists = (try? context.fetch(descriptor)) ?? []
        let snapshots = playlists.map { p in
            PlaylistSnapshot(
                id: p.id,
                name: p.name,
                trackCount: p.entries.count,
                lastPlayedAt: p.lastPlayedAt,
                createdAt: p.createdAt
            )
        }
        PlaylistSnapshotStore.write(snapshots, to: defaults)
    }
}
