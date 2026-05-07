import Combine
import Foundation
@testable import ShadowingApp

final class FakePlayerEngine: PlayerEngine {
    let isPlayingSubject = CurrentValueSubject<Bool, Never>(false)
    let currentTimeSubject = CurrentValueSubject<TimeInterval, Never>(0)
    let durationSubject = CurrentValueSubject<TimeInterval, Never>(0)
    let didFinishSubject = PassthroughSubject<Void, Never>()

    var isPlayingPublisher: AnyPublisher<Bool, Never> { isPlayingSubject.eraseToAnyPublisher() }
    var currentTimePublisher: AnyPublisher<TimeInterval, Never> { currentTimeSubject.eraseToAnyPublisher() }
    var durationPublisher: AnyPublisher<TimeInterval, Never> { durationSubject.eraseToAnyPublisher() }
    var didFinishPublisher: AnyPublisher<Void, Never> { didFinishSubject.eraseToAnyPublisher() }

    private(set) var loadedURLs: [URL] = []
    private(set) var didCallPlay = 0
    private(set) var didCallPause = 0
    private(set) var seekTimes: [TimeInterval] = []
    private(set) var ratesSet: [Double] = []

    func load(url: URL) { loadedURLs.append(url) }
    func play() { didCallPlay += 1; isPlayingSubject.send(true) }
    func pause() { didCallPause += 1; isPlayingSubject.send(false) }
    func seek(to time: TimeInterval) { seekTimes.append(time) }
    func setRate(_ rate: Double) { ratesSet.append(rate) }

    func simulateTrackEnded() { didFinishSubject.send(()) }
}
