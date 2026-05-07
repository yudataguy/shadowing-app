import MediaPlayer

@MainActor
final class NowPlayingCenter {
    func update(title: String, duration: TimeInterval, elapsed: TimeInterval, rate: Double) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func registerCommands(store: PlayerStore) {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { _ in
            Task { @MainActor in store.togglePlayPause() }
            return .success
        }
        center.pauseCommand.addTarget { _ in
            Task { @MainActor in store.togglePlayPause() }
            return .success
        }
        center.nextTrackCommand.addTarget { _ in
            Task { @MainActor in store.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { _ in
            Task { @MainActor in store.previous() }
            return .success
        }
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { _ in
            Task { @MainActor in store.skip(by: 15) }
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { _ in
            Task { @MainActor in store.skip(by: -15) }
            return .success
        }
    }
}
