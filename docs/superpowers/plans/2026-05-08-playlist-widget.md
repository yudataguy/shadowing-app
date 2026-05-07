# Playlist Quick-Play Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a medium iOS Home Screen widget that shows the 4 most-recently-played playlists; tapping a tile opens the app and starts that playlist.

**Architecture:** New `ShadowingWidget` extension target. Both targets share an App Group entitlement so the widget can read the existing SwiftData store. A `PlayPlaylistIntent` AppIntent (shared source between targets) writes the tapped playlist's UUID to shared `UserDefaults` and returns `openAppWhenRun = true`. On launch, the main app reads the pending UUID, looks up the playlist, and starts playback.

**Tech Stack:** WidgetKit, AppIntents (iOS 17+), SwiftUI, SwiftData with `applicationDataContainer(forSecurityApplicationGroupIdentifier:)`, App Groups capability.

**Spec:** `docs/superpowers/specs/2026-05-08-playlist-widget-design.md`

---

## Notes for the Implementer

- Build state at start of plan: branch `feat/initial-build`, commit `8957d60`. Working dir `/Users/samyu/Downloads/code/playground/shadowing-app`. 22 unit tests passing. App icon committed. Tasks 1–16 of the original plan plus a polish pack are all in.
- The Xcode project is regenerated from `project.yml` via XcodeGen. Don't hand-edit `project.pbxproj`.
- Bundle identifier convention: main app is `com.yudataguy.ShadowingApp`. Widget will be `com.yudataguy.ShadowingApp.Widget`. App Group is `group.com.yudataguy.shadowingapp` (lowercase by Apple convention).
- Code-signing: this is sideloaded via a free developer account. Both the main app target and the widget extension share the same team / signing identity. The App Group is created automatically when the entitlement first builds; if it complains, you may need to create it once in the Apple Developer portal — but for free-team sideload it usually just works.
- Manual testing on a real iPhone is required for the widget itself (the simulator's home screen widget support is flaky). Unit tests cover the testable seams.
- Keep iOS 17+ minimum.

Build & test command (used throughout):
```bash
cd /Users/samyu/Downloads/code/playground/shadowing-app
xcodegen generate
xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -20
```

---

## Task 1: Add `lastPlayedAt` to Playlist (TDD via PlayerStore)

**Files:**
- Modify: `ShadowingApp/Models/Playlist.swift`
- Modify: `ShadowingApp/State/PlayerStore.swift`
- Modify: `ShadowingAppTests/PlayerStoreQueueTests.swift`

- [ ] **Step 1: Write a failing test**

In `PlayerStoreQueueTests.swift`, add at the end of the class:

```swift
func test_playPlaylist_updatesLastPlayedAt() async throws {
    // Need a real model context to mutate the @Model.
    let schema = Schema([Playlist.self, PlaylistEntry.self, PlaybackState.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    let context = container.mainContext

    let playlist = Playlist(name: "Test")
    context.insert(playlist)
    try context.save()

    let track = Track(folderID: UUID(),
                      relativePath: "x.mp3",
                      url: URL(fileURLWithPath: "/tmp/x.mp3"))

    XCTAssertNil(playlist.lastPlayedAt)
    store.playPlaylist(playlist, tracks: [track], fromIndex: 0)
    XCTAssertNotNil(playlist.lastPlayedAt)
}
```

Add `import SwiftData` to the test file's imports if not already present.

- [ ] **Step 2: Run, confirm fails**

Expected: compile error — `lastPlayedAt` not on `Playlist`, `playPlaylist(_:tracks:fromIndex:)` not on `PlayerStore`.

- [ ] **Step 3: Add `lastPlayedAt` to Playlist**

In `ShadowingApp/Models/Playlist.swift`, add the property:

```swift
@Model
final class Playlist {
    var id: UUID
    var name: String
    var createdAt: Date
    var lastPlayedAt: Date?       // <-- new
    @Relationship(deleteRule: .cascade, inverse: \PlaylistEntry.playlist)
    var entries: [PlaylistEntry] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
        self.lastPlayedAt = nil
    }
}
```

- [ ] **Step 4: Add `playPlaylist` to PlayerStore**

In `ShadowingApp/State/PlayerStore.swift`, add a method that wraps the existing `play(queue:startIndex:)` and stamps `lastPlayedAt`:

```swift
func playPlaylist(_ playlist: Playlist, tracks: [Track], fromIndex index: Int = 0) {
    guard !tracks.isEmpty else { return }
    playlist.lastPlayedAt = .now
    // PlayerStore doesn't own the model context; the model's owning context
    // will persist the change on its next .save(). Callers that pass a
    // detached Playlist will see the stamp in-memory.
    play(queue: tracks, startIndex: index)
}
```

Note: SwiftData persists changes when the owning `ModelContext` calls `.save()`. The mutation here is in-memory until then — which is fine for tests using `isStoredInMemoryOnly`. In production, the `PlaylistDetailView` and widget handoff path will run inside SwiftData's autosave behavior.

- [ ] **Step 5: Wire `playPlaylist` from PlaylistDetailView**

In `ShadowingApp/Views/Playlists/PlaylistDetailView.swift`, replace the existing `FolderSectionHeader` block's `onPlay` and `onShuffle` closures so they call `playPlaylist` instead of `playFolder`:

Find:
```swift
FolderSectionHeader(
    folderName: playlist.name,
    onPlay: { player.playFolder(orderedTracks, shuffled: false) },
    onShuffle: { player.playFolder(orderedTracks, shuffled: true) }
)
```

Replace with:
```swift
FolderSectionHeader(
    folderName: playlist.name,
    onPlay: {
        player.playPlaylist(playlist, tracks: orderedTracks, fromIndex: 0)
    },
    onShuffle: {
        playlist.lastPlayedAt = .now
        try? modelContext.save()
        player.playFolder(orderedTracks, shuffled: true)
    }
)
```

(Shuffle goes through `playFolder` as today but we still stamp `lastPlayedAt` and persist immediately so the widget sees the bump.)

- [ ] **Step 6: Run tests, confirm pass**

22 + 1 new = 23 tests should pass.

- [ ] **Step 7: Commit**

```bash
git add ShadowingApp/Models/Playlist.swift \
        ShadowingApp/State/PlayerStore.swift \
        ShadowingApp/Views/Playlists/PlaylistDetailView.swift \
        ShadowingAppTests/PlayerStoreQueueTests.swift
git commit -m "feat: track Playlist.lastPlayedAt and surface playPlaylist on PlayerStore"
```

---

## Task 2: Introduce App Group + shared SwiftData container

**Files:**
- Create: `ShadowingApp/Services/AppGroup.swift`
- Create: `ShadowingApp/ShadowingApp.entitlements`
- Modify: `ShadowingApp/ShadowingAppApp.swift`
- Modify: `project.yml` (entitlements path + capabilities)

This task is configuration; no unit tests. Build verification only. The store moves from the default location to the App Group container — existing playlists/playback-state will reset on first launch with the new build. Acceptable for a personal app at this stage.

- [ ] **Step 1: Define the App Group identifier**

```swift
// ShadowingApp/Services/AppGroup.swift
import Foundation
import SwiftData

enum AppGroup {
    static let identifier = "group.com.yudataguy.shadowingapp"

    /// SwiftData container backed by the shared App Group container so the
    /// widget extension can read from the same store as the main app.
    static func makeSharedContainer() throws -> ModelContainer {
        let schema = Schema([Playlist.self, PlaylistEntry.self, PlaybackState.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(identifier)
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

- [ ] **Step 2: Create the entitlements file**

```xml
<!-- ShadowingApp/ShadowingApp.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.yudataguy.shadowingapp</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 3: Reference entitlements from `project.yml`**

In the `ShadowingApp` target settings block in `project.yml`, add:

```yaml
    settings:
      base:
        # ... existing keys ...
        CODE_SIGN_ENTITLEMENTS: ShadowingApp/ShadowingApp.entitlements
```

- [ ] **Step 4: Use the shared container in the main app**

In `ShadowingApp/ShadowingAppApp.swift`, replace the existing container initialization with:

```swift
init() {
    let container: ModelContainer
    do {
        container = try AppGroup.makeSharedContainer()
    } catch {
        fatalError("Failed to create shared model container: \(error)")
    }
    self.modelContainer = container
    // ... rest of init unchanged ...
}
```

- [ ] **Step 5: Regenerate, build, run tests**

```bash
xcodegen generate
xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -15
```

Expected: 23 tests pass. (The shared container path uses a real on-disk SQLite store; tests use in-memory.) If a code-signing error appears about App Groups during *simulator* test, that's iOS being strict — it should still allow simulator runs without provisioning profile complications. If it blocks, the workaround is to set `CODE_SIGN_ENTITLEMENTS` only for Release configuration; for now confirm the simulator test works as-is and only fall back if needed.

- [ ] **Step 6: Commit**

```bash
git add ShadowingApp/Services/AppGroup.swift \
        ShadowingApp/ShadowingApp.entitlements \
        ShadowingApp/ShadowingAppApp.swift \
        project.yml \
        ShadowingApp.xcodeproj/project.pbxproj
git commit -m "feat: move SwiftData store to shared App Group container"
```

---

## Task 3: Shared `PlayPlaylistIntent`

**Files:**
- Create: `ShadowingApp/Intents/PlayPlaylistIntent.swift`
- Create: `ShadowingAppTests/PlayPlaylistIntentTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// ShadowingAppTests/PlayPlaylistIntentTests.swift
import XCTest
import AppIntents
@testable import ShadowingApp

final class PlayPlaylistIntentTests: XCTestCase {
    func test_perform_writesPendingIDToSharedDefaults() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var intent = PlayPlaylistIntent()
        intent.playlistID = "test-uuid-abc-123"

        _ = try await intent.perform(defaults: defaults)

        XCTAssertEqual(
            defaults.string(forKey: PlayPlaylistIntent.pendingIDKey),
            "test-uuid-abc-123"
        )
    }
}
```

The test uses an injectable `defaults` parameter on `perform` so we can verify with a memory-backed suite without touching the App Group store.

- [ ] **Step 2: Run, confirm fails**

Expected: compile error — `PlayPlaylistIntent` not defined.

- [ ] **Step 3: Implement the intent**

```swift
// ShadowingApp/Intents/PlayPlaylistIntent.swift
import AppIntents
import Foundation

struct PlayPlaylistIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Playlist"
    static var description = IntentDescription("Open Shadowing and play a specific playlist.")
    static var openAppWhenRun: Bool = true

    static let pendingIDKey = "pendingPlaylistID"

    @Parameter(title: "Playlist ID")
    var playlistID: String

    init() {}
    init(playlistID: String) { self.playlistID = playlistID }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        return try await perform(defaults: defaults)
    }

    /// Test-friendly seam.
    func perform(defaults: UserDefaults?) async throws -> some IntentResult {
        defaults?.set(playlistID, forKey: Self.pendingIDKey)
        return .result()
    }
}
```

- [ ] **Step 4: Run tests, confirm pass**

23 + 1 = 24 tests should pass.

- [ ] **Step 5: Commit**

```bash
git add ShadowingApp/Intents/PlayPlaylistIntent.swift \
        ShadowingAppTests/PlayPlaylistIntentTests.swift \
        ShadowingApp.xcodeproj/project.pbxproj
git commit -m "feat: add PlayPlaylistIntent that writes pending ID to App Group defaults"
```

---

## Task 4: Main-app handoff (read pendingPlaylistID on launch)

**Files:**
- Create: `ShadowingApp/Services/WidgetHandoff.swift`
- Modify: `ShadowingApp/Views/RootView.swift`
- Modify: `ShadowingApp/State/PlayerStore.swift` (a small wrapper)
- Create: `ShadowingAppTests/WidgetHandoffTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// ShadowingAppTests/WidgetHandoffTests.swift
import XCTest
@testable import ShadowingApp

@MainActor
final class WidgetHandoffTests: XCTestCase {
    func test_handle_callsPlayWithLookedUpPlaylistAndClearsKey() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("uuid-abc", forKey: PlayPlaylistIntent.pendingIDKey)

        var resolvedID: String?
        let handoff = WidgetHandoff(
            defaults: defaults,
            lookupAndPlay: { id in resolvedID = id }
        )
        handoff.handle()

        XCTAssertEqual(resolvedID, "uuid-abc")
        XCTAssertNil(defaults.string(forKey: PlayPlaylistIntent.pendingIDKey))
    }

    func test_handle_doesNothingWhenKeyAbsent() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var called = false
        let handoff = WidgetHandoff(
            defaults: defaults,
            lookupAndPlay: { _ in called = true }
        )
        handoff.handle()

        XCTAssertFalse(called)
    }
}
```

- [ ] **Step 2: Run, confirm fails**

Expected: compile error — `WidgetHandoff` not defined.

- [ ] **Step 3: Implement WidgetHandoff**

```swift
// ShadowingApp/Services/WidgetHandoff.swift
import Foundation

@MainActor
struct WidgetHandoff {
    let defaults: UserDefaults?
    let lookupAndPlay: (String) -> Void

    func handle() {
        guard let defaults,
              let id = defaults.string(forKey: PlayPlaylistIntent.pendingIDKey) else {
            return
        }
        defaults.removeObject(forKey: PlayPlaylistIntent.pendingIDKey)
        lookupAndPlay(id)
    }
}
```

- [ ] **Step 4: Wire it from RootView**

In `ShadowingApp/Views/RootView.swift`, add an environment-injected dependency on the model context, plus the `.task` that runs the handoff:

```swift
import SwiftUI
import SwiftData

struct RootView: View {
    @State private var showNowPlaying = false
    @Environment(PlayerStore.self) private var player
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            // ... existing tabs ...
        }
        .sheet(isPresented: $showNowPlaying) { NowPlayingSheet() }
        .alert(/* existing alert unchanged */)
        .task { handleWidgetHandoff() }
    }

    private func handleWidgetHandoff() {
        let handoff = WidgetHandoff(
            defaults: UserDefaults(suiteName: AppGroup.identifier),
            lookupAndPlay: { idString in
                guard let uuid = UUID(uuidString: idString) else { return }
                let descriptor = FetchDescriptor<Playlist>(
                    predicate: #Predicate { $0.id == uuid }
                )
                guard let playlist = try? modelContext.fetch(descriptor).first else { return }

                let entries = playlist.entries.sorted { $0.position < $1.position }
                // Track resolution requires the in-memory snapshot which is
                // populated by LibraryView. If the user opened the app cold
                // via a widget tap, the snapshot may be empty for a moment —
                // we'll resolve what we can; absent tracks are simply skipped.
                // (LibrarySnapshot is the right abstraction here.)
                let snapshot = ServiceLocator.librarySnapshot
                let tracks = entries.compactMap {
                    snapshot?.track(forStableID: $0.trackStableID)
                }
                guard !tracks.isEmpty else { return }
                player.playPlaylist(playlist, tracks: tracks, fromIndex: 0)
            }
        )
        handoff.handle()
    }
}
```

`ServiceLocator` doesn't exist yet — I'm shoehorning a simple static for the widget path because `LibrarySnapshot` is currently injected via environment but the handoff runs inside `.task`, where `@Environment(LibrarySnapshot.self)` works the same as `@Environment(PlayerStore.self)`. Replace the `ServiceLocator` reference with `@Environment(LibrarySnapshot.self) private var librarySnapshot` and use `librarySnapshot.track(forStableID:)` directly. Cleaner.

Updated handoff:

```swift
private func handleWidgetHandoff() {
    let handoff = WidgetHandoff(
        defaults: UserDefaults(suiteName: AppGroup.identifier),
        lookupAndPlay: { [librarySnapshot, modelContext, player] idString in
            guard let uuid = UUID(uuidString: idString) else { return }
            let descriptor = FetchDescriptor<Playlist>(
                predicate: #Predicate { $0.id == uuid }
            )
            guard let playlist = try? modelContext.fetch(descriptor).first else { return }
            let entries = playlist.entries.sorted { $0.position < $1.position }
            let tracks = entries.compactMap {
                librarySnapshot.track(forStableID: $0.trackStableID)
            }
            guard !tracks.isEmpty else { return }
            player.playPlaylist(playlist, tracks: tracks, fromIndex: 0)
        }
    )
    handoff.handle()
}
```

Add the environment: `@Environment(LibrarySnapshot.self) private var librarySnapshot`.

- [ ] **Step 5: Run tests, confirm pass**

24 + 2 = 26 tests should pass.

- [ ] **Step 6: Commit**

```bash
git add ShadowingApp/Services/WidgetHandoff.swift \
        ShadowingApp/Views/RootView.swift \
        ShadowingAppTests/WidgetHandoffTests.swift \
        ShadowingApp.xcodeproj/project.pbxproj
git commit -m "feat: handle widget-launched playlist on app launch"
```

---

## Task 5: Widget extension target scaffolding

**Files:**
- Modify: `project.yml` (new target)
- Create: `ShadowingWidget/Info.plist`
- Create: `ShadowingWidget/ShadowingWidget.entitlements`
- Create: `ShadowingWidget/ShadowingWidgetBundle.swift` (placeholder)
- Create: `ShadowingWidget/PlaylistsWidget.swift` (placeholder)

This task adds the new target and proves it compiles. The widget renders a stub view; Task 6 implements the real one.

- [ ] **Step 1: Add the target to `project.yml`**

In `project.yml`, after the `ShadowingApp` and `ShadowingAppTests` targets, add:

```yaml
  ShadowingWidget:
    type: app-extension
    platform: iOS
    sources:
      - path: ShadowingWidget
      - path: ShadowingApp/Intents/PlayPlaylistIntent.swift
      - path: ShadowingApp/Services/AppGroup.swift
      - path: ShadowingApp/Models/Playlist.swift
      - path: ShadowingApp/Models/PlaylistEntry.swift
      - path: ShadowingApp/Models/PlaybackState.swift
    info:
      path: ShadowingWidget/Info.plist
      properties:
        CFBundleDisplayName: Shadowing
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.yudataguy.ShadowingApp.Widget
        IPHONEOS_DEPLOYMENT_TARGET: "17.0"
        TARGETED_DEVICE_FAMILY: "1"
        CODE_SIGN_ENTITLEMENTS: ShadowingWidget/ShadowingWidget.entitlements
        GENERATE_INFOPLIST_FILE: "NO"
        SKIP_INSTALL: "NO"
```

Add the widget target as a dependency of the main app so it embeds in the app bundle. Modify the main app's target block to include:

```yaml
  ShadowingApp:
    # ... existing keys ...
    dependencies:
      - target: ShadowingWidget
        embed: true
        codeSign: true
```

(If the existing `dependencies` key is absent, add it. If present and has other entries, append.)

- [ ] **Step 2: Create the widget entitlements**

```xml
<!-- ShadowingWidget/ShadowingWidget.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.yudataguy.shadowingapp</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 3: Create placeholder widget bundle**

```swift
// ShadowingWidget/ShadowingWidgetBundle.swift
import WidgetKit
import SwiftUI

@main
struct ShadowingWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlaylistsWidget()
    }
}
```

```swift
// ShadowingWidget/PlaylistsWidget.swift
import WidgetKit
import SwiftUI

