#!/usr/bin/env bash
# scripts/take_screenshots.sh — capture App Store screenshots from the iPhone 17 simulator.
# Run from repo root with the simulator already booted and the app installed.
set -euo pipefail

OUT_DIR="docs/app-store/screenshots"
mkdir -p "$OUT_DIR"

cat <<'EOF'
Before running this script:

  1. Boot the simulator and install the app:
       xcrun simctl boot 'iPhone 17' || true
       open -a Simulator
       xcodebuild -project ShadowingApp.xcodeproj -scheme ShadowingApp \
         -destination 'platform=iOS Simulator,name=iPhone 17' build
       xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/ShadowingApp-*/Build/Products/Debug-iphonesimulator/ShadowingApp.app
       xcrun simctl launch booted com.yudataguy.ShadowingApp

  2. To force the onboarding sheet to appear again, uninstall first:
       xcrun simctl uninstall booted com.yudataguy.ShadowingApp

  3. Drive the app manually to each screen below. After arriving at each
     screen, press [Enter] in this terminal to capture.

EOF

names=(
  "01-library-with-samples"
  "02-now-playing"
  "03-playlist-detail"
  "04-playlists-list"
  "05-folders-settings"
  "06-onboarding"
)

for name in "${names[@]}"; do
  read -r -p "Ready for $name? Press [Enter] to capture (or s to skip): " key
  if [ "$key" = "s" ]; then
    echo "  -> skipped"
    continue
  fi
  xcrun simctl io booted screenshot "$OUT_DIR/$name.png"
  echo "  -> $OUT_DIR/$name.png"
done

echo
echo "All screenshots saved to $OUT_DIR/"
echo "Inspect them and re-run individual captures by relaunching this script with only the names you want."
