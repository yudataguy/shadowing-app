# App Store Submission Prep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare the Shadowing app for App Store submission — ship reviewer-friendly app changes (bundled samples, sample-library entry, onboarding) plus all submission artifacts (privacy manifest, marketing copy, privacy policy, screenshots, archive script).

**Architecture:** Three independent streams. Stream A (Tasks 1–4) lands code/UX changes that make the app reviewable. Stream B (Tasks 5–8) produces the non-code submission artifacts. Stream C (Task 9) is the human-driven submission checklist + final dry-run. Every task can land independently.

**Tech Stack:** SwiftUI, AVFoundation (existing), `xcodebuild archive`/`-exportArchive`, GitHub Pages, LibriVox public-domain audio.

**Spec:** `docs/superpowers/specs/2026-05-08-app-store-prep-design.md`

---

## Notes for the Implementer

- Build state at start: branch `feat/initial-build`, commit `f8e9c6f`. 32 unit tests passing. Two widgets shipped.
- This plan is **mostly mechanical** but Tasks 1, 5, 6, 7, 8 touch new ground (audio fetching, privacy manifest, marketing copy, hosting, screenshots). Don't skip steps.
- All work stays on `feat/initial-build`. We'll consider whether to merge to `main` after the dry-run in Task 9.
- The user must sign up for the Apple Developer Program ($99/year) before the archive can be uploaded. We can produce a build that's ready for upload without the paid account; the upload itself blocks on it.
- LibriVox audio is in the public domain. Bundling it is permitted; we'll display attribution as a courtesy.

Standard build/test command (used throughout):

```bash
cd /Users/samyu/Downloads/code/playground/shadowing-app
xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -15
```

---

## Task 1: Fetch and bundle LibriVox sample audio

**Files:**
- Create: `scripts/fetch_librivox_samples.py`
- Create: `ShadowingApp/Resources/SampleAudio/` (directory; populated by the script)
- Create: `ShadowingApp/Resources/SampleAudio.json` (metadata)
- Modify: `project.yml` (add Resources to ShadowingApp target sources)
- Modify: `ShadowingApp/.gitignore` (none — we *do* commit the audio)

This is one-time content acquisition. The script is idempotent so we can re-run it if we want different excerpts.

- [ ] **Step 1: Pick the three excerpts**

Selection criteria: short (target 30–60 seconds each, post-trim), clear narration, three different languages, public-domain authors.

Concrete picks (will work in 2026):
- **English** — opening of *Pride and Prejudice* by Jane Austen, narrated by Karen Savage. LibriVox catalog id 87. Direct MP3 of the first chapter, trimmed to ~45s.
- **Spanish** — *Don Quijote de la Mancha (Volumen 1)* by Miguel de Cervantes. LibriVox catalog id 4012. First 45s of chapter 1.
- **French** — *Les Trois Mousquetaires* by Alexandre Dumas. LibriVox catalog id 9477. First 45s of chapter 1.

If any of those URLs 404 at fetch time, fall back to other LibriVox titles in the same languages — record exactly which excerpt was used in `SampleAudio.json`.

- [ ] **Step 2: Write the fetch script**