struct PlaylistsWidget: Widget {
    let kind = "PlaylistsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { entry in
            Text("Shadowing — placeholder")
        }
        .configurationDisplayName("Shadowing Playlists")
        .description("Quickly play a playlist.")
        .supportedFamilies([.systemMedium])
    }
}

private struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry { SimpleEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        completion(Timeline(entries: [SimpleEntry(date: .now)], policy: .after(.now.addingTimeInterval(900))))
    }
}

private struct SimpleEntry: TimelineEntry {
    let date: Date
}
```

- [ ] **Step 4: Regenerate and build**

```bash
xcodegen generate
xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

Expected: build succeeds. `xcodebuild` may emit a `Wrote ShadowingApp.xcodeproj` line; the new target should appear in `xcodebuild -list` output.

If you see "Failed to register bundle" or signing errors specifically about the widget extension on simulator, those are usually safe to ignore for the simulator path. They become real on device install.

- [ ] **Step 5: Run unit tests, confirm still pass**

```bash
xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -10
```

Expected: 26 pass.

- [ ] **Step 6: Commit**

```bash
git add ShadowingWidget project.yml ShadowingApp.xcodeproj/project.pbxproj
git commit -m "feat: scaffold ShadowingWidget app-extension target"
```

---

## Task 6: TimelineProvider that fetches recent playlists

