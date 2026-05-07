import Foundation
import SwiftData

@Model
final class Playlist {
    var id: UUID
    var name: String
    var createdAt: Date
    var lastPlayedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \PlaylistEntry.playlist)
    var entries: [PlaylistEntry] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
        self.lastPlayedAt = nil
    }
}
