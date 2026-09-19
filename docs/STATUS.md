# Where things stand

**Last updated: 2026-09-19**

Start here if you are picking this up cold. For AI sessions, [`CLAUDE.md`](../CLAUDE.md)
summarizes how to work in this repo.

## Phase

**The first working desktop ledger is built** and runs on macOS from [`app/`](../app/).
The owner is refining the ledger by using it and giving feedback; **the budget comes only
after the ledger is dialed in.**

**Git state:** everything is merged to `main` (through PR #13: pay and paydays) and
nothing is uncommitted. Keep the pattern: branch, commit, PR, merge. The owner's data
file is at schema version 5.

Visual direction and the register's UX rules are settled in
[ADR 0004](decisions/0004-ledger-ui.md). Read it before changing any UI.

## What exists

### Built and working (desktop, macOS verified)

| Area | What works |
| --- | --- |
| Storage | Drift/SQLite (schema version 4: accounts can be archived or deleted; v3: entries remember the reconcile that locked them; only account sides are reconciled). Before any schema upgrade the file is copied next to itself (`betterbudget.before-v4-from-v3-<time>.sqlite`); the upgrade runs in one transaction, double-entry per ADR 0003; zero-sum enforced inside each write; soft delete; `cleared` per entry; WAL mode |
| Sidebar | A Settings gear above Net worth opens the Settings page (Backups for now). Sections Ledger / Budget / Savings; the current one expands, its accounts spilling down in a short cascade. Ledger lists accounts grouped (Cash & bank, Credit) with balances. Budget opens the categories (rule 22); Savings is a placeholder ("Later", "Not built yet" page). Right-click an account for its menu. Net worth pinned at the bottom |
| Accounts | "+ Add account" under Ledger: name and kind (Bank account, or Card or loan). A new account first asks what's in it (or what's owed) on a date; that becomes a cleared opening balance and the entry row opens. Click the name to rename; ⋯ has Rename, Change kind (flips an unreconciled opening balance with it), Archive…, Delete…. Archive and delete are always allowed and say exactly what happens first (rule 21): archived accounts leave the sidebar and account lists but stay in net worth ("incl. ₮X in archived"), and come back from Settings; delete removes the account's own rows and keeps its transfers on the other accounts as "X (deleted)", so no other account changes |
| Categories | The Budget section's first version (no amounts yet): Spending and Income, each category with "42 rows · last 09.12 · 1 scheduled". Add category, click a name to rename, ⋯ or right-click for Change to income/spending, Archive (leaves the menus, rows keep the name), Delete… (with rows: pick where they move, a merge). A new name typed in the entry row offers "+ New category" and a gold "new category" note; saving makes it, one ⌘Z undoes both (rule 22) |
| All accounts | Under Ledger, above the groups: every account's rows in one register, Account as the last column, a transfer once. Adding asks for the account (a dropdown that remembers the last). Clicking a category's usage on the Budget screen opens it with a "Category: X ✕" chip and "n rows · ₮X spent"; Esc clears (rule 23) |
| Pay | Payday mark on income categories (only paydays end forecasts). Pay setup (forecast "no payday ahead · Add your pay", Budget screen, Settings): account, from, same or varies ("Expect at least", history, warning if high), monthly / twice a month / every N weeks, weekend rule; the next payday is always scheduled from the plan. Settings: Budget by Month or Pay period, pay list with Edit (rule 24). Schema v5 |
| Header | A cleared + uncleared = working sum whose total is the large number, plus the date last reconciled and a Reconcile button; on a credit card every amount is what's owed, positive, with "Owed" as the total; the lines double as the symbol key (hover highlights, click filters) |
| Forecast | Today → next scheduled income: lowest point, or a coral warning with the date it runs out (or "Below zero now"); 30-day horizon if no income is scheduled. Scheduled money in (transfers, refunds) steps the line up; only an income-category row ends it. Money in due today or earlier and not confirmed isn't counted (the header says so in gold and opens it); on payday "Runs out 10.15 unless ₮2,500,000 due today comes". A credit card shows what will be owed over 30 days. Under the headline, "3 bills · ₮2,790,200 before 10.10" (never payee names); clicking it lists every bill and the income with the balance after each. Chart ends are labeled with plain dates. Hover a dot for the bill, click a dot or a listed bill to open it |
| Register | Full dates, running balance, one signed amount column, every other row tinted a faint blue with a hover clearly lighter than the tint, transfer and split glyphs, split lines in the memo; tabs All / Uncleared (n) / Scheduled (n); search across payee, memo, category, amount |
| Entry | Gold Add button or ⌘N opens the row (stays open for a batch, closes on Esc or when left empty); any field order; Enter from anywhere; memo line under Payee; missing fields outlined; a transfer spells out its direction ("₮640,200.00 from TDB Checking to Golomt Visa") with Swap; payee autocomplete with last-used category; `+` before an amount for money in; calculator (`12000+8500`); `→ Account` as category makes a transfer; future date → scheduled; calendar under the date field (future days gold) |
| Editing | Double-click a row (or Enter, or Edit in its action bar) opens it in place with date, payee, memo, category and amount, and the cursor in the clicked field; Enter/Save keeps changes, Esc cancels, Undo restores; splits edit date, payee and memo only; reconciled rows edit payee, memo and category only (date and amount locked); moving a date into the future schedules it. Also: inline category menu, click a symbol to clear or unclear, Confirm on a scheduled row opens it dated today with the amount selected, so a bill that varied is confirmed as it really was |
| Move to | "Move to" in a row's action bar moves this account's side to another account (entered in the wrong one); it arrives uncleared there; not on reconciled rows, opening balances or adjustments, or onto a transfer's own other side (enforced in the database); undoes with its cleared state |
| Backups | A copy a day (at launch, checked hourly) in `Backups/` beside the database: newest 14 plus the first of each of 12 months, written under a temporary name and renamed once complete. All of it under **Settings** (gear above Net worth; a coral dot when copies stop). "Back up to…" saves a copy anywhere. "Restore from…" checks the file, shows what it holds against what's here, saves what's here first and can be undone |
| Selection | One row at a time (multi-select removed, may return with import). Clicking a row attaches a bar under it with what applies: Edit, Categorize, Mark cleared or uncleared, Delete, ✕; keys Enter, C, Delete, Esc. Reconciled rows can't be edited or deleted, and a transfer reconciled on one side is locked on both (enforced in the database) |
| Undo | ⌘Z / Ctrl+Z undoes the session's actions newest first (add, edit, categorize, clear, delete, confirm, reconcile, undo reconcile); ⌘⇧Z / Ctrl+Y redoes. In a text field both act on typing. Toasts only for saved changes, deletes, confirms and reconciles, each with its own Undo; clearing a row is quiet |
| Reconcile | Reconcile button in the header: statement date, bank balance (starts empty, cursor in it), cleared here, off by with which way and a hint naming a row that matches the difference; the register narrows to unreconciled rows through that date; and its last column becomes Cleared balance. Lock is enabled only at zero and locks those cleared rows; otherwise "Add ₮X adjustment and lock" posts a Reconcile adjustment against Balance adjustments (equity). Credit accounts take what you owe as a positive number. The newest reconcile can be taken back later from any row it locked ("Undo this reconcile"); reconciles unwind newest first |
| Shortcuts | ⌘N new, ⌘K / ⌘F search, ⌘Z undo, ⌘⇧Z redo (Ctrl+Y on Windows), Esc clear (Ctrl on Windows) |
| Tests | 106: rows growing smoothly, reduced motion; payday warning, late money in dated today; late money in, still owed on a short confirm; confirming with a changed amount and date, notes on old rows; restore (damaged files refused, cancel, undo), retention, a failing daily copy; moving between accounts (undo, redo, refusals), card reconcile signs, register speed on 20,000 rows, backups (daily, kept, cut short, saved elsewhere), undo and redo for every action, Windows and Mac keys, switching account mid-reconcile, the transfer sentence; and money parsing, ledger/DB invariants, editing, forecast, reconcile, taking reconciles back, transfer locks, UI lock state matching what the database refuses, statement dates refused out of order, upgrading v1 and v2 files with data (and their backups), screen flows including real key presses, undo and redo, a stale toast Undo refused, sidebar sections and their animation, the date calendar, early confirm, the Add row, row actions, forecast dots and bill list, reconcile with its finding aids and adjustment, credit cards shown as owed, editing a reconciled row, forecast money in, 14 golden screenshots |

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
| [0004](decisions/0004-ledger-ui.md) | Midnight look and 24 ledger rules: purpose, forecast (late money in not counted), one amount column, full dates, clock/check/diamond symbols, header as a cleared + uncleared = working sum, any-order entry, one-row selection with an action bar, session undo with toasts only for saved changes, confirm (opens the bill; still owed), in-place editing that grows smoothly, shortcuts that never steal typing, sectioned sidebar, date calendar, reconcile in the header, transfer direction, Move to, backups in Settings, notes on old rows, accounts managed where they're used (warn, don't block), categories on the Budget screen, an All accounts view, pay and paydays. |