**Files:**
- Create: `ShadowingWidget/PlaylistsTimelineProvider.swift`
- Modify: `ShadowingWidget/PlaylistsWidget.swift`

- [ ] **Step 1: Implement the timeline provider**

```swift
// ShadowingWidget/PlaylistsTimelineProvider.swift
import WidgetKit
import SwiftData
import Foundation

struct PlaylistEntry: TimelineEntry {
    let date: Date
    let playlists: [PlaylistSummary]

    static let empty = PlaylistEntry(date: .now, playlists: [])
}

struct PlaylistSummary: Identifiable, Hashable {
    let id: UUID
    let name: String
    let trackCount: Int
}

struct PlaylistsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaylistEntry {
        PlaylistEntry(date: .now, playlists: [
            PlaylistSummary(id: UUID(), name: "Morning drills", trackCount: 12),
            PlaylistSummary(id: UUID(), name: "Spanish phrases", trackCount: 8),
            PlaylistSummary(id: UUID(), name: "French sentences", trackCount: 5),
            PlaylistSummary(id: UUID(), name: "Pronunciation", trackCount: 20)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (PlaylistEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaylistEntry>) -> Void) {
        let entry = currentEntry()
        let next = Date.now.addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> PlaylistEntry {
        let summaries = (try? fetchTopPlaylists()) ?? []
        return PlaylistEntry(date: .now, playlists: summaries)
    }

    private func fetchTopPlaylists() throws -> [PlaylistSummary] {
        let container = try AppGroup.makeSharedContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Playlist>(
            sortBy: [
                SortDescriptor(\.lastPlayedAt, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse)
            ]
        )
        let all = try context.fetch(descriptor)
        return all.prefix(4).map {
            PlaylistSummary(id: $0.id, name: $0.name, trackCount: $0.entries.count)
        }
    }
}
```