```python
#!/usr/bin/env python3
"""Fetch and trim 3 LibriVox excerpts for bundling as sample audio.

Each excerpt is trimmed to ~45 seconds. Metadata (author, narrator, source URL,
license) is written to SampleAudio.json alongside the MP3s.

Requires: ffmpeg on PATH. Run from repo root.
"""

import json
import subprocess
import urllib.request
from pathlib import Path

OUT_DIR = Path(__file__).resolve().parent.parent / "ShadowingApp" / "Resources" / "SampleAudio"
META_PATH = OUT_DIR.parent / "SampleAudio.json"

EXCERPTS = [
    {
        "filename": "english-pride-and-prejudice.mp3",
        "title": "Pride and Prejudice — Opening",
        "language": "English",
        "author": "Jane Austen",
        "narrator": "Karen Savage",
        "source_url": "https://www.archive.org/download/pride_prejudice_0711_librivox/prideprejudice_01_austen_64kb.mp3",
        "duration_seconds": 45,
    },
    {
        "filename": "spanish-don-quijote.mp3",
        "title": "Don Quijote — Capítulo 1",
        "language": "Spanish",
        "author": "Miguel de Cervantes",
        "narrator": "LibriVox volunteers",
        "source_url": "https://www.archive.org/download/don_quijote_mancha_1_0809_librivox/donquijote1_01_cervantes_64kb.mp3",
        "duration_seconds": 45,
    },
    {
        "filename": "french-trois-mousquetaires.mp3",
        "title": "Les Trois Mousquetaires — Chapitre 1",
        "language": "French",
        "author": "Alexandre Dumas",
        "narrator": "LibriVox volunteers",
        "source_url": "https://www.archive.org/download/trois_mousquetaires_1306_librivox/troismousquetaires_01_dumas_64kb.mp3",
        "duration_seconds": 45,
    },
]


def fetch(url: str, dest: Path) -> None:
    print(f"Downloading {url}")
    urllib.request.urlretrieve(url, dest)


def trim(src: Path, dest: Path, seconds: int) -> None:
    print(f"Trimming {src.name} -> {seconds}s")
    subprocess.run(
        ["ffmpeg", "-y", "-i", str(src), "-t", str(seconds),
         "-acodec", "libmp3lame", "-ab", "96k", str(dest)],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    tmp = OUT_DIR / "_raw"
    tmp.mkdir(exist_ok=True)

    metadata = []
    for excerpt in EXCERPTS:
        raw = tmp / ("raw-" + excerpt["filename"])
        trimmed = OUT_DIR / excerpt["filename"]
        if not raw.exists():
            fetch(excerpt["source_url"], raw)
        trim(raw, trimmed, excerpt["duration_seconds"])
        metadata.append({k: v for k, v in excerpt.items() if k != "source_url"} | {
            "source_url": excerpt["source_url"],
            "license": "Public Domain (LibriVox)",
        })

    META_PATH.write_text(json.dumps({"samples": metadata}, indent=2) + "\n")
    print(f"Wrote {META_PATH}")
    # Cleanup raw downloads
    for f in tmp.iterdir():
        f.unlink()
    tmp.rmdir()


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Run the script**

```bash
cd /Users/samyu/Downloads/code/playground/shadowing-app
python3 scripts/fetch_librivox_samples.py
```

Expected: three MP3 files in `ShadowingApp/Resources/SampleAudio/`, ~500–700 KB each, plus `SampleAudio.json` listing them.

If a URL 404s, edit the script's `EXCERPTS` list with a working LibriVox URL (browse https://librivox.org for alternates) and re-run.

Verify file sizes are reasonable (less than 1 MB each). If any are larger, lower the `-ab 96k` bitrate to 64k in the trim step.

- [ ] **Step 4: Verify the audio**

```bash
ls -lh ShadowingApp/Resources/SampleAudio/
afplay ShadowingApp/Resources/SampleAudio/english-pride-and-prejudice.mp3 &
sleep 5
killall afplay
```

Confirm: clear narration, ~45s each, no clipping or noise.

- [ ] **Step 5: Add Resources to project.yml**

In `project.yml`, modify the `ShadowingApp` target's `sources:` to include the resources folder. Resources directories are picked up automatically when listed as sources, but Xcode treats `.json` and `.mp3` differently from `.swift` — they go into the bundle as resources.

The cleanest way: add a top-level `sources` entry that includes the `Resources/` folder explicitly. xcodegen will auto-classify file types.

```yaml
  ShadowingApp:
    type: application
    platform: iOS
    sources:
      - path: ShadowingApp
    # ... rest unchanged
```

`ShadowingApp/Resources/` is already inside the existing path-globbed source. Just confirm xcodegen picks it up after `xcodegen generate`.

- [ ] **Step 6: Regenerate, build, run tests**

```bash
xcodegen generate
xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED. The MP3s should be embedded in the app bundle's Resources directory.

Verify: after build, look at `~/Library/Developer/Xcode/DerivedData/ShadowingApp-*/Build/Products/Debug-iphonesimulator/ShadowingApp.app/` — the MP3s should be at the top level or within a `SampleAudio/` subfolder.

- [ ] **Step 7: Commit**

```bash
git add scripts/fetch_librivox_samples.py \
        ShadowingApp/Resources/SampleAudio/ \
        ShadowingApp/Resources/SampleAudio.json \
        ShadowingApp.xcodeproj/project.pbxproj
git commit -m "feat: bundle LibriVox public domain audio samples"
```

(If `project.yml` didn't actually change because the `Resources/` path was already inside the globbed `ShadowingApp` source, that's fine — only commit it if you modified it.)

---

## Task 2: BundledLibrary service (TDD)

**Files:**
- Create: `ShadowingApp/Services/BundledLibrary.swift`
- Create: `ShadowingAppTests/BundledLibraryTests.swift`

