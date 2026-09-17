# Where things stand

**Last updated: 2026-09-17**

Start here if you are picking this up cold. For AI sessions, [`CLAUDE.md`](../CLAUDE.md)
summarizes how to work in this repo.

## Phase

**The first working desktop ledger is built** and runs on macOS from [`app/`](../app/).
The owner is refining the ledger by using it and giving feedback; **the budget comes only
after the ledger is dialed in.**

**Git state:** `main` has everything through PR #5. Branch `ledger-findings-f-n`
holds findings H, I, K, M and N plus fixes from their review passes (see Next step);
not merged yet. Keep the pattern: branch, commit, PR, merge.

Visual direction and the register's UX rules are settled in
[ADR 0004](decisions/0004-ledger-ui.md). Read it before changing any UI.

## What exists

### Built and working (desktop, macOS verified)

| Area | What works |
| --- | --- |
| Storage | Drift/SQLite (schema version 3: entries remember the reconcile that locked them; only account sides are reconciled). Before any schema upgrade the file is copied next to itself (`betterbudget.before-v3-from-v2-<time>.sqlite`); the upgrade runs in one transaction, double-entry per ADR 0003; zero-sum enforced inside each write; soft delete; `cleared` per entry; WAL mode |
| Sidebar | Sections Ledger / Budget / Savings; the current one expands, its accounts spilling down in a short cascade. Ledger lists accounts grouped (Cash & bank, Credit) with balances. Budget and Savings are placeholders ("Later", "Not built yet" page). Net worth pinned at the bottom |
| Header | A cleared + uncleared = working sum whose total is the large number, plus the date last reconciled and a Reconcile button; on a credit card every amount is what's owed, positive, with "Owed" as the total; the lines double as the symbol key (hover highlights, click filters) |
| Forecast | Today → next scheduled income: lowest point, or a coral warning with the date it runs out (or "Below zero now"); 30-day horizon if no income is scheduled. Scheduled money in (transfers, refunds) steps the line up; only an income-category row ends it. A credit card shows what will be owed over 30 days. Under the headline, "3 bills · ₮2,790,200 before 10.10" (never payee names); clicking it lists every bill and the income with the balance after each. Chart ends are labeled with plain dates. Hover a dot for the bill, click a dot or a listed bill to open it |
| Register | Full dates, running balance, one signed amount column, every other row tinted a faint blue with a hover clearly lighter than the tint, transfer and split glyphs, split lines in the memo; tabs All / Uncleared (n) / Scheduled (n); search across payee, memo, category, amount |
| Entry | Gold Add button or ⌘N opens the row (stays open for a batch, closes on Esc or when left empty); any field order; Enter from anywhere; memo line under Payee; missing fields outlined; a transfer spells out its direction ("₮640,200.00 from TDB Checking to Golomt Visa") with Swap; payee autocomplete with last-used category; `+` before an amount for money in; calculator (`12000+8500`); `→ Account` as category makes a transfer; future date → scheduled; calendar under the date field (future days gold) |
| Editing | Double-click a row (or Enter, or Edit in its action bar) opens it in place with date, payee, memo, category and amount, and the cursor in the clicked field; Enter/Save keeps changes, Esc cancels, Undo restores; splits edit date, payee and memo only; reconciled rows edit payee, memo and category only (date and amount locked); moving a date into the future schedules it. Also: inline category menu, click a symbol to clear or unclear, confirm scheduled (early confirm posts today and says so) |
| Move to | "Move to" in a row's action bar moves this account's side to another account (entered in the wrong one); it arrives uncleared there; not on reconciled rows, opening balances or adjustments, or onto a transfer's own other side (enforced in the database); undoes with its cleared state |
| Backups | A copy a day (at launch, checked hourly) in `Backups/` beside the database: newest 14 plus the first of each of 12 months, written under a temporary name and renamed once complete. "Daily copy failed" in coral when copies stop. "Back up to…" saves a copy anywhere. "Restore from…" checks the file, shows what it holds against what's here, saves what's here first and can be undone |
| Selection | One row at a time (multi-select removed, may return with import). Clicking a row attaches a bar under it with what applies: Edit, Categorize, Mark cleared or uncleared, Delete, ✕; keys Enter, C, Delete, Esc. Reconciled rows can't be edited or deleted, and a transfer reconciled on one side is locked on both (enforced in the database) |
| Undo | ⌘Z / Ctrl+Z undoes the session's actions newest first (add, edit, categorize, clear, delete, confirm, reconcile, undo reconcile); ⌘⇧Z / Ctrl+Y redoes. In a text field both act on typing. Toasts only for saved changes, deletes, confirms and reconciles, each with its own Undo; clearing a row is quiet |
| Reconcile | Reconcile button in the header: statement date, bank balance (starts empty, cursor in it), cleared here, off by with which way and a hint naming a row that matches the difference; the register narrows to unreconciled rows through that date; and its last column becomes Cleared balance. Lock is enabled only at zero and locks those cleared rows; otherwise "Add ₮X adjustment and lock" posts a Reconcile adjustment against Balance adjustments (equity). Credit accounts take what you owe as a positive number. The newest reconcile can be taken back later from any row it locked ("Undo this reconcile"); reconciles unwind newest first |
| Shortcuts | ⌘N new, ⌘K / ⌘F search, ⌘Z undo, ⌘⇧Z redo (Ctrl+Y on Windows), Esc clear (Ctrl on Windows) |
| Tests | 95: restore (damaged files refused, cancel, undo), retention, a failing daily copy; moving between accounts (undo, redo, refusals), card reconcile signs, register speed on 20,000 rows, backups (daily, kept, cut short, saved elsewhere), undo and redo for every action, Windows and Mac keys, switching account mid-reconcile, the transfer sentence; and money parsing, ledger/DB invariants, editing, forecast, reconcile, taking reconciles back, transfer locks, UI lock state matching what the database refuses, statement dates refused out of order, upgrading v1 and v2 files with data (and their backups), screen flows including real key presses, undo and redo, a stale toast Undo refused, sidebar sections and their animation, the date calendar, early confirm, the Add row, row actions, forecast dots and bill list, reconcile with its finding aids and adjustment, credit cards shown as owed, editing a reconciled row, forecast money in, 14 golden screenshots |

