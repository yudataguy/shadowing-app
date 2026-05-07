# Shadowing App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native SwiftUI iOS app that plays MP3s from one or more iCloud Drive / Files-app folders, with playlists, shuffle, whole-track + playlist loop, resume positions, adjustable speed, and background / lock-screen playback.

**Architecture:** Three layers (Audio / Library / Persistence) coordinated by an `@Observable` `PlayerStore`. `PlayerEngine` is a protocol with one `AVPlayer`-backed implementation. SwiftData persists playlists and resume positions; `UserDefaults` holds folder security-scoped bookmarks and global preferences. Multiple root folders supported via a flat-but-grouped Library list.

**Tech Stack:** Swift 5.9+, SwiftUI, AVFoundation, MediaPlayer (MPNowPlayingInfoCenter / MPRemoteCommandCenter), SwiftData, iOS 17+ deployment target.

**Spec:** `docs/superpowers/specs/2026-05-07-shadowing-app-design.md`

---

## Notes for the Implementer

- **TDD where it pays.** Pure logic (queue advancement, shuffle, resume rules, library scanning) gets unit tests first. SwiftUI views and `AVPlayer` integration get a written manual test plan instead — unit-testing them yields more ceremony than confidence.
- **Test target uses XCTest** (Apple's built-in). No third-party deps.
- **Commit frequently.** Each task ends with a commit. If a task feels too big, split it.
- **Don't pre-build features that aren't in the spec.** No A-B loop, no metadata parsing, no skip-interval picker.
- **File layout** is given in the spec under "File Organization". Stick to it.

---

## Task 1: Create the Xcode project skeleton

**Files:**
- Create: `ShadowingApp.xcodeproj` (via Xcode)
- Create: `ShadowingApp/ShadowingAppApp.swift`
- Create: `ShadowingApp/Info.plist` entries
- Create: `ShadowingAppTests/` target

This task uses Xcode's GUI; no test step.

- [ ] **Step 1: Create the project**

In Xcode: File → New → Project → iOS → App.
- Product Name: `ShadowingApp`
- Interface: SwiftUI
- Language: Swift
- Storage: SwiftData (checked)
- Include Tests: yes
- Save into: `/Users/samyu/Downloads/code/playground/shadowing-app/`

- [ ] **Step 2: Set deployment target**

In project settings → Targets → ShadowingApp → General: set Minimum Deployments → iOS 17.0.

- [ ] **Step 3: Add Info.plist entries**

In `Info.plist` (or "Custom iOS Target Properties"):

```xml
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
```

- [ ] **Step 4: Create folder structure**

Create empty groups in Xcode matching the spec:
`Models/`, `Services/`, `Audio/`, `State/`, `Views/Library`, `Views/Playlists`, `Views/NowPlaying`, `Views/Settings`.

- [ ] **Step 5: Build & run on simulator**

⌘R. Verify the default "Hello, world" view appears.

- [ ] **Step 6: Commit**

```bash
git add ShadowingApp ShadowingApp.xcodeproj ShadowingAppTests
git commit -m "feat: scaffold Xcode SwiftUI project for iOS 17+"
```

---

## Task 2: Define value-type models

**Files:**
- Create: `ShadowingApp/Models/Track.swift`
- Create: `ShadowingApp/Models/FolderBookmark.swift`
- Test: `ShadowingAppTests/TrackTests.swift`

- [ ] **Step 1: Write failing test for `Track.stableID`**

```swift
// ShadowingAppTests/TrackTests.swift
import XCTest
@testable import ShadowingApp

final class TrackTests: XCTestCase {
    func test_stableID_combinesFolderIDAndRelativePath() {
        let folderID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let track = Track(
            folderID: folderID,
            relativePath: "lessons/01-intro.mp3",
            url: URL(fileURLWithPath: "/tmp/lessons/01-intro.mp3")
        )
        XCTAssertEqual(track.stableID, "00000000-0000-0000-0000-000000000001:lessons/01-intro.mp3")
    }

    func test_displayTitle_stripsExtension() {
        let track = Track(
            folderID: UUID(),
            relativePath: "lessons/01-intro.mp3",
            url: URL(fileURLWithPath: "/tmp/x.mp3")
        )
        XCTAssertEqual(track.displayTitle, "01-intro")
    }
}
```

- [ ] **Step 2: Run test, confirm it fails**

`⌘U` in Xcode. Expected: compile error, `Track` not defined.

- [ ] **Step 3: Implement `Track`**

```swift
// ShadowingApp/Models/Track.swift
import Foundation

struct Track: Identifiable, Hashable {
    let folderID: UUID
    let relativePath: String
    let url: URL

    var id: String { stableID }
    var stableID: String { "\(folderID.uuidString):\(relativePath)" }
    var displayTitle: String {
        (relativePath as NSString).lastPathComponent
            .replacingOccurrences(of: ".mp3", with: "", options: [.caseInsensitive, .backwards])
    }
}
```

- [ ] **Step 4: Implement `FolderBookmark`**

```swift
// ShadowingApp/Models/FolderBookmark.swift
import Foundation

struct FolderBookmark: Codable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
    var bookmarkData: Data
}
```

- [ ] **Step 5: Run tests, confirm pass**

`⌘U`. Expected: 2 tests pass.

- [ ] **Step 6: Commit**

```bash
git add ShadowingApp/Models ShadowingAppTests/TrackTests.swift
git commit -m "feat: add Track and FolderBookmark value types"
```

---

## Task 3: SwiftData models (Playlist, PlaylistEntry, PlaybackState)

**Files:**
- Create: `ShadowingApp/Models/Playlist.swift`
- Create: `ShadowingApp/Models/PlaylistEntry.swift`
- Create: `ShadowingApp/Models/PlaybackState.swift`
- Modify: `ShadowingApp/ShadowingAppApp.swift` (register models in container)

- [ ] **Step 1: Implement `PlaybackState`**

```swift
// ShadowingApp/Models/PlaybackState.swift
import Foundation
import SwiftData

@Model
final class PlaybackState {
    @Attribute(.unique) var trackStableID: String
    var lastPosition: TimeInterval
    var lastPlayedAt: Date

    init(trackStableID: String, lastPosition: TimeInterval, lastPlayedAt: Date = .now) {
        self.trackStableID = trackStableID
        self.lastPosition = lastPosition
        self.lastPlayedAt = lastPlayedAt
    }
}
```

- [ ] **Step 2: Implement `Playlist` and `PlaylistEntry`**

```swift
// ShadowingApp/Models/Playlist.swift
import Foundation
import SwiftData

@Model
final class Playlist {
    var id: UUID
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \PlaylistEntry.playlist)
    var entries: [PlaylistEntry] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
    }
}
```

```swift
// ShadowingApp/Models/PlaylistEntry.swift
import Foundation
import SwiftData

@Model
final class PlaylistEntry {
    var id: UUID
    var trackStableID: String
    var position: Int
    var playlist: Playlist?

    init(trackStableID: String, position: Int) {
        self.id = UUID()
        self.trackStableID = trackStableID
        self.position = position
    }
}
```

- [ ] **Step 3: Register models in the SwiftData container**

In `ShadowingAppApp.swift`:

```swift
@main
struct ShadowingAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Playlist.self, PlaylistEntry.self, PlaybackState.self])
    }
}
```

- [ ] **Step 4: Build, confirm it compiles**

`⌘B`. Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add ShadowingApp/Models ShadowingApp/ShadowingAppApp.swift
git commit -m "feat: add SwiftData models for playlists and playback state"
```

---

## Task 4: BookmarkStore (folder bookmarks in UserDefaults)

**Files:**
- Create: `ShadowingApp/Services/BookmarkStore.swift`
- Test: `ShadowingAppTests/BookmarkStoreTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// ShadowingAppTests/BookmarkStoreTests.swift
import XCTest
@testable import ShadowingApp

final class BookmarkStoreTests: XCTestCase {
    var defaults: UserDefaults!
    var store: BookmarkStore!

    override func setUp() {
        defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        store = BookmarkStore(defaults: defaults)
    }

    func test_emptyByDefault() {
        XCTAssertEqual(store.all().count, 0)
    }

    func test_addAndRetrieve() {
        let bookmark = FolderBookmark(id: UUID(), displayName: "Lessons", bookmarkData: Data([1, 2, 3]))
        store.add(bookmark)
        XCTAssertEqual(store.all(), [bookmark])
    }

    func test_remove() {
        let a = FolderBookmark(id: UUID(), displayName: "A", bookmarkData: Data([1]))
        let b = FolderBookmark(id: UUID(), displayName: "B", bookmarkData: Data([2]))
        store.add(a); store.add(b)
        store.remove(id: a.id)
        XCTAssertEqual(store.all(), [b])
    }
}
```

- [ ] **Step 2: Run, confirm fails**

`⌘U`. Expected: compile error.

- [ ] **Step 3: Implement BookmarkStore**

```swift
// ShadowingApp/Services/BookmarkStore.swift
import Foundation

final class BookmarkStore {
    private let defaults: UserDefaults
    private let key = "folderBookmarks.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func all() -> [FolderBookmark] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([FolderBookmark].self, from: data)) ?? []
    }

    func add(_ bookmark: FolderBookmark) {
        var current = all()
        current.append(bookmark)
        save(current)
    }

    func remove(id: UUID) {
        save(all().filter { $0.id != id })
    }

    func update(_ bookmark: FolderBookmark) {
        save(all().map { $0.id == bookmark.id ? bookmark : $0 })
    }

    private func save(_ bookmarks: [FolderBookmark]) {
        let data = try? JSONEncoder().encode(bookmarks)
        defaults.set(data, forKey: key)
    }
}
```

- [ ] **Step 4: Run tests, confirm pass**

`⌘U`. Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add ShadowingApp/Services/BookmarkStore.swift ShadowingAppTests/BookmarkStoreTests.swift
git commit -m "feat: add BookmarkStore for persisting folder bookmarks"
```

