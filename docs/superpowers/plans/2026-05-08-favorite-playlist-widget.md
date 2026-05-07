# Favorite Playlist Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `.systemSmall` configurable widget that lets the user pick one specific playlist via long-press → Edit Widget; tapping the tile starts that playlist via the existing `PlayPlaylistIntent`.

**Architecture:** New widget in the existing `ShadowingWidget` extension. Configuration via `WidgetConfigurationIntent` carrying a `PlaylistEntity?`. `EntityQuery` reads from the existing `PlaylistSnapshotStore`. `AppIntentTimelineProvider` resolves the configured playlist against the live snapshot on each refresh. No main-app changes; reuses `PlayPlaylistIntent` for the tap.

**Tech Stack:** AppIntents (`AppEntity`, `EntityQuery`, `WidgetConfigurationIntent`), WidgetKit `AppIntentConfiguration`, SwiftUI, iOS 17+.

**Spec:** `docs/superpowers/specs/2026-05-08-favorite-playlist-widget-design.md`

---

## Notes for the Implementer

- Build state at start: branch `feat/initial-build`, commit `d4b90f7`. 29 unit tests passing. Medium widget already shipping.
- The existing widget extension target source-globs everything under `ShadowingWidget/`, so new files there require no `project.yml` edits.
- `PlaylistSnapshotStore`, `AppGroup`, and `PlayPlaylistIntent` are already members of the widget target. Reuse them as-is.
- iOS 17+ APIs: `WidgetConfigurationIntent`, `AppIntentConfiguration(kind:intent:provider:)`, `AppIntentTimelineProvider`. Don't fall back to deprecated `IntentConfiguration` patterns from older docs.
- Don't add new entitlements. Don't change the main app target. Don't touch `project.yml` unless something unexpectedly breaks.

Build & test command (used throughout):
```bash
cd /Users/samyu/Downloads/code/playground/shadowing-app
xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -15
```

`xcodegen generate` is harmless to run; new files under `ShadowingWidget/` are picked up automatically by source-globbing.

---

## Task 1: PlaylistEntity + EntityQuery (TDD)

**Files:**
- Create: `ShadowingWidget/PlaylistEntity.swift`
- Create: `ShadowingAppTests/PlaylistEntityQueryTests.swift`

This is the only TDD-able piece in the plan. The query reads from `PlaylistSnapshotStore`, which is already covered by `PlaylistSnapshotTests`, so we can construct snapshots in a test suite and verify the query maps them to `PlaylistEntity` records correctly.

- [ ] **Step 1: Write failing tests**

```swift
// ShadowingAppTests/PlaylistEntityQueryTests.swift
import XCTest
import AppIntents
@testable import ShadowingApp

final class PlaylistEntityQueryTests: XCTestCase {
    func test_suggestedEntities_returnsAllSnapshots() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let id1 = UUID(); let id2 = UUID()
        let snapshots = [
            PlaylistSnapshot(id: id1, name: "Morning",   trackCount: 5, lastPlayedAt: nil, createdAt: .now),
            PlaylistSnapshot(id: id2, name: "Evening",   trackCount: 3, lastPlayedAt: nil, createdAt: .now)
        ]
        PlaylistSnapshotStore.write(snapshots, to: defaults)

        let query = PlaylistEntityQuery(defaults: defaults)
        let entities = try await query.suggestedEntities()

        XCTAssertEqual(entities.map(\.id).sorted { $0.uuidString < $1.uuidString },
                       [id1, id2].sorted { $0.uuidString < $1.uuidString })
        XCTAssertEqual(Set(entities.map(\.name)), ["Morning", "Evening"])
    }

    func test_entitiesFor_returnsOnlyMatchingIDs() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let id1 = UUID(); let id2 = UUID(); let id3 = UUID()
        let snapshots = [
            PlaylistSnapshot(id: id1, name: "A", trackCount: 0, lastPlayedAt: nil, createdAt: .now),
            PlaylistSnapshot(id: id2, name: "B", trackCount: 0, lastPlayedAt: nil, createdAt: .now),
            PlaylistSnapshot(id: id3, name: "C", trackCount: 0, lastPlayedAt: nil, createdAt: .now)
        ]
        PlaylistSnapshotStore.write(snapshots, to: defaults)

        let query = PlaylistEntityQuery(defaults: defaults)
        let entities = try await query.entities(for: [id1, id3])

        XCTAssertEqual(Set(entities.map(\.name)), ["A", "C"])
    }

    func test_emptyWhenSnapshotEmpty() async throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let query = PlaylistEntityQuery(defaults: defaults)
        XCTAssertEqual(try await query.suggestedEntities().count, 0)
    }
}
```