Seeded on first launch with **synthetic** demo data dated relative to today: TDB
Checking, Khan Savings, Cash wallet, Golomt Visa, 14 expense categories, Salary, and 4
scheduled items.

### Not built yet

- **Encryption.** Plain SQLite for now, and so are the backups in `Backups/` and any
  saved with "Back up to…": the SQLCipher work must encrypt or remove the old copies,
  and check that `VACUUM INTO` keeps the key (owner agreed, 2026-09-17). ADR 0001 requires SQLCipher; do the Windows spike
  first. `package:sqlite3` supports `hooks: user_defines: sqlite3: source: sqlcipher` (or
  `sqlite3mc`) in `pubspec.yaml`.
- Creating or editing **splits**: split lines are display-only. A split's date, payee and
  memo can be edited.
- Adding, renaming or archiving **accounts and categories** (seed data only).
- **Import** (TDB per ADR 0002), **recurring** schedules (scheduled
  items are one-off), payees merge, rules, tags, attachments.
- CSV export, app lock.
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
| [0004](decisions/0004-ledger-ui.md) | Midnight look and 16 ledger rules: purpose, forecast, one amount column, full dates, clock/check/diamond symbols, header as a cleared + uncleared = working sum, any-order entry, one-row selection with an action bar, session undo with toasts only for saved changes, early confirm, in-place editing, shortcuts that never steal typing, sectioned sidebar, date calendar, reconcile in the header. |

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

### 2. Cash accounts (owner, 2026-09-17: "not yet")

From budget-app finding F: cash entries saved as cleared, and "Count" instead of
Reconcile, with the difference posted to a category the user picks. Needs the account
type from accounts management. Until then Cash wallet uses the bank flow.

### 3. Sorting

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

