import Foundation
import Combine
import Observation

@Observable
@MainActor
final class PlayerStore {
    private let engine: PlayerEngine
    private let preferences: PreferencesStore
    private let persistence: PlaybackStatePersisting
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    private(set) var queue: [Track] = []
    private(set) var currentIndex: Int = 0
    private(set) var isPlaying: Bool = false

    @ObservationIgnored private var shuffleHistory: Set<Int> = []
    @ObservationIgnored private var currentDuration: TimeInterval = 0

    init(engine: PlayerEngine, preferences: PreferencesStore, persistence: PlaybackStatePersisting) {
        self.engine = engine
        self.preferences = preferences
        self.persistence = persistence

        engine.didFinishPublisher
            .sink { [weak self] in
                MainActor.assumeIsolated { self?.handleTrackEnded() }
            }
            .store(in: &cancellables)
        engine.isPlayingPublisher
            .sink { [weak self] value in
                MainActor.assumeIsolated { self?.isPlaying = value }
            }
            .store(in: &cancellables)
        engine.durationPublisher
            .sink { [weak self] value in
                MainActor.assumeIsolated { self?.currentDuration = value }
            }
            .store(in: &cancellables)
        engine.currentTimePublisher
            .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] time in
                guard let self else { return }
                MainActor.assumeIsolated {
                    guard let track = self.currentTrack else { return }
                    self.persistence.savePosition(time, for: track.stableID)
                }
            }
            .store(in: &cancellables)
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
        engine.setRate(rate)
    }

    func setLoopMode(_ mode: LoopMode) { preferences.loopMode = mode }

    func toggleShuffle() {
        preferences.shuffleEnabled.toggle()
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
    }
}
