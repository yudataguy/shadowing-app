import SwiftUI
import SwiftData

struct PlaylistDetailView: View {
    @Bindable var playlist: Playlist
    @Environment(\.modelContext) private var modelContext
    @Environment(LibrarySnapshot.self) private var snapshot
    @Environment(PlayerStore.self) private var player

    private var orderedTracks: [Track] {
        playlist.entries
            .sorted { $0.position < $1.position }
            .compactMap { snapshot.track(forStableID: $0.trackStableID) }
    }

    var body: some View {
        List {
            if orderedTracks.isEmpty {
                ContentUnavailableView("Empty playlist",
                    systemImage: "music.note.list",
                    description: Text("Add tracks from the Library tab."))
            } else {
                Section {
                    ForEach(orderedTracks) { track in
                        Text(track.displayTitle)
                    }
                    .onMove(perform: moveTracks)
                    .onDelete(perform: deleteTracks)
                } header: {
                    FolderSectionHeader(
                        folderName: playlist.name,
                        onPlay: { player.playFolder(orderedTracks, shuffled: false) },
                        onShuffle: { player.playFolder(orderedTracks, shuffled: true) }
                    )
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
    }

    private func moveTracks(from source: IndexSet, to destination: Int) {
        var sortedEntries = playlist.entries.sorted { $0.position < $1.position }
        sortedEntries.move(fromOffsets: source, toOffset: destination)
        for (newPosition, entry) in sortedEntries.enumerated() {
            entry.position = newPosition
        }
        try? modelContext.save()
    }

    private func deleteTracks(at offsets: IndexSet) {
        let sortedEntries = playlist.entries.sorted { $0.position < $1.position }
        let toDelete = offsets.map { sortedEntries[$0] }
        for entry in toDelete {
            modelContext.delete(entry)
        }
        let remaining = sortedEntries.filter { entry in !toDelete.contains(where: { $0.id == entry.id }) }
        for (idx, entry) in remaining.enumerated() {
            entry.position = idx
        }
        try? modelContext.save()
    }
}
