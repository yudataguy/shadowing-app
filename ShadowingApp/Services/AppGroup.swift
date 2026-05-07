import Foundation
import SwiftData

enum AppGroup {
    static let identifier = "group.com.yudataguy.shadowingapp"

    /// SwiftData container backed by the shared App Group container so the
    /// widget extension can read from the same store as the main app.
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