The service exposes the bundled MP3s as `[Track]` records using a fixed `folderID` so they integrate with the existing `PlayerStore` and `LibrarySnapshot` unchanged.

- [ ] **Step 1: Write failing tests**

```swift
// ShadowingAppTests/BundledLibraryTests.swift
import XCTest
@testable import ShadowingApp

final class BundledLibraryTests: XCTestCase {
    func test_tracks_returnsBundledMP3s() {
        let tracks = BundledLibrary.tracks()
        XCTAssertGreaterThanOrEqual(tracks.count, 3)
        XCTAssertTrue(tracks.allSatisfy { $0.folderID == BundledLibrary.folderID })
        XCTAssertTrue(tracks.allSatisfy { $0.url.pathExtension.lowercased() == "mp3" })
    }

    func test_tracks_haveStableIDs() {
        let tracks = BundledLibrary.tracks()
        let ids = Set(tracks.map(\.stableID))
        XCTAssertEqual(ids.count, tracks.count, "All bundled tracks should have unique stable IDs")
    }

    func test_folderID_isStableAcrossCalls() {
        XCTAssertEqual(BundledLibrary.folderID, BundledLibrary.folderID)
    }

    func test_folderName_isLocalized() {
        XCTAssertEqual(BundledLibrary.folderName, "Sample Library")
    }
}
```

- [ ] **Step 2: Run, confirm fails**

Compile error — `BundledLibrary` not defined.

- [ ] **Step 3: Implement BundledLibrary**

```swift
// ShadowingApp/Services/BundledLibrary.swift
import Foundation

enum BundledLibrary {
    /// Fixed UUID so the synthetic folder always has the same ID across launches.
    /// Stable IDs for resume positions remain consistent.
    static let folderID = UUID(uuidString: "00000000-0000-0000-0000-53414d504c45")!

    static let folderName = "Sample Library"

    static func tracks() -> [Track] {
        let bundle = Bundle.main
        guard let resourceURL = bundle.resourceURL else { return [] }
        let sampleDir = resourceURL.appendingPathComponent("SampleAudio")
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: sampleDir,
                                                          includingPropertiesForKeys: nil)
        else { return [] }

        return contents
            .filter { $0.pathExtension.lowercased() == "mp3" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { url in
                Track(
                    folderID: folderID,
                    relativePath: url.lastPathComponent,
                    url: url
                )
            }
    }
}
```

- [ ] **Step 4: Run tests, confirm pass**

32 + 4 = 36 tests should pass.

- [ ] **Step 5: Commit**

```bash
git add ShadowingApp/Services/BundledLibrary.swift \
        ShadowingAppTests/BundledLibraryTests.swift \
        ShadowingApp.xcodeproj/project.pbxproj
git commit -m "feat: add BundledLibrary service for in-bundle sample audio"
```

---

## Task 3: Library tab integration

**Files:**
- Modify: `ShadowingApp/Views/Library/LibraryView.swift`

Add a "Try Sample Library" CTA to the empty state, and make the bundled folder appear as a section alongside user-added folders.

- [ ] **Step 1: Add the bundled section to `rescan`**

Read the current `rescan()` body. After the loop that iterates over user bookmarks, prepend a synthetic section for the bundled library:

```swift
private func rescan() {
    var newSections: [LibrarySection] = []
    var newActiveURLs: [UUID: URL] = [:]

    // Bundled samples — always present.
    let bundledTracks = BundledLibrary.tracks()
    if !bundledTracks.isEmpty {
        newSections.append(LibrarySection(
            id: BundledLibrary.folderID,
            name: BundledLibrary.folderName,
            tracks: bundledTracks
        ))
    }

    // User-added folders (existing logic unchanged below).
    for bookmark in bookmarks.all() {
        // ... existing logic ...
    }

    // ... rest of rescan unchanged
    librarySnapshot.update(newSections.flatMap(\.tracks))
}
```

The bundled section appears first in the list. Users can scroll past it to their own folders.

- [ ] **Step 2: Add the empty-state CTA**

The existing empty state shows when `bookmarks.all().isEmpty`. With bundled tracks, that branch never renders if we always show bundled samples. So instead: when `bookmarks.all().isEmpty` AND we have bundled samples, show a one-liner above the list explaining the user can pick their own folder.

Simpler approach: just remove the empty-state branch entirely (since the list is never empty now, thanks to bundled samples). Add a footer or similar that says "Add your own MP3 folder via the gear icon."