The tests use a `defaults:` initializer parameter on `PlaylistEntityQuery` so we can swap in a memory-backed suite. The implementation will provide a default that reads from the App Group suite.

- [ ] **Step 2: Run tests, confirm fail**

```bash
xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -15
```

Expected: compile error — `PlaylistEntity` / `PlaylistEntityQuery` not defined.

- [ ] **Step 3: Implement PlaylistEntity + Query**

```swift
// ShadowingWidget/PlaylistEntity.swift
import AppIntents
import Foundation

struct PlaylistEntity: AppEntity {
    let id: UUID
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Playlist"
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = PlaylistEntityQuery()
}

struct PlaylistEntityQuery: EntityQuery {
    let defaults: UserDefaults?

    init(defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)) {
        self.defaults = defaults
    }

    func entities(for identifiers: [PlaylistEntity.ID]) async throws -> [PlaylistEntity] {
        let snapshots = PlaylistSnapshotStore.read(from: defaults)
        let idSet = Set(identifiers)
        return snapshots
            .filter { idSet.contains($0.id) }
            .map { PlaylistEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [PlaylistEntity] {
        let snapshots = PlaylistSnapshotStore.read(from: defaults)
        return snapshots.map { PlaylistEntity(id: $0.id, name: $0.name) }
    }
}
```

Important: the file lives in `ShadowingWidget/`, but the test file imports `@testable import ShadowingApp`. Because `PlaylistEntity.swift` lives only in the widget target, the test won't see it.

**Resolution:** Add `ShadowingWidget/PlaylistEntity.swift` to the main app's compile sources too. The simplest way is to add it to `project.yml`'s `ShadowingApp` `sources:` list. But the existing pattern (`PlayPlaylistIntent.swift`, `AppGroup.swift`) is the inverse — those files live in the main app and are pulled into the widget. To stay consistent with that pattern, **place the new file in `ShadowingApp/Intents/PlaylistEntity.swift` and add it to the widget's `sources:`** like the existing `PlayPlaylistIntent.swift`.

Updated path:
- Create: `ShadowingApp/Intents/PlaylistEntity.swift` (instead of `ShadowingWidget/`)
- Modify: `project.yml` — add this file to the widget target's `sources:`

The widget target's current `sources:` block:
```yaml
    sources:
      - path: ShadowingWidget
      - path: ShadowingApp/Intents/PlayPlaylistIntent.swift
      - path: ShadowingApp/Services/AppGroup.swift
      - path: ShadowingApp/Services/PlaylistSnapshot.swift
```

Add `ShadowingApp/Intents/PlaylistEntity.swift` so the widget can use it:
```yaml
    sources:
      - path: ShadowingWidget
      - path: ShadowingApp/Intents/PlayPlaylistIntent.swift
      - path: ShadowingApp/Intents/PlaylistEntity.swift
      - path: ShadowingApp/Services/AppGroup.swift
      - path: ShadowingApp/Services/PlaylistSnapshot.swift
```

Run `xcodegen generate` after editing project.yml.

- [ ] **Step 4: Run tests, confirm pass**

```bash
xcodegen generate
xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -15
```

29 + 3 = 32 tests should pass.

- [ ] **Step 5: Commit**

```bash
git add ShadowingApp/Intents/PlaylistEntity.swift \
        ShadowingAppTests/PlaylistEntityQueryTests.swift \
        project.yml \
        ShadowingApp.xcodeproj/project.pbxproj
git commit -m "feat: add PlaylistEntity and EntityQuery for widget configuration"
```

---

## Task 2: SelectPlaylistIntent (configuration intent)

**Files:**
- Create: `ShadowingApp/Intents/SelectPlaylistIntent.swift`
- Modify: `project.yml` — add to widget `sources:`

