import SwiftUI

struct RootView: View {
    @State private var showNowPlaying = false
    @Environment(PlayerStore.self) private var player

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
