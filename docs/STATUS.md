# Where things stand

**Last updated: 2026-09-17**

Start here if you are picking this up cold. For AI sessions, [`CLAUDE.md`](../CLAUDE.md)
summarizes how to work in this repo.

## Phase

**The first working desktop ledger is built** and runs on macOS from [`app/`](../app/).
The owner is refining the ledger by using it and giving feedback; **the budget comes only
after the ledger is dialed in.**

**Git state:** everything through the sidebar animation, the chevron removal and the
reconciled-delete lock is committed and merged to `main` (PR #2). Keep the pattern:
branch, commit, PR, merge.

Visual direction and the register's UX rules are settled in
[ADR 0004](decisions/0004-ledger-ui.md). Read it before changing any UI.

## What exists

### Built and working (desktop, macOS verified)

| Area | What works |
| --- | --- |
| Storage | Drift/SQLite, double-entry per ADR 0003; zero-sum enforced inside each write; soft delete; `cleared` per entry; WAL mode |
| Sidebar | Sections Ledger / Budget / Savings; the current one expands, its accounts spilling down in a short cascade. Ledger lists accounts grouped (Cash & bank, Credit) with balances. Budget and Savings are placeholders ("Later", "Not built yet" page). Net worth pinned at the bottom |
| Header | A cleared + uncleared = working sum whose total is the large number, plus the date last reconciled; the lines double as the symbol key (hover highlights, click filters) |
| Forecast | Today → next scheduled income: lowest point, or a coral warning with the date it runs out and which bills cause it; 30-day horizon if no income is scheduled |
| Register | Full dates, running balance, one signed amount column, transfer and split glyphs, split lines in the memo; tabs All / Uncleared / Scheduled; search across payee, memo, category, amount |
| Entry | Any field order; Enter from anywhere; Add button; missing fields outlined; payee autocomplete with last-used category; `+` for money in; calculator (`12000+8500`); `→ Account` as category makes a transfer; future date → scheduled |
| Editing | Double-click a row (or Enter, or Edit in the selection bar) opens it in place with date, payee, memo, category and amount, and the cursor in the clicked field; Enter/Save keeps changes, Esc cancels, Undo restores; splits edit date, payee and memo only; reconciled rows are locked; moving a date into the future schedules it. Also: inline category menu, click a symbol to clear or unclear, confirm scheduled (early confirm posts today) |
| Bulk | Click / ⌘-click / Shift-click selection; bar with Categorize, Mark cleared, Mark uncleared, Delete; keys C, Delete, Esc; all undoable. Delete skips reconciled rows and says how many it left locked (enforced in the database) |
| Shortcuts | ⌘N new, ⌘K / ⌘F search, Esc clear (Ctrl on Windows) |
| Tests | 41: money parsing, ledger/DB invariants, bulk ops, editing, forecast, screen flows including real key presses and sidebar sections and their animation, 7 golden screenshots |

Seeded on first launch with **synthetic** demo data dated relative to today: TDB
Checking, Khan Savings, Cash wallet, Golomt Visa, 14 expense categories, Salary, and 4
scheduled items.

### Not built yet

- **Encryption.** Plain SQLite for now. ADR 0001 requires SQLCipher; do the Windows spike
  first. `package:sqlite3` supports `hooks: user_defines: sqlite3: source: sqlcipher` (or
  `sqlite3mc`) in `pubspec.yaml`.
- Creating or editing **splits**: split lines are display-only. A split's date, payee and
  memo can be edited.
- A **memo field when adding** a transaction (memo is editable only on existing ones).
- Adding, renaming or archiving **accounts and categories** (seed data only).
- **Import** (TDB per ADR 0002), **reconcile** flow, **recurring** schedules (scheduled
  items are one-off), payees merge, rules, tags, attachments.
- **Backup/restore, CSV export, app lock.**
- **Mongolian UI strings** (the UI is English; payees are Cyrillic), **mobile layout**,
  Windows build (scaffolded, never built), a real app icon.
- **CI.** Nothing runs tests on pull requests.

### Known bugs and loose ends

- **The owner's own data file** (not the demo seed) has leftovers from testing. The owner
  says it's all test data now:
  - Two "asdfa" test entries (₮3 and ₮4).
  - Two October rows posted before the early-confirm fix.

## Settled decisions

| ADR | Decision |
| --- | --- |
| [0001](decisions/0001-database.md) | SQLite via Drift, encrypted with SQLCipher. MNT is exponent 2. |
| [0002](decisions/0002-tdb-import-format.md) | TDB import targets the unformatted Excel export. Column map and dedup key recorded. |
| [0003](decisions/0003-double-entry-schema.md) | Double-entry storage, categories as accounts, accounting hidden from the UI. |
| [0004](decisions/0004-ledger-ui.md) | Midnight look and 14 register rules: purpose, forecast, one amount column, full dates, clock/check/diamond symbols, header as a cleared + uncleared = working sum, any-order entry, multi-select, in-place editing, shortcuts that never steal typing, sectioned sidebar. |

Full ledger feature map, with what's built marked: [ledger-features.md](ledger-features.md).

## Roadmap (ledger, before the budget)

Items the owner has put on the roadmap. They are not scheduled in any order yet. Each
must follow [ADR 0004](decisions/0004-ledger-ui.md), especially "every element earns its
place". Design each before building it and show it to the owner.

### 1. Search

**Today:** one box that does a plain substring match on payee, memo, category and amount
digits, in the current account only.

**To build:**
- **Search across all accounts**, not just the one open, with the account shown on each
  result.
- **Amount search that understands money:** `8000` matches ₮8,000.00, not every amount
  containing those digits; ranges like `>100000` or `50000-120000`.
- **Dates:** a single day (`2026.09.14`), a month (`2026.09`) or a range.
- **Cyrillic-aware matching:** case-insensitive, and a Latin query should find the
  Cyrillic payee and vice versa ("nomin" finds "Номин"). Real bank data will contain both
  spellings (§F).
- **Structured filters** (category, status, amount range, date range) that combine with
  the text, plus **saved filters** for searches people repeat (§G).
- **Results show a total** for what matched. "How much did I spend at E-Mart since
  July?" is usually the reason for searching.

**Questions to settle:** one smart box with a syntax, or a box plus filter chips? What
does the header's forecast show while results span several accounts?

### 2. Sorting

**Today:** newest first, fixed.

**To build:**
- Click a column header to sort by **date, payee, category or amount**; click again to
  reverse. The active column shows its direction.
- The sort is remembered for each account.
- It works together with search, filters and multi-select (Shift-click ranges follow the
  visible order, which the code already does).

**Questions to settle:** a running balance only makes sense in date order, so what does
the Balance column show when sorted by amount or payee? Hide it, dim it, or keep each
row's date-order balance? Where do scheduled rows go when not sorted by date?

## Open questions

Roughly in the order they will block something.

1. **Does TDB's internet banking offer CSV or modern `.xlsx`?** Both current exports are
   legacy BIFF `.xls`, which has no mature Dart reader. **Check before starting a BIFF
   reader.**
2. **What does the ledger still need before the budget?** The owner is steering this by
   feel. Likely candidates: splits, accounts/categories management, reconcile, import,
   plus search and sorting on the roadmap. Ask rather than assume.
3. **What is "Savings"?** A placeholder name in the sidebar; the owner will define it later
   (goals? savings accounts?). Relates to the budget model below.
4. **Budget model: envelopes or targets?** Blocks the budget. The double-entry schema
   suits envelopes.
5. **Multi-currency at launch?** Current lean: data model ready (entries carry
   `currency` and `rate`), UI MNT-only.
6. **Is the dedup key stable across overlapping exports?** Two overlapping TDB exports
   would settle it.
7. **Which other banks import at launch?** Khan, Golomt, Khas, State Bank, M Bank.
8. **Cash-heavy or card-heavy users?** Decides whether wallet-count reconciliation is core.
9. **Does BetterBudget get its own wordmark?** `assets/logo/` is the Loveland Solutions
   company mark. The app uses a gold diamond plus "BetterBudget" as a placeholder.
10. **Header height.** Smaller since the separate big balance was removed; about seven
    rows show at 1440×900. Collapsing it on scroll was offered; the owner hasn't asked for it.

## Next step

**Nothing is in progress. Ask the owner what's next.**

Most recently done and approved by the owner ("very nice"): the Ledger section spills
open in the sidebar (`_Spill` in `app/lib/ui/ledger_screen.dart`; 360 ms open, 200 ms
close, instant with reduced motion), section headers have no chevron, and bulk Delete
leaves reconciled rows locked. All are recorded in ADR 0004 (rules 8 and 14). The
deleted 09.02 card payment is restored in the owner's data file.

The queue is whatever the owner picks. The [roadmap](#roadmap-ledger-before-the-budget)
has search and sorting. Also offered and not yet answered:

- CI that runs `flutter test` on pull requests.
- The SQLCipher spike, before much more data work builds on plain SQLite.

Past pattern: the owner uses the running app, points at what feels wrong, and it gets
fixed immediately. Keep that loop tight, rebuild and relaunch the app after each change,
and look at the result (a screenshot or golden) before saying it's done.

## Local setup notes

- **Toolchain:** Flutter via Homebrew (`brew install --cask flutter`, 3.47 at time of
  writing). Xcode is installed and selected (`sudo xcode-select -s
  /Applications/Xcode.app/Contents/Developer`, license accepted). If the macOS build fails
  with `tapi error … MacOSX27.0.sdk`, `xcode-select` is pointing at the Command Line Tools
  again, and the native build hook for `objective_c` is picking up the wrong SDK.
- **Run:** `cd app && flutter run -d macos`, or build with `flutter build macos --debug`
  and open `app/build/macos/Build/Products/Debug/BetterBudget.app`.
- **App data:** `~/Library/Containers/com.lovelandsolutions.betterbudget/Data/Library/Application Support/com.lovelandsolutions.betterbudget/betterbudget.sqlite`
  (plus `-wal`, `-shm`). Quit the app and delete all three to reseed demo data. The
  owner's current file has hand-edited test data in it; see Known bugs. Don't delete or
  change it without asking.
- **Rebuild and relaunch:** `pkill -f "BetterBudget.app/Contents/MacOS"; flutter build
  macos --debug && open build/macos/Build/Products/Debug/BetterBudget.app` (from `app/`).
- **Screenshots of the running app** (for checking UI changes): `screencapture -l<window
  id>` works once the terminal has screen-recording permission; get the window id from
  `CGWindowListCopyWindowInfo` for owner `BetterBudget`. Golden PNGs in
  `app/test/goldens/` are the quicker check.
- `tdb-bank-transaction-exports/` holds **real, unredacted** TDB statements. It is
  gitignored and must stay that way. Committed fixtures must be redacted: real headers,
  real date format, real Cyrillic payee strings, scrubbed account numbers, synthetic
  amounts.
- Reading legacy `.xls` during analysis needs `xlrd` in a throwaway venv.
- **Workflow:** branch off `main`, commit, open a PR, merge. PR #1 used a merge commit.