**Waiting on the owner:** pick designs for **G** (stale items, options A/B/C) and **L**
(confirming a bill whose amount differs, options A/B/C), then merge
`ledger-findings-f-n`. The owner said yes to restore, the failed-copy warning, monthly
copies and the encryption note; all built.

**Branch `ledger-findings-f-n` (2026-09-17):** the owner said "do it" to H, I, K and
"fix it" to M and N. 87 tests, analyze clean, checked in the macOS app (its first
daily copy was made from the owner's file). ADR 0004 rules 17–19.

- **H.** A transfer says which way it goes, with Swap.
- **I.** Move to.
- **K.** Daily copies and "Back up to…". **"Back up to…" hasn't been clicked through
  in the sandboxed app yet**: the owner should save one to the Desktop and to a USB
  stick.
- **M.** Register, summary and reconcile lookups are worked out once per ledger
  load (a 20,000-row register went from 5.4 s to well under 1 s).
- **N.** The test gaps listed below, all filled.
- **Fixed from the review passes:** a backup cut short no longer counts as the day's
  copy; the database refuses moving opening balances and adjustments; Swap before an
  amount still asks for one; unexpected errors show a short toast; cached register
  lists can't be reordered.

- **Then, on the owner's yes:** "Restore from…", "Daily copy failed", and monthly
  copies (ADR 0004 rule 19). 95 tests. Fixed from its code review: a backup with
  unbalanced transactions or broken references is refused (and the replace itself
  refuses and rolls back); input is blocked while a restore runs, and an open edit or
  reconcile closes first; undoing or redoing a restore saves what's there first; a
  backup waiting in the dialog isn't swept by the daily copy; the check runs off the UI
  thread. Not done (low): the newest 5 `before-restore` files are kept, not the
  oldest; Enter confirms the restore dialog.
- **Not yet tried in the real app:** "Back up to…" and "Restore from…" through the
  macOS dialogs. The tests use a stand-in dialog.

**Raised by the reviews, not decided yet** (budget-app expert unless marked):
- **Remind about copies elsewhere**: "Last copied elsewhere 41 days ago" past 30 days.
- **Moving into Cash wallet** leaves the row uncleared with no statement to clear it
  (ties to F). **A "Show" button** on the move toast to go to the other account.
- **Refunds typed without `+`** double-count; e.g. prefill `+` when the payee's last
  transaction was money in.
- (code) "Back up to…" overwriting a file can't be atomic in the sandbox; a pulled USB
  stick leaves that file broken. Accepted and noted in `backup.dart`.

**PR #5 (merged, 2026-09-17):** the owner's calls on review findings A–E, plus row
striping. 67 tests pass, `flutter analyze` is clean, checked in the macOS app. Rules are
in ADR 0004 (2, 4, 6, 8, 16).

- **A. Bank balance starts empty** with the cursor in it, so a reconcile needs the
  bank's number typed. "Not the “available” balance" beside it.
- **B. Off by won't reach zero.** Direction ("Bank is lower"), a hint naming the one row
  that matches the difference, a Cleared balance column while reconciling, and "Add
  ₮X adjustment and lock", which posts a "Reconcile adjustment" against the equity
  account "Balance adjustments" (created on first use) and undoes with the reconcile.
  An adjustment left behind by undoing a reconcile in a later session stays as a cleared
  row the user can delete.
- **C. Credit cards show what's owed**, positive, never coral: header, register,
  sidebar and a card forecast ("₮0 owed after 09.25").
- **D. Reconciled rows edit payee, memo and category**; date, amount and accounts stay
  locked (in the database too), and Delete stays off.
- **E. The forecast counts scheduled money in** (transfers, refunds) as steps up, and
  only income-category rows end it. The owner's data file has its 10.10 salary filed
  under Dining out, so that account shows "Next 30 days" with the salary as money in.
- **Row striping (owner's request).** Every other posted row is tinted `Mid.stripe`
  (blue at 4.5%); hover on register rows is `Mid.rowHover` (pale at 8%), because the
  old hover matched the stripe (owner's correction). Scheduled rows aren't striped.

PR #4 (merged): reconcile, taking reconciles back, transfer locks, session undo/redo,
the forecast bill list, and fixes from the two review passes.

⌘Z and ⌘⇧Z reach the app: the macOS Edit menu's Undo and Redo stay disabled (no
responder handles them), and ⌘Z undid typing in the entry row. Undoing a register
action in the real app hasn't been tried yet.

### Fixed from the review passes (2026-09-17, owner said fix all five)

1. **Locks that didn't match.** The seed (and so every data file) also reconciled
   category, opening-balance and statement-less sides. Rows looked unlocked but refused
   edits, and the other accounts' opening balances were locked for good. Now only asset
   and liability entries count, the seed only locks TDB Checking's side, and **schema
   version 3** puts the rest back to cleared. The owner's file had 11 bad locks, now 0.
   Its copy from before is `betterbudget.before-v3-from-v2-20260917-154104.sqlite`
   in the app data folder.
2. **A toast's Undo out of order** silently wiped later clears. It now works only while
   its action is the newest. Restoring a snapshot no longer touches cleared state and
   refuses a reconciled transaction.
3. **Undo and redo said "Undone" when the database refused.** They now check what
   changed and say "Couldn't undo … it changed since".
4. **Migration safety.** The upgrade runs in one transaction, the file is copied
   first (`VACUUM INTO`), and tests upgrade v1 and v2 files with data.
5. **Small ones.** Forecast dots do nothing while reconciling. Starting a reconcile
   closes the editor and the Add row. Lock can't run twice from a double-click. The
   database refuses statement dates after today or before the last statement.

### Review findings logged for the owner to decide later

From the budget-app expert, unless marked (code) for the code reviewer. Each has
options; recommendations in brackets. A–E were decided and built (see Next step).

- **F. Cash accounts go through the bank flow.** Owner: not yet; on the roadmap (§2).
- **G. Stale items skew Working.** Owner likes it; design options offered. Overdue scheduled rows are left out; old uncleared
  rows are left in. Say "due 5 days ago" / "not cleared for 34 days" on the row.
- **H. A transfer entered from the receiving account goes the wrong way.** Built on the branch. Show the
  direction as a sentence before Add ("₮640,200 from Golomt Visa to TDB Checking").
- **I. Moving a transaction to another account** meant deleting and retyping it. Built on the branch:
  "Move to…" in the action bar.
- **J. Undoing a reconcile in a later session throws away the statement balance.**
  Keep undone statements and offer the old balance. Recommended: leave it for now.
- **K. Backups beyond upgrades.** Built on the branch: Rolling automatic copies, and a "Back up to…"
  command before any real user.
- **L. Smaller:** Owner: bills vary, allow changes on confirm; design options offered. Confirm always posts the scheduled amount (varying bills); no
  duplicate warning for the same payee, amount and day.
- **M. (code) The register rebuild is slow for big files.** Fixed on the branch. Every row looks up the
  latest reconcile across all transactions, on every keystroke in search. Fine for demo
  data; fix before import.
- **N. (code) Test gaps** (filled on the branch): redo for add, edit, categorize and delete; undo for add and
  categorize; switching account mid-reconcile; Ctrl+Y on Windows; liability reconcile
  (sign flip) in the database.

Also noted as now blocking something: **splits** (a receipt typed as two rows won't
match the bank's one line, which affects the matching-row hint and import), and
**accounts with opening balances** (no real user can start from nothing; F needs the
account type, and C relies on it).

**Tabled for their own fresh conversations**, one each (owner's call):
1. Creating and editing splits.
2. Adding, renaming and archiving accounts and categories.
3. Recurring scheduled items.
4. An empty state for a new account (opening balance).
5. SQLCipher encryption and TDB import (import is blocked on the export format question).

Also offered and not yet answered: CI that runs `flutter test` on pull requests; the
SQLCipher spike before much more data work builds on plain SQLite. The
[roadmap](#roadmap-ledger-before-the-budget) has search and sorting.

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
