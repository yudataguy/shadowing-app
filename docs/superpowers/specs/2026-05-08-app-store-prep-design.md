# App Store Submission Prep — Design Spec

**Date:** 2026-05-08
**Status:** Draft for review

## Purpose

Prepare the Shadowing app for submission to the Apple App Store. Two distinct streams of work: (1) code/UX changes that make the app reviewable by Apple, and (2) submission artifacts (privacy manifest, marketing copy, privacy policy, screenshots, archive build command).

## Goals

- The app passes Apple's first review pass without rejection due to "no usable content" or missing standard metadata.
- A first-time user (including the App Reviewer) can experience the app's value within 30 seconds without any external setup.
- All non-human submission artifacts (privacy manifest, marketing copy, privacy policy, build script) are version-controlled in the repo.
- Clear, ordered submission checklist for the human-only steps (paying for Developer Program, ASC enrollment, archive upload, metadata entry, submission).

## Non-Goals (v1)

- Building a backend, account system, or paid features.
- Streaming integration with Apple Music, Spotify, or any service.
- iPad-specific layout polish (universal target stays as-is).
- Localization of metadata (English only for v1).
- TestFlight beta testing prior to submission.

## Streams

### Stream A — Reviewer-friendly app changes

#### A1. Bundled sample library
- Bundle 3 short (30–60s each) LibriVox excerpts — public domain audiobook clips — into the app.
- Files live in a non-iCloud location (the app bundle), accessible without a security-scoped resource.
- A new `BundledLibrary` service exposes the samples as `[Track]` records with a synthetic `folderID` (a fixed UUID constant), so they integrate with the existing PlayerStore unchanged.
- Languages: pick a mix relevant to language-learning shadowing — likely Spanish, French, English. Concrete excerpt selection happens in the implementation step.
- Audio source: `https://librivox.org` direct downloads. License: public domain. Attribution displayed in the app's onboarding / About area as a courtesy and best practice.

#### A2. Sample library entry point
- The Library tab's empty state ("No MP3 folder yet") gains a second button: **"Try the Sample Library"**.
- Tapping it loads the bundled tracks into the library — they appear as their own folder section ("Sample Library") alongside any user-added folders.
- The bundled folder behaves like any other: tracks tappable, addable to playlists, included in the Library scan output.
- The bundled folder is always present in the Library tab — even after the user adds their own iCloud folders. They can play / shuffle / add to playlist from the samples just like real folders.

#### A3. Onboarding screen
- First-launch only: a single-screen modal explaining what shadowing is and how the app works.
- Three short bullets: "Listen and repeat", "Add your own MP3s from Files / iCloud Drive", "Adjust speed for harder sections".
- Dismissed via a Continue button. State persisted in `UserDefaults` (`hasSeenOnboarding: Bool`).
- Reviewer benefit: makes the app's purpose clear within 5 seconds of opening.

### Stream B — Submission artifacts

#### B1. Privacy manifest (`PrivacyInfo.xcprivacy`)
- iOS-required since May 2024 for app submissions.
- Declares: no tracking, no required-reason API beyond `UserDefaults` (declare reason `CA92.1` — "Access info from same app, per documentation"), no third-party SDKs.
- File path: `ShadowingApp/PrivacyInfo.xcprivacy`. Auto-bundled by Xcode when present in target sources.

#### B2. Build configuration for Release
- `MARKETING_VERSION: 1.0.0`, `CURRENT_PROJECT_VERSION: 1` (build number).
- `SWIFT_OPTIMIZATION_LEVEL: -O` for Release (default; verify via xcodebuild output).
- `STRIP_INSTALLED_PRODUCT: YES` for Release.
- Distribution-ready `CODE_SIGN_STYLE` remains `Automatic`; user's developer team handles provisioning at archive time.
- No new entitlements beyond what's already in place.

#### B3. Archive build command
- A documented `xcodebuild archive` + `xcodebuild -exportArchive` invocation that produces a signed `.ipa` ready for Xcode Organizer upload.
- Captured in `scripts/archive.sh` (a one-line wrapper) so future releases are reproducible.
- Note: the actual upload to App Store Connect goes through Xcode Organizer's UI for first-time submissions because it handles certificate prompts and 2FA.

#### B4. Marketing copy
- App Store name: "Shadowing"
- Subtitle (30 chars max): "Language Shadowing Practice"
- Promotional text (170 chars max): one-liner about what's new, refreshed per release.
- Description (4000 chars): paragraphs covering what shadowing is, what the app does, who it's for, key features, sample content disclosure.
- Keywords (100 chars max, comma-separated): "shadowing, language, learning, practice, audio, mp3, pronunciation, speech, repeat, ab loop"
- Category (primary): Education. Secondary: Music.
- Age rating: 4+ (no objectionable content).
- Support URL, marketing URL: GitHub repo or GitHub Pages site.

All copy stored in `docs/app-store/marketing.md` for the user to copy-paste into ASC.

