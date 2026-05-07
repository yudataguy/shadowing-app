import Foundation
import SwiftData

@MainActor
final class SwiftDataPlaybackPersistence: PlaybackStatePersisting {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func lastPosition(for stableID: String) -> TimeInterval? {
        let descriptor = FetchDescriptor<PlaybackState>(
            predicate: #Predicate { $0.trackStableID == stableID }
        )
        return (try? context.fetch(descriptor))?.first?.lastPosition
    }

    func savePosition(_ position: TimeInterval, for stableID: String) {
        let descriptor = FetchDescriptor<PlaybackState>(
            predicate: #Predicate { $0.trackStableID == stableID }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.lastPosition = position
            existing.lastPlayedAt = .now
        } else {
            context.insert(PlaybackState(trackStableID: stableID, lastPosition: position))
        }
        try? context.save()
    }
}
