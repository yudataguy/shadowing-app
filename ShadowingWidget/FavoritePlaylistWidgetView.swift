// ShadowingWidget/FavoritePlaylistWidgetView.swift
import SwiftUI
import WidgetKit
import AppIntents

struct FavoritePlaylistWidgetView: View {
    let entry: FavoritePlaylistEntry

    var body: some View {
        Group {
            if let summary = entry.summary {
                configured(summary)
            } else {
                unconfigured
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

    private func configured(_ summary: PlaylistSummary) -> some View {
        Button(intent: PlayPlaylistIntent(playlistID: summary.id.uuidString)) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                Spacer()
                Text(summary.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text("\(summary.trackCount) track\(summary.trackCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .buttonStyle(.plain)
    }

    private var unconfigured: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.title)
                .foregroundStyle(.white)
            Text("Tap and hold to choose")
                .font(.caption)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