#### B5. Privacy policy
- Plain-language privacy policy declaring: no tracking, no analytics, no data leaves the device, all storage is local (or via the user's iCloud Drive for audio).
- Hosted on GitHub Pages from the same repo. Path: `docs/privacy-policy.md` rendered via a `gh-pages` branch or the `docs/` folder served by Pages.
- Stored in the repo so updates are git-tracked.

#### B6. Screenshots
- Required sizes for App Store as of 2026: 6.7" iPhone (1290×2796), 6.5" iPhone (1242×2688), 5.5" iPhone (1242×2208). At least one of the largest is required; supplying all three is recommended.
- Capture strategy: use the iPhone 17 simulator (iOS 26.3) for the 6.7" set; xcrun simctl screenshot saves PNGs at native resolution.
- Six screenshots planned: Library view, Now Playing sheet, Playlists detail, Folder picker / Settings, Sample Library being browsed, Widget on home screen.
- Stored in `docs/app-store/screenshots/` for re-use across submissions.

### Stream C — Submission checklist (human-only steps)

A `docs/app-store/SUBMISSION_CHECKLIST.md` covering:
1. Enroll in Apple Developer Program ($99/year).
2. In Xcode → Settings → Accounts, confirm developer team is selected.
3. Push privacy policy commit to a `gh-pages` branch (or the main branch with `docs/` source enabled).
4. Verify the policy URL renders on github.io.
5. In ASC: create app record (bundle id `com.yudataguy.ShadowingApp`, name "Shadowing", primary language English).
6. In ASC → App Privacy: declare data types (none collected) using the privacy manifest as the source of truth.
7. Run `scripts/archive.sh` — produces `build/Shadowing.xcarchive`.
8. Open Xcode → Window → Organizer → Archives → select archive → Distribute App → App Store Connect → Upload. Xcode handles signing + 2FA.
9. Wait 5–30 minutes for ASC processing.
10. In ASC → App Store → 1.0 Prepare for Submission: paste marketing copy from `docs/app-store/marketing.md`, upload screenshots, set category, age rating, copyright, etc.
11. Privacy policy URL (from step 4), support URL.
12. Save → Add for Review → Submit for Review.
13. Wait. Review can take 24h–7 days.

## Architecture

```
ShadowingApp/
  Resources/
    SampleAudio/           [+] LibriVox MP3 files (bundled)
    SampleAudio.json       [+] Metadata for samples (title, language, attribution)
  Services/
    BundledLibrary.swift   [+] Provides [Track] from the bundle
  Views/
    Library/
      LibraryView.swift    [m] Render bundled section + "Try Sample Library" CTA
    Onboarding/
      OnboardingSheet.swift [+] First-launch sheet
  PrivacyInfo.xcprivacy    [+] Privacy manifest
  ShadowingAppApp.swift    [m] Show onboarding sheet on first launch

scripts/
  fetch_librivox_samples.py [+] Downloads + trims excerpts from LibriVox
  archive.sh               [+] One-line release archive command

docs/
  privacy-policy.md        [+] Hosted via GitHub Pages
  app-store/
    marketing.md           [+] Copy-pasteable App Store metadata
    SUBMISSION_CHECKLIST.md [+] Step-by-step user instructions
    screenshots/           [+] Generated PNGs ready for upload
```

## Edge Cases

- **Reviewer plays samples and tries to add a folder.** Existing flow handles this. The bundled folder + user folders coexist.
- **User force-deletes the bundled folder.** Not allowed — it's not a `BookmarkStore` entry, just a synthetic folder injected into LibraryView. The "Folders" settings screen lists only user-added bookmarks.
- **iCloud Drive disabled on review device.** Bundled samples don't depend on iCloud. The "Pick Folder" flow shows an iOS-native error, but the app remains functional via samples.
- **App Review rejection.** The submission checklist's last item is "Iterate based on rejection feedback". We address whatever Apple flags and re-submit.
- **Bundle size.** Three 60s MP3s at ~96kbps ≈ 2.2 MB total. Negligible.

## Testing

### Unit tests
- `BundledLibraryTests` — verifies the service returns the expected number of tracks with valid bundle URLs.

### Manual tests
- Fresh install on simulator → verify onboarding sheet appears on first launch.
- Tap "Try Sample Library" → verify samples load and play.
- Add an iCloud folder → verify both bundle + user folder appear.
- Run the archive build → verify a `.xcarchive` is produced and opens in Organizer.
- Validate the archive (Xcode Organizer → Validate App) — catches most submission-time errors before upload.

## Open Questions

- **Specific LibriVox excerpts.** Need to pick 3 books / chapters. Suggested: a Spanish (Cervantes? Borges public domain isn't reliable, so something older like Don Quijote), a French (Antoine de Saint-Exupéry not yet PD universally — pick something else; maybe Maupassant), and an English (Sherlock Holmes works). Will finalize during implementation.
- **Apple Developer team registration.** User needs to confirm they will sign up for the paid program before we generate distribution provisioning artifacts.
- **GitHub repo state.** If the repo is currently local-only, we need to push to a public GitHub remote for the GitHub Pages hosting to work.

## Decisions Log

- **Bundle samples in the app rather than fetching at first launch.** Reviewer's network may be limited; bundled is reliable.
- **LibriVox over generated TTS.** Real human speech matches the shadowing use case; TTS feels artificial.
- **GitHub Pages for privacy policy.** Free, version-controlled, easy to update; standard pattern for indie iOS apps.
- **Sample library always-visible** rather than dismissable. Reduces UX surface; reviewer (and user) sees consistent content.
- **Onboarding is first-launch-only, not always-accessible.** Standard iOS pattern. A "Help" or "About" view could be added later if users ask, but YAGNI for v1.
- **English-only metadata.** Localization is meaningful work for marginal benefit at v1; can localize after first release lands.
