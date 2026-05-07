# Favorite Playlist Widget — Design Spec

**Date:** 2026-05-08
**Status:** Draft for review
**Depends on:** the playlist widget spec (`2026-05-08-playlist-widget-design.md`)

## Purpose

Add a small (`.systemSmall`) Home Screen widget for one user-chosen playlist. Tapping the tile starts that playlist. Configuration (which playlist) happens via long-press → Edit Widget.

## Goals

- New `.systemSmall` widget alongside the existing medium widget.
- User selects one specific playlist via the widget's edit configuration UI.
- Selection persists with the widget. Long-press → Edit Widget shows the current pick and lets the user change it.
- Tap the tile → the selected playlist starts playing (same launch + handoff path as the medium widget).

## Non-Goals (v1)

- Multiple small widgets with different selections — the user can already add the small widget twice if they want this; we don't need bespoke logic.
- Lock-screen variants. Out of scope.
- Playback controls inside the small widget. Tap is the only interaction.
- A "now playing" small widget showing the active track. Different feature.

## Platform & Stack

- iOS 17+ (already the project minimum).
- AppIntents framework: `AppIntentConfiguration`, `WidgetConfigurationIntent`, `AppEntity`, `EntityQuery`.
- WidgetKit's `AppIntentTimelineProvider`.
- All new code lives in the existing `ShadowingWidget` extension target.

## Architecture

The new widget reuses the playlist snapshot system that the medium widget already relies on. No changes to the main app, no new entitlements, no new target.

### Configuration intent

A new `SelectPlaylistIntent` conforming to `WidgetConfigurationIntent` carries one parameter: the chosen `PlaylistEntity?`. This is the intent iOS hands the widget on every refresh, and the user edits via long-press.

```swift
struct SelectPlaylistIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Playlist"
    static var description = IntentDescription("Pick the playlist this widget should play.")

    @Parameter(title: "Playlist")
    var playlist: PlaylistEntity?
}
```

### PlaylistEntity + Query

`PlaylistEntity` is a thin `AppEntity` representing a single playlist for the configuration picker. Its `Query` reads from the existing `PlaylistSnapshotStore` so the picker is populated by whatever the main app has currently published.

```swift
struct PlaylistEntity: AppEntity {
    let id: UUID
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Playlist"
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    static var defaultQuery = PlaylistEntityQuery()
}

struct PlaylistEntityQuery: EntityQuery {
    func entities(for identifiers: [PlaylistEntity.ID]) async throws -> [PlaylistEntity] {
        let snapshots = PlaylistSnapshotStore.read(from: UserDefaults(suiteName: AppGroup.identifier))
        return snapshots
            .filter { identifiers.contains($0.id) }
            .map { PlaylistEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [PlaylistEntity] {
        let snapshots = PlaylistSnapshotStore.read(from: UserDefaults(suiteName: AppGroup.identifier))
        return snapshots.map { PlaylistEntity(id: $0.id, name: $0.name) }
    }
}
```

### Timeline provider

`FavoritePlaylistTimelineProvider` conforms to `AppIntentTimelineProvider` (the configuration-aware variant). Each refresh receives the current `SelectPlaylistIntent` and resolves the picked playlist against the current snapshot:

```swift
struct FavoritePlaylistEntry: TimelineEntry {
    let date: Date
    let summary: PlaylistSummary?
}

struct FavoritePlaylistTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = FavoritePlaylistEntry
    typealias Intent = SelectPlaylistIntent

    func placeholder(in context: Context) -> FavoritePlaylistEntry {
        FavoritePlaylistEntry(date: .now, summary: PlaylistSummary(id: UUID(), name: "Morning drills", trackCount: 12))
    }

    func snapshot(for configuration: SelectPlaylistIntent, in context: Context) async -> FavoritePlaylistEntry {
        FavoritePlaylistEntry(date: .now, summary: resolve(configuration))
    }

    func timeline(for configuration: SelectPlaylistIntent, in context: Context) async -> Timeline<FavoritePlaylistEntry> {
        let entry = FavoritePlaylistEntry(date: .now, summary: resolve(configuration))
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60)))
    }

    private func resolve(_ configuration: SelectPlaylistIntent) -> PlaylistSummary? {
        guard let id = configuration.playlist?.id else { return nil }
        let snapshots = PlaylistSnapshotStore.read(from: UserDefaults(suiteName: AppGroup.identifier))
        guard let s = snapshots.first(where: { $0.id == id }) else { return nil }
        return PlaylistSummary(id: s.id, name: s.name, trackCount: s.trackCount)
    }
}
```

