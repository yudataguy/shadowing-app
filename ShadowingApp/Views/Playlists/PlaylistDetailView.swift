import SwiftUI
import SwiftData

struct PlaylistDetailView: View {
    @Bindable var playlist: Playlist
    @Environment(\.modelContext) private var modelContext
    @Environment(LibrarySnapshot.self) private var snapshot
    @Environment(PlayerStore.self) private var player
    @Environment(PlaylistSnapshotPublisher.self) private var snapshotPublisher
    @State private var showRename = false
    @State private var renameText = ""

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
                        onPlay: {
                            player.playPlaylist(playlist, tracks: orderedTracks, fromIndex: 0)
                        },
                        onShuffle: {
                            playlist.lastPlayedAt = .now
                            try? modelContext.save()
                            snapshotPublisher.publish()
                            player.playFolder(orderedTracks, shuffled: true)
                        }
                    )
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    renameText = playlist.name
                    showRename = true
                } label: { Image(systemName: "pencil") }
            }
        }
        .alert("Rename Playlist", isPresented: $showRename) {
            TextField("Playlist name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                playlist.name = trimmed
                try? modelContext.save()
                snapshotPublisher.publish()
            }
        }
    }

    private func moveTracks(from source: IndexSet, to destination: Int) {
        var sortedEntries = playlist.entries.sorted { $0.position < $1.position }
        sortedEntries.move(fromOffsets: source, toOffset: destination)
        for (newPosition, entry) in sortedEntries.enumerated() {
            entry.position = newPosition
        }
        try? modelContext.save()
        snapshotPublisher.publish()
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
        snapshotPublisher.publish()
    }
}