- [ ] **Step 2: Wire it into the widget**

In `ShadowingWidget/PlaylistsWidget.swift`, replace the placeholder provider reference:

```swift
struct PlaylistsWidget: Widget {
    let kind = "PlaylistsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaylistsTimelineProvider()) { entry in
            PlaylistsWidgetView(entry: entry)
        }
        .configurationDisplayName("Shadowing Playlists")
        .description("Quickly play a recent playlist.")
        .supportedFamilies([.systemMedium])
    }
}
```

`PlaylistsWidgetView` doesn't exist yet — Task 7 builds it. Add a stub at the bottom of `PlaylistsWidget.swift` so this compiles:

```swift
struct PlaylistsWidgetView: View {
    let entry: PlaylistEntry
    var body: some View {
        Text(entry.playlists.first?.name ?? "Empty")
    }
}
```

(Task 7 replaces this with the real view in its own file.)

- [ ] **Step 3: Build, confirm compiles**

```bash
xcodegen generate
xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -10
```

- [ ] **Step 4: Commit**

```bash
git add ShadowingWidget ShadowingApp.xcodeproj/project.pbxproj
git commit -m "feat: widget timeline provider reading top playlists from shared store"
```

---

## Task 7: Widget UI — 2×2 tile grid

**Files:**
- Create: `ShadowingWidget/PlaylistsWidgetView.swift`
- Modify: `ShadowingWidget/PlaylistsWidget.swift` (remove the stub view)

