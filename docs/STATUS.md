# Where things stand

**Last updated: 2026-10-09** · version 0.21.0 · schema v18 · 560 tests pass

**This file holds the current state and the next steps, nothing else.** No log of PRs:
git, the PRs and [ADR 0004](decisions/0004-ledger-ui.md) hold the history. When a PR
merges, rewrite "Next step" and correct the tables; don't add a dated block. Keep it
under about 20,000 characters. Everything this file said up to 2026-10-07 is in
`docs/archive/STATUS-2026-10-07.md`, which is not for reading unless the owner asks.

## Next step

**After PR #57 (version 0.21.0).** Four of the open items are built (ADR 0004 rule 20, "Changed 2026-10-09"): the uncleared note goes by the last statement, a late bill counts the other late ones, Confirm names a row already in, the Move popup has Show, and a month without a copy off this computer is said under Net worth. The computer wears the owner's logo and its
colors from the first launch: a navy sidebar, green main buttons, and gold kept as an
accent for what is done (the reconciled diamond, the saved popup, the sidebar's marks);
a scheduled bill is gray with a blue Confirm (ADR 0004 "The logo's colors" and "Gold is
an accent, and the new colors come first"; the screens compared are at
<https://claude.ai/artifact/1xJW37g537PUgA5BRLkzvq>).
The owner's ledger is stored in their Google Drive folder; the Android app records
money out and money in, and what it records reaches the computer's ledger through the
folder. Then, in order (the owner was asked on 2026-10-08 whether transfers on the
phone come before item 1; "Waiting on the owner" 16):

1. **More than one computer on the same ledger** (owner, 2026-10-07: "I definitely
   want to be able to support multiple machines on the same ledger. Let's figure that
   out in a new conversation"). **Start that conversation with this**, before building
   anything else on the folder. Where it stands: each computer keeps its own working
   file and writes the whole of it over `Ledger.betterbudget` in the folder, at launch
   and after each change, without looking at what is there, so a second or
   out-of-date computer silently replaces the newer ledger. Nothing reads the folder's
   file back in except Restore from…. [ADR 0005](decisions/0005-mobile-companion.md)
   was written for one computer plus phones ("one writer per file") and rejected a
   full two-way merge as too much for phones; that has to be looked at again for
   computers. Until it is designed, only one computer should have the ledger moved to
   the folder. Bring two or three ways with sketches, as for any feature.
2. **The rest of the phone.** Its entries and new categories now reach the computer
   (ADR 0005, "Built, 2026-10-08"), seen working on the owner's Pixel and Drive folder
   on 2026-10-08. Not yet seen: whether asking Drive to refresh its listing makes the
   phone's waiting line go within a minute, or only the two-minute fetch does. Money
   in is built: the +/− button beside the amount, with Income offered in the Category
   list (ADR 0004 "Phone screens: Ledger first"); the button was tapped on the
   owner's Pixel, but no real refund or income has been saved there and watched
   arriving. Then: transfers on the phone, the other phone's entries, and the iPhone
   build (its folder access and icon). With two computers on one ledger each takes the same
   entries in, which item 1 has to settle.
3. **The rest of setup.** The owner picked mockup A (setup inside the app's own window;
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
4. **A place to see and drop the "Always file" rules** ([ROADMAP](ROADMAP.md) "Still on
   the list").
5. **The rest of the new look.** The computer is fully on the logo's colors (ADR 0004
   "Gold is an accent, and the new colors come first"). **The phone is next when the
   owner asks**: it still always shows dark Blue eclipse (`main.dart` sets it), and
   the Pixel still has the old build and the bee icon: its new icon is drawn in the
   project and arrives with the next install. The iPhone and Windows builds still have
   Flutter's icon. The four Savings pictures the owner drew are made ready
   (`assets/logo/prepared/savings-*.svg`, day and night) and wait: the owner is going
   to change the Savings steps, and said to take that up with the budget page.


**The owner's ledger is production data** (since 2026-10-06; rules in
[CLAUDE.md](../CLAUDE.md)). It holds one tugrik account; the dollar accounts and their
categories were deleted on 2026-10-07. A wordless screenshot from the owner, after
being told something couldn't be checked in the real app, is the result being shown,
not a complaint.

**Git:** `main` has everything through PR #57. Branch, commit, PR, merge. The logo and
the Savings pictures are made by `assets/logo/prepared/prepare.py` from the owner's five
vectors in `assets/logo/Images/`; the rest of that folder (their PNG originals and
copies) is on the owner's Mac only, not in git.

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
12. **Balances in the phone's Paid from list** (2026-10-08): should each account in
    the list show its balance, so they can tell whether that card will go through?
13. **The phone's waiting line** (2026-10-08). "1 of your entries is waiting for your
    computer" made the owner ask what it was waiting for the computer to do. Two
    wordings were offered, "1 entry isn't in your ledger yet" (recommended) and "1
    entry will be added when BetterBudget is next open on your computer"; the owner
    wanted to see it work before choosing, and now has.
14. **Header height.** About seven rows show at 1440 × 900. Collapsing the header on
    scroll was offered; the owner hasn't asked for it.
15. **Pay saved on the phone** (2026-10-08). Pay arrives and +₮2,500,000 is saved
    under Income on the phone; the payday set up on the computer is still in the
    forecast as money to come, so the pay is counted twice, and Confirm on it adds a
    second row. Should a phone entry under Income take the place of the next
    scheduled payday? Recommended yes: a button for it on the popup that says "1
    transaction from your phone".
16. **Transfers on the phone next?** (2026-10-08) ₮100,000 taken out of an ATM is
    neither a refund nor income, and the phone has only wrong places for it. Should
    transfers on the phone be built ahead of the two-computers work (Next step 1)?
17. **Two wordings from the colors review** (2026-10-09). Should a late bill say what
    it means for the balance, "due 22 days ago · not in Working yet"? And should an
    import that doesn't match the bank lead with the amount as its own sentence,
    "₮3,298,850.00 apart from the bank."?

## Phase

**A working desktop ledger and budget are built** and run on macOS from
[`app/`](../app/). The owner is using it with real money and refining it by what they
hit. The road to beta and the platforms after it is in [ROADMAP.md](ROADMAP.md).

## What exists (desktop; each line checked against the code on 2026-10-07)

| Area | What works |
| --- | --- |
| Storage | Drift/SQLite at schema v18, encrypted in SQLCipher v4 format, WAL mode. Double-entry ([ADR 0003](decisions/0003-double-entry-schema.md)): a write that doesn't sum to zero is refused. Deletes are soft. Before an upgrade the file is copied beside itself (`Ledger.before-v19-from-v18-<time>.betterbudget`) and the upgrade runs in one transaction. A ledger saved by a newer build is refused |
| Sidebar | Sections Ledger, Budget, Savings. Under Ledger: All accounts, then accounts grouped Bank, Cash, Credit. A Settings gear above Net worth |
| Accounts | Add account: name, Type (Bank account, Cash, Credit card or loan), Currency. It starts from an opening balance, or from a bank file ("Or import a file from your bank"). Menu: Rename, Change to bank account / credit card or loan, Archive…, Delete…, and "Payments come out of" for a card or loan. A cash account is offered neither Reconcile nor Import |
| Register | One signed amount column (money in green with a plus, money out in ordinary ink with a minus) and a running balance. Tabs All, Uncleared, Scheduled, Not categorized. Search with ⌘F |
| Entry | Add or ⌘N opens the row. Missing fields are named ("needs date"). An amount takes a sum, and `+` in front for money in. `→ Account` as the category makes a transfer. A calendar under the date |
| Editing | Double-click a row to edit it in place, with Cancel. A reconciled row's date and amount are locked. Split lines can't be edited |
| Row actions | Edit, Categorize, Mark cleared, Move to (its popup has Show), Delete; Confirm on a scheduled row, which names a row already in the account that looks to be the same bill and offers "Delete the scheduled one". Keys Enter, C, Delete |
| Undo | ⌘Z and ⌘⇧Z (Ctrl+Y on Windows) through the session's actions; in a text field they act on typing |
| Popup | A card 440 wide with Undo. After a category is picked it offers "Always file this payee here", and the next import follows the rule |
| Header | Cleared + uncleared = working, the working balance as the large number; "Last reconciled on"; Reconcile and Import… buttons; a credit account reads Owed |
| Forecast | Its span is a dropdown: the pay period, 30, 60 or 90 days, 6 months, a year. It says the lowest point, or "Runs out" or "Below zero now". "N bills · amount through date" opens the list. Late money in is "not counted". Paydays and plan bills are projected past the scheduled ones |
| Reconcile | Statement date and balance; "Add … adjustment and lock" when they differ; "Undo this reconcile" from a locked row. The database refuses changes to locked rows |
| Budget | Spending and Income tabs. The top key: Cash & bank, in categories, Not assigned, and "Assigned too much". Each category reads Assigned · Spent · Left, the three columns parted by two dotted lines, their headings centred. Period arrows and "Back to today". A view by Month or by a pay's periods. "Assign what's planned". Each currency on its own |
| Categories | Add category, Edit, Delete…, Archive. Edit asks "Is there a due date?" and holds How often (with Every payday, Every pay period and Custom…), Stop at, Paid from and Currency. One built-in Income. "+ New category" from the entry row |
| Pay | A pay has a name, an account and Monthly, Twice a month (a second amount allowed) or every N weeks, with a weekend rule (before, after, Keep the day). "No regular pay". Stopping a pay moves the categories that ran by it |
| Savings | Six steps: one month of expenses, health coverage, no consumer debt, more months, retirement, the mortgage and student loans. Each is done, current, later or set aside. Counts one currency ("another currency, not counted yet") |
| Import | `.xls`, `.xlsx`, CSV and OFX, told apart by the file's contents. The column choice is saved per account. A check of the bank's running balance. Each row is New, Matches, Already in or left out. A Start from date. One undo for the whole import |
| Currencies | 155, each with its own decimals and symbol ([currencies.md](currencies.md)). A transfer between two currencies takes both amounts, through a hidden exchange account. An account's currency can't be changed after it's made |
| Backups | A copy a day, keeping the newest 14 and the first of each of 12 months. Back up to… (Settings says when it was last used, and after more than 30 days without it a line under Net worth says "Last backup 41 days ago", unless the ledger is in a folder), Restore from… (undoable), "Erase everything and start over…" (the old ledger is saved first). "Move my ledger to a folder…" stores the whole ledger, encrypted, as `Ledger.betterbudget` in a folder the owner picks (Google Drive, OneDrive, Box, Dropbox), written again 5 seconds after any change. Settings always says where it is: "Stored in · This computer", or "Stored in · My Drive/BetterBudget · Today 10:00" with "Move to another folder…" and "Move it back to this computer", both undoable. Every ledger file the app writes ends in `.betterbudget` (the working file, daily copies, Back up to…, the copies around a restore or an upgrade); older `.sqlite` copies still count and Restore from… opens both. The owner's ledger has been in their Drive folder since 2026-10-07 |
| Security | A recovery key shown at setup (a key shown before 11:50 on 2026-09-29 ends in a check character worked out by an earlier rule; the app takes both, and the owner's key, saved as `BetterBudget recovery key 2.txt`, is one of those); a screen that asks for it when this device has none; Settings → Security has "Check my recovery key…" ([ADR 0001](decisions/0001-database.md)) |
| Appearance | Same as this Mac, Light or Dark; 101 color schemes. What a new install shows is the app's own, “BetterBudget”, the logo's: a navy sidebar, a cool white page by day and blue-black at night, green main buttons, blue for the row and tab you choose. Money's green and red and the reconciled gold are the same in every scheme |
| Language | Same as this Mac, English or Монгол; 1,148 messages, the same keys in both files |
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
- **Phone apps** ([ADR 0005](decisions/0005-mobile-companion.md)): on Android the app
  asks once for the recovery key and for the folder the ledger was moved to, then
  opens on Ledger: amount, Payee, Category (picked from a list or typed, and the list
  can make a new one), Paid from, Date, Save. A +/− button beside the amount makes the
  entry money in: a refund to its category, or income, with Income the first line of
  the Category list. Budget, the other screen, shows what
  is left in each category (those waiting for a bill apart, under Bills), makes a new
  category too, and links to each account's balance. The figures are read from
  `Ledger.betterbudget` in that folder, again whenever the app comes back to the front
  or the Budget list is pulled down (ADR 0004 "Phone screens: Ledger first"). What is
  saved is kept on the phone, written to the folder in the phone's own file, and taken
  in by the computer as uncleared rows with one undo. Not built: renaming a category
  made on the phone; fixing a waiting entry; transfers; other phones'
  entries; the iPhone's folder access and icon.
- **A Windows build.**
- **Encryption has been run on macOS and iOS** (recorded 2026-09-29), **and once on
  Android** (2026-10-07, a debug build on a Pixel 10a, Android 17: the key was stored
  and the ledger file made is not plain SQLite; reopening it after the app is closed
  wasn't checked). Windows and Linux are unverified.
- **CI.** Nothing runs tests on pull requests.
- More in [ROADMAP.md](ROADMAP.md): search that understands amounts and dates, sorting,
  counting a cash account, moving money between categories.

## Known bugs and loose ends

- **From the reviews of the new look (2026-10-09), not fixed:** the gold popup that
  says a change was saved also carries failures ("Couldn't save: …", "Couldn't
  undo…"), which read as success (about 35 places show one; a failure wants its own
  plain popup); on a
  hovered row or menu item by day the gray currency code is 4.0; eight old bee files
  are still in `assets/logo/`; the phone's amount screen needs the deeper green
  button before it follows day and night.
- **From the reviews of the register notes (2026-10-09), not fixed:** a bill the
  bank names with no word in common with its payee (Rent paid as "IB TRANSFER
  0412"), not yet categorized and for another amount, still isn't found when the
  bill is confirmed; All accounts looks only among the rows it shows; two fast
  clicks on "Delete the scheduled one" (or on Delete) record two undos; the scroll
  to a row more than a screen down the list was not tested (the test's row is in
  sight); an open row scrolled far out of sight loses what was typed in it, as it
  did before.
- **From the reviews of the backup reminder (2026-10-09), not fixed:** "Erase
  everything and start over" keeps the old record, so a new ledger can be told on
  its first day, or not for a month; "Back up to…" into a folder on the same disk
  counts as elsewhere; a count of 100 days or more may wrap to a second line in the
  sidebar, and the Mongolian line's fit wasn't looked at; no test that a ledger in
  a folder, or setup, hides the line, nor that "Back up to…" records the day.
- **From the reviews of the folder and the phone (2026-10-07), not fixed:** a ledger
  under both names (`betterbudget.sqlite` beside `Ledger.betterbudget`, which an older
  build would make) is ignored without a word; a write already under way when "Move
  it back to this computer" is pressed still lands in the folder; an old or second
  computer replaces the folder's ledger without a warning (Next step 1); the Backups note still says to use a USB stick once the ledger is in
  a folder. Untested: the phone's figures for a budget run by pay periods, and the
  phone meeting a ledger from a newer version.
- **From the reviews of the phone's Ledger screen (2026-10-08), not fixed:** the "left
  now" line on Ledger doesn't say how old the figures are (Budget does) and counts
  only this phone's entries, whatever their date; Rent chosen on Ledger reads "left
  now" in ordinary ink, though Budget lists it apart as a bill; a waiting entry whose
  category has gone from the ledger shows no category and its amount in tugrik; a
  category made on the phone and one of the same name arriving from the Mac are both
  listed; on a 360 × 640 phone Save is reached by scrolling.
- **From the reviews of the phone's entries reaching the computer (2026-10-08), not
  fixed:** a purchase imported from the bank before its phone entry arrives is in
  twice (the other order is matched by import); an entry whose account
  or category was deleted on the computer waits on the phone for good with no reason
  given; after a week away, 40 arrivals are one count in a popup with no way to see
  which rows they were; an entry dated in an earlier budget period or before the last
  reconcile changes that period without a word; a phone category is matched by name
  alone, so a dollar entry can land in a tugrik category of that name; the list of
  entries already in (`phone.taken`) only grows, about 130 KB a year for two phones.
- **From the reviews of money in on the phone (2026-10-08), not fixed:** pay saved
  under Income isn't tied to its scheduled payday, so the forecast counts both and
  Confirm adds it again; with no transfers, cash from an ATM or a card payment has
  only wrong homes; a refund the bank posts over 10 days later, or for another
  amount, comes in twice on import; a refund dated in an earlier period raises this
  period's "left" on the phone, though the computer may put it in Not assigned; the
  Income toast doesn't say the money is in no category; a category made while the
  entry is money in is a spending one holding a refund; the account list offers a
  mortgage or student loan, which the computer's budget leaves out; the +/− button is
  half under the toast while it shows; the +/− button's spoken label in Mongolian
  ("Орлого болгох") uses Income's own word.
- **`keys_test.dart` "rejects a bad checksum" failed once in a full run**
  (2026-10-09) and passed alone and in the next two full runs; like the one below
  it builds its input from a random key.
- **`keys_test.dart` "corrects a typed O or I to 0 or 1" failed once in a full run**
  (2026-10-08) and passed in the next and in twelve reruns: it builds its input from a
  random key. **`budget_test.dart` "plans paid weekly, a date years ahead is still
  quick" failed once** the same day with the Mac busy (it times itself against 200
  ms) and passed three times alone.
- **Launched while the Mac is locked, the app stops at startup.** The Keychain refuses
  the key (-25308) and `_start` in `startup.dart` doesn't catch it, so the window stays
  on the startup screen until the app is quit and opened again. Seen 2026-10-01; the
  ledger wasn't touched. **Seen again 2026-10-09 with the Mac unlocked** (the owner:
  a blank window after a rebuild and relaunch; it opened normally the next three
  times), so the cause isn't known. Agreed with the owner as the next small fix: the
  startup screen says what went wrong, with a Try again button and no "unlock your
  Mac" line.
- **Buttons may sit wrong on a Mac while their goldens look right** (a Mac draws them
  8 shorter). Only the popup's two were looked at.
- **From the reviews of PR #44, none fixed:** the mouse wheel does nothing over the
  popup; in dark mode an amount's cents fall to about 2.6 contrast on a hovered row in
  the worst color scheme, and `schemes_test.dart` checks neither stripe nor hover; the
  forecast's bill list shows money out plain; "1 more row now" counts that payee's
  waiting rows in every period while the Not categorized tab counts this period's, and
  the offer silently replaces an earlier rule for the payee; reconcile's "Add ₮X
  adjustment" doesn't say which way; a transfer shown once in All accounts reads as
  spending.
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

## Open items

None waiting. **Dropped:** putting `+` in the amount when a payee's last row was
money in. It is a guess filled into a field (owner, 2026-10-08: "Don't autofill").

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
- **App data:** `~/Library/Containers/com.lovelandsolutions.betterbudget/Data/Library/Application Support/com.lovelandsolutions.betterbudget/Ledger.betterbudget`
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
