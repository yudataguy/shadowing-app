import Foundation

@MainActor
protocol PlaybackStatePersisting {
    func lastPosition(for stableID: String) -> TimeInterval?
    func savePosition(_ position: TimeInterval, for stableID: String)
}
