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

For questions about this policy, please open an issue at the project's GitHub repository, or contact the developer via the support URL listed on the App Store page.

## Changes

If we ever change this policy, the updated version will be posted at this URL with an updated "Last updated" date.
