# BetterBudget — working notes for Claude

Read **[docs/STATUS.md](docs/STATUS.md)** first: what's built, what isn't, known bugs,
uncommitted work, **the next step the owner asked for**, and setup. UI decisions are in **[docs/decisions/0004-ledger-ui.md](docs/decisions/0004-ledger-ui.md)**.

## Unbreakable rules (from the README)

- Nothing leaves the user's machine: no network calls, telemetry, sync, update checks,
  or runtime font or asset fetching. Release builds declare no network entitlement.
- Real bank statements in `tdb-bank-transaction-exports/` never get committed, and no
  values from them go into code, tests or docs.
- Ledger first, polished, then the budget.

## How the owner works

- They run the app, react to it, and expect fixes right away. Show the change working in
  the real app, not just in tests.
- **Every element needs a purpose.** Don't copy other budget apps' conventions.
- They correct UX assumptions, so write each correction into ADR 0004 so it isn't lost.
  Past corrections: no In/Out columns, no month subheadings, symbols that look like
  checkboxes, entry that only works left to right, no savings suggestions yet, shortcuts
  that swallowed typing, no way to edit a transaction, "not posted" wording for
  uncleared (banks show pending), a dash symbol that read as a minus sign, a separate big
  balance above the header sum, "latest cleared" date (noise), a reconciled amount (only
  the date matters), a sidebar layout (option A chosen), Delete removing reconciled
  rows, a chevron on sidebar sections (it promised a toggle), an always-visible blank
  entry row, a "+ for money in" hint, multi-select (not wanted yet), a toast on
  every cleared-symbol click (toasts are for saved changes; ⌘Z undoes anything), and
  an income name under the forecast's end date (both ends show plain dates).
- They often choose between options, so offer two or three with a recommendation and
  sketches, then build the one they pick. Record the choice, and what was rejected, in
  ADR 0004.
- If they must run something themselves (for example `sudo`), give them one copy-paste
  line and say why.

## Code map (`app/`)

- `lib/domain/`: pure Dart, no Flutter and no database. `money.dart` (integer minor
  units, MNT exponent 2, amount calculator), `ledger.dart` (register rows, balances),
  `forecast.dart`.
- `lib/data/`: Drift schema and writes (`database.dart`; regenerate with
  `dart run build_runner build`), plus `demo_seed.dart`.
- `lib/ui/`: `theme.dart` (Midnight tokens, `Money`, `StatusGlyph`), `ledger_screen.dart`
  (state, selection, row actions, toasts), `balance_header.dart` (key, forecast chart and bill list),
  `register.dart` (rows, row action bar, category menu), `entry_row.dart`
  (entry row, `DateField` and calendar), `reconcile.dart` (reconcile panel).
  `ledger_screen.dart` also holds the session undo/redo history (`_did`, `_undo`,
  `_redoLast`): every new action must record both an undo and a redo.

## Two review passes before wrapping a feature or page

Run both before calling a feature or page done (owner's rule), and bring the findings to
the owner rather than fixing everything silently:

1. **Code review** by the `code-reviewer` agent (`.claude/agents/code-reviewer.md`):
   correctness, data integrity, the unbreakable rules, tests.
2. **Budget app review** by the `budget-app-expert` agent
   (`.claude/agents/budget-app-expert.md`): does it hold up for someone actually
   managing money in Mongolia? It flags gaps without copying other apps' conventions.

## Checks before handing work back

```sh
cd app && flutter analyze && flutter test
```

- Visual changes: `flutter test --update-goldens`, then look at the PNGs in
  `test/goldens/`, then rebuild and relaunch the macOS app.
- Widget tests that touch the database must do the I/O inside `tester.runAsync` (see
  `test/ledger_screen_test.dart`). The fake clock never completes real SQLite work.
- Goldens load Onest and Manrope explicitly. Border and fade animations need an extra
  `pump()` before capture.
- Any font change: confirm the font has ₮ (U+20AE), Ө and Ү.
