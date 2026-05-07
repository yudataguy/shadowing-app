import AVFoundation
import Combine

final class AVPlayerEngine: PlayerEngine {
    private let player = AVPlayer()
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var desiredRate: Float = 1.0

    private let isPlayingSubject = CurrentValueSubject<Bool, Never>(false)
    private let currentTimeSubject = CurrentValueSubject<TimeInterval, Never>(0)
    private let durationSubject = CurrentValueSubject<TimeInterval, Never>(0)
    private let didFinishSubject = PassthroughSubject<Void, Never>()

    var isPlayingPublisher: AnyPublisher<Bool, Never> {
        isPlayingSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    var currentTimePublisher: AnyPublisher<TimeInterval, Never> {
        currentTimeSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    var durationPublisher: AnyPublisher<TimeInterval, Never> {
        durationSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    var didFinishPublisher: AnyPublisher<Void, Never> {
        didFinishSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    init() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            let seconds = time.seconds
            guard seconds.isFinite else { return }
            self?.currentTimeSubject.send(seconds)
        }
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in self?.didFinishSubject.send(()) }
            .store(in: &cancellables)
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }

    func load(url: URL) {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        Task { @MainActor in
            let duration = (try? await item.asset.load(.duration).seconds) ?? 0
            durationSubject.send(duration)
        }
    }

    func play() {
        player.rate = desiredRate
        isPlayingSubject.send(true)
    }

    func pause() {
        player.pause()
        isPlayingSubject.send(false)
    }

    func seek(to time: TimeInterval) {
        player.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }

    func setRate(_ rate: Double) {
        desiredRate = Float(rate)
        if player.rate != 0 {
            // Currently playing — apply immediately.
            player.rate = desiredRate
        }
        // If paused, the rate will be applied on the next play().
        isPlayingSubject.send(player.rate != 0)
    }
}
