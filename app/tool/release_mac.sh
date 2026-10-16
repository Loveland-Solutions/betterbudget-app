#!/bin/sh
# Makes the Mac download for the version in pubspec.yaml and puts it on the
# public repo's releases page as a draft, for the owner to read and publish:
# https://github.com/Loveland-Solutions/betterbudget/releases
#
#   1. builds the release app and signs it with Developer ID
#   2. checks it asks for no network
#   3. has Apple notarize the app, then the disk image
#   4. tags this commit vX.Y.Z and pushes the tag
#   5. makes a draft release in Loveland-Solutions/betterbudget with the image
#
# Run from a clean main with the version already bumped. Needs, once:
#   - the paid Apple Developer team signed in to Xcode and set in the project
#   - notary credentials in the Keychain under the name below:
#       xcrun notarytool store-credentials betterbudget-notary \
#         --apple-id <Apple ID> --team-id <team ID>
#     (it asks for an app-specific password from account.apple.com)
set -eu

notary_profile=betterbudget-notary
public_repo=Loveland-Solutions/betterbudget

cd "$(dirname "$0")/.."

if [ -n "$(git status --porcelain -- . ../.github)" ]; then
  echo "Commit or set aside the changes first: a release is built from a commit." >&2
  exit 1
fi

version=$(sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml)
tag=v$version
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "$tag is already tagged. Bump version: in pubspec.yaml first." >&2
  exit 1
fi
team=$(sed -n 's/.*DEVELOPMENT_TEAM = \([A-Z0-9]*\);/\1/p' \
  macos/Runner.xcodeproj/project.pbxproj | head -n 1)

work=build/release
rm -rf "$work"
mkdir -p "$work"

# 1. Build, archive and sign with Developer ID.
flutter build macos --release
cat >"$work/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>teamID</key>
	<string>$team</string>
	<key>signingStyle</key>
	<string>automatic</string>
</dict>
</plist>
EOF
xcodebuild -quiet -workspace macos/Runner.xcworkspace -scheme Runner \
  -configuration Release -archivePath "$work/BetterBudget.xcarchive" \
  -allowProvisioningUpdates archive
xcodebuild -quiet -exportArchive -archivePath "$work/BetterBudget.xcarchive" \
  -exportPath "$work/export" -exportOptionsPlist "$work/ExportOptions.plist" \
  -allowProvisioningUpdates
app=$work/export/BetterBudget.app

# 2. Nothing leaves the user's machine: the download may not ask for network.
if codesign -d --entitlements - --xml "$app" 2>/dev/null | grep -q 'security.network'; then
  echo "The signed app asks for network access. Not releasing it." >&2
  exit 1
fi

# 3. Notarize the app, staple it, pack it, then notarize and staple the image.
ditto -c -k --keepParent "$app" "$work/BetterBudget.zip"
xcrun notarytool submit "$work/BetterBudget.zip" \
  --keychain-profile "$notary_profile" --wait
xcrun stapler staple "$app"
dmg=$(tool/make_dmg.sh "$app")
xcrun notarytool submit "$dmg" --keychain-profile "$notary_profile" --wait
xcrun stapler staple "$dmg"
spctl --assess --type open --context context:primary-signature -v "$dmg"

# 4. Tag the commit the download was built from.
git tag -a "$tag" -m "BetterBudget $version"
git push origin "$tag"

# 5. A draft release on the public repo; the owner publishes it.
gh release create "$tag" "$dmg" --repo "$public_repo" --draft \
  --title "BetterBudget $version" \
  --notes "Built from Loveland-Solutions/betterbudget-app@$tag."

echo "Draft release $tag is up: https://github.com/$public_repo/releases"
