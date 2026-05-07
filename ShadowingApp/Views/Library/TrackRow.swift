import SwiftUI

struct TrackRow: View {
    let track: Track
    let onTap: () -> Void
    @State private var showAddToPlaylist = false

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(track.displayTitle)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button {
                showAddToPlaylist = true
            } label: {
                Label("Add to Playlist", systemImage: "text.badge.plus")
            }
            .tint(.blue)
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistSheet(track: track)
        }
    }
}
