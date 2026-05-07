# Playlist Quick-Play Widget — Design Spec

**Date:** 2026-05-08
**Status:** Draft for review
**Depends on:** the existing Shadowing app spec (`2026-05-07-shadowing-app-design.md`)

## Purpose

Add a Home Screen widget that lets the user one-tap into playing any of their recent playlists. Reduces the "open app → tap Playlists tab → tap playlist → tap play" sequence to a single tap from the home screen.

## Goals

- Single medium-sized iOS Home Screen widget showing the 4 most-recently-played playlists.
- Tap a tile → the app opens and starts playing that playlist immediately.
- Widget refreshes its "recently played" ordering automatically after each playback.
- Free side benefit: the AppIntent that powers the widget is also available to Siri / Shortcuts.

## Non-Goals (v1)

- Small or large widget sizes (medium only).
- Lock-screen widgets, StandBy widgets, Control Center widgets.
- User-configurable widget content (the rule is automatic: most-recently-played).
- Playback that begins without launching the main app.
- Per-track widgets (only playlists).
- Live Activity for in-progress playback.

## Platform & Stack

- iOS 17+ minimum (for interactive widgets and modern AppIntent APIs).
- WidgetKit, AppIntents, SwiftUI for the widget UI.
- App Groups entitlement for shared SwiftData store between the main app and the widget extension.
- xcodegen continues to be the project source of truth.

## Architecture

Three pieces coordinate the feature.

### 1. App Group + shared SwiftData store

A new App Group `group.com.yudataguy.shadowingapp` is added to both targets via entitlements. The SwiftData `ModelContainer` is constructed with `ModelConfiguration(.applicationDataContainer(forSecurityApplicationGroupIdentifier: ...))` so its underlying SQLite store lives in the shared container. The widget reads from this store; only the main app writes.

A small model addition: `Playlist.lastPlayedAt: Date?`. `PlayerStore.playPlaylist(_:fromIndex:)` sets it whenever a playlist begins playing. The widget's TimelineProvider sorts by `lastPlayedAt` descending, falling back to `createdAt` for never-played playlists.

### 2. Widget extension target (`ShadowingWidget`)

A new app-extension target named `ShadowingWidget`, configured in `project.yml`. The extension contains:

- `ShadowingWidgetBundle.swift` — the `@main` entry point declaring one widget.
- `PlaylistsWidget.swift` — the `Widget` declaration with a `TimelineProvider` that fetches up to 4 playlists from the shared SwiftData store on a 15-minute cadence (and immediately on tap, since `openAppWhenRun` triggers a refresh).
- `PlaylistsWidgetView.swift` — the SwiftUI view that renders a 2×2 grid. Each cell is a `Link` or `Button(intent:)` wrapping the tile.

Each tile is a `Button(intent: PlayPlaylistIntent(playlistID: id.uuidString))`.

### 3. Shared AppIntent (`PlayPlaylistIntent`)

