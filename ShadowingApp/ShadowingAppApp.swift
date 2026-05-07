import SwiftUI
import SwiftData

@main
struct ShadowingAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Playlist.self, PlaylistEntry.self, PlaybackState.self])
    }
}
