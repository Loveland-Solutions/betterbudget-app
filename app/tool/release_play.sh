#!/bin/sh
# Builds the Android app and puts it on Google Play's Internal testing track,
# for the testers there (the owner's phone among them):
#
#   tool/release_play.sh "What changed, in a sentence or two."
#   tool/release_play.sh --check "…"   does it all but the last step, then
#                                       throws the upload away
#
#   1. builds the signed .aab (the build number is the commit count, ADR 0006)
#   2. checks it asks for no network
#   3. uploads it and makes it the only build in Internal testing, with the
#      notes above in English
#
# Moving a build on to a wider track stays the owner's click in Play Console.
# Run from a clean commit. Needs, once:
#   - the upload key in android/key.properties (git-ignored)
#   - a Play service-account key at the path below (or in $BB_PLAY_KEY), for an
#     account Play Console lets release to testing tracks. Never in the repo.
set -eu

package=mn.lls.betterbudget
track=internal
key=${BB_PLAY_KEY:-$HOME/.config/betterbudget/play-service-account.json}
api=https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$package
upload_api=https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$package

cd "$(dirname "$0")/.."

check=
if [ "${1:-}" = --check ]; then
  check=1
  shift
fi
notes=${1:-}
if [ -z "$notes" ]; then
  echo "Give the release notes: tool/release_play.sh \"What changed.\"" >&2
  exit 1
fi
if [ "$(printf %s "$notes" | wc -m)" -gt 500 ]; then
  echo "Play takes at most 500 characters of notes." >&2
  exit 1
fi
if [ ! -r "$key" ]; then
  echo "No Play key at $key." >&2
  exit 1
fi
if [ -n "$(git status --porcelain -- .)" ]; then
  echo "Commit or set aside the changes first: a release is built from a commit." >&2
  exit 1
fi

version=$(sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml)

# 1. Build and sign with the upload key.
flutter build appbundle --release
aab=build/app/outputs/bundle/release/app-release.aab

# 2. Nothing leaves the user's machine: the bundle must not ask for the internet.
if unzip -p "$aab" base/manifest/AndroidManifest.xml | strings |
  grep -q 'android.permission.INTERNET'; then
  echo "The bundle asks for internet access. Not releasing it." >&2
  exit 1
fi

# 3. Sign in as the service account: a JWT signed with its key, traded for a
# token that can only reach the Play Developer API.
json() { python3 -I -c "import json,sys;print(json.load(sys.stdin)$1)"; }
b64() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
pem=$(mktemp)
edit=
token=
cleanup() {
  rm -f "$pem"
  # An edit left open would hold back the next run's; throw it away.
  if [ -n "$edit" ]; then
    curl -s -o /dev/null -X DELETE -H "Authorization: Bearer $token" "$api/edits/$edit"
  fi
}
trap cleanup EXIT
chmod 600 "$pem"
json "['private_key']" <"$key" >"$pem"
email=$(json "['client_email']" <"$key")
now=$(date +%s)
header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64)
claims=$(printf '{"iss":"%s","scope":"https://www.googleapis.com/auth/androidpublisher","aud":"https://oauth2.googleapis.com/token","iat":%d,"exp":%d}' \
  "$email" "$now" $((now + 3600)) | b64)
signature=$(printf '%s.%s' "$header" "$claims" | openssl dgst -sha256 -sign "$pem" | b64)
token=$(curl -sf https://oauth2.googleapis.com/token \
  -d grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer \
  -d assertion="$header.$claims.$signature" | json "['access_token']")

call() { curl -sS --fail-with-body -H "Authorization: Bearer $token" "$@"; }

edit=$(call -X POST -H 'Content-Length: 0' "$api/edits" | json "['id']")
code=$(call -X POST -H 'Content-Type: application/octet-stream' --data-binary "@$aab" \
  "$upload_api/edits/$edit/bundles?uploadType=media" | json "['versionCode']")

# The track's release lists only this build, so a tester never gets an older one.
body=$(VERSION=$version CODE=$code NOTES=$notes python3 -I -c '
import json, os
print(json.dumps({"track": "internal", "releases": [{
    "name": "%s (%s)" % (os.environ["VERSION"], os.environ["CODE"]),
    "versionCodes": [os.environ["CODE"]],
    "status": "completed",
    "releaseNotes": [{"language": "en-US", "text": os.environ["NOTES"]}]}]}))')
call -X PUT -H 'Content-Type: application/json' -d "$body" \
  "$api/edits/$edit/tracks/$track" >/dev/null
if [ -n "$check" ]; then
  echo "Play took BetterBudget $version ($code); not released (--check)."
  exit 0
fi
call -X POST -H 'Content-Length: 0' "$api/edits/$edit:commit" >/dev/null
edit=

echo "BetterBudget $version ($code) is on Play's Internal testing track."
