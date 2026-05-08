import AppIntents
import Foundation

struct SelectPlaylistIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Playlist"
    static var description = IntentDescription(
        "Pick which playlist this widget should play."
    )

    @Parameter(title: "Playlist")
    var playlist: PlaylistEntity?

    init() {}
    init(playlist: PlaylistEntity?) { self.playlist = playlist }
}
