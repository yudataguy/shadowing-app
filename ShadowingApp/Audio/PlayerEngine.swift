import Foundation
import Combine

protocol PlayerEngine: AnyObject {
    var isPlayingPublisher: AnyPublisher<Bool, Never> { get }
    var currentTimePublisher: AnyPublisher<TimeInterval, Never> { get }
    var durationPublisher: AnyPublisher<TimeInterval, Never> { get }
    var didFinishPublisher: AnyPublisher<Void, Never> { get }
    var failurePublisher: AnyPublisher<String, Never> { get }

    func load(url: URL)
    func play()
    func pause()
    func seek(to time: TimeInterval)
    func setRate(_ rate: Double)
}
