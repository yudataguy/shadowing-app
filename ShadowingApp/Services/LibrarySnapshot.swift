import Foundation
import Observation

@Observable
@MainActor
final class LibrarySnapshot {
    private(set) var allTracks: [Track] = []

    func update(_ tracks: [Track]) {
        allTracks = tracks
    }

    func track(forStableID stableID: String) -> Track? {
        allTracks.first { $0.stableID == stableID }
    }
}