---

## Task 5: PreferencesStore (rate, loop mode, shuffle)

**Files:**
- Create: `ShadowingApp/Services/PreferencesStore.swift`
- Create: `ShadowingApp/State/LoopMode.swift`
- Test: `ShadowingAppTests/PreferencesStoreTests.swift`

- [ ] **Step 1: Define `LoopMode`**

```swift
// ShadowingApp/State/LoopMode.swift
import Foundation

enum LoopMode: String, CaseIterable {
    case off, track, playlist

    var next: LoopMode {
        switch self {
        case .off: return .track
        case .track: return .playlist
        case .playlist: return .off
        }
    }
}
```

- [ ] **Step 2: Write failing tests**

```swift
// ShadowingAppTests/PreferencesStoreTests.swift
import XCTest
@testable import ShadowingApp

final class PreferencesStoreTests: XCTestCase {
    var defaults: UserDefaults!
    var store: PreferencesStore!

    override func setUp() {
        defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        store = PreferencesStore(defaults: defaults)
    }

    func test_defaults() {
        XCTAssertEqual(store.playbackRate, 1.0)
        XCTAssertEqual(store.loopMode, .off)
        XCTAssertFalse(store.shuffleEnabled)
    }

    func test_persistRate() {
        store.playbackRate = 0.75
        let store2 = PreferencesStore(defaults: defaults)
        XCTAssertEqual(store2.playbackRate, 0.75)
    }

    func test_loopModeRoundtrip() {
        store.loopMode = .playlist
        XCTAssertEqual(PreferencesStore(defaults: defaults).loopMode, .playlist)
    }
}
```

