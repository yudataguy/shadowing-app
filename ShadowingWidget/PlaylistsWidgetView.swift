import SwiftUI
import WidgetKit
import AppIntents

struct PlaylistsWidgetView: View {
    let entry: PlaylistTimelineEntry

    private var displayed: [PlaylistSummary?] {
        // Pad up to 4 slots so the grid layout stays stable.
        var arr: [PlaylistSummary?] = entry.playlists.map { Optional($0) }
        while arr.count < 4 { arr.append(nil) }
        return Array(arr.prefix(4))
    }

    var body: some View {
        Group {
            if entry.playlists.isEmpty {
                emptyContent
            } else {
                gridContent
            }
        }
        .containerBackground(for: .widget) { background }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.39, green: 0.40, blue: 0.95),
                     Color(red: 0.02, green: 0.71, blue: 0.83)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var gridContent: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                tile(displayed[0])
                tile(displayed[1])
            }
            HStack(spacing: 6) {
                tile(displayed[2])
                tile(displayed[3])
            }
        }
    }

    @ViewBuilder
    private func tile(_ summary: PlaylistSummary?) -> some View {
        if let summary {
            Button(intent: PlayPlaylistIntent(playlistID: summary.id.uuidString)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Spacer()
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.caption2)
                        Text("\(summary.trackCount)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white.opacity(0.85))
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.06))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyContent: some View {
        VStack(spacing: 6) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.title2)
                .foregroundStyle(.white)
            Text("Create a playlist in the app")
                .font(.caption)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
