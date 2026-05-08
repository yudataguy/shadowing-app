import WidgetKit
import SwiftUI

struct FavoritePlaylistWidget: Widget {
    let kind = "FavoritePlaylistWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectPlaylistIntent.self,
            provider: FavoritePlaylistTimelineProvider()
        ) { entry in
            FavoritePlaylistWidgetView(entry: entry)
        }
        .configurationDisplayName("Shadowing — Favorite Playlist")
        .description("One-tap play for a chosen playlist.")
        .supportedFamilies([.systemSmall])
    }
}
