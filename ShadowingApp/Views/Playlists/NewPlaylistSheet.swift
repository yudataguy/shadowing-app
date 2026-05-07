import SwiftUI
import SwiftData

struct NewPlaylistSheet: View {
    var onCreate: ((Playlist) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PlaylistSnapshotPublisher.self) private var snapshotPublisher
    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Playlist name", text: $name)
                    .textInputAutocapitalization(.words)
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        let playlist = Playlist(name: trimmed)
                        modelContext.insert(playlist)
                        try? modelContext.save()
                        snapshotPublisher.publish()
                        onCreate?(playlist)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
