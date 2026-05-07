# Shadowing App — Design Spec

**Date:** 2026-05-07
**Status:** Draft for review

## Purpose

A native iOS app that plays MP3s from one or more user-selected folders (synced via iCloud Drive / Files app), built for personal language-shadowing practice and on-the-go listening. The user wants a simple UI with playlists, shuffle, loop, resume-where-you-left-off, and adjustable playback speed.

## Goals

- Play MP3s stored in user-selected iCloud Drive / local folders without re-importing them on every launch.
- Support multiple root folders.
- Provide standard playback controls: play/pause, seek, prev/next, ±15s, shuffle, loop, speed (0.5×–2×).
- Resume each track at its last playback position.
- Continue playing in the background and via lock-screen / Control Center controls.
- Allow ad-hoc playlists with reorderable membership.
- Keep the UI deliberately minimal.

## Non-Goals (v1)

- A-B segment looping (deferred; whole-track and playlist loop only).
- ID3 metadata parsing or album art (filename is the title).
- Sleep timer, EQ, CarPlay, Apple Watch companion.
- Audio formats other than `.mp3`.
- iPad-specific layouts (universal target, but designed for iPhone first).
- Cloud sync of playlists or playback state across devices.

## Platform & Stack

- iOS 17+ (for SwiftData and modern SwiftUI APIs).
- Swift 5.9+, SwiftUI lifecycle, single iOS target named `ShadowingApp`.
- Audio: `AVFoundation` (`AVPlayer`), `MediaPlayer` framework for lock-screen integration.
- Persistence: SwiftData for playlists & playback state; `UserDefaults` for folder bookmarks and global preferences.
- Distribution: personal use, sideloaded via Xcode (free Apple Developer account; weekly rebuild acceptable).

## Architecture

Three layers, coordinated by a single root store.

### 1. Audio layer

`PlayerEngine` protocol with one concrete implementation `AVPlayerEngine`.

Responsibilities:
- Own the `AVPlayer` instance and its `AVPlayerItem` lifecycle.
- Configure `AVAudioSession` with category `.playback`, mode `.spokenAudio`, activate on first play.
- Publish `currentTime`, `duration`, `isPlaying`, `playbackRate` via Combine / `@Observable`.
- Handle `AVAudioSession` interruptions (auto-pause; auto-resume on `.shouldResume` option).
- Update `MPNowPlayingInfoCenter` on track change, play/pause, seek, and rate change.
- Register `MPRemoteCommandCenter` handlers: play, pause, next, previous, skip-forward (15s), skip-backward (15s), change-playback-position.

The protocol exists so we can swap in an `AVAudioEngine + AVAudioUnitTimePitch` implementation later if 0.5× pitch quality from `AVPlayer` is unsatisfactory.

### 2. Library layer

`LibraryService`:
- Reads `[FolderBookmark]` from `UserDefaults` on launch.
- Resolves each bookmark; on `bookmarkDataIsStale`, marks the folder as needing re-pick and surfaces an alert via the Folders settings screen.
- For each resolved root URL, recursively enumerates `.mp3` files (case-insensitive extension match).
- Produces `[Track]` records: stable ID (folder ID + relative path), display title (filename without extension), root folder reference, absolute URL valid for this session.
- Re-scans on app foreground to pick up new files added via iCloud sync.

`UIDocumentPickerViewController` is used to add a new root folder; the returned URL is converted to a security-scoped bookmark and appended to the bookmarks array.

### 3. Persistence layer

SwiftData models:

- `Playlist` — id, name, createdAt, ordered list of `PlaylistEntry`.
- `PlaylistEntry` — id, trackStableID (string), positionInPlaylist (Int).
- `PlaybackState` — trackStableID (unique), lastPosition (TimeInterval), lastPlayedAt (Date).

`UserDefaults`:

- `folderBookmarks: [FolderBookmark]` — each entry: id (UUID), displayName (String), bookmarkData (Data).
- `playbackRate: Double` — global, persisted.
- `loopMode: String` — `.off | .track | .playlist`.
- `shuffleEnabled: Bool`.

### 4. Coordinator

`PlayerStore` (`@Observable`, app-root scoped):
- Holds the current queue (`[Track]`), current index, shuffle state, loop mode, playback rate.
- Exposes intents: `play(track:queue:)`, `playFolder(_:shuffled:)`, `playPlaylist(_:fromIndex:)`, `togglePlayPause()`, `next()`, `previous()`, `seek(to:)`, `skip(by:)`, `setRate(_:)`, `setLoopMode(_:)`, `toggleShuffle()`, `addToPlaylist(_:track:)`.
- Owns a debounced (1 Hz) writer that persists `lastPosition` to SwiftData.
- Translates "track ended" events from `PlayerEngine` into queue advancement using the loop & shuffle rules.

## UI

Tab bar with two tabs: **Library**, **Playlists**. A persistent mini-player sits above the tab bar whenever a queue is loaded; tapping it opens the Now Playing sheet.

### Library tab

- Toolbar: app title left, gear icon right (opens Folders settings).
- Empty state (no folders configured): centered CTA "Pick your MP3 folder" → opens document picker.
- Otherwise: flat scrollable list, sectioned by folder.
- Each section header: folder display name (left), `▶︎ Play` and `🔀 Shuffle` buttons (right).
- Each row: track title; tap → plays the folder starting at that index, current shuffle/loop preserved; swipe-action: "Add to playlist…".

