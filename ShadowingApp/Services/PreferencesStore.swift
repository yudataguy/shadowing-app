import Foundation

final class PreferencesStore {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var playbackRate: Double {
        get { defaults.object(forKey: "playbackRate") as? Double ?? 1.0 }
        set { defaults.set(newValue, forKey: "playbackRate") }
    }

    var loopMode: LoopMode {
        get { LoopMode(rawValue: defaults.string(forKey: "loopMode") ?? "") ?? .off }
        set { defaults.set(newValue.rawValue, forKey: "loopMode") }
    }

    var shuffleEnabled: Bool {
        get { defaults.bool(forKey: "shuffleEnabled") }
        set { defaults.set(newValue, forKey: "shuffleEnabled") }
    }
}