Full ledger feature map, with what's built marked: [ledger-features.md](ledger-features.md).

## Roadmap (ledger, before the budget)

Items the owner has put on the roadmap. They are not scheduled in any order yet. Each
must follow [ADR 0004](decisions/0004-ledger-ui.md), especially "every element earns its
place". Design each before building it and show it to the owner.

### 1. Search

**Today:** one box that does a plain substring match on payee, memo, category and amount
digits, in the current account only.

**To build:**
- **Search in All accounts** (the view exists, rule 23): the search box and filter chips there should search every account.
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
   feel. Likely candidates: splits, accounts/categories management, import, recurring,
   plus search and sorting on the roadmap. Ask rather than assume.
3. **What is "Savings"?** A placeholder name in the sidebar; the owner will define it later
   (goals? savings accounts?). Relates to the budget model below.
4. **Budget model: envelopes or targets?** Blocks the budget. The double-entry schema
   suits envelopes. **The budget runs per pay period or per month, not all time**
   (owner, 2026-09-19; which of the two is still open). A category's rows, opened
   from Budget, should show that period, not all time.
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

**Work through the list below, one item at a time** (owner, 2026-09-18). Design each,
show the owner, build the one they pick, review, merge, tick it off here, then start
the next. Details for each item are further down (open items, roadmap, tabled).