### Playlists tab

- List of playlists, "+" button creates a new one (modal name prompt).
- Tap a playlist → detail screen with reorderable track list, swipe-to-remove, and a header `▶︎ Play` / `🔀 Shuffle`.

### Folders settings (modal)

- List of configured folders, each with a `▶︎ Play` button and swipe-to-remove.
- "Add folder" button → document picker.
- Stale bookmarks render in a warning style with a "Re-pick" action.

### Mini-player

- Title, play/pause, next.
- Tap anywhere on the bar (except buttons) → opens Now Playing sheet.

### Now Playing sheet

Layout, top to bottom:
- Track title + folder name.
- Scrubber with elapsed / remaining timestamps.
- Transport row: `⏮ -15s ⏯ +15s ⏭`.
- Mode row: shuffle toggle, loop button (cycles off → track → playlist), speed picker (0.5 / 0.75 / 1.0 / 1.25 / 1.5 / 1.75 / 2.0).
- "Add to playlist" button.

## Playback Behaviors

### Starting a track

1. Resolve the track's root folder bookmark, call `startAccessingSecurityScopedResource()`.
2. Build `AVPlayerItem`, attach to the player.
3. If a `PlaybackState` exists and `lastPosition < duration - 5s`, seek to `lastPosition`. Otherwise start from 0.
4. Apply current `playbackRate`.
5. Update `MPNowPlayingInfoCenter`.

### Track ends

- `loopMode == .track`: seek to 0, continue.
- `loopMode == .playlist`: advance; wrap to index 0 at end.
- `loopMode == .off`: advance; stop at end of queue.
- `shuffle` on: "next" picks a random un-played index; once all played, reshuffle and continue.

### Speed

`AVPlayer.rate` driven by the picker; persisted globally so it survives launches and applies to new tracks.

### Edge cases

- **Bookmark stale**: alert in Folders settings, "Re-pick" CTA. App still functions with remaining valid folders.
- **Track URL unreachable mid-queue**: skip the track, surface a brief toast, advance.
- **Interruption (call, Siri)**: `AVAudioSession.interruptionNotification` → pause; resume if `.shouldResume` flag is set.
- **App backgrounded**: keeps playing via `UIBackgroundModes: audio`.
- **Duplicate tracks across folders**: stable ID is per `(folderID, relativePath)`, so duplicates are independent and have independent resume positions.

## File Organization

```
ShadowingApp/
  ShadowingAppApp.swift          // app entry, SwiftData container, root view
  Models/
    Track.swift                   // value type, not persisted
    FolderBookmark.swift          // Codable, lives in UserDefaults
    Playlist.swift                // @Model
    PlaylistEntry.swift           // @Model
    PlaybackState.swift           // @Model
  Services/
    LibraryService.swift
    BookmarkStore.swift           // wraps UserDefaults [FolderBookmark]
    PreferencesStore.swift        // wraps UserDefaults rate/loop/shuffle
  Audio/
    PlayerEngine.swift            // protocol
    AVPlayerEngine.swift          // implementation
    NowPlayingCenter.swift        // MPNowPlayingInfoCenter + remote commands
    AudioSessionCoordinator.swift // category, interruptions
  State/
    PlayerStore.swift             // @Observable coordinator
  Views/
    RootView.swift                // tab view + mini-player overlay
    Library/
      LibraryView.swift
      FolderSectionHeader.swift
      TrackRow.swift
    Playlists/
      PlaylistsView.swift
      PlaylistDetailView.swift
      NewPlaylistSheet.swift
    NowPlaying/
      NowPlayingSheet.swift
      MiniPlayerBar.swift
      ScrubberView.swift
    Settings/
      FoldersSettingsView.swift
  Info.plist                      // UIBackgroundModes: audio, usage strings
```

## Testing Strategy

- **Unit tests** for queue logic in `PlayerStore`: shuffle exhaustion, loop transitions, stable ID derivation, edge of queue behavior. Inject a fake `PlayerEngine`.
- **Unit tests** for `LibraryService` recursion against a temp directory of fixture `.mp3`-named files.
- **Unit tests** for resume logic: lastPosition < duration-5s seeks; >= duration-5s starts at 0.
- **Manual test plan** for things not easily unit-tested: background audio, lock-screen controls, interruption recovery, bookmark stale flow, multi-folder add/remove, iCloud file appearing during a session.

## Open Questions

None blocking. Possible v2 follow-ups:
- A-B loop with `AVAudioEngine` engine swap.
- ID3 metadata + cover art.
- Custom skip interval (3/5/10/15s).
- Cross-device sync of playlists.

## Decisions Log

- **Native SwiftUI over PWA / RN** — best AVFoundation control, background audio, Files-app integration.
- **AVPlayer over AVAudioEngine for v1** — simpler; protocol abstraction lets us upgrade later if 0.5× quality is poor.
- **SwiftData over JSON / UserDefaults for playlists** — type-safe, scales as features grow.
- **Whole-track and playlist loop only, no A-B** — user requirement; A-B deferred to v2.
- **Multiple root folders** — flat list grouped by folder in Library; folders managed in a settings sheet.
- **iOS 17+ minimum** — SwiftData and `@Observable` simplify state management materially.
