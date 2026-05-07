import SwiftUI

struct RootView: View {
    @State private var showNowPlaying = false
    @Environment(PlayerStore.self) private var player

    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("Library", systemImage: "music.note.list") }
            PlaylistsView()
                .tabItem { Label("Playlists", systemImage: "rectangle.stack") }
        }
        .safeAreaInset(edge: .bottom) {
            if player.currentTrack != nil {
                MiniPlayerBar(onTap: { showNowPlaying = true })
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingSheet()
        }
    }
}
