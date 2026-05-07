import SwiftUI

struct MiniPlayerBar: View {
    @Environment(PlayerStore.self) private var player
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                HStack {
                    Image(systemName: "music.note")
                        .foregroundStyle(.secondary)
                    Text(player.currentTrack?.displayTitle ?? "")
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 32, height: 32)
            }

            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
}
