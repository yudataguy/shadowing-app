import SwiftUI
import SwiftData

@main
struct ShadowingAppApp: App {
    @State private var playerStore: PlayerStore
    @State private var snapshotPublisher: PlaylistSnapshotPublisher
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

        let publisher = PlaylistSnapshotPublisher(context: container.mainContext)
        publisher.publish()  // initial write so widget has data on first launch
        _snapshotPublisher = State(initialValue: publisher)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(playerStore)
                .environment(bookmarks)
                .environment(librarySnapshot)
                .environment(snapshotPublisher)
        }
        .modelContainer(modelContainer)
    }
}
