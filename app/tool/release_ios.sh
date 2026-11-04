#!/bin/sh
# Builds the iPhone app for the version in pubspec.yaml and sends it to App
# Store Connect, where it shows under TestFlight and can be chosen for the App
# Store version:
#
#   tool/release_ios.sh            builds, checks and uploads
#   tool/release_ios.sh --check    builds and checks, uploads nothing
#
#   1. archives the release app unsigned (the build number is the commit
#      count, ADR 0006)
#   2. signs a copy for the App Store and checks its version and that it
#      carries its privacy manifest
#   3. uploads it
#
# Giving a build to testers, and submitting it for review, stay the owner's
# clicks in App Store Connect. Run from a clean commit. Needs, once: the paid
# team's App Store Connect API key (below), and the app made in App Store
# Connect with the bundle ID com.lovelandsolutions.betterbudget. The archive
# is unsigned because a signed one needs a registered iPhone; Apple keeps the
# certificate that signs the export.
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
build=$(git rev-list --count HEAD)
team=$(sed -n 's/.*DEVELOPMENT_TEAM = \([A-Z0-9]*\);/\1/p' \
  ios/Runner.xcodeproj/project.pbxproj | head -n 1)

# Xcode 27.2's command line can't use the account signed in to Xcode, so every
# step that signs or uploads goes by an App Store Connect API key (#380): its
# AuthKey_<Key ID>.p8 in ~/.config/betterbudget/, and the Issuer ID beside it
# in app-store-connect-issuer. Neither goes in the repo.
keys=$HOME/.config/betterbudget
key=$(ls "$keys"/AuthKey_*.p8 2>/dev/null | head -n 1)
issuer=$(cat "$keys/app-store-connect-issuer" 2>/dev/null || true)
if [ -z "$key" ] || [ -z "$issuer" ]; then
  echo "No App Store Connect API key: put AuthKey_<Key ID>.p8 and a file" >&2
  echo "app-store-connect-issuer holding the Issuer ID in $keys." >&2
  exit 1
fi
key_id=$(basename "$key" .p8)
key_id=${key_id#AuthKey_}
signed() {
  xcodebuild -quiet "$@" -allowProvisioningUpdates \
    -authenticationKeyPath "$key" -authenticationKeyID "$key_id" \
    -authenticationKeyIssuerID "$issuer"
}

work=build/release-ios
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
	<key>uploadSymbols</key>
	<false/>
</dict>
</plist>
EOF
}

# 1. Archive.
flutter build ios --release --config-only --build-number="$build"
xcodebuild -quiet -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Release -destination generic/platform=iOS \
  -archivePath "$work/BetterBudget.xcarchive" archive CODE_SIGNING_ALLOWED=NO

# 2. Sign a copy and check it.
options export
signed -exportArchive -archivePath "$work/BetterBudget.xcarchive" \
  -exportPath "$work/export" -exportOptionsPlist "$work/export.plist"
ditto -x -k "$work/export/"*.ipa "$work/expanded"
app=$work/expanded/Payload/Runner.app
built=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Info.plist")
number=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Info.plist")
if [ "$built" != "$version" ] || [ "$number" != "$build" ]; then
  echo "The app says $built ($number), not $version ($build). Not uploading it." >&2
  exit 1
fi
if [ ! -f "$app/PrivacyInfo.xcprivacy" ]; then
  echo "The app has no privacy manifest. Not uploading it." >&2
  exit 1
fi
codesign --verify --strict "$app"

if [ -n "$check" ]; then
  echo "BetterBudget $version ($build) for iPhone is built and checked; nothing uploaded."
  exit 0
fi

# 3. Upload, signed the same way as the copy checked above.
options upload
signed -exportArchive -archivePath "$work/BetterBudget.xcarchive" \
  -exportPath "$work/upload" -exportOptionsPlist "$work/upload.plist"

echo "BetterBudget $version ($build) for iPhone is uploaded. It shows in App Store"
echo "Connect under TestFlight once Apple has processed it (usually 10 to 30 minutes)."
