# 0006 — Version numbers: semantic, 0.x until beta, build = commit count

**Status:** Accepted
**Date:** 2026-09-30

## Context

Bug reports (ROADMAP B) and releases need to say which build they came from. Until now
`pubspec.yaml` held Flutter's default `1.0.0+1`, which never changed and would call an
alpha "1.0".

## Decision

- **Semantic versioning, `MAJOR.MINOR.PATCH`**, started fresh at **0.1.0** on
  2026-09-30 (owner's choice).
  - **Minor** goes up with each feature PR (`0.1.0 → 0.2.0`).
  - **Patch** goes up for fixes only (`0.2.0 → 0.2.1`).
  - **1.0.0** is the public release; the owner decides when. A beta can carry a label
    (`0.9.0-beta.1`).
  - Major goes up after 1.0 only when something breaks what came before, such as a
    ledger file that older versions can't open.
- **The version lives in `app/pubspec.yaml`** (`version: 0.1.0+1`). Bump it in the PR
  that ships the change.
- **The build number is the repo's commit count** (`git rev-list --count HEAD`). The
  macOS target's "Build number from git" build phase writes it into the built
  `Info.plist` before signing. It reads only local git; without git it keeps pubspec's
  `+1`. The number points to one commit only for tagged release builds: a local build
  with uncommitted changes, or another branch with as many commits, shows the same one
  (it must be a plain number, so a git hash can't go in it). Android's Gradle build reads the same count into `versionCode` (2026-10-15), since Play refuses an upload whose number isn't higher than the last; without git it keeps pubspec's number. Other platforms use pubspec's number until they're built for real.
- **Settings shows it** at the bottom: "Version 0.1.0 (134)" / "Хувилбар 0.1.0 (134)".
  It's selectable so it can be copied into a bug report. The app reads it from its own
  bundle (`package_info_plus`), with no network call.
- **Tag each release** in git as `v0.1.0` and so on, so every version maps to a commit.
- **No CI for now** (owner, 2026-09-30: no paid GitHub plan yet). Builds and releases
  stay local. When a release pipeline comes (ROADMAP B), it should be tag-driven: a
  pushed `v0.x.0` tag builds that commit. Its checkout needs `fetch-depth: 0`, or the
  commit count, and so the build number, comes out as 1. macOS runners on a private
  repo bill at about 10× Linux minutes, and notarizing needs the Apple credentials as
  secrets.
- **Since the repo went public (2026-10-16), Actions minutes are free**, and the
  owner asked for Mac and Windows downloads. Windows is built on GitHub
  (`.github/workflows/windows.yml`, on a `v*` tag), with `fetch-depth: 0` and
  `--build-number` set to the commit count. The Mac stays local
  (`tool/release_mac.sh`): its Developer ID certificate and notary password stay in
  this Mac's Keychain rather than becoming repo secrets. The script tags the commit,
  pushes the tag (which starts the Windows build) and makes a draft release on
  `Loveland-Solutions/betterbudget` for the owner to publish.
- **Superseded for distribution (owner, 2026-10-20): stores only**, no GitHub
  downloads, so the Mac script and the Windows workflow's releases are unused. Version
  numbers, build numbers and tags stand; the stores need them too.

## Rejected

- **Calendar versions** (`2026.9`): easy to read, but they don't say how big a change was.
- **Counting the PRs merged so far** to pick a starting number: nobody outside has seen a
  version yet, so starting fresh loses nothing.
- **Passing `--build-number` by hand** to `flutter build`: forgotten builds would all say 1.
- **Versions worked out from commit messages** (release-please, semantic-release): the
  owner already decides what's a feature, and it would force a commit-message format.
