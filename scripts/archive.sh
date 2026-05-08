#!/usr/bin/env bash
# scripts/archive.sh — produce a Release archive ready for App Store upload.
# Run from repo root.
set -euo pipefail

ARCHIVE_PATH="build/Shadowing.xcarchive"

mkdir -p build
rm -rf "$ARCHIVE_PATH"

xcodebuild archive \
  -project ShadowingApp.xcodeproj \
  -scheme ShadowingApp \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic

echo
echo "Archive created at: $ARCHIVE_PATH"
echo
echo "Next steps:"
echo "  1. Open Xcode → Window → Organizer"
echo "  2. Select the new archive → Validate App (catches signing/entitlement issues)"
echo "  3. Once validation passes, Distribute App → App Store Connect → Upload"
echo "  4. Xcode handles signing identity prompts and 2FA on your other Apple device"
