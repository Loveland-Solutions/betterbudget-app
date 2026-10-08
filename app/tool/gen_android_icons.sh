#!/bin/sh
# Draws the Android launcher icons from the logo (assets/logo/prepared/logo.svg, made
# by prepare.py beside it): upright on white, as on the Mac (ADR 0004 "App icon").
# Writes the adaptive icon's foreground (API 26+) and the plain icons older phones
# use, into android/app/src/main/res. Needs rsvg-convert (brew install librsvg).
set -eu

cd "$(dirname "$0")/.."
res=android/app/src/main/res
logo=../assets/logo/prepared/logo.svg
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
[ -r "$logo" ] || { echo "No logo at $logo: run assets/logo/prepared/prepare.py first." >&2; exit 1; }

# The logo as an element to nest: its own <svg>, without the XML declaration, at
# the place and size given (x, y, width, height). It is 0.813 as wide as it is tall.
nested() {
  sed -e '/<?xml/d' \
    -e "s/<svg width=\"[^\"]*\" height=\"[^\"]*\"/<svg x=\"$1\" y=\"$2\" width=\"$3\" height=\"$4\"/" \
    "$logo"
}

# Adaptive foreground: a 108 square of which the launcher shows the middle 72 and
# keeps a circle 66 across whatever its mask, so the logo's corners stay inside that.
fg=$(nested 32.4 27.4 43.3 53.2)
case $fg in *'<svg x="'*) ;; *) echo "The logo in $logo isn't the shape this script expects." >&2; exit 1 ;; esac
cat > "$tmp/foreground.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="108" height="108" viewBox="0 0 108 108">
$fg
</svg>
SVG

# Plain icon: a white disc with the logo on it.
cat > "$tmp/legacy.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="48" height="48" viewBox="0 0 48 48">
  <circle cx="24" cy="24" r="23" fill="#ffffff"/>
$(nested 11.8 9 24.4 30)
</svg>
SVG

for pair in mdpi:1 hdpi:1.5 xhdpi:2 xxhdpi:3 xxxhdpi:4; do
  density=${pair%%:*}
  scale=${pair##*:}
  mkdir -p "$res/mipmap-$density"
  rsvg-convert -z "$scale" "$tmp/foreground.svg" -o "$res/mipmap-$density/ic_launcher_foreground.png"
  rsvg-convert -z "$scale" "$tmp/legacy.svg" -o "$res/mipmap-$density/ic_launcher.png"
done
