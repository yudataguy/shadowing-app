import Foundation
import SwiftData

@Model
final class PlaylistEntry {
    var id: UUID
    var trackStableID: String
    var position: Int
    var playlist: Playlist?

    init(trackStableID: String, position: Int) {
        self.id = UUID()
        self.trackStableID = trackStableID
        self.position = position
    }
}
