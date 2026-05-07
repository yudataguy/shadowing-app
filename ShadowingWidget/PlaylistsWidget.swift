import WidgetKit
import SwiftUI

struct PlaylistsWidget: Widget {
    let kind = "PlaylistsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { _ in
            Text("Shadowing — placeholder")
                .containerBackground(for: .widget) { Color.indigo }
        }
        .configurationDisplayName("Shadowing Playlists")
        .description("Quickly play a playlist.")
        .supportedFamilies([.systemMedium])
    }
}

private struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry { SimpleEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        completion(Timeline(entries: [SimpleEntry(date: .now)],
                            policy: .after(.now.addingTimeInterval(900))))
    }
}

private struct SimpleEntry: TimelineEntry {
    let date: Date
}
