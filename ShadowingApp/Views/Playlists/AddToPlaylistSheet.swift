import SwiftUI
import SwiftData

struct AddToPlaylistSheet: View {
    let track: Track
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Playlist.createdAt, order: .reverse) private var playlists: [Playlist]
    @State private var showNewSheet = false

    var body: some View {
        NavigationStack {
            List {
                Button {
                    showNewSheet = true
                } label: {
                    Label("New playlist…", systemImage: "plus")
                }
                ForEach(playlists) { playlist in
                    Button {
                        addToPlaylist(playlist)
                    } label: {
                        HStack {
                            Text(playlist.name)
                            Spacer()
                            Text("\(playlist.entries.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showNewSheet) { NewPlaylistSheet() }
        }
    }

    private func addToPlaylist(_ playlist: Playlist) {
        let entry = PlaylistEntry(
            trackStableID: track.stableID,
            position: playlist.entries.count
        )
        entry.playlist = playlist
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
}
