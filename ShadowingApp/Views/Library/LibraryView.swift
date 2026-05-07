import SwiftUI

struct LibraryView: View {
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(PlayerStore.self) private var player
    @Environment(LibrarySnapshot.self) private var librarySnapshot
    @State private var sections: [LibrarySection] = []
    @State private var showSettings = false
    @State private var showFirstPicker = false
    @State private var activeScopedURLs: [UUID: URL] = [:]   // bookmark id → currently-accessed URL

    struct LibrarySection: Identifiable {
        let id: UUID            // folderID
        let name: String        // display name
        let tracks: [Track]
    }

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.all().isEmpty {
                    ContentUnavailableView {
                        Label("No MP3 folder yet", systemImage: "music.note.list")
                    } description: {
                        Text("Pick a folder in iCloud Drive or Files to get started.")
                    } actions: {
                        Button("Pick Folder") { showFirstPicker = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else if sections.isEmpty {
                    ContentUnavailableView("No MP3s found",
                        systemImage: "music.note",
                        description: Text("Add audio files to your selected folder."))
                } else {
                    List {
                        ForEach(sections) { section in
                            Section {
                                ForEach(section.tracks) { track in
                                    TrackRow(track: track) {
                                        player.play(queue: section.tracks,
                                                    startIndex: section.tracks.firstIndex(of: track) ?? 0)
                                    }
                                }
                            } header: {
                                FolderSectionHeader(
                                    folderName: section.name,
                                    onPlay: { player.playFolder(section.tracks, shuffled: false) },
                                    onShuffle: { player.playFolder(section.tracks, shuffled: true) }
                                )
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings, onDismiss: rescan) { FoldersSettingsView() }
            .sheet(isPresented: $showFirstPicker) {
                DocumentPicker { url in
                    do {
                        let bookmark = try bookmarks.makeBookmark(from: url, displayName: url.lastPathComponent)
                        bookmarks.add(bookmark)
                        rescan()
                    } catch {}
                }
            }
            .onAppear { rescan() }
        }
    }

    private func rescan() {
        var newSections: [LibrarySection] = []
        var newActiveURLs: [UUID: URL] = [:]

        for bookmark in bookmarks.all() {
            guard let resolved = bookmarks.resolve(bookmark) else { continue }

            // If we already have access to this exact URL, reuse it (don't double-start).
            if activeScopedURLs[bookmark.id] != resolved.url {
                // Stop the old one if any (e.g., bookmark was re-resolved to a different URL).
                activeScopedURLs[bookmark.id]?.stopAccessingSecurityScopedResource()
                _ = resolved.url.startAccessingSecurityScopedResource()
            }
            newActiveURLs[bookmark.id] = resolved.url

            let tracks = LibraryService.scan(rootURL: resolved.url, folderID: bookmark.id)
                .sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
            if !tracks.isEmpty {
                newSections.append(LibrarySection(
                    id: bookmark.id,
                    name: bookmark.displayName,
                    tracks: tracks
                ))
            }
        }

        // Stop access on bookmarks that have been removed since the last scan.
        for (id, url) in activeScopedURLs where newActiveURLs[id] == nil {
            url.stopAccessingSecurityScopedResource()
        }

        activeScopedURLs = newActiveURLs
        sections = newSections
        librarySnapshot.update(newSections.flatMap(\.tracks))
    }
}
