#!/bin/zsh
# Builds a signed App Store package in ~/Library/Developer/AshenBuild/export/AshenBuild.ipa
# (outside OneDrive on purpose: OneDrive locks freshly built files and export times out).
# With --upload it also sends the build to App Store Connect for TestFlight,
# using the Apple ID signed in to Xcode (Settings > Accounts).
#
# The archive is made unsigned and signed at export with the App Store profile,
# which needs no registered test devices.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="${ASHEN_BUILD_DIR:-$HOME/Library/Developer/AshenBuild}"
ARCHIVE="$OUT/AshenBuild.xcarchive"
mkdir -p "$OUT"
rm -rf "$ARCHIVE" "$OUT/export"

xcodebuild archive -project AshenBuild.xcodeproj -scheme AshenBuild -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO | grep -E "error:|ARCHIVE"

OPTIONS=AppStore/ExportOptions.plist
if [[ "${1:-}" == "--upload" ]]; then
  OPTIONS=$(mktemp -t ashen-export).plist
  sed 's#<string>export</string>#<string>upload</string>#' AppStore/ExportOptions.plist > "$OPTIONS"
fi

xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$OPTIONS" \
  -exportPath "$OUT/export" -allowProvisioningUpdates | grep -E "error|EXPORT|Upload"
echo "Package: $OUT/export/AshenBuild.ipa"
