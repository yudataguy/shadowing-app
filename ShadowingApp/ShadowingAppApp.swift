import SwiftUI
import SwiftData

@main
struct ShadowingAppApp: App {
    @State private var playerStore: PlayerStore
    private let bookmarks = BookmarkStore()
    private let librarySnapshot = LibrarySnapshot()
    let modelContainer: ModelContainer

    init() {
        let container: ModelContainer
        do {
            container = try AppGroup.makeSharedContainer()
        } catch {
            fatalError("Failed to create shared model container: \(error)")
        }
        self.modelContainer = container

        let prefs = PreferencesStore()
        let persistence = SwiftDataPlaybackPersistence(context: container.mainContext)
        let engine = AVPlayerEngine()
        AudioSessionCoordinator().activate()
        let nowPlaying = NowPlayingCenter()
        let store = PlayerStore(engine: engine, preferences: prefs, persistence: persistence, nowPlaying: nowPlaying)
        nowPlaying.registerCommands(store: store)
        _playerStore = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(playerStore)
                .environment(bookmarks)
                .environment(librarySnapshot)
        }
        .modelContainer(modelContainer)
    }
}
