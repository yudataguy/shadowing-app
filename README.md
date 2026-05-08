# Shadowing

A focused iOS app for language-shadowing practice. Listen to native audio, adjust playback speed, build playlists, resume where you left off — all on-device with your own MP3s or built-in samples.

## Privacy

See the [privacy policy](docs/privacy-policy.md).

## Building from source

The Xcode project is generated from `project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
open ShadowingApp.xcodeproj
```

Minimum iOS deployment target: 17.0.

## License

Code: see LICENSE (if present) or contact the maintainer.
Bundled audio samples: public domain, sourced from [LibriVox](https://librivox.org).
