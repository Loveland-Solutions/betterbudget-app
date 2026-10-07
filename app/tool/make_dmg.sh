#!/bin/sh
# Builds the release Mac app and packs it into a disk image with a shortcut to
# Applications: build/dmg/BetterBudget-<version>.dmg. Run from anywhere.
# Uses only local tools (flutter, diskutil); nothing is uploaded.
#
# The image is signed the way the Release build is. Until that is a Developer ID
# signature and the image is notarized (ROADMAP B), it opens only on a Mac listed
# in the build's provisioning profile, and only until that profile expires.
set -eu

cd "$(dirname "$0")/.."

flutter build macos --release

app=build/macos/Build/Products/Release/BetterBudget.app
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist")
out=build/dmg
stage=$out/stage
dmg=$out/BetterBudget-$version.dmg

rm -rf "$stage"
mkdir -p "$stage"
# ditto keeps the signature, symlinks and extended attributes intact.
ditto "$app" "$stage/BetterBudget.app"
ln -s /Applications "$stage/Applications"

rm -f "$dmg"
diskutil image create from --format UDZO --volumeName "BetterBudget $version" "$stage" "$dmg"
rm -rf "$stage"

echo "$dmg"