Concretely, replace the existing `if bookmarks.all().isEmpty { ... } else if sections.isEmpty { ... } else { List { ... } }` chain with:

```swift
List {
    ForEach(sections) { section in
        Section {
            ForEach(section.tracks) { track in
                TrackRow(track: track) {
                    player.play(queue: section.tracks,
                                startIndex: section.tracks.firstIndex(of: track) ?? 0)
                }
            }
        } header: {
            FolderSectionHeader(
                folderName: section.name,
                onPlay: { player.playFolder(section.tracks, shuffled: false) },
                onShuffle: { player.playFolder(section.tracks, shuffled: true) }
            )
        }
    }
    if bookmarks.all().isEmpty {
        Section {
            Button {
                showFirstPicker = true
            } label: {
                Label("Add your own MP3 folder", systemImage: "folder.badge.plus")
            }
        } footer: {
            Text("Add a folder from iCloud Drive or Files to bring in your own audio.")
        }
    }
}
.listStyle(.plain)
```

This shows bundled tracks always, plus a "+" CTA when the user hasn't added any folders yet.

- [ ] **Step 3: Build & test**

```bash
xcodegen generate
xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -10
```

36 tests pass.

- [ ] **Step 4: Manual verify in simulator**

```bash
xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/ShadowingApp-*/Build/Products/Debug-iphonesimulator/ShadowingApp.app
xcrun simctl launch booted com.yudataguy.ShadowingApp
```

Verify the Library tab shows the "Sample Library" section with three tracks. Tap one → it should play.

- [ ] **Step 5: Commit**

```bash
git add ShadowingApp/Views/Library/LibraryView.swift \
        ShadowingApp.xcodeproj/project.pbxproj
git commit -m "feat: always-visible Sample Library in Library tab"
```

---

## Task 4: First-launch onboarding sheet

**Files:**
- Create: `ShadowingApp/Views/Onboarding/OnboardingSheet.swift`
- Modify: `ShadowingApp/Views/RootView.swift`
- Modify: `ShadowingApp/Services/PreferencesStore.swift` (add `hasSeenOnboarding`)

- [ ] **Step 1: Add `hasSeenOnboarding` to PreferencesStore**

```swift
// in ShadowingApp/Services/PreferencesStore.swift
var hasSeenOnboarding: Bool {
    get { defaults.bool(forKey: "hasSeenOnboarding") }
    set { defaults.set(newValue, forKey: "hasSeenOnboarding") }
}
```

- [ ] **Step 2: Build OnboardingSheet**

```swift
// ShadowingApp/Views/Onboarding/OnboardingSheet.swift
import SwiftUI

struct OnboardingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(
                    colors: [Color(red: 0.39, green: 0.40, blue: 0.95),
                             Color(red: 0.02, green: 0.71, blue: 0.83)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            VStack(spacing: 8) {
                Text("Welcome to Shadowing")
                    .font(.largeTitle.weight(.semibold))
                Text("Practice languages by listening and repeating.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 20) {
                bullet(icon: "ear", text: "Listen to native audio at adjustable speeds")
                bullet(icon: "folder.badge.plus", text: "Add your own MP3 folders from iCloud Drive")
                bullet(icon: "rectangle.stack", text: "Save tracks to playlists for daily practice")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                onContinue()
                dismiss()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    private func bullet(icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            Text(text)
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}
```

- [ ] **Step 3: Wire it from RootView**

In `RootView`:

```swift
@State private var showOnboarding: Bool = false

// in body, after .alert(...):
.sheet(isPresented: $showOnboarding) {
    OnboardingSheet(onContinue: {
        let prefs = PreferencesStore()
        prefs.hasSeenOnboarding = true
    })
    .interactiveDismissDisabled()
}

// in .task or a new .onAppear, decide whether to show:
.task {
    let prefs = PreferencesStore()
    if !prefs.hasSeenOnboarding {
        showOnboarding = true
    }
    handleWidgetHandoff()
}
```

`PreferencesStore` is currently passed via `PlayerStore`'s init; you can also instantiate a local one inside `RootView` for the onboarding read since `PreferencesStore` is a stateless wrapper around `UserDefaults.standard` — no shared state concerns.

- [ ] **Step 4: Build & test**

```bash
xcodegen generate
xcodebuild ... test
```

36 tests still pass (no new tests; onboarding is UI-driven).

- [ ] **Step 5: Manually verify**

Reset the simulator's app data:
```bash
xcrun simctl uninstall booted com.yudataguy.ShadowingApp
```
Then build & launch. The onboarding should appear on first launch and not appear on subsequent launches after Continue is tapped.

