import WidgetKit
import SwiftUI

@main
struct ShadowingWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlaylistsWidget()
        FavoritePlaylistWidget()
    }
}
