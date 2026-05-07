import Foundation

enum LoopMode: String, CaseIterable {
    case off, track, playlist

    var next: LoopMode {
        switch self {
        case .off: return .track
        case .track: return .playlist
        case .playlist: return .off
        }
    }
}