- [ ] **Step 6: Commit**

```bash
git add ShadowingApp/Views/Onboarding/ \
        ShadowingApp/Views/RootView.swift \
        ShadowingApp/Services/PreferencesStore.swift \
        ShadowingApp.xcodeproj/project.pbxproj
git commit -m "feat: first-launch onboarding sheet"
```

---

## Task 5: Privacy manifest + version bump

**Files:**
- Create: `ShadowingApp/PrivacyInfo.xcprivacy`
- Modify: `project.yml` (set MARKETING_VERSION + CURRENT_PROJECT_VERSION)

- [ ] **Step 1: Write the privacy manifest**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

Reasoning:
- `CA92.1` — UserDefaults access for app's own functionality (we read/write our own keys for preferences and folder bookmarks).
- `C617.1` — File timestamp access for files within the app's container (we use FileManager enumeration on user-picked folders).

Save as `ShadowingApp/PrivacyInfo.xcprivacy`.

- [ ] **Step 2: Set version + build**

In `project.yml`, in `ShadowingApp` target's `settings.base`:

```yaml
        MARKETING_VERSION: "1.0.0"
        CURRENT_PROJECT_VERSION: "1"
```

- [ ] **Step 3: Build & verify**

```bash
xcodegen generate
xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

Verify the privacy manifest is in the bundle:
```bash
ls ~/Library/Developer/Xcode/DerivedData/ShadowingApp-*/Build/Products/Debug-iphonesimulator/ShadowingApp.app/PrivacyInfo.xcprivacy
```

Should exist.

- [ ] **Step 4: Run tests**

36 tests pass.

- [ ] **Step 5: Commit**

```bash
git add ShadowingApp/PrivacyInfo.xcprivacy \
        project.yml \
        ShadowingApp.xcodeproj/project.pbxproj
git commit -m "feat: add privacy manifest and 1.0.0 version stamps"
```

---

## Task 6: Privacy policy + GitHub Pages setup

**Files:**
- Create: `docs/privacy-policy.md`
- Create: `docs/_config.yml` (GitHub Pages config)
- Modify: README (add link to policy)

- [ ] **Step 1: Write the privacy policy**

```markdown
# Privacy Policy for Shadowing

**Last updated:** 2026-05-08

## Summary

Shadowing is a personal language-shadowing app. **It does not collect, track, or transmit any of your data.** Everything you do in the app stays on your device or, if you use iCloud Drive, in your own iCloud storage.

## What we do not collect

- Personal identifiers (no accounts, no email, no phone number).
- Usage analytics (no tracking pixels, no SDKs that report usage).
- Crash reports (none beyond what Apple itself collects per your iOS settings).
- Audio content (your MP3s never leave your device or iCloud Drive).

## Data the app stores locally

- **Folder bookmarks**: when you pick a folder via the Files app, iOS gives the app a security-scoped bookmark. We store this in `UserDefaults` so we can re-read your folder on subsequent launches. It contains a path reference; nothing is uploaded.
- **Playlists**: the playlists you create are stored on-device using SwiftData. They live in your app's sandbox and the App Group container.
- **Playback positions**: how far you've played each track is saved on-device so we can resume where you left off.
- **Preferences**: playback speed, loop mode, shuffle toggle, and a flag indicating whether you've seen the onboarding screen.

## Data shared with Apple

The app uses Apple's MediaPlayer framework to surface the currently-playing track on the lock screen and in Control Center. The track title is sent to Apple's iOS daemon for display purposes only; it is not retained by Apple beyond standard system behavior.

## Children

The app contains no advertising, analytics, or content unsuitable for children. It is rated 4+.

## Third-party content

