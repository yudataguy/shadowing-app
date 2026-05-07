import WidgetKit
import SwiftUI

struct PlaylistsWidget: Widget {
    let kind = "PlaylistsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaylistsTimelineProvider()) { entry in
            PlaylistsWidgetView(entry: entry)
        }
        .configurationDisplayName("Shadowing Playlists")
        .description("Quickly play a recent playlist.")
        .supportedFamilies([.systemMedium])
    }
}

// Temporary stub — Task 7 replaces this with the real grid view in its own file.
struct PlaylistsWidgetView: View {
    let entry: PlaylistTimelineEntry
    var body: some View {
        Text(entry.playlists.first?.name ?? "Empty")
            .containerBackground(for: .widget) { Color.indigo }
    }
}
