import Foundation
import SwiftData

extension AppGroup {
    /// SwiftData container backed by the shared App Group container.
    /// Lives in the main app target only — the widget reads via JSON snapshot.
    static func makeSharedContainer() throws -> ModelContainer {
        let schema = Schema([Playlist.self, PlaylistEntry.self, PlaybackState.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(identifier)
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