- [ ] **Step 3: Run, confirm fails**

`⌘U`. Expected: compile error.

- [ ] **Step 4: Implement PreferencesStore**

```swift
// ShadowingApp/Services/PreferencesStore.swift
import Foundation

final class PreferencesStore {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var playbackRate: Double {
        get { defaults.object(forKey: "playbackRate") as? Double ?? 1.0 }
        set { defaults.set(newValue, forKey: "playbackRate") }
    }

    var loopMode: LoopMode {
        get { LoopMode(rawValue: defaults.string(forKey: "loopMode") ?? "") ?? .off }
        set { defaults.set(newValue.rawValue, forKey: "loopMode") }
    }

    var shuffleEnabled: Bool {
        get { defaults.bool(forKey: "shuffleEnabled") }
        set { defaults.set(newValue, forKey: "shuffleEnabled") }
    }
}
```

- [ ] **Step 5: Run tests, confirm pass**

`⌘U`. Expected: 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add ShadowingApp/Services/PreferencesStore.swift ShadowingApp/State/LoopMode.swift ShadowingAppTests/PreferencesStoreTests.swift
git commit -m "feat: add PreferencesStore and LoopMode"
```

---

## Task 6: LibraryService (folder scanning)

**Files:**
- Create: `ShadowingApp/Services/LibraryService.swift`
- Test: `ShadowingAppTests/LibraryServiceTests.swift`

- [ ] **Step 1: Write failing tests against a temp directory**

```swift
// ShadowingAppTests/LibraryServiceTests.swift
import XCTest
@testable import ShadowingApp

final class LibraryServiceTests: XCTestCase {
    var tmp: URL!

    override func setUp() {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func touch(_ relativePath: String) {
        let full = tmp.appendingPathComponent(relativePath)
        try! FileManager.default.createDirectory(at: full.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: full.path, contents: Data())
    }

    func test_scan_findsTopLevelMP3s() {
        touch("a.mp3"); touch("b.mp3"); touch("notes.txt")
        let folderID = UUID()
        let tracks = LibraryService.scan(rootURL: tmp, folderID: folderID)
        XCTAssertEqual(tracks.map(\.relativePath).sorted(), ["a.mp3", "b.mp3"])
    }

    func test_scan_recurses() {
        touch("lessons/01.mp3"); touch("lessons/sub/02.mp3")
        let tracks = LibraryService.scan(rootURL: tmp, folderID: UUID())
        XCTAssertEqual(tracks.map(\.relativePath).sorted(), ["lessons/01.mp3", "lessons/sub/02.mp3"])
    }

    func test_scan_caseInsensitiveExtension() {
        touch("a.MP3"); touch("b.Mp3")
        let tracks = LibraryService.scan(rootURL: tmp, folderID: UUID())
        XCTAssertEqual(tracks.count, 2)
    }
}
```

- [ ] **Step 2: Run, confirm fails**

`⌘U`. Expected: compile error.

- [ ] **Step 3: Implement `LibraryService.scan`**

```swift
// ShadowingApp/Services/LibraryService.swift
import Foundation

enum LibraryService {
    static func scan(rootURL: URL, folderID: UUID) -> [Track] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [Track] = []
        let rootPath = rootURL.standardizedFileURL.path
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "mp3",
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            let absolute = url.standardizedFileURL.path
            guard absolute.hasPrefix(rootPath + "/") else { continue }
            let relative = String(absolute.dropFirst(rootPath.count + 1))
            results.append(Track(folderID: folderID, relativePath: relative, url: url))
        }
        return results
    }
}
```

- [ ] **Step 4: Run tests, confirm pass**

`⌘U`. Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add ShadowingApp/Services/LibraryService.swift ShadowingAppTests/LibraryServiceTests.swift
git commit -m "feat: add LibraryService.scan with recursive mp3 discovery"
```

---

## Task 7: Audio session + PlayerEngine protocol + AVPlayerEngine

**Files:**
- Create: `ShadowingApp/Audio/AudioSessionCoordinator.swift`
- Create: `ShadowingApp/Audio/PlayerEngine.swift`
- Create: `ShadowingApp/Audio/AVPlayerEngine.swift`

