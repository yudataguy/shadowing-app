import SwiftUI

struct FoldersSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BookmarkStore.self) private var bookmarks
    @State private var folders: [FolderBookmark] = []
    @State private var showPicker = false
    @State private var renameTarget: FolderBookmark?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                if folders.isEmpty {
                    ContentUnavailableView(
                        "No folders yet",
                        systemImage: "folder.badge.plus",
                        description: Text("Tap Add to pick an MP3 folder from iCloud Drive or Files.")
                    )
                } else {
                    ForEach(folders) { folder in
                        Button {
                            renameTarget = folder
                            renameText = folder.displayName
                        } label: {
                            HStack {
                                Text(folder.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "pencil")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: removeFolders)
                }
            }
            .navigationTitle("Folders")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                DocumentPicker { url in
                    do {
                        let bookmark = try bookmarks.makeBookmark(
                            from: url,
                            displayName: url.lastPathComponent
                        )
                        bookmarks.add(bookmark)
                        folders = bookmarks.all()
                    } catch {
                        // Bookmark creation failure is rare; surface silently for now
                    }
                }
            }
            .onAppear { folders = bookmarks.all() }
            .alert("Rename Folder",
                   isPresented: Binding(
                       get: { renameTarget != nil },
                       set: { if !$0 { renameTarget = nil } }
                   ),
                   presenting: renameTarget) { folder in
                TextField("Folder name", text: $renameText)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    var updated = folder
                    updated.displayName = trimmed
                    bookmarks.update(updated)
                    folders = bookmarks.all()
                }
            } message: { _ in
                Text("Choose a name to display for this folder.")
            }
        }
    }

    private func removeFolders(at offsets: IndexSet) {
        for offset in offsets {
            bookmarks.remove(id: folders[offset].id)
        }
        folders = bookmarks.all()
    }
}