- [ ] **Step 1: Implement the view**

```swift
// ShadowingWidget/PlaylistsWidgetView.swift
import SwiftUI
import WidgetKit
import AppIntents

struct PlaylistsWidgetView: View {
    let entry: PlaylistEntry

    private var displayed: [PlaylistSummary?] {
        // Pad up to 4 slots so the grid layout stays stable.
        var arr: [PlaylistSummary?] = entry.playlists.map { Optional($0) }
        while arr.count < 4 { arr.append(nil) }
        return Array(arr.prefix(4))
    }

    var body: some View {
        if entry.playlists.isEmpty {
            emptyState
        } else {
            grid
        }
    }

    private var grid: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                tile(displayed[0])
                tile(displayed[1])
            }
            HStack(spacing: 6) {
                tile(displayed[2])
                tile(displayed[3])
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.39, green: 0.40, blue: 0.95),
                         Color(red: 0.02, green: 0.71, blue: 0.83)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private func tile(_ summary: PlaylistSummary?) -> some View {
        if let summary {
            Button(intent: PlayPlaylistIntent(playlistID: summary.id.uuidString)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Spacer()
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.caption2)
                        Text("\(summary.trackCount)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white.opacity(0.85))
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.06))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.title2)
                .foregroundStyle(.white)
            Text("Create a playlist in the app")
                .font(.caption)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.39, green: 0.40, blue: 0.95),
                         Color(red: 0.02, green: 0.71, blue: 0.83)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
```