This task is integration with Apple frameworks; tests are manual.

- [ ] **Step 1: Define `PlayerEngine` protocol**

```swift
// ShadowingApp/Audio/PlayerEngine.swift
import Foundation
import Combine

protocol PlayerEngine: AnyObject {
    var isPlayingPublisher: AnyPublisher<Bool, Never> { get }
    var currentTimePublisher: AnyPublisher<TimeInterval, Never> { get }
    var durationPublisher: AnyPublisher<TimeInterval, Never> { get }
    var didFinishPublisher: AnyPublisher<Void, Never> { get }

    func load(url: URL)
    func play()
    func pause()
    func seek(to time: TimeInterval)
    func setRate(_ rate: Double)
}
```

- [ ] **Step 2: Implement `AudioSessionCoordinator`**

```swift
// ShadowingApp/Audio/AudioSessionCoordinator.swift
import AVFoundation

final class AudioSessionCoordinator {
    func activate() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
        try? session.setActive(true)
    }
}
```

- [ ] **Step 3: Implement `AVPlayerEngine`**

```swift
// ShadowingApp/Audio/AVPlayerEngine.swift
import AVFoundation
import Combine

final class AVPlayerEngine: PlayerEngine {
    private let player = AVPlayer()
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    private let isPlayingSubject = CurrentValueSubject<Bool, Never>(false)
    private let currentTimeSubject = CurrentValueSubject<TimeInterval, Never>(0)
    private let durationSubject = CurrentValueSubject<TimeInterval, Never>(0)
    private let didFinishSubject = PassthroughSubject<Void, Never>()

    var isPlayingPublisher: AnyPublisher<Bool, Never> { isPlayingSubject.eraseToAnyPublisher() }
    var currentTimePublisher: AnyPublisher<TimeInterval, Never> { currentTimeSubject.eraseToAnyPublisher() }
    var durationPublisher: AnyPublisher<TimeInterval, Never> { durationSubject.eraseToAnyPublisher() }
    var didFinishPublisher: AnyPublisher<Void, Never> { didFinishSubject.eraseToAnyPublisher() }

    init() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.currentTimeSubject.send(time.seconds)
        }
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in self?.didFinishSubject.send(()) }
            .store(in: &cancellables)
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
        player.play()
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
        player.rate = Float(rate)
        isPlayingSubject.send(player.rate != 0)
    }
}
```

- [ ] **Step 4: Build, confirm it compiles**

`⌘B`. Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add ShadowingApp/Audio
git commit -m "feat: add PlayerEngine protocol and AVPlayer-backed implementation"
```

---

## Task 8: PlayerStore — queue logic (TDD heavy)

**Files:**
- Create: `ShadowingApp/State/PlayerStore.swift`
- Create: `ShadowingAppTests/Fakes/FakePlayerEngine.swift`
- Test: `ShadowingAppTests/PlayerStoreQueueTests.swift`

The queue logic is the riskiest part of the app. We unit-test it against a fake engine.

- [ ] **Step 1: Build a fake engine**

```swift
// ShadowingAppTests/Fakes/FakePlayerEngine.swift
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
```

- [ ] **Step 2: Write failing tests for queue advancement**

```swift
// ShadowingAppTests/PlayerStoreQueueTests.swift
import XCTest
@testable import ShadowingApp

@MainActor
final class PlayerStoreQueueTests: XCTestCase {
    var engine: FakePlayerEngine!
    var prefs: PreferencesStore!
    var store: PlayerStore!

    override func setUp() async throws {
        engine = FakePlayerEngine()
        prefs = PreferencesStore(defaults: UserDefaults(suiteName: "test-\(UUID())")!)
        store = PlayerStore(engine: engine, preferences: prefs, persistence: NoopPersistence())
    }

    private func makeQueue(_ count: Int) -> [Track] {
        let folderID = UUID()
        return (0..<count).map { Track(folderID: folderID, relativePath: "\($0).mp3", url: URL(fileURLWithPath: "/tmp/\($0).mp3")) }
    }

    func test_play_loadsFirstTrackAndPlays() {
        let queue = makeQueue(3)
        store.play(queue: queue, startIndex: 0)
        XCTAssertEqual(engine.loadedURLs.count, 1)
        XCTAssertEqual(engine.loadedURLs.first?.lastPathComponent, "0.mp3")
        XCTAssertEqual(engine.didCallPlay, 1)
    }

    func test_trackEnded_loopOff_advances() {
        prefs.loopMode = .off
        let queue = makeQueue(3)
        store.play(queue: queue, startIndex: 0)
        engine.simulateTrackEnded()
        XCTAssertEqual(engine.loadedURLs.last?.lastPathComponent, "1.mp3")
    }

    func test_trackEnded_loopOff_atEnd_stops() {
        prefs.loopMode = .off
        let queue = makeQueue(2)
        store.play(queue: queue, startIndex: 1)
        engine.simulateTrackEnded()
        XCTAssertEqual(engine.didCallPause, 1)
        XCTAssertEqual(store.currentIndex, 1)
    }