### Widget declaration

```swift
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

### Widget view

Single tile with the same gradient background. Two states:

- **Configured + resolved:** name (centered), play icon, track count.
- **Unconfigured or stale:** soft icon + "Tap and hold to choose" hint.

When configured, the tile is wrapped in `Button(intent: PlayPlaylistIntent(playlistID: id))` — the same intent that powers the medium widget's tile taps. Same handoff, same launch path. No new main-app code.

When unconfigured, no button — the tile is decorative; tapping does nothing. (User long-presses → Edit Widget to configure.)

### Bundle registration

`ShadowingWidgetBundle.swift` gains one line:

```swift
var body: some Widget {
    PlaylistsWidget()
    FavoritePlaylistWidget()
}
```

## File Layout

```
ShadowingWidget/
  PlaylistEntity.swift                  [+] AppEntity + Query
  SelectPlaylistIntent.swift            [+] WidgetConfigurationIntent
  FavoritePlaylistWidget.swift          [+] AppIntentConfiguration declaration
  FavoritePlaylistTimelineProvider.swift [+] AppIntentTimelineProvider
  FavoritePlaylistWidgetView.swift      [+] SwiftUI single-tile view
  ShadowingWidgetBundle.swift           [m] register the new widget
```

No changes to the main app, `project.yml`, or entitlements.

## Edge Cases

- **No playlists yet.** `PlaylistEntityQuery.suggestedEntities` returns empty; iOS shows an empty picker. The widget renders the unconfigured state. User must create playlists in the app first.
- **Configured playlist deleted.** Snapshot lookup returns nil → unconfigured-state tile. Self-heals when user picks a new one.
- **Configured playlist renamed.** Lookup by id still succeeds; the new name renders on next refresh (within 15 min, or instantly if the user plays anything that triggers `WidgetCenter.shared.reloadAllTimelines()`).
- **Multiple instances of the small widget.** Each iOS widget instance has its own `SelectPlaylistIntent` configuration, so each can point to a different playlist independently. No special handling needed.
- **Tap while configured playlist is empty (no tracks).** Same as the medium widget: the app opens, `PlayerStore.playPlaylist([])` early-returns. The widget tap effectively just opens the app.

## Testing Strategy

### Unit tests

- `PlaylistEntityQueryTests` — verifies `entities(for:)` returns matching entities and `suggestedEntities()` returns all entities, both reading from `PlaylistSnapshotStore`.

### Manual tests

- Add the small widget to the home screen.
- Long-press → Edit Widget → confirm the picker shows the current playlist names.
- Pick a playlist → confirm the tile updates within seconds.
- Tap the tile → app opens, that playlist plays.
- Add the small widget twice with different selections → confirm each works independently.
- Delete the configured playlist in the app → return to home → tile shows unconfigured state.
- Rename the configured playlist → confirm the tile updates within ~15 min (or instantly after any other play that triggers a reload).

## Open Questions / Future Work

- Lock-screen `.accessoryRectangular` and `.accessoryCircular` variants — same configuration intent could drive them.
- Show the playlist's track count more prominently, or include a "last played" timestamp on the tile.
- Add a context menu to the tile for "Shuffle this playlist" alongside the default play.

## Decisions Log

- **Reuse the existing `PlayPlaylistIntent`** for the tap action rather than introducing a new one. Single source of truth for the launch + handoff behavior.
- **Reuse `PlaylistSnapshotStore`** for the entity query rather than reading SwiftData. Same reasoning as the medium widget — no shared SwiftData containers.
- **Auto-resolve at refresh** rather than caching the name in the configuration. If the user renames a playlist in the app, the widget should reflect that — caching the name in the intent would freeze it.
- **Single widget extension** (no separate target). The two widgets share types, snapshot reader, and intent — splitting them would just duplicate boilerplate.
- **No "default playlist" fallback.** When unconfigured, the tile shows a "tap and hold to choose" hint rather than auto-picking the most-recently-played. Configurable widgets that auto-pick anything tend to surprise users.