- [ ] **Step 2: Remove the stub view from `PlaylistsWidget.swift`**

Delete the `struct PlaylistsWidgetView: View { … }` stub added at the end of that file in Task 6.

- [ ] **Step 3: Build, confirm compiles**

```bash
xcodegen generate
xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -10
```

- [ ] **Step 4: Run tests, confirm still pass**

26 tests.

- [ ] **Step 5: Commit**

```bash
git add ShadowingWidget ShadowingApp.xcodeproj/project.pbxproj
git commit -m "feat: widget 2x2 tile grid with PlayPlaylistIntent buttons"
```

---

## Task 8: Reload widget timelines when `lastPlayedAt` updates (nice-to-have, in scope)

**Files:**
- Modify: `ShadowingApp/State/PlayerStore.swift`

Without this, the widget's "most recently played" ordering only refreshes every 15 minutes. With it, it refreshes the moment you start a playlist.

- [ ] **Step 1: Add WidgetKit reload**

In `ShadowingApp/State/PlayerStore.swift`, at the top:

```swift
import WidgetKit
```

In `playPlaylist`:

```swift
func playPlaylist(_ playlist: Playlist, tracks: [Track], fromIndex index: Int = 0) {
    guard !tracks.isEmpty else { return }
    playlist.lastPlayedAt = .now
    WidgetCenter.shared.reloadAllTimelines()
    play(queue: tracks, startIndex: index)
}
```

