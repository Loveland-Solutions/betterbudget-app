#!/bin/sh
# Packs the Mac app into a disk image with a shortcut to Applications:
# build/dmg/BetterBudget-<version>.dmg. Run from anywhere.
# Uses only local tools (flutter, diskutil); nothing is uploaded.
#
#   tool/make_dmg.sh                 builds the release app first
#   tool/make_dmg.sh path/to/BetterBudget.app   packs that app as it is
#
# A downloadable image comes from tool/release_mac.sh, which passes it an app
# signed with Developer ID and notarized. Built here alone, the app carries the
# Apple Development signature and opens only on this Mac.
set -eu

cd "$(dirname "$0")/.."

if [ $# -ge 1 ]; then
  app=$1
else
  flutter build macos --release
  app=build/macos/Build/Products/Release/BetterBudget.app
fi
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
diskutil image create from --format UDZO --volumeName "BetterBudget $version" "$stage" "$dmg" >&2
rm -rf "$stage"

echo "$dmg"
