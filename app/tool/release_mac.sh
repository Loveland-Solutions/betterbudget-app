#!/bin/sh
# Builds the Mac app for the version in pubspec.yaml and sends it to App Store
# Connect, where it shows under TestFlight and can be chosen for the Mac App
# Store version:
#
#   tool/release_mac.sh            builds, checks and uploads
#   tool/release_mac.sh --check    builds and checks, uploads nothing
#
#   1. archives the release app, signed by the team in the Xcode project (the
#      build number is the commit count, ADR 0006)
#   2. signs a copy for the App Store and checks it is sandboxed and asks for
#      no network
#   3. uploads it
#
# Submitting it for review stays the owner's click in App Store Connect.
# Run from a clean commit. Needs, once: the paid team signed in to Xcode
# (Settings → Accounts); this Mac registered with the team, which a build for
# it does (STATUS "Signing"); and the app made in App Store Connect with the
# bundle ID com.lovelandsolutions.betterbudget. Apple keeps the signing
# certificate.
set -eu

cd "$(dirname "$0")/.."

check=
if [ "${1:-}" = --check ]; then
  check=1
fi

if [ -n "$(git status --porcelain -- .)" ]; then
  echo "Commit or set aside the changes first: a release is built from a commit." >&2
  exit 1
fi

version=$(sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml)
team=$(sed -n 's/.*DEVELOPMENT_TEAM = \([A-Z0-9]*\);/\1/p' \
  macos/Runner.xcodeproj/project.pbxproj | head -n 1)

work=build/release-mac
rm -rf "$work"
mkdir -p "$work"

options() {
  cat >"$work/$1.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>$1</string>
	<key>teamID</key>
	<string>$team</string>
	<key>signingStyle</key>
	<string>automatic</string>
</dict>
</plist>
EOF
}

# 1. Archive. Only xcodebuild may make the team's signing profile, so Flutter
# writes its settings and the archive builds the app.
flutter build macos --release --config-only
xcodebuild -quiet -workspace macos/Runner.xcworkspace -scheme Runner \
  -configuration Release -archivePath "$work/BetterBudget.xcarchive" \
  -allowProvisioningUpdates archive

# 2. Nothing leaves the user's machine: the app the store gets must be
# sandboxed and ask for no network. A codesign that fails stops the script.
options export
xcodebuild -quiet -exportArchive -archivePath "$work/BetterBudget.xcarchive" \
  -exportPath "$work/export" -exportOptionsPlist "$work/export.plist" \
  -allowProvisioningUpdates
pkgutil --expand-full "$work/export/BetterBudget.pkg" "$work/expanded"
app=$(find "$work/expanded" -name BetterBudget.app -type d -prune | head -n 1)
built=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  "$app/Contents/Info.plist")
if [ "$built" != "$version" ]; then
  echo "The app says $built, not $version. Not uploading it." >&2
  exit 1
fi
entitlements=$(codesign -d --entitlements - --xml "$app" 2>/dev/null)
case $entitlements in
  *security.network*)
    echo "The signed app asks for network access. Not uploading it." >&2
    exit 1 ;;
  *app-sandbox*) ;;
  *)
    echo "The signed app isn't sandboxed. Not uploading it." >&2
    exit 1 ;;
esac
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \
  "$app/Contents/Info.plist")

if [ -n "$check" ]; then
  echo "BetterBudget $version ($build) is built and checked; nothing uploaded."
  exit 0
fi

# 3. Upload, signed the same way as the copy checked above.
options upload
xcodebuild -quiet -exportArchive -archivePath "$work/BetterBudget.xcarchive" \
  -exportPath "$work/upload" -exportOptionsPlist "$work/upload.plist" \
  -allowProvisioningUpdates

echo "BetterBudget $version ($build) is uploaded. It shows in App Store Connect"
echo "under TestFlight once Apple has processed it (usually 10 to 30 minutes)."