(`WidgetCenter` lives in WidgetKit, importable from the main app target.)

- [ ] **Step 2: Run tests, confirm still pass**

26 tests pass.

- [ ] **Step 3: Commit**

```bash
git add ShadowingApp/State/PlayerStore.swift
git commit -m "feat: reload widget timelines when a playlist starts playing"
```

---

## Task 9: Manual test pass on a real iPhone

**Files:** none.

This task is checklist-driven; no code changes.

- [ ] Sideload the new build (`⌘R` in Xcode with iPhone selected).
- [ ] Confirm the app still launches and existing playback works.
- [ ] Long-press home screen → "+" → search "Shadowing" → add the medium widget.
- [ ] Confirm the widget shows up to 4 of your playlists. If you have <4, the empty slots are blank.
- [ ] Tap a playlist tile → app opens, that playlist starts playing within ~1 second.
- [ ] Open the app, play a different playlist via the Playlists tab → return home → confirm widget reorders within ~1 minute (Task 8 should make this near-instant).
- [ ] Delete a playlist that's currently in the widget; tap its old tile within 5 minutes → app opens but no playback (silent — expected).
- [ ] Force-quit the app, then tap a widget tile → cold launch + playback.
- [ ] Lock the device → confirm lock-screen now-playing controls work for the widget-launched playlist.

If any of these fail, document the failure mode and either fix-forward (small) or open a follow-up issue (larger). Commit any fixes individually.

- [ ] **Final commit** if any fixes were made:

```bash
git commit -m "chore: manual test fixes for widget"
```

---

## Definition of Done

- All unit tests pass (26 expected after this plan).
- Widget appears in the Add Widget list on a real iPhone.
- Tapping a widget tile starts the corresponding playlist within ~1 second.
- Widget order reflects most-recently-played within ~1 minute (instant via Task 8).
- Existing app behavior unchanged: tests for Library, Playlists, NowPlaying, etc. still green.
- No `TODO` / `FIXME` comments left in widget-related code.