`SelectPlaylistIntent` is a `WidgetConfigurationIntent` that carries the chosen `PlaylistEntity?`. iOS uses it as the configuration surface for the widget's edit UI. Not unit-testable in a useful way (it's a declaration; the framework drives it).

- [ ] **Step 1: Implement the intent**

```swift
// ShadowingApp/Intents/SelectPlaylistIntent.swift
import AppIntents
import Foundation

struct SelectPlaylistIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Playlist"
    static var description = IntentDescription(
        "Pick which playlist this widget should play."
    )

    @Parameter(title: "Playlist")
    var playlist: PlaylistEntity?

    init() {}
    init(playlist: PlaylistEntity?) { self.playlist = playlist }
}
```

- [ ] **Step 2: Add to widget sources in project.yml**

Append `ShadowingApp/Intents/SelectPlaylistIntent.swift` to the `ShadowingWidget` target's `sources:` list (same place you edited in Task 1).

- [ ] **Step 3: Build, confirm compiles**

```bash
xcodegen generate
xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run tests, confirm still pass**

```bash
xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -10
```

32 tests pass.

- [ ] **Step 5: Commit**

```bash
git add ShadowingApp/Intents/SelectPlaylistIntent.swift \
        project.yml \
        ShadowingApp.xcodeproj/project.pbxproj
git commit -m "feat: add SelectPlaylistIntent widget configuration intent"
```

---

## Task 3: FavoritePlaylistTimelineProvider

**Files:**
- Create: `ShadowingWidget/FavoritePlaylistTimelineProvider.swift`

The timeline provider conforms to `AppIntentTimelineProvider`, which receives the current `SelectPlaylistIntent` configuration on each refresh. Not unit-tested (WidgetKit drives it; manual verification covers it).

- [ ] **Step 1: Implement the provider**

```swift
// ShadowingWidget/FavoritePlaylistTimelineProvider.swift
import WidgetKit
import Foundation

struct FavoritePlaylistEntry: TimelineEntry {
    let date: Date
    let summary: PlaylistSummary?
}

struct FavoritePlaylistTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = FavoritePlaylistEntry
    typealias Intent = SelectPlaylistIntent

    func placeholder(in context: Context) -> FavoritePlaylistEntry {
        FavoritePlaylistEntry(
            date: .now,
            summary: PlaylistSummary(id: UUID(), name: "Morning drills", trackCount: 12)
        )
    }

    func snapshot(for configuration: SelectPlaylistIntent, in context: Context) async -> FavoritePlaylistEntry {
        FavoritePlaylistEntry(date: .now, summary: resolve(configuration))
    }

    func timeline(for configuration: SelectPlaylistIntent, in context: Context) async -> Timeline<FavoritePlaylistEntry> {
        let entry = FavoritePlaylistEntry(date: .now, summary: resolve(configuration))
        let next = Date.now.addingTimeInterval(15 * 60)
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func resolve(_ configuration: SelectPlaylistIntent) -> PlaylistSummary? {
        guard let id = configuration.playlist?.id else { return nil }
        let snapshots = PlaylistSnapshotStore.read(from: UserDefaults(suiteName: AppGroup.identifier))
        guard let s = snapshots.first(where: { $0.id == id }) else { return nil }
        return PlaylistSummary(id: s.id, name: s.name, trackCount: s.trackCount)
    }
}
```

`PlaylistSummary` already exists from the medium widget's timeline provider — reuse it as-is.

- [ ] **Step 2: Build, confirm compiles**

```bash
xcodegen generate
xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -10
```

- [ ] **Step 3: Commit**

```bash
git add ShadowingWidget/FavoritePlaylistTimelineProvider.swift \
        ShadowingApp.xcodeproj/project.pbxproj
git commit -m "feat: add favorite-playlist timeline provider"
```

---

## Task 4: FavoritePlaylistWidgetView

**Files:**
- Create: `ShadowingWidget/FavoritePlaylistWidgetView.swift`

Single-tile view with two states: configured (playlist resolved) and unconfigured (show hint).

- [ ] **Step 1: Implement the view**

```swift
// ShadowingWidget/FavoritePlaylistWidgetView.swift
import SwiftUI
import WidgetKit
import AppIntents

struct FavoritePlaylistWidgetView: View {
    let entry: FavoritePlaylistEntry

