import WidgetKit
import Foundation

struct FavoritePlaylistEntry: TimelineEntry {
    let date: Date
    let summary: PlaylistSummary?
}

struct FavoritePlaylistTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = FavoritePlaylistEntry
    typealias Intent = SelectPlaylistIntent

    func placeholder(in context: Context) -> FavoritePlaylistEntry {
        FavoritePlaylistEntry(
            date: .now,
            summary: PlaylistSummary(id: UUID(), name: "Morning drills", trackCount: 12)
        )
    }

    func snapshot(for configuration: SelectPlaylistIntent, in context: Context) async -> FavoritePlaylistEntry {
        FavoritePlaylistEntry(date: .now, summary: resolve(configuration))
    }

    func timeline(for configuration: SelectPlaylistIntent, in context: Context) async -> Timeline<FavoritePlaylistEntry> {
        let entry = FavoritePlaylistEntry(date: .now, summary: resolve(configuration))
        let next = Date.now.addingTimeInterval(15 * 60)
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func resolve(_ configuration: SelectPlaylistIntent) -> PlaylistSummary? {
        guard let id = configuration.playlist?.id else { return nil }
        let snapshots = PlaylistSnapshotStore.read(from: UserDefaults(suiteName: AppGroup.identifier))
        guard let s = snapshots.first(where: { $0.id == id }) else { return nil }
        return PlaylistSummary(id: s.id, name: s.name, trackCount: s.trackCount)
    }
}
