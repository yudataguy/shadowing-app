import AppIntents
import Foundation

struct PlayPlaylistIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Playlist"
    static var description = IntentDescription("Open Shadowing and play a specific playlist.")
    static var openAppWhenRun: Bool = true

    static let pendingIDKey = "pendingPlaylistID"

    @Parameter(title: "Playlist ID")
    var playlistID: String

    init() {}
    init(playlistID: String) { self.playlistID = playlistID }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        return try await perform(defaults: defaults)
    }

    /// Test-friendly seam.
    func perform(defaults: UserDefaults?) async throws -> some IntentResult {
        defaults?.set(playlistID, forKey: Self.pendingIDKey)
        return .result()
    }
}