- [x] 1. **Accounts**: add, rename, archive; a new account starts empty with an opening balance
- [x] 2. **Categories**: add, rename, archive (on the Budget screen, rule 22), plus the
  **All accounts** view the owner asked for with it (rule 23)
- [ ] 3. **Splits**: create and edit them
- [ ] 4. **Recurring** scheduled items. **Pay is done** (PR #13, rule 24): payday mark,
  pay setup, the next payday always scheduled, budget by month or pay period. Still to
  do: recurring bills (rent, СӨХ, utilities, phone), probably on the same schedule
  model. **Two pay questions are waiting for the owner** (asked 2026-09-19, both
  recommended yes): (a) twice a month with **an amount for each day** (advance, then
  the rest); (b) **"I don't have regular pay"** in the setup, which turns off the "Add
  your pay" prompt (undo it in Settings), for self-employed users.
- [ ] 5. A better **"not cleared" note**
- [ ] 6. **Duplicate check on Confirm**
- [ ] 7. **Several overdue bills** in All
- [ ] 8. **Backup reminders**
- [ ] 9. Small polish: Show on the Move toast, `+` prefill for refunds, moving into Cash wallet
- [ ] 10. **Search**
- [ ] 11. **Sorting**
- [ ] 12. **Cash accounts** (after 1)
- [ ] 13. **CI** running `flutter test` on pull requests
- [ ] 14. **Encryption** (SQLCipher, Windows spike first, backups too)
- [ ] 15. **TDB import** (first: does TDB export CSV or `.xlsx`?)

### How to work with the owner

- They use the running app, point at what feels wrong, and expect it fixed right away.
  Rebuild and relaunch after each change, and look at a screenshot or golden before
  saying it's done.
- Offer two or three options with a recommendation and sketches for anything new, build
  the one they pick, and record it in ADR 0004 with what was rejected.
- **Don't re-ask decisions they've made** (their correction, 2026-09-17: "you keep
  asking me the same five questions"). Decide review follow-ups along their reasoning
  and report them briefly. Run the two review passes once per feature, not again on
  their own follow-ups.
- For a hard product question they may ask for "a committee": several agents with
  different seats (household money in Mongolia, design, ledger integrity), then a
  summary of where they agree and split.

### Open items, roughly by value (none decided yet)

1. **A better "not cleared" note.** Today any uncleared row 14+ days old says "not
   cleared for 34 days". It's noisy for monthly reconcilers, fires on foreign card holds
   (20–30 days) and on every cash row. Recommended: note rows dated on or before the
   last statement ("· not on the 09.10 statement"); count days only on accounts never
   reconciled (30 on credit); none on cash until cash accounts exist.
2. **Duplicate check on Confirm.** Confirming an overdue bill can duplicate one already
   typed from the bank app. Recommended: when Confirm opens, name a posted row with the
   same payee within 7 days and offer to delete the scheduled one instead.
3. **Several overdue bills.** In All only the first scheduled row shows, and its "due 7
   days ago" replaces "next of N". Recommended: "· due 7 days ago · 2 overdue".
4. **Backup reminders.** "Last copied elsewhere 41 days ago" once past 30 days (daily
   copies share a disk with the data).
5. **Smaller:** a "Show" button on the Move toast; prefill `+` when a payee's last
   transaction was money in (refunds typed without it count twice); moving a row into
   Cash wallet leaves it uncleared with no statement (ties to cash accounts).
6. **Roadmap:** search and sorting (sections above); CI running `flutter test` on pull
   requests; the SQLCipher spike before more data work builds on plain SQLite.

**Tabled, each for its own conversation** (owner's call): creating and editing splits;
recurring scheduled items (keep
the planned amount on the schedule, not the last actual; a late or short occurrence
mustn't hide the next); SQLCipher
encryption (must also encrypt or remove the backups) and TDB import (blocked on the
export format question). Splits now block other work: a receipt typed as
two rows won't match the bank's one line. Cash accounts can now build on the account
kind added with item 1.

**Known limits, accepted:** a scheduled split confirms at its planned total only;
"Back up to…" overwriting a file isn't atomic in the sandbox; the newest 5
`before-restore` copies are kept, not the oldest; undoing a reconcile in a later
session loses the statement balance (finding J, leave for now). ⌘Z in the real app has
been used for typing but a register undo there hasn't been tried.

### Recent work (details in ADR 0004 and the PRs)

- **PR #13 (2026-09-19):** pay (rule 24). Only payday income ends a forecast, and a
  pay setup is prompted from the forecast, the Budget screen and Settings. Pay that
  varies is an estimate on the low side. The next payday is always scheduled from the
  plan, and early or late pay belongs to its planned payday. Budget by month or pay
  period is set in Settings. Schema v5.
- **PR #12:** categories on the Budget screen, managed there, and created from the
  entry row (rule 22). The All accounts view under Ledger has an Account column, an
  account picker when adding, and category and period chips (rule 23).
- **PR #11:** accounts: add, rename, change kind, archive, delete (rule 21, "warn,
  don't block"), with a right-click menu in the sidebar. Schema v4.

- **PR #9 (2026-09-18):** rows grow smoothly when opened into the editor or action bar
  (`SmoothHeight`, rule 12).
- **PR #8:** late money in isn't counted in the forecast and the header names it
  ("+₮2,500,000 in, 2 days late · not counted", opens the row; on payday "Runs out
  10.15 unless ₮2,500,000 due today comes"). Confirm: late money in is dated today;
  money in confirmed short offers "Still owed, due 10.10" (chosen when more than a
  tenth is missing) or "Paid in full". Rules 2 and 10.
- **PR #6:** review findings F–N: transfer direction sentence with Swap (H), Move to
  (I), notes on old rows (G), Confirm opens the bill with the amount selected (L),
  faster register (M), test gaps (N); cash accounts put on the roadmap (F). Backups:
  daily copies (14 plus one a month for a year), Back up to…, Restore from… (checked,
  saves first, undoable), a failing copy flagged, all under a **Settings** page (gear
  labelled "Settings" above Net worth). Rules 10, 17–20.
- **PR #5 and earlier:** findings A–E (empty bank balance, reconcile adjustments, cards
  shown as owed, editing reconciled rows' payee, scheduled money in), row striping,
  reconcile, undo/redo, schema v3.

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
