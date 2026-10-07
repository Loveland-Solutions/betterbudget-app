# Where things stand

**Last updated: 2026-10-07** · version 0.15.0 · schema v18 · 477 tests pass

**This file holds the current state and the next steps, nothing else.** No log of PRs:
git, the PRs and [ADR 0004](decisions/0004-ledger-ui.md) hold the history. When a PR
merges, rewrite "Next step" and correct the tables; don't add a dated block. Keep it
under about 20,000 characters. Everything this file said up to 2026-10-07 is in
`docs/archive/STATUS-2026-10-07.md`, which is not for reading unless the owner asks.

## Next step

**After PR #48 (version 0.15.0).** The owner is using the app on real money and sending
what they hit; expect more of that first. Then, in order:

1. **The rest of setup.** The owner picked mockup A (setup inside the app's own window;
   ADR 0004, "Onboarding: the first half hour"; the mockups are at
   <https://claude.ai/artifact/QUejrKZteHYtATY65EV3kS>, the committee's reports in
   [committee/onboarding/](committee/onboarding/)). "Your accounts" and "Your pay"
   are built, with the step names across the top. **Next is the Bills step** (with "is
   there a set payment each month?" for an account that owes; a loan payment the bank
   takes after payday is collected here, and until it is, nothing in setup takes it
   out of the forecast). When it is built, the Pay step's filled button becomes
   Continue. After it, each its own PR: Everyday, Saved, Assign, Tomorrow, then Import
   and the which-period question. Two questions asked with the mockups are unanswered; bring each up when
   its step is built: whether a budget that starts next month assigns today's money
   now or waits, and which accounts the "what is this saved money for?" step asks
   about. The owner can't see setup in their own app (their ledger has an account):
   show each step by its screenshots in `app/test/goldens/setup_*.png`, and report it
   starting from what they last saw (the Pay step's three screenshots, sent with
   PR #48).
2. **A place to see and drop the "Always file" rules** ([ROADMAP](ROADMAP.md) "Still on
   the list").

**The owner's ledger is production data** (since 2026-10-06; rules in
[CLAUDE.md](../CLAUDE.md)). It holds one tugrik account; the dollar accounts and their
categories were deleted on 2026-10-07. A wordless screenshot from the owner, after
being told something couldn't be checked in the real app, is the result being shown,
not a complaint.

**Git:** `main` has everything through PR #48. Branch, commit, PR, merge.

## Waiting on the owner

Asked and not answered. Don't re-ask; bring one up when its screen comes up again.

1. **Three from the Pay step's budget review** (2026-10-07). Payday today: with pay
   "On the 7th" set up on 10.07, the form says "Next payday 2026.10.07" though the
   balance just typed may already hold that pay, so it would be counted twice; should
   a payday on the balances' date be taken as already in? An irregular earner picks
   "It varies" and is then made to give a day: should When have "No set day", doing
   what "I don't have regular pay" does? And Name is the form's first field though it
   does nothing until there is a second pay: show it only from "Add other pay" on?
2. **"Always file" in the category dropdown** (2026-10-07). The offer also at the foot
   of a row's category dropdown, reading "Always filed here · Stop" once the rule
   exists. Today the popup's 12 seconds are the only chance. Recommended yes; it would
   also be the first way to drop a rule.
3. **The row's date and amount on the popup's second line** (2026-10-07): "09.15 ·
   −₮200 · IB-INTERBANK…", since a bank repeats payees, and the same two-line form for
   the other row popups. Recommended yes.
4. **Is a test payee invented?** (2026-10-07) "IB-INTERBANK TRANSFER CHARGE 1.2.3,
   1.2.4" in `ledger_screen_test.dart` has the shape of a real statement line. If it
   came from a statement it has to go.
5. **Should the forecast take out what's budgeted?** (2026-10-05) Set to Next 6 months,
   TDB Checking shows pay coming in and rent and water going out and nothing else, so
   the line climbs about ₮800,000 a month richer than the household will be. Should it
   also take out what's budgeted for groceries, transport and the rest?
6. **Which account a new bill starts in** (2026-10-05). A new Rent category due on the
   20th says Paid from "All accounts" when there are two or more, so the rent is in no
   account's forecast until one is left checked alone. Should it start with the account
   the rent rows were paid from?
7. **A bill that arrives by import** (2026-10-04). A Paid-from bill that comes in
   through a bank file leaves its scheduled row behind. Matching the import to the
   scheduled row would fix it; that is new work.
8. **Two notes beside Add** (2026-10-03): "needs amount" is still in the old voice, and
   the gold "new category · money in counts as a refund to it…" note gets cut off.
9. **Money in that is still Not categorized** (2026-10-03): should the Budget page's
   Income figure name it? Imported pay lands there.
10. **Currencies in the ledger file** (2026-10-02). The owner asked "You're putting the
   currencies in the database, right?" They are built into the app; the file stores
   each account's code. Asked twice what the file should hold; a table would be a
   schema change.
11. **What "dedicated" means** (2026-10-02). Emergency fund limited to Khan Savings,
    holding ₮10,000,000 of its ₮12,600,000: is the other ₮2,600,000 the fund's too, or
    free to assign, as built?
12. **Header height.** About seven rows show at 1440 × 900. Collapsing the header on
    scroll was offered; the owner hasn't asked for it.

## Phase

**A working desktop ledger and budget are built** and run on macOS from
[`app/`](../app/). The owner is using it with real money and refining it by what they
hit. The road to beta and the platforms after it is in [ROADMAP.md](ROADMAP.md).

## What exists (desktop; each line checked against the code on 2026-10-07)

| Area | What works |
| --- | --- |
| Storage | Drift/SQLite at schema v18, encrypted in SQLCipher v4 format, WAL mode. Double-entry ([ADR 0003](decisions/0003-double-entry-schema.md)): a write that doesn't sum to zero is refused. Deletes are soft. Before an upgrade the file is copied beside itself (`betterbudget.before-v18-from-v17-<time>.sqlite`) and the upgrade runs in one transaction. A ledger saved by a newer build is refused |
| Sidebar | Sections Ledger, Budget, Savings. Under Ledger: All accounts, then accounts grouped Bank, Cash, Credit. A Settings gear above Net worth |
| Accounts | Add account: name, Type (Bank account, Cash, Credit card or loan), Currency. It starts from an opening balance, or from a bank file ("Or import a file from your bank"). Menu: Rename, Change to bank account / credit card or loan, Archive…, Delete…, and "Payments come out of" for a card or loan. A cash account is offered neither Reconcile nor Import |
| Register | One signed amount column (money in green with a plus, money out in the coral red with a minus) and a running balance. Tabs All, Uncleared, Scheduled, Not categorized. Search with ⌘F |
| Entry | Add or ⌘N opens the row. Missing fields are named ("needs date"). An amount takes a sum, and `+` in front for money in. `→ Account` as the category makes a transfer. A calendar under the date |
| Editing | Double-click a row to edit it in place, with Cancel. A reconciled row's date and amount are locked. Split lines can't be edited |
| Row actions | Edit, Categorize, Mark cleared, Move to, Delete; Confirm on a scheduled row. Keys Enter, C, Delete |
| Undo | ⌘Z and ⌘⇧Z (Ctrl+Y on Windows) through the session's actions; in a text field they act on typing |
| Popup | A card 440 wide with Undo. After a category is picked it offers "Always file this payee here", and the next import follows the rule |
| Header | Cleared + uncleared = working, the working balance as the large number; "Last reconciled on"; Reconcile and Import… buttons; a credit account reads Owed |
| Forecast | Its span is a dropdown: the pay period, 30, 60 or 90 days, 6 months, a year. It says the lowest point, or "Runs out" or "Below zero now". "N bills · amount through date" opens the list. Late money in is "not counted". Paydays and plan bills are projected past the scheduled ones |
| Reconcile | Statement date and balance; "Add … adjustment and lock" when they differ; "Undo this reconcile" from a locked row. The database refuses changes to locked rows |
| Budget | Spending and Income tabs. The top key: Cash & bank, in categories, Not assigned, and "Assigned too much". Each category reads Assigned · Spent · Left. Period arrows and "Back to today". A view by Month or by a pay's periods. "Assign what's planned". Each currency on its own |
| Categories | Add category, Edit, Delete…, Archive. Edit asks "Is there a due date?" and holds How often (with Every payday, Every pay period and Custom…), Stop at, Paid from and Currency. One built-in Income. "+ New category" from the entry row |
| Pay | A pay has a name, an account and Monthly, Twice a month (a second amount allowed) or every N weeks, with a weekend rule (before, after, Keep the day). "No regular pay". Stopping a pay moves the categories that ran by it |
| Savings | Six steps: one month of expenses, health coverage, no consumer debt, more months, retirement, the mortgage and student loans. Each is done, current, later or set aside. Counts one currency ("another currency, not counted yet") |
| Import | `.xls`, `.xlsx`, CSV and OFX, told apart by the file's contents. The column choice is saved per account. A check of the bank's running balance. Each row is New, Matches, Already in or left out. A Start from date. One undo for the whole import |
| Currencies | 155, each with its own decimals and symbol ([currencies.md](currencies.md)). A transfer between two currencies takes both amounts, through a hidden exchange account. An account's currency can't be changed after it's made |
| Backups | A copy a day, keeping the newest 14 and the first of each of 12 months. Back up to…, Restore from… (undoable), "Erase everything and start over…" (the old ledger is saved first) |
| Security | A recovery key shown at setup; a screen that asks for it when this device has none; Settings → Security has "Check my recovery key…" ([ADR 0001](decisions/0001-database.md)) |
| Appearance | Same as this Mac, Light or Dark; 101 color schemes, Blue eclipse the default |
| Language | Same as this Mac, English or Монгол; 1,051 messages, the same keys in both files |
| Shortcuts | ⌘N new, ⌘F search (⌘K also works), ⌘Z undo, ⌘⇧Z redo |
| Setup | A new, empty ledger opens on "Your accounts": one date for every balance, one line per account, × to remove, the cash question, Continue. Then "Your pay": the pay form on the page, answered by "Save pay" or "I don't have regular pay", after which the pays are listed with Edit and "Add other pay", and "Open my ledger" ends setup. The steps are named across the top (Accounts › Pay), with Back. It is on the step it was left on after a quit, and never returns once done. A ledger that already had accounts never sees it |
| Demo data | Tests only (`LedgerScreen.demo`): TDB Checking, Khan Savings, Cash wallet, Golomt Visa. The app no longer seeds it |

Rules behind each: ADR 0004. Where the code is: [MAP.md](MAP.md).

**Not carried over** from the old table, because they weren't checked against the
code: details of Accounts (archive and delete), Entry, Register, Forecast, Budget,
Savings, Import, Backups and Appearance. Before changing behavior in one of those
areas, search `docs/archive/STATUS-2026-10-07.md` for that area's claims and verify
them against the code first (owner, 2026-10-07; this is the one standing reason to
open the archive).

## Not built yet

- **Setup after pay:** bills, everyday amounts, saved money, assigning,
  "from tomorrow", import. Settings can't be reached until setup ends.
- **Splits** can't be created or edited (`splitNotEditable`).
- **A list of the "Always file" rules**, with a way to drop or rename one.
- **A scheduled row typed by hand doesn't repeat.** Repeating bills come only from a
  category's dated plan.
- Matching scheduled bills and own-account transfers on import.
- CSV export, app lock, printing the recovery key.
- **Phone apps** ([ADR 0005](decisions/0005-mobile-companion.md)), a Windows build.
- **Encryption has been run only on macOS and iOS** (recorded 2026-09-29); Windows,
  Linux and Android are unverified.
- **CI.** Nothing runs tests on pull requests.
- More in [ROADMAP.md](ROADMAP.md): search that understands amounts and dates, sorting,
  counting a cash account, moving money between categories.

## Known bugs and loose ends

- **Launched while the Mac is locked, the app stops at startup.** The Keychain refuses
  the key (-25308) and `_start` in `startup.dart` doesn't catch it, so the window stays
  on the startup screen until the app is quit and opened again. Seen 2026-10-01; the
  ledger wasn't touched. Worth an "unlock your Mac and try again" screen.
- **Buttons may sit wrong on a Mac while their goldens look right** (a Mac draws them
  8 shorter). Only the popup's two were looked at.
- **From the reviews of PR #44, none fixed:** the mouse wheel does nothing over the
  popup; in dark mode an amount's cents fall to about 2.6 contrast on a hovered row in
  the worst color scheme, and `schemes_test.dart` checks neither stripe nor hover; the
  forecast's bill list shows money out plain; "1 more row now" counts that payee's
  waiting rows in every period while the Not categorized tab counts this period's, and
  the offer silently replaces an earlier rule for the payee; reconcile's "Add ₮X
  adjustment" doesn't say which way; a transfer shown once in All accounts reads as
  red spending.
- **From the reviews of setup's Accounts step, not fixed:** reopened on a later day,
  "Balances as of" still shows the day setup began and nothing says the earlier
  figures are from then; the "You owe" hints fit a credit card and not a salary loan,
  лизинг or Storepay (the remaining balance, not payments × months or the next
  instalment); an account in the list can be removed but not edited; the bank hint
  says not the "available" balance while the page says to type what the bank app
  shows, and which figure Khan and TDB put forward hasn't been checked.
- **From the reviews of setup's Pay step, not fixed:** removing an account leaves its
  pay live with no paydays (in setup the pay is listed without Edit; the app's own
  account Delete has the same gap); two unnamed pays into one account are both titled
  "Income into TDB Checking"; the saved line says "monthly on the 25th · next 10.23"
  without saying a weekend moved it; opening the pay form makes the Income category,
  a write with no undo; `press` in `setup_test.dart` waits a real 300 ms.
- **The forecast still speaks to one person** ("Until your 10.15 paycheck") though a
  ledger can hold two earners' pay.
- **"Nothing has been budgeted…"** in the forecast shows whenever no bills are
  scheduled; it should go by whether there is a budget.
- **The Mongolian is a draft** awaiting a native speaker
  ([mongolian-review.csv](mongolian-review.csv)).

## Open items, roughly by value (none decided)

1. **A better "not cleared" note.** Today any uncleared row 14+ days old says "not
   cleared for 34 days". It's noisy for monthly reconcilers, fires on foreign card holds
   (20–30 days) and on every cash row. Recommended: note rows dated on or before the
   last statement ("· not on the 09.10 statement"); count days only on accounts never
   reconciled (30 on credit); none on cash.
2. **Duplicate check on Confirm.** Confirming an overdue bill can duplicate one already
   typed from the bank app. Recommended: when Confirm opens, name a posted row with the
   same payee within 7 days and offer to delete the scheduled one instead.
3. **Several overdue bills.** In All only the first scheduled row shows, and its "due 7
   days ago" replaces "next of N". Recommended: "· due 7 days ago · 2 overdue".
4. **Backup reminders.** "Last copied elsewhere 41 days ago" once past 30 days (daily
   copies share a disk with the data).
5. **Smaller:** a "Show" button on the Move toast; prefill `+` when a payee's last
   transaction was money in (refunds typed without it count twice).

**Known limits, accepted:** a scheduled split confirms at its planned total only;
"Back up to…" overwriting a file isn't atomic in the sandbox; the newest 5
`before-restore` copies are kept, not the oldest; undoing a reconcile in a later
session loses the statement balance.

## Local setup notes

- **Toolchain:** Flutter via Homebrew (`brew install --cask flutter`, 3.47 at time of
  writing). Xcode is installed and selected (`sudo xcode-select -s
  /Applications/Xcode.app/Contents/Developer`, license accepted). If the macOS build fails
  with `tapi error … MacOSX27.0.sdk`, `xcode-select` is pointing at the Command Line Tools
  again, and the native build hook for `objective_c` is picking up the wrong SDK.
- **Signing:** the Mac and iOS apps sign with the owner's Apple developer team
  `5FJUXAJX9P` ("Apple Development", automatic), needed for the Keychain entitlement.
  This Mac needed Apple's WWDR G3 intermediate installed (done 2026-09-28). If Xcode
  asks for a new provisioning profile, run once from `app/macos`: `xcodebuild -workspace
  Runner.xcworkspace -scheme Runner -configuration Debug -allowProvisioningUpdates build`.
- **macOS 27** (2026-09-28) draws text edges slightly differently: goldens were redrawn on
  it. Goldens made on another macOS version will differ by about 0.1%.
- **If tests stall** (random widget tests time out after 10 minutes with the CPU idle,
  even on older commits), restart the Mac: on 2026-09-29 a stuck `dart pub get` and
  leftover `flutter_tester` processes caused it. Check first with
  `ps -ax | grep -E "flutter|dart"`.
- **Run:** `cd app && flutter run -d macos`, or build with `flutter build macos --debug`
  and open `app/build/macos/Build/Products/Debug/BetterBudget.app`.
- **Rebuild and relaunch:** `pkill -f "BetterBudget.app/Contents/MacOS"; flutter build
  macos --debug && open build/macos/Build/Products/Debug/BetterBudget.app` (from `app/`).
- **App data:** `~/Library/Containers/com.lovelandsolutions.betterbudget/Data/Library/Application Support/com.lovelandsolutions.betterbudget/betterbudget.sqlite`
  (plus `-wal`, `-shm`). **This file is production data.** Never delete, reseed, erase or
  hand-edit it; tests use demo data, and anything tried by hand goes on a copy.
- **Screenshots of the running app:** `screencapture -l<window id>` works once the
  terminal has screen-recording permission; get the window id from
  `CGWindowListCopyWindowInfo` for owner `BetterBudget`.
- `tdb-bank-transaction-exports/` and `afcu-bank-transaction-exports/` hold **real,
  unredacted** statements. Both are gitignored and must stay that way. Committed
  fixtures must be redacted: real headers, real date format, real Cyrillic payee
  strings, scrubbed account numbers, synthetic amounts.
- Reading legacy `.xls` during analysis needs `xlrd` in a throwaway venv.