    var body: some View {
        Group {
            if let summary = entry.summary {
                configured(summary)
            } else {
                unconfigured
            }
        }
        .containerBackground(for: .widget) { background }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.39, green: 0.40, blue: 0.95),
                     Color(red: 0.02, green: 0.71, blue: 0.83)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func configured(_ summary: PlaylistSummary) -> some View {
        Button(intent: PlayPlaylistIntent(playlistID: summary.id.uuidString)) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                Spacer()
                Text(summary.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text("\(summary.trackCount) track\(summary.trackCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .buttonStyle(.plain)
    }

    private var unconfigured: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.title)
                .foregroundStyle(.white)
            Text("Tap and hold to choose")
                .font(.caption)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 2: Build, confirm compiles**

```bash
xcodegen generate
xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -10
```

- [ ] **Step 3: Commit**

```bash
git add ShadowingWidget/FavoritePlaylistWidgetView.swift \
        ShadowingApp.xcodeproj/project.pbxproj
git commit -m "feat: add favorite-playlist widget view"
```

---

## Task 5: FavoritePlaylistWidget declaration + bundle registration

**Files:**
- Create: `ShadowingWidget/FavoritePlaylistWidget.swift`
- Modify: `ShadowingWidget/ShadowingWidgetBundle.swift`

- [ ] **Step 1: Implement the widget declaration**

```swift
// ShadowingWidget/FavoritePlaylistWidget.swift
import WidgetKit
import SwiftUI

struct FavoritePlaylistWidget: Widget {
    let kind = "FavoritePlaylistWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectPlaylistIntent.self,
            provider: FavoritePlaylistTimelineProvider()
        ) { entry in
            FavoritePlaylistWidgetView(entry: entry)
        }
        .configurationDisplayName("Shadowing — Favorite Playlist")
        .description("One-tap play for a chosen playlist.")
        .supportedFamilies([.systemSmall])
    }
}
```

- [ ] **Step 2: Register in the bundle**

Modify `ShadowingWidget/ShadowingWidgetBundle.swift`:

```swift
import WidgetKit
import SwiftUI

@main
struct ShadowingWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlaylistsWidget()
        FavoritePlaylistWidget()
    }
}
```

- [ ] **Step 3: Build, confirm compiles**

```bash
xcodegen generate
xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -10
```

- [ ] **Step 4: Run tests, confirm still pass**

```bash
xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -10
```

32 tests pass.

- [ ] **Step 5: Commit**

```bash
git add ShadowingWidget/FavoritePlaylistWidget.swift \
        ShadowingWidget/ShadowingWidgetBundle.swift \
        ShadowingApp.xcodeproj/project.pbxproj
git commit -m "feat: register favorite-playlist widget in the bundle"
```

---

## Task 6: Manual test pass on a real iPhone

**Files:** none.

- [ ] Sideload the new build (`⌘R` with iPhone selected).
- [ ] On the home screen, long-press → "+" → search "Shadowing" → confirm both widget options appear (the existing 4-tile medium and the new "Favorite Playlist" small).
- [ ] Add the small widget. It should render in the unconfigured state ("Tap and hold to choose").
- [ ] Long-press the small widget → "Edit Widget" → confirm the playlist picker shows your existing playlists.
- [ ] Pick a playlist. The tile should update within seconds to show the playlist name and track count.
- [ ] Tap the tile → app opens, that playlist plays.
- [ ] Add the small widget a second time, configure with a different playlist. Confirm both tiles work independently.
- [ ] Rename the configured playlist in the app → confirm the tile name updates within ~15 minutes (or sooner via any play action that triggers `WidgetCenter.shared.reloadAllTimelines()`).
- [ ] Delete the configured playlist in the app → confirm the tile reverts to the unconfigured state.

If any step fails, document the failure mode. Commit any fixes individually.

- [ ] **Final commit** if any fixes were made:

```bash
git commit -m "chore: manual test fixes for favorite playlist widget"
```

---

## Definition of Done

- All unit tests pass (32 expected).
- Both widgets appear in the Add Widget list on a real iPhone.
- Small widget's edit UI lists the user's playlists.
- Tapping a configured small tile starts the playlist within ~1 second.
- Existing medium widget still works; existing tests still green.
- No `TODO` / `FIXME` comments left in widget-related code.
