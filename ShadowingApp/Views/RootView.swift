import SwiftUI
import SwiftData

struct RootView: View {
    @State private var showNowPlaying = false
    @Environment(PlayerStore.self) private var player
    @Environment(\.modelContext) private var modelContext
    @Environment(LibrarySnapshot.self) private var librarySnapshot
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            LibraryView()
                .modifier(MiniPlayerInset(showNowPlaying: $showNowPlaying))
                .tabItem { Label("Library", systemImage: "music.note.list") }
            PlaylistsView()
                .modifier(MiniPlayerInset(showNowPlaying: $showNowPlaying))
                .tabItem { Label("Playlists", systemImage: "rectangle.stack") }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingSheet()
        }
        .alert("Playback error",
               isPresented: Binding(
                   get: { player.lastError != nil },
                   set: { if !$0 { player.clearError() } }
               ),
               presenting: player.lastError) { _ in
            Button("OK") { player.clearError() }
        } message: { error in
            Text(error)
        }
        .task { handleWidgetHandoff() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                handleWidgetHandoff()
            }
        }
    }

    private func handleWidgetHandoff() {
        let handoff = WidgetHandoff(
            defaults: UserDefaults(suiteName: AppGroup.identifier),
            lookupAndPlay: { idString in
                guard let uuid = UUID(uuidString: idString) else { return }
                let descriptor = FetchDescriptor<Playlist>(
                    predicate: #Predicate { $0.id == uuid }
                )
                guard let playlist = try? modelContext.fetch(descriptor).first else { return }
                let entries = playlist.entries.sorted { $0.position < $1.position }
                let tracks = entries.compactMap {
                    librarySnapshot.track(forStableID: $0.trackStableID)
                }
                guard !tracks.isEmpty else { return }
                player.playPlaylist(playlist, tracks: tracks, fromIndex: 0)
            }
        )
        handoff.handle()
    }
}

private struct MiniPlayerInset: ViewModifier {
    @Binding var showNowPlaying: Bool
    @Environment(PlayerStore.self) private var player

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if player.currentTrack != nil {
                MiniPlayerBar(onTap: { showNowPlaying = true })
            }
        }
    }
}
