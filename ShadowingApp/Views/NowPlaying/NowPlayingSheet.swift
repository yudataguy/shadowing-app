import SwiftUI

struct NowPlayingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayerStore.self) private var player
    @State private var showAddToPlaylist = false

    private let speeds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 4) {
                    Text(player.currentTrack?.displayTitle ?? "—")
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                ScrubberView(
                    currentTime: player.currentTime,
                    duration: player.currentDuration,
                    onSeek: { player.seek(to: $0) }
                )
                .padding(.horizontal)

                HStack(spacing: 32) {
                    Button { player.previous() } label: {
                        Image(systemName: "backward.fill").font(.title2)
                    }
                    Button { player.skip(by: -15) } label: {
                        Image(systemName: "gobackward.15").font(.title2)
                    }
                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                    }
                    Button { player.skip(by: 15) } label: {
                        Image(systemName: "goforward.15").font(.title2)
                    }
                    Button { player.next() } label: {
                        Image(systemName: "forward.fill").font(.title2)
                    }
                }
                .foregroundStyle(.primary)

                HStack(spacing: 24) {
                    Button {
                        player.toggleShuffle()
                    } label: {
                        Image(systemName: "shuffle")
                            .foregroundStyle(player.shuffleEnabled ? Color.accentColor : .primary)
                    }

                    Button {
                        player.setLoopMode(player.loopMode.next)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: loopIcon)
                            Text(loopBadge).font(.caption2)
                        }
                        .foregroundStyle(player.loopMode == .off ? .primary : Color.accentColor)
                    }

                    Menu {
                        ForEach(speeds, id: \.self) { rate in
                            Button(action: { player.setRate(rate) }) {
                                if rate == player.playbackRate {
                                    Label(rateLabel(rate), systemImage: "checkmark")
                                } else {
                                    Text(rateLabel(rate))
                                }
                            }
                        }
                    } label: {
                        Text(rateLabel(player.playbackRate))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(player.playbackRate == 1.0 ? .primary : Color.accentColor)
                    }
                }
                .font(.title3)

                if player.currentTrack != nil {
                    Button {
                        showAddToPlaylist = true
                    } label: {
                        Label("Add to Playlist", systemImage: "text.badge.plus")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddToPlaylist) {
                if let track = player.currentTrack {
                    AddToPlaylistSheet(track: track)
                }
            }
        }
    }

    private var loopIcon: String {
        switch player.loopMode {
        case .off: return "repeat"
        case .track: return "repeat.1"
        case .playlist: return "repeat"
        }
    }

    private var loopBadge: String {
        switch player.loopMode {
        case .off: return "Off"
        case .track: return "1"
        case .playlist: return "All"
        }
    }

    private func rateLabel(_ rate: Double) -> String {
        if rate == floor(rate) {
            return String(format: "%.1f×", rate)
        } else {
            return String(format: "%.2f×", rate)
        }
    }
}
