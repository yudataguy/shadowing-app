import AppIntents
import Foundation

struct PlaylistEntity: AppEntity {
    let id: UUID
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Playlist"
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = PlaylistEntityQuery()
}

struct PlaylistEntityQuery: EntityQuery {
    let defaults: UserDefaults?

    init() {
        self.defaults = UserDefaults(suiteName: AppGroup.identifier)
    }

    init(defaults: UserDefaults?) {
        self.defaults = defaults
    }

    func entities(for identifiers: [PlaylistEntity.ID]) async throws -> [PlaylistEntity] {
        let snapshots = PlaylistSnapshotStore.read(from: defaults)
        let idSet = Set(identifiers)
        return snapshots
            .filter { idSet.contains($0.id) }
            .map { PlaylistEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [PlaylistEntity] {
        let snapshots = PlaylistSnapshotStore.read(from: defaults)
        return snapshots.map { PlaylistEntity(id: $0.id, name: $0.name) }
    }
}
