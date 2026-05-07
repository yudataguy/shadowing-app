import Foundation
import Combine
import Observation

@Observable
@MainActor
final class PlayerStore {
    private let engine: PlayerEngine
    private let preferences: PreferencesStore
    private let persistence: PlaybackStatePersisting
    private let nowPlaying: NowPlayingCenter?
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    private(set) var queue: [Track] = []
    private(set) var currentIndex: Int = 0
    private(set) var isPlaying: Bool = false
    private(set) var loopMode: LoopMode = .off
    private(set) var shuffleEnabled: Bool = false
    private(set) var playbackRate: Double = 1.0

    private(set) var currentTime: TimeInterval = 0
    @ObservationIgnored private var shuffleHistory: Set<Int> = []
    private(set) var currentDuration: TimeInterval = 0

    init(engine: PlayerEngine,
         preferences: PreferencesStore,
         persistence: PlaybackStatePersisting,
         nowPlaying: NowPlayingCenter? = nil) {
        self.engine = engine
        self.preferences = preferences
        self.persistence = persistence
        self.nowPlaying = nowPlaying

        engine.didFinishPublisher
            .sink { [weak self] in
                MainActor.assumeIsolated { self?.handleTrackEnded() }
            }
            .store(in: &cancellables)
        engine.isPlayingPublisher
            .sink { [weak self] value in
                MainActor.assumeIsolated {
                    self?.isPlaying = value
                    self?.updateNowPlaying()
                }
            }
            .store(in: &cancellables)
        engine.currentTimePublisher
            .sink { [weak self] time in
                MainActor.assumeIsolated { self?.currentTime = time }
            }
            .store(in: &cancellables)
        engine.durationPublisher
            .sink { [weak self] value in
                MainActor.assumeIsolated { self?.currentDuration = value }
            }
            .store(in: &cancellables)
        engine.currentTimePublisher
            .compactMap { [weak self] time -> (String, TimeInterval)? in
                // The currentTimePublisher delivers on main; the closure runs on main.
                // Capture stableID synchronously here, BEFORE the throttle defers delivery.
                guard let self else { return nil }
                return MainActor.assumeIsolated {
                    guard let track = self.currentTrack else { return nil }
                    return (track.stableID, time)
                }
            }
            .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] stableID, time in
                MainActor.assumeIsolated {
                    self?.persistence.savePosition(time, for: stableID)
                }
            }
            .store(in: &cancellables)

        self.loopMode = preferences.loopMode
        self.shuffleEnabled = preferences.shuffleEnabled
        self.playbackRate = preferences.playbackRate
    }

    var currentTrack: Track? {
        queue.indices.contains(currentIndex) ? queue[currentIndex] : nil
    }

    func play(queue: [Track], startIndex: Int) {
        self.queue = queue
        self.currentIndex = startIndex
        self.shuffleHistory = [startIndex]
        loadAndPlayCurrent()
    }

    func playFolder(_ tracks: [Track], shuffled: Bool) {
        guard !tracks.isEmpty else { return }
        if shuffled {
            preferences.shuffleEnabled = true
        }
        play(queue: tracks, startIndex: shuffled ? Int.random(in: 0..<tracks.count) : 0)
    }

    func togglePlayPause() {
        isPlaying ? engine.pause() : engine.play()
    }

    func next() { advance(forced: true) }

    func previous() {
        if currentIndex > 0 {
            currentIndex -= 1
            loadAndPlayCurrent()
        } else {
            engine.seek(to: 0)
        }
    }

    func setRate(_ rate: Double) {
        preferences.playbackRate = rate
        playbackRate = rate
        engine.setRate(rate)
    }

    func setLoopMode(_ mode: LoopMode) {
        preferences.loopMode = mode
        loopMode = mode
    }

    func seek(to time: TimeInterval) {
        engine.seek(to: time)
    }

    func skip(by seconds: TimeInterval) {
        let target: TimeInterval
        if currentDuration > 0 {
            target = max(0, min(currentDuration, currentTime + seconds))
        } else {
            target = max(0, currentTime + seconds)
        }
        engine.seek(to: target)
    }

    func toggleShuffle() {
        preferences.shuffleEnabled.toggle()
        shuffleEnabled = preferences.shuffleEnabled
        shuffleHistory = [currentIndex]
    }

    private func handleTrackEnded() {
        switch preferences.loopMode {
        case .track:
            engine.seek(to: 0)
            engine.play()
        case .off, .playlist:
            advance(forced: false)
        }
    }

    private func advance(forced: Bool) {
        guard let nextIdx = nextIndex(forced: forced) else {
            engine.pause()
            return
        }
        currentIndex = nextIdx
        shuffleHistory.insert(nextIdx)
        loadAndPlayCurrent()
    }

    private func nextIndex(forced: Bool) -> Int? {
        if preferences.shuffleEnabled {
            let unvisited = Set(queue.indices).subtracting(shuffleHistory)
            if let pick = unvisited.randomElement() { return pick }
            if preferences.loopMode == .playlist || forced {
                shuffleHistory = []
                return queue.indices.randomElement()
            }
            return nil
        } else {
            let candidate = currentIndex + 1
            if candidate < queue.count { return candidate }
            if preferences.loopMode == .playlist || forced { return 0 }
            return nil
        }
    }

    private func loadAndPlayCurrent() {
        guard let track = currentTrack else { return }
        engine.load(url: track.url)
        engine.setRate(preferences.playbackRate)
        if let last = persistence.lastPosition(for: track.stableID) {
            let duration = currentDuration
            if duration <= 0 || last < duration - 5 {
                engine.seek(to: last)
            }
        }
        engine.play()
        updateNowPlaying()
    }

    private func updateNowPlaying() {
        guard let track = currentTrack else { return }
        nowPlaying?.update(
            title: track.displayTitle,
            duration: currentDuration,
            elapsed: currentTime,
            rate: preferences.playbackRate
        )
    }
}
