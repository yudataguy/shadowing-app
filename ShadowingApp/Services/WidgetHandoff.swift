import Foundation

@MainActor
struct WidgetHandoff {
    let defaults: UserDefaults?
    let lookupAndPlay: (String) -> Void

    func handle() {
        guard let defaults,
              let id = defaults.string(forKey: PlayPlaylistIntent.pendingIDKey) else {
            return
        }
        defaults.removeObject(forKey: PlayPlaylistIntent.pendingIDKey)
        lookupAndPlay(id)
    }
}