A single Swift file `PlayPlaylistIntent.swift` defines the intent. It is added to both the main app target and the widget extension target (via `project.yml`'s explicit source assignment).

```swift
struct PlayPlaylistIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Playlist"
    static var openAppWhenRun = true

    @Parameter(title: "Playlist ID")
    var playlistID: String

    init() {}
    init(playlistID: String) { self.playlistID = playlistID }

    func perform() async throws -> some IntentResult {
        // Hand off the playlistID via shared App Group UserDefaults
        // so the main app can pick it up on launch.
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        defaults?.set(playlistID, forKey: "pendingPlaylistID")
        return .result()
    }
}
```

### 4. Main app handoff

When the widget intent runs, iOS launches the main app. Before the main app reads the pending ID, the intent's `perform()` has already written `pendingPlaylistID` to the shared `UserDefaults`.

`RootView` (or a new tiny `WidgetHandoff` view modifier) calls a handler in `.task { ... }` that:

1. Reads `pendingPlaylistID` from shared defaults.
2. If non-nil, clears it.
3. Looks up the `Playlist` by id in SwiftData.
4. Calls `playerStore.playPlaylist(playlist, fromIndex: 0)` if found.
5. If lookup fails, no-op (silent — the widget is stale, nothing more to do).

This same handler runs on cold launch and resume (`.task` in SwiftUI runs on view appearance and when the view re-becomes active).

## Data Flow

```
[User taps widget tile]
       ↓
[WidgetKit invokes PlayPlaylistIntent(playlistID: "abc-123…")]
       ↓
[perform() writes "abc-123…" to UserDefaults(suiteName: groupID)]
       ↓
[openAppWhenRun=true → main app launches/foregrounds]
       ↓
[ShadowingAppApp.init wires up dependencies as today]
       ↓
[RootView.task reads pendingPlaylistID, clears it]
       ↓
[Looks up Playlist in SwiftData by UUID]
       ↓
[Calls playerStore.playPlaylist(playlist, fromIndex: 0)]
       ↓
[Audio starts; mini-player appears]
```

When `playPlaylist` runs it also updates `playlist.lastPlayedAt = .now`, which means the next time the widget timeline refreshes, that playlist will be at the top.

## File Layout

```
ShadowingApp/
  Models/
    Playlist.swift                          [m] add lastPlayedAt
  Services/
    AppGroupContainer.swift                 [+] group ID constant + container factory
  Intents/
    PlayPlaylistIntent.swift                [+] shared AppIntent
  State/
    PlayerStore.swift                       [m] update lastPlayedAt on playPlaylist
  Views/
    RootView.swift                          [m] handoff handler in .task
  ShadowingApp.entitlements                 [+] App Group entitlement

ShadowingWidget/
  ShadowingWidgetBundle.swift               [+] @main bundle
  PlaylistsWidget.swift                     [+] Widget + TimelineProvider
  PlaylistsWidgetView.swift                 [+] 2×2 grid SwiftUI view
  Info.plist                                [+] NSExtension declaration
  ShadowingWidget.entitlements              [+] App Group entitlement

project.yml                                 [m] new ShadowingWidget target,
                                                shared file membership for
                                                PlayPlaylistIntent.swift,
                                                AppGroupContainer.swift,
                                                Playlist.swift
```

`AppGroupContainer.swift`, `PlayPlaylistIntent.swift`, `Playlist.swift` (and its dependents `PlaylistEntry.swift`) are members of *both* targets. Other files belong to only one.

## Edge Cases

- **Playlist deleted between widget refresh and tap.** SwiftData lookup returns nil, handler no-ops. Widget refreshes naturally on next timeline tick.
- **No playlists yet.** Widget tiles render with a single "Create a playlist in the app" call-to-action; tapping anywhere opens the app to the Playlists tab.
- **App force-quit.** `openAppWhenRun` cold-launches; the audio session activates as today during `ShadowingAppApp.init`.
- **Track files still downloading from iCloud.** Existing failure-alert path handles unreadable items.
- **Multiple widget instances.** Each instance independently runs the timeline provider. Reads are idempotent and cheap.
- **`pendingPlaylistID` set but app already running.** SwiftUI's `.task` re-runs when the view becomes active, picks up the value, plays. No race because reads always clear-on-read.
- **Widget reads while main app writes `lastPlayedAt`.** SwiftData/SQLite handles concurrent reads from extensions and the main app at the storage layer; the widget reads will see a consistent snapshot.

## Testing Strategy

### Unit tests
- `Playlist.lastPlayedAt` is updated when `PlayerStore.playPlaylist` is invoked. Extend `PlayerStoreQueueTests`.
- `PlayPlaylistIntent.perform()` writes the expected key to the configured suite. New test `PlayPlaylistIntentTests.swift` using a memory-backed UserDefaults suite.
- `RootView`'s handoff is hard to unit-test in SwiftUI; extract the handoff logic into a small testable `WidgetHandoff` helper that takes a `UserDefaults` and a "lookup playlist" closure as injectable seams.

### Manual tests (real iPhone)
- Add the widget to home screen → confirm 4 most-recently-played render.
- Tap a tile → app opens, audio starts.
- Tap a tile when app is already foreground (open and on a different tab) → audio starts.
- Tap a tile after force-quitting the app → cold launch + audio.
- Delete a playlist, wait < 15 min, tap its widget tile → app opens, no playback (silent).
- Edit playlist names, confirm the widget reflects the new names within 15 min (or sooner via WidgetCenter reload).

## Open Questions / Future Work

- A small "favorite playlist" widget (1×1) where the user picks the playlist via widget configuration. Worth doing once the medium widget proves useful.
- A "currently playing" Live Activity that shows track + transport on the lock screen / Dynamic Island.
- Localize the AppIntent title for Siri.
- Force a `WidgetCenter.shared.reloadAllTimelines()` from the main app on `lastPlayedAt` updates so the widget reflects new orderings immediately, not on the next 15-min tick.

## Decisions Log

- **Medium widget only for v1.** Most useful shape; adding small/large later is incremental.
- **Auto-rule "most recently played"** rather than user-configurable selection. Removes the need for widget configuration UI; matches actual usage.
- **App Group + shared SwiftData store** rather than mirroring data via `UserDefaults` JSON. SwiftData is already the source of truth; the App Group entitlement is the only added dependency.
- **`openAppWhenRun = true` + sidecar UserDefaults handoff** rather than running playback in the widget extension. Audio playback requires the main app's process; this is the canonical iOS pattern.
- **Single `PlayPlaylistIntent` shared between targets** rather than duplicate intents per target. Simpler ownership; xcodegen supports cross-target file membership.
- **15-minute timeline refresh.** WidgetKit's typical budget. The widget also reloads after the app updates `lastPlayedAt` (via `WidgetCenter.shared.reloadAllTimelines()` in PlayerStore — a nice-to-have noted in Open Questions; v1 may rely solely on the 15-min cadence).