    func test_trackEnded_loopTrack_seeksToZero() {
        prefs.loopMode = .track
        let queue = makeQueue(2)
        store.play(queue: queue, startIndex: 0)
        engine.simulateTrackEnded()
        XCTAssertEqual(engine.seekTimes, [0])
        XCTAssertEqual(engine.loadedURLs.count, 1) // didn't reload
    }

    func test_trackEnded_loopPlaylist_wrapsToStart() {
        prefs.loopMode = .playlist
        let queue = makeQueue(2)
        store.play(queue: queue, startIndex: 1)
        engine.simulateTrackEnded()
        XCTAssertEqual(engine.loadedURLs.last?.lastPathComponent, "0.mp3")
    }

    func test_shuffle_visitsAllBeforeRepeating() {
        prefs.shuffleEnabled = true
        prefs.loopMode = .playlist
        let queue = makeQueue(4)
        store.play(queue: queue, startIndex: 0)

        var visited = Set<String>()
        visited.insert(engine.loadedURLs.last!.lastPathComponent)
        for _ in 0..<3 {
            engine.simulateTrackEnded()
            visited.insert(engine.loadedURLs.last!.lastPathComponent)
        }
        XCTAssertEqual(visited.count, 4)
    }
}

final class NoopPersistence: PlaybackStatePersisting {
    func lastPosition(for stableID: String) -> TimeInterval? { nil }
    func savePosition(_ position: TimeInterval, for stableID: String) {}
}
```

- [ ] **Step 3: Run tests, confirm fail**

`⌘U`. Expected: compile error.

- [ ] **Step 4: Define `PlaybackStatePersisting`**

```swift
// ShadowingApp/State/PlaybackStatePersisting.swift
import Foundation

protocol PlaybackStatePersisting {
    func lastPosition(for stableID: String) -> TimeInterval?
    func savePosition(_ position: TimeInterval, for stableID: String)
}
```

- [ ] **Step 5: Implement `PlayerStore`**

```swift
// ShadowingApp/State/PlayerStore.swift
import Foundation
import Combine
import Observation

@Observable
@MainActor
final class PlayerStore {
    private let engine: PlayerEngine
    private let preferences: PreferencesStore
    private let persistence: PlaybackStatePersisting
    private var cancellables = Set<AnyCancellable>()

    private(set) var queue: [Track] = []
    private(set) var currentIndex: Int = 0
    private(set) var isPlaying: Bool = false

    private var shuffleHistory: Set<Int> = []

    init(engine: PlayerEngine, preferences: PreferencesStore, persistence: PlaybackStatePersisting) {
        self.engine = engine
        self.preferences = preferences
        self.persistence = persistence

        engine.didFinishPublisher
            .sink { [weak self] in self?.handleTrackEnded() }
            .store(in: &cancellables)
        engine.isPlayingPublisher
            .sink { [weak self] in self?.isPlaying = $0 }
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
            engine.seek(to: last)
        }
        engine.play()
    }
}
```

- [ ] **Step 6: Run tests, confirm pass**

`⌘U`. Expected: 6 tests pass.

- [ ] **Step 7: Commit**

```bash
git add ShadowingApp/State ShadowingAppTests/Fakes ShadowingAppTests/PlayerStoreQueueTests.swift
git commit -m "feat: add PlayerStore with queue, loop, shuffle logic"
```

---

## Task 9: Resume position persistence

**Files:**
- Create: `ShadowingApp/Services/SwiftDataPlaybackPersistence.swift`
- Modify: `ShadowingApp/State/PlayerStore.swift` (add seek-skip logic, debounced save)
- Test: `ShadowingAppTests/PlayerStoreResumeTests.swift`

- [ ] **Step 1: Write failing resume tests**

```swift
// ShadowingAppTests/PlayerStoreResumeTests.swift
import XCTest
@testable import ShadowingApp

@MainActor
final class PlayerStoreResumeTests: XCTestCase {
    func test_resume_seeksToLastPosition_whenAvailable() {
        let engine = FakePlayerEngine()
        let prefs = PreferencesStore(defaults: UserDefaults(suiteName: "t-\(UUID())")!)
        let persistence = MemoryPersistence()
        persistence.savePosition(42, for: "stable-id")

        let track = Track(folderID: UUID(), relativePath: "x.mp3", url: URL(fileURLWithPath: "/tmp/x.mp3"))
        // override stable ID is annoying; instead set it via a real track
        let store = PlayerStore(engine: engine, preferences: prefs, persistence: persistence)
        // seed persistence with the actual stableID
        persistence.savePosition(42, for: track.stableID)

        store.play(queue: [track], startIndex: 0)
        XCTAssertEqual(engine.seekTimes, [42])
    }

    func test_resume_doesNotSeek_whenNearEnd() {
        let engine = FakePlayerEngine()
        let prefs = PreferencesStore(defaults: UserDefaults(suiteName: "t-\(UUID())")!)
        let persistence = MemoryPersistence()
        let track = Track(folderID: UUID(), relativePath: "x.mp3", url: URL(fileURLWithPath: "/tmp/x.mp3"))
        let store = PlayerStore(engine: engine, preferences: prefs, persistence: persistence)

        // simulate persistence reporting near-end position; PlayerStore should skip the seek.
        // We model "near end" by storing a sentinel; PlayerStore queries duration via engine.
        engine.durationSubject.send(60)
        persistence.savePosition(58, for: track.stableID) // within last 5s

        store.play(queue: [track], startIndex: 0)
        XCTAssertEqual(engine.seekTimes, [])
    }
}