The app bundles a small number of public-domain audio excerpts from LibriVox (https://librivox.org). These are credited in the app and remain in the public domain.

## Contact

For questions about this policy, contact: [your-contact-here]

## Changes

If we ever change this policy, the updated version will be posted at this URL with an updated "Last updated" date.
```

(Replace `[your-contact-here]` with the user's preferred contact during the implementation step. If they don't have one, default to a placeholder GitHub Issues URL.)

- [ ] **Step 2: Configure GitHub Pages**

```yaml
# docs/_config.yml
title: Shadowing
description: Documentation and privacy policy for the Shadowing iOS app.
theme: jekyll-theme-cayman
```

- [ ] **Step 3: Add a top-level README link**

If a `README.md` exists at the repo root, add to it:

```markdown
## Privacy

See the [privacy policy](docs/privacy-policy.md).
```

If no README exists, create a minimal one:

```markdown
# Shadowing

A personal iOS app for language-shadowing practice.

## Privacy

See the [privacy policy](docs/privacy-policy.md).
```

- [ ] **Step 4: Commit**

```bash
git add docs/privacy-policy.md docs/_config.yml README.md
git commit -m "docs: privacy policy and GitHub Pages config"
```

(The user will push to GitHub and enable Pages in the repo settings as part of Task 9.)

---

## Task 7: App Store marketing copy

**Files:**
- Create: `docs/app-store/marketing.md`

- [ ] **Step 1: Write the marketing copy**

```markdown
# App Store Marketing Copy

Copy-paste these into App Store Connect → App Store → 1.0 Prepare for Submission.

## App name (30 char max)

Shadowing

## Subtitle (30 char max)

Language Shadowing Practice

## Promotional Text (170 char max)

A focused tool for language-shadowing practice. Listen at adjustable speeds, build playlists, resume anywhere — all on-device, with your own MP3s or built-in samples.

## Description (4000 char max)

Shadowing is a focused, no-frills audio player for language-shadowing practice — the technique of listening to native speech and repeating it out loud to build pronunciation, rhythm, and intonation.

The app is built around three things:

• Use your own MP3s. Drop a folder of audio into iCloud Drive on your computer; the app reads it directly on your iPhone. No uploads, no accounts, no servers.

• Practice at your pace. Choose playback speeds from 0.5× to 2.0×. Loop a track or a whole playlist. Skip back 15 seconds with one tap.

• Stay focused. The app does one thing — play audio for shadowing — without distractions. No ads, no analytics, no social features.

WHAT'S INCLUDED

• Bundled sample audio in three languages (English, Spanish, French) so you can try the app immediately without setup. All public-domain recordings from LibriVox.

• Playlists you can reorder, rename, and add to with a swipe.

• Resume playback exactly where you left off, on every track.

• Background audio with full lock-screen and Control Center support.

• Two home-screen widgets: a 4-tile recent-playlists view and a small one-tap favorite-playlist tile.

PRIVACY

The app does not collect, track, or transmit any user data. All playlists, preferences, and playback state are stored on your device. Audio content from your folders stays in your iCloud Drive — the app never uploads it. See the privacy policy at: [policy URL]

WHO IT'S FOR

Language learners practicing shadowing. Anyone who wants a clean, fast way to play a focused set of MP3s — podcasts, audiobook excerpts, pronunciation drills, dialogue clips — without an algorithmic library shoving content at them.

## Keywords (100 char max, comma-separated)

shadowing, language, learning, practice, audio, mp3, pronunciation, speech, repeat, focus

## Category

Primary: Education
Secondary: Music

## Age Rating

4+

## Copyright

© 2026 [Your Name]

## Support URL

https://github.com/[your-username]/shadowing-app/issues

## Marketing URL (optional)

https://[your-username].github.io/shadowing-app/

## Privacy Policy URL

https://[your-username].github.io/shadowing-app/privacy-policy

## What's New in This Version (170 char max)

Initial release.
```

- [ ] **Step 2: Commit**

```bash
git add docs/app-store/marketing.md
git commit -m "docs: App Store marketing copy"
```

---

## Task 8: Screenshots + archive script

**Files:**
- Create: `scripts/take_screenshots.sh`
- Create: `scripts/archive.sh`
- Create: `docs/app-store/screenshots/` (populated at runtime)

- [ ] **Step 1: Write the archive script**

```bash
#!/usr/bin/env bash
# scripts/archive.sh — produce a Release archive ready for App Store upload.
# Run from repo root.
set -euo pipefail

ARCHIVE_PATH="build/Shadowing.xcarchive"
EXPORT_PATH="build/export"

mkdir -p build
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

xcodebuild archive \
  -project ShadowingApp.xcodeproj \
  -scheme ShadowingApp \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Automatic

echo
echo "Archive created at: $ARCHIVE_PATH"
echo
echo "Next steps:"
echo "  1. Open Xcode → Window → Organizer"
echo "  2. Select the new archive → Distribute App → App Store Connect → Upload"
echo "  3. Xcode handles certificate and 2FA prompts"
```

```bash
chmod +x scripts/archive.sh
```

- [ ] **Step 2: Write the screenshot script**

```bash
#!/usr/bin/env bash
# scripts/take_screenshots.sh — capture App Store screenshots from the iPhone 17 simulator.
# Run from repo root. The simulator must be booted with the app installed.
set -euo pipefail

OUT_DIR="docs/app-store/screenshots"
mkdir -p "$OUT_DIR"

echo "Boot the iPhone 17 simulator and install the latest build:"
echo
echo "  xcrun simctl boot 'iPhone 17' || true"
echo "  xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp \\"
echo "    -destination 'platform=iOS Simulator,name=iPhone 17' build"
echo "  xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/ShadowingApp-*/Build/Products/Debug-iphonesimulator/ShadowingApp.app"
echo "  xcrun simctl launch booted com.yudataguy.ShadowingApp"
echo
echo "Then drive the app manually to each of these screens, and after each one,"
echo "press [Enter] in this terminal to capture a screenshot:"
echo
echo "  1. Library tab showing the Sample Library section"
echo "  2. Now Playing sheet (tap a track and let it play)"
echo "  3. Playlist detail view (with at least 2-3 tracks added)"
echo "  4. Playlists tab list"
echo "  5. Folders settings sheet (gear icon → folders)"
echo "  6. Onboarding sheet (uninstall + reinstall to reset)"
echo

names=(
  "01-library-with-samples"
  "02-now-playing"
  "03-playlist-detail"
  "04-playlists-list"
  "05-folders-settings"
  "06-onboarding"
)

for name in "${names[@]}"; do
  read -p "Ready for $name? Press [Enter] to capture..." _
  xcrun simctl io booted screenshot "$OUT_DIR/$name.png"
  echo "  -> $OUT_DIR/$name.png"
done

echo
echo "All 6 screenshots saved to $OUT_DIR/"
echo "Inspect them and re-run individual captures if needed."
```

```bash
chmod +x scripts/take_screenshots.sh
```

- [ ] **Step 3: Commit the scripts (don't run them yet)**

```bash
git add scripts/archive.sh scripts/take_screenshots.sh
git commit -m "scripts: archive and screenshot capture for App Store submission"
```

The actual screenshot capture happens during Task 9's manual checklist run.

---

## Task 9: Submission checklist + dry-run

**Files:**
- Create: `docs/app-store/SUBMISSION_CHECKLIST.md`

This task is mostly user-driven. We document the steps and run the local dry-run (archive build + manual validation).

- [ ] **Step 1: Write the submission checklist**

```markdown
# App Store Submission Checklist

Step-by-step from current state (everything code-side is ready; nothing has been uploaded) to "Submitted for Review".

## Phase 1: Apple Developer enrollment ($99/year)

- [ ] Visit https://developer.apple.com/programs/enroll/
- [ ] Sign in with the Apple ID you want to use as the developer
- [ ] Complete enrollment (individual is fine; company requires DUNS lookup)
- [ ] Pay the $99 fee
- [ ] Wait for confirmation email (usually 24–48 hours)

## Phase 2: Local repo cleanup

- [ ] If the repo isn't already on GitHub, create a public repo at
  https://github.com/new (name suggestion: `shadowing-app`)
- [ ] `git remote add origin https://github.com/<your-username>/shadowing-app.git`
- [ ] `git push -u origin feat/initial-build` (or merge to main first)
- [ ] In the repo's GitHub Settings → Pages, set Source = "Deploy from branch", Branch = `main`, Folder = `/docs`
- [ ] Verify the policy renders at `https://<your-username>.github.io/shadowing-app/privacy-policy`

## Phase 3: Update marketing copy with your URLs

- [ ] Edit `docs/app-store/marketing.md` — replace `[your-username]` placeholders with your GitHub username and any contact info.
- [ ] Edit `docs/privacy-policy.md` — replace `[your-contact-here]` with a real email or GitHub Issues URL.
- [ ] Commit & push.

## Phase 4: ASC app record

- [ ] Sign in to https://appstoreconnect.apple.com
- [ ] Apps → My Apps → "+" → New App
- [ ] Platform: iOS. Name: Shadowing. Primary language: English (U.S.).
  Bundle ID: `com.yudataguy.ShadowingApp` (must match `project.yml`).
  SKU: `SHADOWING-001` (any unique string).
- [ ] Save.

## Phase 5: Build the archive

- [ ] In Xcode → Settings → Accounts, confirm your developer team is selected.
- [ ] Run from terminal: `./scripts/archive.sh`
- [ ] On success, the archive is at `build/Shadowing.xcarchive`.

## Phase 6: Validate + upload

- [ ] Open Xcode → Window → Organizer → Archives.
- [ ] Select the new archive.
- [ ] Click "Validate App" first — catches signing/entitlement errors before upload.
- [ ] Once validation passes, click "Distribute App" → "App Store Connect" → "Upload".
- [ ] Xcode prompts for signing identity and 2FA. Approve on your other Apple device.
- [ ] Wait 5–30 minutes for ASC to process the upload (you'll receive an email when done).

## Phase 7: ASC metadata

- [ ] In ASC → your app → 1.0 Prepare for Submission, fill in:
  - App Information: Subtitle, Categories (Education / Music), Content Rights (does it contain third-party content? Yes — LibriVox public domain).
  - Pricing & Availability: Free, all territories.
  - App Privacy: declare "Data Not Collected" — the privacy manifest backs this up.
  - 1.0 Version Information: paste from `docs/app-store/marketing.md`.
  - Screenshots: drag the PNGs from `docs/app-store/screenshots/` (you'll generate these in Phase 8).
  - Build: select the build that finished processing in Phase 6.

## Phase 8: Take screenshots

- [ ] Boot iPhone 17 simulator: `xcrun simctl boot 'iPhone 17' && open -a Simulator`
- [ ] Build & install:
  ```
  xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp \
    -destination 'platform=iOS Simulator,name=iPhone 17' build
  xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/ShadowingApp-*/Build/Products/Debug-iphonesimulator/ShadowingApp.app
  ```
- [ ] Run `./scripts/take_screenshots.sh` and follow its prompts.
- [ ] Inspect the 6 PNGs in `docs/app-store/screenshots/`. Re-do any that look bad.
- [ ] Drag PNGs into the ASC screenshots area for the 6.7" iPhone size.

## Phase 9: Submit

- [ ] Click "Save" then "Add for Review" then "Submit for Review".
- [ ] Wait. App Review typically takes 24h–7 days.
- [ ] If rejected, read the feedback carefully, address the issues, increment `CURRENT_PROJECT_VERSION` (1 → 2 → ...), re-run `./scripts/archive.sh`, re-upload, re-submit.

## Common rejection reasons (and what we've already mitigated)

- "App lacks demonstrable functionality" → we bundle 3 LibriVox samples that play out of the box. Mitigated.
- "Insufficient privacy manifest" → we ship `PrivacyInfo.xcprivacy` declaring no tracking, no data collection. Mitigated.
- "Missing privacy policy URL" → we host on GitHub Pages. Mitigated when Phase 2 is complete.
- "Misleading metadata" → keep marketing copy honest and specific. Don't add features in copy that aren't in the app.
```

- [ ] **Step 2: Commit**

```bash
git add docs/app-store/SUBMISSION_CHECKLIST.md
git commit -m "docs: App Store submission checklist"
```

- [ ] **Step 3: Local dry-run — archive build**

```bash
./scripts/archive.sh
```

This will produce `build/Shadowing.xcarchive`. Even without a paid developer account, the archive command should succeed (it'll sign with whatever team is currently selected; the upload step is what blocks on paid enrollment).

If the archive build fails, capture the error and address it before proceeding. Common failures:
- Missing development team → set in Xcode → Settings → Accounts.
- Bitcode-related warnings → ignore (Bitcode is deprecated and not relevant).
- Provisioning profile mismatch → re-sign in Xcode → Project → Signing & Capabilities.

- [ ] **Step 4: Local dry-run — Xcode Organizer validation**

In Xcode:
1. Window → Organizer → Archives → select the new one.
2. Click "Validate App".
3. Choose "App Store Connect" as the destination.
4. Walk through the wizard.

If validation passes, the archive is upload-ready. If validation fails, address the errors and re-run `./scripts/archive.sh`.

If the user has not yet enrolled in the paid Developer Program, validation may fail at the certificate step — that's expected. Document the error in this task's report and proceed.

- [ ] **Step 5: Final commit (if any fixes were made)**

```bash
git commit -am "chore: archive build adjustments from dry-run"
```

---

## Definition of Done

- 36 unit tests pass (32 baseline + 4 from BundledLibraryTests).
- `./scripts/archive.sh` produces a valid `.xcarchive`.
- Bundled sample audio plays in both simulator and physical-device builds.
- Onboarding sheet appears on first launch and not subsequent launches.
- Privacy manifest is bundled in the `.app`.
- All marketing/privacy/checklist docs are committed.
- The user has a clear, ordered submission checklist for the human-only Phase 1, 2, 4, 6, 7, 9 steps.
