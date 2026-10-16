# BetterBudget — working notes for Claude

Read **[docs/STATUS.md](docs/STATUS.md)** first: what's built, what isn't, known bugs,
uncommitted work, **the next step the owner asked for**, and setup. The road from alpha to
beta (and the platforms after it) is tracked in **[docs/ROADMAP.md](docs/ROADMAP.md)**. UI decisions are in **[docs/decisions/0004-ledger-ui.md](docs/decisions/0004-ledger-ui.md)**.
The phone apps' design (record and check only, synced through a cloud folder the OS
handles) is in **[docs/decisions/0005-mobile-companion.md](docs/decisions/0005-mobile-companion.md)**.
The work is tracked as issues on the
[BetterBudget board](https://github.com/orgs/Loveland-Solutions/projects/1): Type is
Feature, Bug or Task; Status is Later, Next, In progress or Done; the milestone is Beta
or After beta.

## Unbreakable rules (from the README)

- Nothing leaves the user's machine: no network calls, telemetry, sync, update checks,
  or runtime font or asset fetching. Release builds declare no network entitlement.
- Real bank statements in `tdb-bank-transaction-exports/` and
  `afcu-bank-transaction-exports/` never get committed, and no
  values from them go into code, tests or docs.
- This repo is public, under GPL-3.0 or later (owner, 2026-10-16). Anything pushed,
  on any branch, in any commit message or PR, is published. The name and logo are not
  under the license.
- Ledger first, polished, then the budget.
- The published privacy policy is `PRIVACY.md` in the public repo
  `Loveland-Solutions/betterbudget` (no copy here). It says what the app stores and
  where: on the device, encrypted, a folder the user picks, files the user saves, bank
  files read on the device, bug reports on GitHub. A change that puts data anywhere
  new, or alters what Report a bug fills in, updates it and its "Last updated" date
  first.

## How the owner works

- They run the app, react to it, and expect fixes right away. Show the change working in
  the real app, not just in tests.
- **Every element needs a purpose.** Don't copy other budget apps' conventions.
- They correct UX assumptions. Write each correction into ADR 0004 and add it to
  **[docs/owner-corrections.md](docs/owner-corrections.md)**, and read that list before
  any work on a screen or its words. What the corrections so far add up to:
  - Use the plain word people say, and the app's own words: cleared, **Assigned**,
    **Income**, **Type**, **Paid from**, **Custom…**, tugrik.
  - Don't tell them what they already know, and don't show a figure or label that is
    only noise.
  - Say a thing on the page where it's fixed. Pages fill the window.
  - Everything works with the mouse alone (a Cancel button, a click away), and Esc too.
  - Undo is only for what the person at this computer did or decided, never for
    what another computer or the app did.
  - Offer a thing only while there's something for it, and don't ask about what they
    can't see.
  - Arithmetic that's right can still confuse: show a number the way a person would
    say it.
  - Toasts are for saved changes. Money out is ordinary ink with a minus in front;
    red is for a shortfall. A currency's
    code goes at the end, with its real symbol.
  - Questions to the owner are whole sentences with a plain example from the screen,
    not the app's internals.
  - The owner's logo sets the app's colors, and each of its colors does a job on
    screen. A rule that would leave one out is a trade to draw for them, not to
    settle.
- **The owner's ledger is production data** (owner, 2026-10-06: "I'm going to be
  testing my app by using it. The data that I have is now production data"). Every
  schema change needs an upgrade that keeps what's in their file, with a test; weigh a
  change by what it does to rows already there, and say so when one would alter or drop
  them. Never delete, reseed, erase or hand-edit their database file; try things on
  demo data or a copy. One exception (owner, 2026-10-09, for the two-computers work in
  ADR 0005: "It's okay if we need to replace the existing ledger to build something
  that is bulletproof. Remove it if you must"): that design may change the file's
  form or replace the ledger, and before anything of theirs is removed, say what will
  go and ask.
- **Warn, don't block** (owner, 2026-09-18: "I really hate it when a developer tries to
  save me from myself"). Don't forbid an action to protect the user. Say exactly what
  will happen, big and specific with real numbers, then let them go ahead, with undo.
  Use a default rather than a required choice. Locks the owner chose themselves (such as
  reconciled rows) stay.
- They often choose between options, so offer two or three with a recommendation and
  sketches, then build the one they pick. Record the choice, and what was rejected, in
  ADR 0004.
- Once they've made a call, don't re-ask it. Review findings that refine it (wording,
  defaults, edge cases) are yours to decide along the lines they gave; report them
  briefly. Ask only about new features or new ways money is counted or shown, two or
  three at a time. Run the review passes once per feature, not again on their own
  follow-ups (owner, 2026-09-17: "you keep asking me the same five questions").
- If they must run something themselves (for example `sudo`), give them one copy-paste
  line and say why.

## Code (`app/`)

- **Finding files:** when a task touches more than one area, or you don't know where
  something lives, read [docs/MAP.md](docs/MAP.md) before searching. Don't open or list
  `app/test/goldens/` or `app/test/failures/`, except to look at the one golden you just
  changed. When you add, move or rename a file under `app/lib` or `app/test`, update
  MAP.md in the same change.
- Don't open `docs/archive/` unless the owner asks.
- [docs/STATUS.md](docs/STATUS.md) holds the current state and next steps only: when a
  PR merges, rewrite its "Next step" and correct its tables, and add no dated log.
- Every new action records both an undo and a redo (`_did` in `ui/ledger_screen.dart`).
- English text is never glued from pieces: one whole message per sentence, in both
  `.arb` files (Mongolian word order differs).

## Two review passes before wrapping a feature or page

Run both before calling a feature or page done (owner's rule), and bring the findings to
the owner rather than fixing everything silently:

1. **Code review** by the `code-reviewer` agent: correctness, data integrity, the
   unbreakable rules, tests.
2. **Budget app review** by the `budget-app-expert` agent: does it hold up for someone
   actually managing money in Mongolia? It flags gaps without copying other apps'
   conventions.

## Design committee, for how a screen is presented

When the owner says a screen has the right features but the wrong presentation, run
these four agents in parallel and fold their reports into two or three mockups with a
recommendation (the Design artifact type draws them): `ui-designer` (layout),
`ux-writer` (words), `interaction-designer` (flow, clicks, focus), `first-time-user`
(someone in Ulaanbaatar who has never used a budget app, reading it literally).
`budget-expert` is for how money is counted, not presentation. Don't bring back the same
row of controls with better words (owner, 2026-10-04).

## Checks before handing work back

```sh
cd app && flutter analyze && flutter test
```

- Every PR names its issue on the board with `Closes #N` in its description (or
  `Part of #N` when it finishes only some of it). No issue yet: make one first, with
  its Type, milestone and Status. Set the issue to In progress when the PR opens.
- Bump `version:` in `app/pubspec.yaml` in each feature PR (minor) or fix PR (patch);
  the build number comes from git ([ADR 0006](docs/decisions/0006-version-numbers.md)).
- Visual changes: `flutter test --update-goldens`, then look at the PNGs you changed in
  `test/goldens/`, then rebuild and relaunch the macOS app.
- Before writing a widget test, a golden, or changing a font, read the gotchas in
  [docs/MAP.md](docs/MAP.md): a button can look right in every golden and sit wrong on
  a Mac.
