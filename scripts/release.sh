#!/bin/bash
# Builds, signs (Developer ID), notarizes and staples FocusBlocker, writes the Sparkle appcast,
# then prints the zip's sha256. Upload both build/FocusBlocker.app.zip and build/appcast.xml
# to the GitHub release tagged v<CFBundleShortVersionString>.
# Requires: Developer ID Application certificate, `xcrun notarytool store-credentials focusblocker-notary`
# and the Sparkle EdDSA private key in the login Keychain (created once with generate_keys).
set -euo pipefail

cd "$(dirname "$0")/.."
PROFILE="${NOTARY_PROFILE:-focusblocker-notary}"
ARCHIVE=build/FocusBlocker.xcarchive
EXPORT=build/export
ZIP=build/FocusBlocker.app.zip
PACKAGES=build/SourcePackages
SPARKLE_BIN="$PACKAGES/artifacts/sparkle/Sparkle/bin"
REPO_URL=https://github.com/elmastahsin/focusblocker

rm -rf build
xcodebuild archive -project FocusBlocker.xcodeproj -scheme FocusBlocker -configuration Release \
    -archivePath "$ARCHIVE" -clonedSourcePackagesDirPath "$PACKAGES"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportOptionsPlist Config/ExportOptions.plist -exportPath "$EXPORT"

ditto -c -k --keepParent "$EXPORT/FocusBlocker.app" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$EXPORT/FocusBlocker.app"

rm "$ZIP"
ditto -c -k --keepParent "$EXPORT/FocusBlocker.app" "$ZIP"

VERSION=$(defaults read "$PWD/$EXPORT/FocusBlocker.app/Contents/Info" CFBundleShortVersionString)
mkdir build/updates
cp "$ZIP" build/updates/
"$SPARKLE_BIN/generate_appcast" --download-url-prefix "$REPO_URL/releases/download/v$VERSION/" \
    -o build/appcast.xml build/updates

shasum -a 256 "$ZIP"
echo "Next: gh release create v$VERSION $ZIP build/appcast.xml"
