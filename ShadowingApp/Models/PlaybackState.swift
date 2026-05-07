import Foundation
import SwiftData

@Model
final class PlaybackState {
    @Attribute(.unique) var trackStableID: String
    var lastPosition: TimeInterval
    var lastPlayedAt: Date

    init(trackStableID: String, lastPosition: TimeInterval, lastPlayedAt: Date = .now) {
        self.trackStableID = trackStableID
        self.lastPosition = lastPosition
        self.lastPlayedAt = lastPlayedAt
    }
}
