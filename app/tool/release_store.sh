#!/bin/sh
# Sends the Windows app to the Microsoft Store, from the Mac:
#
#   tool/release_store.sh            tags this version, waits for the Windows
#                                    build, sends its .msix to Partner Center
#   tool/release_store.sh --check    does it all but the last step, then
#                                    throws the new submission away; stops if
#                                    one is already waiting, and deletes nothing
#
#   1. checks something is published to build on
#   2. tags main vX.Y.Z (the version in pubspec.yaml) and pushes the tag, which
#      starts .github/workflows/windows.yml; a tag already pushed is used as is
#   3. waits for that build and downloads its unsigned .msix
#   4. checks the package is this version and asks for no network
#   5. deletes any submission waiting in Partner Center, even one in
#      certification (owner, 2026-10-30), then makes a new one from the last
#      published one, with this package, set to publish only when the owner clicks Publish now in Partner Center,
#      and, once it is sure the submission holds this package, sends it to
#      certification
#
# Run from a clean commit on main that has been pushed. Needs, once: msstore,
# signed in to the Partner Center account (msstore reconfigure), and gh.
set -eu

product=9NH3HJNFJN4G
repo=Loveland-Solutions/betterbudget-app

cd "$(dirname "$0")/.."

check=
if [ "${1:-}" = --check ]; then
  check=1
fi

json() { python3 -I -c "import json,sys;t=sys.stdin.read();print(json.loads(t[t.index('{'):])$1)"; }

# Whether Partner Center holds a submission waiting; Partner Center holds one
# at a time.
waiting() {
  app=$(msstore apps get $product 2>/dev/null)
  [ "$(printf %s "$app" | json "['PendingApplicationSubmission'] is not None")" = True ]
}
waiting_status() {
  msstore submission status $product 2>&1 | sed -n 's/.*Submission Status = //p'
}

# 1. Something published to copy from. --check promises to delete nothing.
if waiting && [ -n "$check" ]; then
  echo "A submission is already waiting in Partner Center ($(waiting_status)); --check won't touch it." >&2
  exit 1
fi
if [ "$(printf %s "$app" | json "['LastPublishedApplicationSubmission'] is None")" = True ]; then
  echo "Nothing is published in the Store yet; the first submission is made in Partner Center." >&2
  exit 1
fi

if [ -n "$(git status --porcelain -- .)" ]; then
  echo "Commit or set aside the changes first: a release is built from a commit." >&2
  exit 1
fi
git fetch -q origin main
if ! git merge-base --is-ancestor HEAD origin/main; then
  echo "This commit isn't on main on GitHub; the Store gets only what main has." >&2
  exit 1
fi

version=$(sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml)
tag=v$version
name=BetterBudget-$version-store

# 2. Tag, unless this version is tagged already.
if ! git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null; then
  if [ -n "$check" ]; then
    echo "$tag isn't tagged; --check uses a build that is there already." >&2
    exit 1
  fi
  git tag -a "$tag" -m "BetterBudget $version"
  git push -q origin "$tag"
  echo "Tagged $tag; waiting for the Windows build to start."
  sleep 20
fi

# 3. The tag's newest Windows build: wait for it, then take its package.
run=
for _ in 1 2 3 4 5 6; do
  run=$(gh run list -R $repo --workflow windows.yml --branch "$tag" --limit 1 \
    --json databaseId -q '.[0].databaseId')
  [ -n "$run" ] && break
  sleep 10
done
if [ -z "$run" ]; then
  echo "No Windows build for $tag. Start one: gh workflow run windows.yml --ref $tag" >&2
  exit 1
fi
gh run watch -R $repo "$run" --exit-status >/dev/null ||
  { echo "The Windows build for $tag failed: gh run view -R $repo $run" >&2; exit 1; }

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
gh run download -R $repo "$run" -n "$name" -D "$dir"
msix=$dir/BetterBudget-$version.msix
if [ ! -f "$msix" ]; then
  echo "The build for $tag has no $name package (downloads expire after 14 days)." >&2
  exit 1
fi

# 4. Nothing leaves the user's machine: the package must ask only to run as a
# desktop app, and it must be this version.
manifest=$(unzip -p "$msix" AppxManifest.xml)
if ! printf %s "$manifest" | grep -q "Version=\"$version.0\""; then
  echo "The package isn't version $version.0." >&2
  exit 1
fi
capabilities=$(printf %s "$manifest" | grep -o 'Capability Name="[^"]*"' | sort -u)
if [ "$capabilities" != 'Capability Name="runFullTrust"' ]; then
  echo "The package asks for more than runFullTrust:" >&2
  echo "$capabilities" >&2
  exit 1
fi

# 5. A new submission, a copy of the last published one with this package in it,
# kept as a draft until it is set to wait for the owner's Publish now.
# msstore can fail and still exit 0 (#287), so the submission it leaves is
# checked: it must hold this package. The one waiting goes only now, so a
# failed build leaves it in place. msstore's delete is checked the same way:
# it can't delete some made in Partner Center (#287).
if waiting; then
  echo "Deleting the submission waiting in Partner Center ($(waiting_status))."
  msstore submission delete $product --no-confirm >/dev/null
  if waiting; then
    echo "msstore couldn't delete it. Delete it in Partner Center, then run this again." >&2
    exit 1
  fi
fi
msstore publish "$msix" --appId $product --noCommit
submission=$(msstore submission get $product 2>/dev/null)
problem=$(printf %s "$submission" | python3 -I -c "
import json, sys
t = sys.stdin.read()
if '{' not in t:
    print('Partner Center has no new submission')
    sys.exit()
s = json.loads(t[t.index('{'):])
# Before the commit Partner Center hasn't read the package: it is
# PendingUpload with no version yet (step 4 read it). After, it has one.
mine = [p for p in s.get('ApplicationPackages') or []
        if p.get('FileName') == 'BetterBudget-$version.msix'
        and (p.get('Version') == '$version.0'
             or (p.get('Version') is None
                 and p.get('FileStatus') == 'PendingUpload'))
        and p.get('FileStatus') != 'PendingDelete']
if not mine:
    print('the submission waiting in Partner Center (' + str(s.get('Id')) +
          ') does not hold BetterBudget-$version.msix')")
if [ -n "$problem" ]; then
  echo "msstore couldn't send $version: $problem. Nothing was sent to certification;" >&2
  echo "msstore's messages above say why. Look in Partner Center before running again." >&2
  exit 1
fi
if [ "$(printf %s "$submission" | json "['TargetPublishMode']")" != Manual ]; then
  updated=$(printf %s "$submission" | python3 -I -c "
import json, sys
t = sys.stdin.read()
s = json.loads(t[t.index('{'):])
s['TargetPublishMode'] = 'Manual'
print(json.dumps(s))")
  msstore submission update $product "$updated" >/dev/null
  submission=$(msstore submission get $product 2>/dev/null)
  if [ "$(printf %s "$submission" | json "['TargetPublishMode']")" != Manual ]; then
    msstore submission delete $product --no-confirm >/dev/null
    echo "Couldn't set the submission to wait for Publish now; threw it away." >&2
    exit 1
  fi
fi
if [ -n "$check" ]; then
  msstore submission delete $product --no-confirm >/dev/null
  echo "Partner Center took BetterBudget $version; not submitted (--check)."
  exit 0
fi
msstore submission publish $product >/dev/null

echo "BetterBudget $version is in certification. When it passes, Partner Center"
echo "waits for Publish now."
