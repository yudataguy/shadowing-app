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