final class MemoryPersistence: PlaybackStatePersisting {
    private var dict: [String: TimeInterval] = [:]
    func lastPosition(for stableID: String) -> TimeInterval? { dict[stableID] }
    func savePosition(_ position: TimeInterval, for stableID: String) { dict[stableID] = position }
}
```

- [ ] **Step 2: Run, confirm fails**

`⌘U`. Expected: assertion failures (skip-near-end not implemented).

- [ ] **Step 3: Update `PlayerStore.loadAndPlayCurrent` to skip seek when near end**

Replace the `loadAndPlayCurrent()` body with logic that listens for the next `durationPublisher` value before deciding whether to seek:

```swift
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
```

Also add:

```swift
private var currentDuration: TimeInterval = 0
// in init, also subscribe:
engine.durationPublisher.sink { [weak self] in self?.currentDuration = $0 }.store(in: &cancellables)
```

- [ ] **Step 4: Add periodic save of `lastPosition`**

```swift
// in init, append:
engine.currentTimePublisher
    .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)
    .sink { [weak self] time in
        guard let self, let track = self.currentTrack else { return }
        self.persistence.savePosition(time, for: track.stableID)
    }
    .store(in: &cancellables)
```

- [ ] **Step 5: Implement SwiftData-backed persistence**

```swift
// ShadowingApp/Services/SwiftDataPlaybackPersistence.swift
import Foundation
import SwiftData

@MainActor
final class SwiftDataPlaybackPersistence: PlaybackStatePersisting {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func lastPosition(for stableID: String) -> TimeInterval? {
        let descriptor = FetchDescriptor<PlaybackState>(
            predicate: #Predicate { $0.trackStableID == stableID }
        )
        return (try? context.fetch(descriptor))?.first?.lastPosition
    }

    func savePosition(_ position: TimeInterval, for stableID: String) {
        let descriptor = FetchDescriptor<PlaybackState>(
            predicate: #Predicate { $0.trackStableID == stableID }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.lastPosition = position
            existing.lastPlayedAt = .now
        } else {
            context.insert(PlaybackState(trackStableID: stableID, lastPosition: position))
        }
        try? context.save()
    }
}
```

- [ ] **Step 6: Run tests, confirm pass**

`⌘U`. Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add ShadowingApp ShadowingAppTests/PlayerStoreResumeTests.swift
git commit -m "feat: persist resume positions with skip-near-end rule"
```

---

## Task 10: Now-playing center + remote commands

**Files:**
- Create: `ShadowingApp/Audio/NowPlayingCenter.swift`
- Modify: `ShadowingApp/State/PlayerStore.swift` (call NowPlayingCenter on track changes)

Manual test only.

- [ ] **Step 1: Implement `NowPlayingCenter`**

```swift
// ShadowingApp/Audio/NowPlayingCenter.swift
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
        center.playCommand.addTarget { _ in store.togglePlayPause(); return .success }
        center.pauseCommand.addTarget { _ in store.togglePlayPause(); return .success }
        center.nextTrackCommand.addTarget { _ in store.next(); return .success }
        center.previousTrackCommand.addTarget { _ in store.previous(); return .success }
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { _ in store.skip(by: 15); return .success }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { _ in store.skip(by: -15); return .success }
    }
}
```

- [ ] **Step 2: Add `skip(by:)` to PlayerStore**

```swift
func skip(by seconds: TimeInterval) {
    let target = max(0, currentDuration > 0 ? min(currentDuration, currentTime + seconds) : currentTime + seconds)
    engine.seek(to: target)
}
```

Also track `currentTime` via the existing `currentTimePublisher` subscription.

- [ ] **Step 3: Wire NowPlayingCenter from PlayerStore**

After every track change & on play/pause, call `nowPlayingCenter.update(...)`. Inject `NowPlayingCenter` into PlayerStore (or call a closure to avoid coupling — your call).

- [ ] **Step 4: Manual test**

