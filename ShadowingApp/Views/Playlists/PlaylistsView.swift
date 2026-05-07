import SwiftUI
import SwiftData

struct PlaylistsView: View {
    @Query(sort: \Playlist.createdAt, order: .reverse) private var playlists: [Playlist]
    @Environment(\.modelContext) private var modelContext
    @Environment(PlaylistSnapshotPublisher.self) private var snapshotPublisher
    @State private var showNewSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if playlists.isEmpty {
                    ContentUnavailableView(
                        "No playlists yet",
                        systemImage: "rectangle.stack.badge.plus",
                        description: Text("Tap + to create one.")
                    )
                } else {
                    List {
                        ForEach(playlists) { playlist in
                            NavigationLink(value: playlist) {
                                VStack(alignment: .leading) {
                                    Text(playlist.name)
                                    Text("\(playlist.entries.count) track\(playlist.entries.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { offsets in
                            for offset in offsets {
                                modelContext.delete(playlists[offset])
                            }
                            try? modelContext.save()
                            snapshotPublisher.publish()
                        }
                    }
                }
            }
            .navigationTitle("Playlists")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: Playlist.self) { playlist in
                PlaylistDetailView(playlist: playlist)
            }
            .sheet(isPresented: $showNewSheet) {
                NewPlaylistSheet()
            }
        }
    }
}
