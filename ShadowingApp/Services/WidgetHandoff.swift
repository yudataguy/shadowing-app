import Foundation

@MainActor
struct WidgetHandoff {
    let defaults: UserDefaults?
    /// Returns true if the playlist was successfully played. Only on success
    /// will the pending key be cleared.
    let lookupAndPlay: (String) -> Bool

    func handle() {
        guard let defaults,
              let id = defaults.string(forKey: PlayPlaylistIntent.pendingIDKey) else {
            return
        }
        if lookupAndPlay(id) {
            defaults.removeObject(forKey: PlayPlaylistIntent.pendingIDKey)
        }
    }
}