Run on a real device (lock-screen controls don't appear in the simulator reliably).
- Start playback → lock device → verify title + transport on lock screen.
- Tap pause/play, next, prev, ±15s — each should work.

- [ ] **Step 5: Commit**

```bash
git add ShadowingApp/Audio/NowPlayingCenter.swift ShadowingApp/State/PlayerStore.swift
git commit -m "feat: integrate MPNowPlayingInfoCenter and remote commands"
```

---

## Task 11: Root view + tab structure + mini-player

**Files:**
- Create: `ShadowingApp/Views/RootView.swift`
- Create: `ShadowingApp/Views/NowPlaying/MiniPlayerBar.swift`
- Modify: `ShadowingApp/ShadowingAppApp.swift` (use RootView; build dependency graph)

- [ ] **Step 1: Build dependency graph in `ShadowingAppApp`**

```swift
@main
struct ShadowingAppApp: App {
    @State private var playerStore: PlayerStore
    @State private var bookmarks = BookmarkStore()
    let modelContainer: ModelContainer

    init() {
        let container = try! ModelContainer(for: Playlist.self, PlaylistEntry.self, PlaybackState.self)
        self.modelContainer = container
        let prefs = PreferencesStore()
        let persistence = SwiftDataPlaybackPersistence(context: container.mainContext)
        let engine = AVPlayerEngine()
        AudioSessionCoordinator().activate()
        let store = PlayerStore(engine: engine, preferences: prefs, persistence: persistence)
        NowPlayingCenter().registerCommands(store: store)
        _playerStore = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(playerStore)
                .environmentObject(bookmarks)
                .modelContainer(modelContainer)
        }
    }
}
```

- [ ] **Step 2: Build `RootView`**

```swift
// ShadowingApp/Views/RootView.swift
import SwiftUI

struct RootView: View {
    @State private var showNowPlaying = false
    @Environment(PlayerStore.self) private var player

    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("Library", systemImage: "music.note.list") }
            PlaylistsView()
                .tabItem { Label("Playlists", systemImage: "rectangle.stack") }
        }
        .safeAreaInset(edge: .bottom) {
            if player.currentTrack != nil {
                MiniPlayerBar(onTap: { showNowPlaying = true })
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingSheet()
        }
    }
}
```

- [ ] **Step 3: Build `MiniPlayerBar`**

Title + play/pause + next; tap area opens sheet. Keep it ~40 lines.

- [ ] **Step 4: Stub `LibraryView`, `PlaylistsView`, `NowPlayingSheet`**

Each with a `Text("TODO")` placeholder so the project compiles.

- [ ] **Step 5: Build & run, verify tab bar + (no mini-player when nothing playing)**

`⌘R` in simulator.

- [ ] **Step 6: Commit**

```bash
git add ShadowingApp
git commit -m "feat: root view, tab structure, mini-player skeleton"
```

---

## Task 12: Folders settings + document picker

**Files:**
- Create: `ShadowingApp/Views/Settings/FoldersSettingsView.swift`
- Create: `ShadowingApp/Views/Settings/DocumentPicker.swift` (UIViewControllerRepresentable wrapper)
- Modify: `ShadowingApp/Services/BookmarkStore.swift` (add helper to convert URL → bookmark)

- [ ] **Step 1: Add bookmark helper**

```swift
extension BookmarkStore {
    func makeBookmark(from url: URL, displayName: String) throws -> FolderBookmark {
        let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        return FolderBookmark(id: UUID(), displayName: displayName, bookmarkData: data)
    }

    func resolve(_ bookmark: FolderBookmark) -> (url: URL, isStale: Bool)? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark.bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        return (url, stale)
    }
}
```

- [ ] **Step 2: Build the `DocumentPicker` wrapper**

```swift
import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            _ = url.startAccessingSecurityScopedResource()
            onPick(url)
            url.stopAccessingSecurityScopedResource()
        }
    }
}
```

- [ ] **Step 3: Build `FoldersSettingsView`**

List the bookmarks, "Add folder" button presents the document picker, swipe-to-delete removes from `BookmarkStore`. Each row also has a `▶︎` button that calls `playerStore.playFolder(...)` (defined next task).

- [ ] **Step 4: Manual test**

In the simulator, drop an MP3 folder into iCloud Drive (Files app → Browse → iCloud Drive → drag in). Use Folders settings to add it, verify it persists across app relaunch.

- [ ] **Step 5: Commit**

```bash
git add ShadowingApp/Views/Settings ShadowingApp/Services/BookmarkStore.swift
git commit -m "feat: folders settings with document picker and bookmark resolution"
```

---

## Task 13: Library view (flat, grouped, with play/shuffle headers)

**Files:**
- Create: `ShadowingApp/Views/Library/LibraryView.swift`
- Create: `ShadowingApp/Views/Library/FolderSectionHeader.swift`
- Create: `ShadowingApp/Views/Library/TrackRow.swift`
- Modify: `ShadowingApp/State/PlayerStore.swift` (add `playFolder`, `playShuffled`)

- [ ] **Step 1: Add `playFolder` / `playShuffled` to PlayerStore**

```swift
func playFolder(_ tracks: [Track], shuffled: Bool) {
    if shuffled { preferences.shuffleEnabled = true }
    play(queue: tracks, startIndex: shuffled ? Int.random(in: 0..<tracks.count) : 0)
}
```

- [ ] **Step 2: Build LibraryView**

Reads `BookmarkStore`, resolves each bookmark, scans via `LibraryService`, builds `[(folderName: String, tracks: [Track])]`, renders a `List` with a `Section` per folder.

- [ ] **Step 3: Build FolderSectionHeader**

```swift
struct FolderSectionHeader: View {
    let folderName: String
    let onPlay: () -> Void
    let onShuffle: () -> Void
    var body: some View {
        HStack {
            Text(folderName).font(.headline)
            Spacer()
            Button(action: onPlay) { Image(systemName: "play.fill") }
            Button(action: onShuffle) { Image(systemName: "shuffle") }
        }
    }
}
```

- [ ] **Step 4: Build TrackRow with swipe-action "Add to playlist…"**

The "Add to playlist" sheet picks a playlist via SwiftData query, or creates a new one inline. Defers full polish to Task 14.

- [ ] **Step 5: Empty state**

If `bookmarks.all().isEmpty`, show centered CTA "Pick your MP3 folder" that opens the document picker directly (skip Settings round-trip on first launch).

- [ ] **Step 6: Manual test**

Run on device. Verify tracks list, tap a row → playback starts, tap section header play/shuffle → behavior matches.

- [ ] **Step 7: Commit**

```bash
git add ShadowingApp/Views/Library ShadowingApp/State/PlayerStore.swift
git commit -m "feat: library view with folder grouping and play/shuffle headers"
```

---

## Task 14: Playlists views

**Files:**
- Create: `ShadowingApp/Views/Playlists/PlaylistsView.swift`
- Create: `ShadowingApp/Views/Playlists/PlaylistDetailView.swift`
- Create: `ShadowingApp/Views/Playlists/NewPlaylistSheet.swift`
- Create: `ShadowingApp/Views/Playlists/AddToPlaylistSheet.swift`

- [ ] **Step 1: PlaylistsView**

`@Query` for `[Playlist]`, list rows, "+" toolbar item presents `NewPlaylistSheet`. Tap row → push `PlaylistDetailView`.

- [ ] **Step 2: PlaylistDetailView**

Lists `playlist.entries` sorted by `position`, resolves each `trackStableID` to a `Track` from the in-memory library snapshot. Reorder + delete via `.onMove` and `.onDelete`. Header has play/shuffle buttons.

- [ ] **Step 3: NewPlaylistSheet**

Single text field + Save button → inserts new `Playlist` into model context.

- [ ] **Step 4: AddToPlaylistSheet**

Triggered from the Library track-row swipe action. Lists existing playlists; selection appends a `PlaylistEntry` with `position = playlist.entries.count`. "+ New playlist…" row at top.

- [ ] **Step 5: Manual test**

Create a playlist, add tracks via swipe, reorder, delete, play.

- [ ] **Step 6: Commit**

```bash
git add ShadowingApp/Views/Playlists
git commit -m "feat: playlists CRUD and add-to-playlist flow"
```

---

## Task 15: Now Playing sheet + scrubber

**Files:**
- Create: `ShadowingApp/Views/NowPlaying/NowPlayingSheet.swift`
- Create: `ShadowingApp/Views/NowPlaying/ScrubberView.swift`

- [ ] **Step 1: Build ScrubberView**

`Slider` bound to a local `@State` time, dragging updates the local state; on `editingChanged == false` calls `playerStore.seek(to:)`. Display elapsed / `-remaining` labels.

- [ ] **Step 2: Build NowPlayingSheet**

Title + folder, scrubber, transport row (`⏮ -15s ⏯ +15s ⏭`), mode row (shuffle toggle, loop button cycling icons, speed picker as `Menu` or segmented control), "Add to playlist" button.

- [ ] **Step 3: Speed picker**

```swift
Menu("\(playerStore.rate, format: .number.precision(.fractionLength(2)))×") {
    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { rate in
        Button("\(rate, format: .number.precision(.fractionLength(2)))×") {
            playerStore.setRate(rate)
        }
    }
}
```

- [ ] **Step 4: Manual test**

Drag scrubber, change speed, toggle loop through all 3 states, toggle shuffle, ±15s.

- [ ] **Step 5: Commit**

```bash
git add ShadowingApp/Views/NowPlaying
git commit -m "feat: now-playing sheet with scrubber and full transport"
```

---

## Task 16: End-to-end manual test pass + polish

**Files:**
- Modify: as needed for fixes uncovered.

- [ ] **Step 1: Run the manual test plan**

Test plan checklist (do each, on a real device):
- [ ] First launch shows empty state.
- [ ] Pick a folder → tracks appear grouped.
- [ ] Tap a track → starts playing; mini-player appears.
- [ ] Pause via mini-player; resume.
- [ ] Open Now Playing → all controls work.
- [ ] Speed change persists across app relaunch.
- [ ] Loop = track: track repeats indefinitely.
- [ ] Loop = playlist: queue wraps at end.
- [ ] Shuffle on: visits all tracks before any repeats.
- [ ] Track ends with loop = off at end of queue → stops.
- [ ] Resume position: play track, pause partway, kill app, relaunch, play same track → resumes at position.
- [ ] Resume skip: play to last 5s, kill app, replay → starts from 0.
- [ ] Background audio: lock device → audio continues.
- [ ] Lock-screen controls work (play/pause, next/prev, ±15s).
- [ ] Phone call interrupts → pauses, resumes after.
- [ ] Add second folder → both appear in library.
- [ ] Remove a folder → its tracks disappear; existing playback unaffected.
- [ ] Create playlist, add tracks, reorder, play → works.
- [ ] Stale bookmark warning surfaces when iCloud folder is moved.

- [ ] **Step 2: Fix any issues found, commit each as its own commit**

- [ ] **Step 3: Final commit (if any cleanup)**

```bash
git commit -m "chore: polish and bug fixes from manual test pass"
```

---

## Definition of Done

- All unit tests pass (`⌘U`).
- Manual test checklist in Task 16 fully ticked off on a physical iPhone.
- No `TODO` or `FIXME` comments left in code.
- App runs cleanly without warnings in Xcode build log.
- Spec's "Goals" section satisfied; "Non-Goals" intentionally absent.
