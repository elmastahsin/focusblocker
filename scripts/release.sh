#!/bin/bash
# Builds, signs (Developer ID), notarizes and staples FocusBlocker, then prints the zip's sha256.
# Requires: Developer ID Application certificate and `xcrun notarytool store-credentials focusblocker-notary`.
set -euo pipefail

cd "$(dirname "$0")/.."
PROFILE="${NOTARY_PROFILE:-focusblocker-notary}"
ARCHIVE=build/FocusBlocker.xcarchive
EXPORT=build/export
ZIP=build/FocusBlocker.app.zip

rm -rf build
xcodebuild archive -project FocusBlocker.xcodeproj -scheme FocusBlocker -configuration Release \
    -archivePath "$ARCHIVE"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportOptionsPlist Config/ExportOptions.plist -exportPath "$EXPORT"

ditto -c -k --keepParent "$EXPORT/FocusBlocker.app" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$EXPORT/FocusBlocker.app"

rm "$ZIP"
ditto -c -k --keepParent "$EXPORT/FocusBlocker.app" "$ZIP"
shasum -a 256 "$ZIP"
