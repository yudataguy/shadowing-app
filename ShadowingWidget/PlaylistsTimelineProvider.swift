import WidgetKit
import SwiftData
import Foundation

struct PlaylistTimelineEntry: TimelineEntry {
    let date: Date
    let playlists: [PlaylistSummary]

    static let empty = PlaylistTimelineEntry(date: .now, playlists: [])
}

struct PlaylistSummary: Identifiable, Hashable {
    let id: UUID
    let name: String
    let trackCount: Int
}

struct PlaylistsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaylistTimelineEntry {
        PlaylistTimelineEntry(date: .now, playlists: [
            PlaylistSummary(id: UUID(), name: "Morning drills", trackCount: 12),
            PlaylistSummary(id: UUID(), name: "Spanish phrases", trackCount: 8),
            PlaylistSummary(id: UUID(), name: "French sentences", trackCount: 5),
            PlaylistSummary(id: UUID(), name: "Pronunciation", trackCount: 20)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (PlaylistTimelineEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaylistTimelineEntry>) -> Void) {
        let entry = currentEntry()
        let next = Date.now.addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> PlaylistTimelineEntry {
        let summaries = (try? fetchTopPlaylists()) ?? []
        return PlaylistTimelineEntry(date: .now, playlists: summaries)
    }

    private func fetchTopPlaylists() throws -> [PlaylistSummary] {
        let container = try AppGroup.makeSharedContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Playlist>(
            sortBy: [
                SortDescriptor(\.lastPlayedAt, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse)
            ]
        )
        let all = try context.fetch(descriptor)
        return all.prefix(4).map {
            PlaylistSummary(id: $0.id, name: $0.name, trackCount: $0.entries.count)
        }
    }
}
