import Foundation

struct PlaylistSnapshot: Codable, Equatable {
    let id: UUID
    let name: String
    let trackCount: Int
    let lastPlayedAt: Date?
    let createdAt: Date
}

enum PlaylistSnapshotStore {
    static let key = "playlistSnapshots.v1"

    static func write(_ snapshots: [PlaylistSnapshot], to defaults: UserDefaults?) {
        guard let defaults else { return }
        if let data = try? JSONEncoder().encode(snapshots) {
            defaults.set(data, forKey: key)
            defaults.synchronize()  // cross-process flush
        }
    }

    static func read(from defaults: UserDefaults?) -> [PlaylistSnapshot] {
        guard let defaults,
              let data = defaults.data(forKey: key),
              let snapshots = try? JSONDecoder().decode([PlaylistSnapshot].self, from: data) else {
            return []
        }
        return snapshots
    }
}
