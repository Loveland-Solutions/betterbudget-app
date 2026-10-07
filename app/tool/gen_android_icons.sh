#!/bin/sh
# Draws the Android launcher icons from assets/brand/bee.svg: the bee on white, tilted
# 45° so it flies up and to the right, as on the Mac (ADR 0004 "App icon"). Writes the
# adaptive icon's foreground (API 26+) and the plain icons older phones use, into
# android/app/src/main/res. Needs rsvg-convert (brew install librsvg).
set -eu

cd "$(dirname "$0")/.."
res=android/app/src/main/res
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# The bee's own drawing, without its outer <svg> element, to nest in the two below.
viewbox=$(grep -o 'viewBox="[^"]*"' assets/brand/bee.svg | head -1)
inner=$(awk '/<g/{go=1} go' assets/brand/bee.svg | sed '$d')

# Adaptive foreground: a 108 square of which the launcher shows the middle 72 and
# keeps the middle 66 whatever its mask, so the bee stays inside that. The shift
# centres the tilted bee's own outline, which the antennae pull up and to the right.
cat > "$tmp/foreground.svg" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="108" height="108" viewBox="0 0 108 108">
  <g transform="translate(-3.5 3.5) rotate(45 54 54)">
    <svg x="27" y="24" width="54" height="60" $viewbox>$inner</svg>
  </g>
</svg>
EOF

# Plain icon: a white disc with the bee on it.
cat > "$tmp/legacy.svg" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <circle cx="24" cy="24" r="23" fill="#ffffff"/>
  <g transform="translate(-1.5 1.5) rotate(45 24 24)">
    <svg x="10.5" y="9" width="27" height="30" $viewbox>$inner</svg>
  </g>
</svg>
EOF

for pair in mdpi:1 hdpi:1.5 xhdpi:2 xxhdpi:3 xxxhdpi:4; do
  density=${pair%%:*}
  scale=${pair##*:}
  mkdir -p "$res/mipmap-$density"
  rsvg-convert -z "$scale" "$tmp/foreground.svg" -o "$res/mipmap-$density/ic_launcher_foreground.png"
  rsvg-convert -z "$scale" "$tmp/legacy.svg" -o "$res/mipmap-$density/ic_launcher.png"
done
