# Where things stand

**Last updated: 2026-10-21** · version 0.41.3 · schema v21 · 779 tests pass

**This file holds the current state, nothing else.** What's left to do (features, bugs,
questions for the owner) is on the [BetterBudget board](https://github.com/orgs/Loveland-Solutions/projects/1), one issue each. No log of PRs:
git, the PRs and [ADR 0004](decisions/0004-ledger-ui.md) hold the history. When a PR
merges, rewrite "Next step" and correct the tables; don't add a dated block. Keep it
under about 20,000 characters. Everything this file said up to 2026-10-07 is in
`docs/archive/STATUS-2026-10-07.md`, which is not for reading unless the owner asks.

## Next step

**The forecast's "Nothing has been budgeted" goes by the budget** (0.41.4, closes
#129): it shows only while no category in use has a plan or an amount assigned. With
a budget but no bills in the account, the line above already says there are none and
nothing is added. `budgeted` on `BalanceHeader`, worked out in `ledger_screen.dart`.

**A failure has its own popup** (0.41.3, closes #128; ADR 0004 rule 9, "A failure
has its own plain popup"): gold is only for a saved change. Anything that didn't
happen (a failure, a refusal, a nudge such as "Nothing to undo") is the page's own
card with a coral edge and mark (the owner's pick, option A of three), says what in
one line, and keeps the technical reason behind Show details, which holds the popup
until it's closed. A damaged file of a kind the import reads says the file may be
damaged. Seen by the owner in the real app. `_showFailure` in `ledger_screen.dart`.

**Checks on every pull request** (PR #230, merged 2026-10-21; closes #89):
`.github/workflows/check.yml` runs `flutter analyze` and `flutter test` on each pull
request that touches `app/`, on GitHub's arm64 Mac (macOS 15), about 17 minutes, no
cache. There a golden may differ by 0.5% of its pixels, since that macOS smooths
letters differently from the one the goldens are drawn on; locally they match
exactly (MAP.md "Checks on GitHub"). Not required for merging.

**No overflow stripe** (0.41.2, PR #227, merged 2026-10-20; ADR 0004 "No overflow
stripe"): an amount or date too wide for its box is drawn smaller (`Shrink`, which
every `Money` uses), a name ends in "…", and a sentence with an amount wraps. New
account fits its Types in Mongolian. `test/overflow_test.dart` walks every page and the
phone screens with huge amounts and long names in both languages. Names that cut to
the same text stay (owner, #225). Screens the test doesn't open yet: #226.

**Two computers: asked before, after all** (0.41.0, merged 2026-10-20; ADR 0004
"Two computers: asked before, after all"). The owner tested step 4 on the two Mac
accounts, saw the asking window instead of the popup, and chose it: a row changed two
ways is asked in the window before anything comes in, with two computers as with more.
Answered on one, the other isn't asked again (seen in the real app). Step 4's change
files, applied markers, shared ids and locks stay; the told-after code (the settling
rule, the popup that stayed, a version picked afterwards) is gone (0.41.1, #218), and
the popup's saved setting is cleared at launch. A folder file from a build before
change files can't be asked about: a crossing there is the whole-ledger question.
Step 5 waits until after beta. Test builds signed
"Apple Development" carry a provisioning profile that lasts 7 days: a build that
"can't be opened", with no Open Anyway in Privacy & Security, has an expired profile,
and a rebuild renews it.

**Open source (owner, 2026-10-16):** the repo is public under GPL-3.0 or later, with its
whole history (ROADMAP "Decided (owner, 2026-10-16)"), and free in every store.
Anything pushed is published. The public repo's README and the website's copy of
PRIVACY.md were already right (#96, #97 closed). Left: #98, the store listings set to
free: Google Play now, the Microsoft Store and the App Store once registered.
The privacy policy stays as it is (owner, 2026-10-16: "I don't think it makes a big
difference"); it gains no line about the source being public.

**Splitting one transaction over categories is built** (version 0.36.0, PR #198;
ADR 0004 "One receipt over several categories: the split card"): the owner chose a
card under the row, and Add waits until the lines add up; a split names each category
once (owner's correction on trying it). Seen working by the owner in the real app.
Its reviews' leftovers are built (0.39.3, PR #214): a new category from a line, a split
known as a scheduled bill already in, lines merged with their categories, search by a
line's category, the memo after the breakdown, shares unrounded, the card saying which
way the total goes, and a split that evens out to ₮0. **On the phone too** (version 0.37.0, PR #202; the
owner's pick, a split page; ADR 0005 "A split from the phone"): a phone split comes in
as one split row, and a computer older than 0.37.0 leaves it waiting on the phone; a
line whose category was deleted on the computer meanwhile comes in as Not categorized
(0.38.0, PR #204). Its reviews' leftovers are built (0.39.2, PR #213): a waiting entry
opens to be fixed, a line can be marked Returned, only an overspent line in the toast
is red, money out is ordinary ink on the phone, and a quick second tap no longer lands
under the closed list. The phone's categories are now chosen
from a dropdown on the entry screen, Split with its icon at the top (0.39.0, PR #209;
owner's correction, ADR 0004); a signed 0.39.0 bundle is built for Internal testing.
The computer's Category list has Split with its icon at the top too (0.39.1, PR #212;
owner's correction). Play's Internal testing has 0.41.2 (uploaded 2026-10-20). **Downloads: none from
GitHub** (owner, 2026-10-20: stores only; ROADMAP). Windows 0.35.1, 0.36.0 and 0.38.0
are still published on the public repo's releases page; whether to take them down is
the owner's call. Apple's paid Developer Program was still pending on 2026-10-17; it is
now needed for the App Store, not for a download. Actions storage: the Windows build keeps its download
14 days and the caches of merged pull requests were deleted (#205).

**Where to pick up:** the board's In progress and Next columns. **Savings step 2
has a debt's interest rate** (version 0.35.0, PR #79; ADR 0004 "A debt's
interest rate on step 2"). The owner's answers on 2026-10-14: a rate typed on each
debt's line or on Add account, a month's or a year's as the person picks (tugrik
starts at a month), with an ⓘ; no monthly payment; Save for the future stays as it
is, goals with dates go on the roadmap (ROADMAP D); the course's line under the steps
is gone. Both reviews are in and their fixes made. Whether "Pay extra here" should
follow the costliest debt waits for the owner's look at Savings in depth (#174). Two computers, step 4 (#111): see the top of this section.

**Version 0.34.4 (fix):** Android's build number is the repo's commit count, as the
Mac's is (ADR 0006), so each upload to Play is higher than the last; it was 1 on
every build. Play is set up and the app is on the owner's phone through Internal
testing (owner, 2026-10-16). Next on Android: the stores (issue #114).

**Version 0.34.5 (PR #86):** downloads. The Windows app is built on GitHub
(`.github/workflows/windows.yml`, on a `v*` tag or by hand; not on pull requests)
and is now BetterBudget by Loveland Solutions, which names its data folder. The
owner asked for it as a release (2026-10-16): 0.35.0 is on the public repo's releases
page, and on their PC it stopped at "MSVCP140.dll was not found". **Version 0.35.1
(fix, #194)** puts Microsoft's C++ runtime DLLs beside `BetterBudget.exe` and gives it the Mac's
icon (the logo's night form on a navy tile, filling the square); whether
it then runs on that PC is #154.
`app/tool/release_mac.sh` signs, notarizes and drafts a release on the public repo;
it is unused since the owner chose stores only, with no GitHub downloads
(2026-10-20, ROADMAP; #94 and #152 closed).

**Version 0.34.3 (fix, found by the owner on 2026-10-15):** a balance typed in
setup, then the bank's last days imported, came out off by the rows dated on the
balance's own day: the import only held rows dated before it. Rows on that day now
count as held by the balance ("dated on or before"), with the same default move and
"Leave it" (ADR 0004 "Rows on its own day count too"). Running on the owner's main
account; not yet tried on a real import.

**Version 0.34.1 (PR #75):** a launch that can't finish (the Keychain refusing the
key, a file that can't be read, a key that can't be kept, a ledger that fails to
open) says what went wrong, with Try again and Show details, instead of a blank
window (ADR 0001 "At launch"). Running on the owner's main account; the screen
itself is seen only in `app/test/goldens/startup_failed.png`.

**Version 0.34.0 (PR #73; both Mac accounts run it):** a row made under another account of the same Mac
reads "Entered locally" too, by a hash of the Mac's hardware id kept as
`computer.machine.<id>` (ADR 0005 "The same Mac is here"). A computer with no id yet
takes a GUID worked out from its Mac and account instead of a random one; one that
has an id keeps it (ADR 0005 "A computer's id is worked out, once").

**A bug in 0.33.0, fixed in 0.33.1 (PR #72; found by the owner's second run, and the
main account was pointed at the folder again and worked):** the launch
asked for this computer's id before the saved folder settings were read, so the
file `cloud-folder` beside the ledger was written again with only a new id and the
folder, its token and what was published were gone: a computer opened on 0.33.0 says
"Stored in · This computer" and writes nothing to the folder. The ledger itself was
not touched. The id now waits for the settings (`CloudFolder.computerId`, with a
test). **A computer that ran 0.33.0 has to be pointed at the folder again**
(Settings → "Move my ledger to a folder…", the Drive folder; a folder that
already holds a ledger is never written over on being picked), and it has a new
id, so the old `Computer <id>` files stay in the folder, harmless, until
compaction (step 5).

**Source column (version 0.33.0, PR #71; both review passes are in and their fixes
made; the build before it, 0.32.0, refuses a v21 ledger, so the second Mac account
needs 0.33.0 before the folder's ledger is next written):** asked for by the
owner after the first real run, where a quick switch to the other account missed the
popup. Each new transaction records how it came to be and where (schema v21:
`made_how`, `made_on`; the upgrade adds two empty columns and touches no row, so
every row already there says nothing). An optional **Source** column in the
register, on, and turned off in Settings → Register ("Show where each transaction came from"),
reads "Entered locally", "Entered on Mac mini", "Imported on …", "From Pixel", "Scheduled",
"Opening balance"; a row keeps the id of the computer or phone, and each is named
(and renamed) in the same panel, so a rename shows on every row
(ADR 0005 "Where a row came from"; ADR 0004 "Where a row came from: a Source
column"). The popup that goes away unseen was
offered to be kept up until clicked away; the owner saw it work and didn't ask for
the change, so it stays six seconds.

**Merged on 2026-10-13, in order:** #66 (the row question, 0.29.0), #67 (step 1,
schema v20, 0.30.0), #68 (step 2, shared ids, 0.31.0), #69 (step 3, change files,
0.32.0; its code review's five findings fixed). The folder holds `Ledger.betterbudget`
and one `Computer <id>.betterbudget-changes` per computer. The Pixel needs a build
at or after 0.30.0 before it can read the folder's ledger again (every schema bump
does this).

**The two-computers design was re-chosen on 2026-10-12: a change file per
computer** (ADR 0005 "Two computers: the way chosen, 2026-10-12"; the four expert
reports are in [committee/two-computers/](committee/two-computers/)). Told that
five kinds of conflict still asked which whole ledger to keep, the owner said "I
don't want them to have to make this decision" and "Databases are made for this
type of thing", proposed a master database with a local child and a lock file,
and after the reports chose B ("Let's go with B"): each computer appends its
changes to a file only it writes (as the phones do), every computer applies the
others', `Ledger.betterbudget` becomes a derived snapshot the phones keep reading,
and the lock goes (not atomic over Drive). About six weeks, give or take two, in
five PRs. **PR 1 of 5 is merged (#67, version 0.30.0): schema v20**, the `changes` table filled by TEMP triggers made on every
open, the hold that keeps another computer's changes, a restore and an erase out
of it, `sync.ledger` for a new ledger, `sync.applied` reserved; the upgrade adds
one table and touches no row (ADR 0005 "Built, 2026-10-12: step 1"); the code
review's findings are in (no bug that touches data; its rules are in the ADR).
Nothing in the folder changes yet, so the owner sees nothing new on the Mac;
**the Pixel's old build can't open a v20 `Ledger.betterbudget`** (nor a v19 one:
every schema bump does this), so the phone wants this build at the next
install. **PR 2 of 5 is merged too (#68, version 0.31.0): one id for
the same thing made on both** (ADR 0005 "Built, 2026-10-12: step 2"): the same
payday, bill, phone entry, bank row, payee, category, Income and Safety net get
the same id on every computer, so two computers that did the same thing hold one
row and have nothing to merge, write or say; the digest ignores when a row was
written; the old matching by what a row says stays as the backstop. **PR 3 of 5
is merged too (#69, version 0.32.0): the folder cycle on change
files** (ADR 0005 "Built, 2026-10-13: step 3"): each computer writes one file
only it writes, reads the others', folds each into the compare that already
exists, and the shared `Ledger.betterbudget` is written only by a computer that
holds everything; an answer to the row question, and "Keep this computer's
ledger", travel as changes so the other computer takes the decision instead of
being asked. The counters, seal and agreed file are still written for the
older look, which runs until both computers carry a vector. The code review's
five findings (the transition when the second computer upgrades with changes
of its own, a cleared log's count, merges that weren't symmetric, answers
that crossed, a gap in a change file) are fixed, each with a test (ADR 0005
"Rules from the code review (2026-10-13)"). **Not run on two real computers**;
the first real run is the owner's to watch on the testuser account. Rough
edges for step 5: an erase while the folder's ledger moved on asks the erasing
computer the whole-ledger question first; a third computer never gets changes
a computer took in whole. **Next is PR 4** (the facts-first policy and the blocks for the cases
still asked as a whole ledger), then 5 (restore and erase as batches,
compaction, the catch-up take, the digest guard, a soak on two Mac accounts). The money
rules were put to the owner with the choice and not objected to (ADR 0005 "The
money rules"). The hole the review found (two
computers writing within Drive's propagation window made the loser's agreed file
a false base) is closed by PR 3: the base comes from the other computer's own
file, and nobody writes over anyone's file.

Before it, **the row question (version 0.29.0, PR #66)**, built the same morning (ADR 0004
"Two computers: the one row both changed"; ADR 0005 "Built, 2026-10-12: asking
about the one row"): when two computers changed one transaction two ways (or one
deleted it and the other changed it), or one category's assigned amount for one
period, a window lists each with what each computer says and "As it was", three
buttons on each (Keep this computer's, Keep the other's, Neither: as it was), one
Save my choices; nothing is written until answered; put off, Settings is red with
Choose…; no Undo (owner: "We don't need to build Undo into this part"). Both
review passes run and their fixes in. It survives the new design whole, reading
later as a thing already done that the person may change. The two small questions
asked with it (a Show on each block; a line under Net worth while put off) fold
into PR 4 and aren't asked again. **Not run on two real computers.**

Before it, PR #65 (version 0.28.0): Payees is a section of its own in the sidebar, under
Savings, and a real feature** (ADR 0004 "Payees: its own section" and "Payees: the real
feature"; owner, 2026-10-12: "I don't want to hide this", "Let's make this a real
feature", "B. Looks great.", "allow them to apply a payee rule to multiple
accounts"). Every payee the app remembers a category for is a line that reads as a
sentence and opens into its Edit: the words, at the start of the payee or anywhere
in it or the bank's description, the accounts it holds on (several), the category or
pay, a live count of the rows it fits, one drawn as it will read; Add a payee;
Delete. **Schema v19**: the rules are a table; the upgrade carries the owner's
rules over from the setting and leaves the setting in place. **Not yet seen by the
owner in the real app**; the pictures are `app/test/goldens/payees.png` and
`payees_edit.png`. Asked with it and answered: no moving of rows already filed
("that would be really bad"). Not understood as worded, to ask with a picture of
the row: the offer at the foot of a row's category dropdown. Put on the list the
same day: splitting one transaction over categories.

Before it, PR #64 (version 0.27.0): a computer with no ledger opens on three ways to
start (ADR 0004 "How a new computer starts"): Start fresh, Restore from backup,
Open ledger, the one clicked opening in place with the recovery key and its button.
Open ledger is one pick of the folder: the ledger there comes over and the computer
stays on it. The key is kept only once it opens what was picked. "Open your newest backup?" is gone; where a pick is cancelled, "Where
is your ledger?" asks. **Not yet seen by the owner**: their own account has a
ledger, so it shows only on a second account or machine.

Before it, PR #63 (version 0.26.0): Restore from… pointed at `Ledger.betterbudget`
in the folder shows a ticked "Share the ledger in My Drive/BetterBudget" in the
restore dialog; Restore then brings the ledger over and keeps the computer on the
folder (ADR 0004 "A second computer set up in one step"). On a Mac the folder is
chosen once more in the Mac's own dialog, which opens on it. **Not yet seen by the
owner on a second account or machine**: tests only.

Before it, PR #62 (version 0.25.1), a fix: on a computer where the recovery key was
typed, "Open your newest backup?" comes back after Cancel in the file dialog and
at each launch until it is answered (now "Where is your ledger?").

**Before it, PR #61 (version 0.25.0): two computers that each changed the ledger are
combined** without a question when what they did can both stand (item 1 below; ADR
0005 "Built, 2026-10-10: step 2"). A popup says "4 transactions from Tom’s MacBook
Air", and when there is one, that a row looks the same as one already here (with
Show) or that more is assigned than there is. It has no Undo, and "Opened the ledger
saved on …" lost its own (owner, 2026-10-10: Undo is only for what the person at
this computer did; ADR 0004 "Two computers: combined without a question"). No
upgrade: nothing in the owner's file changed. **Seen working by the owner on
2026-10-10 on two accounts of one Mac** (a second macOS user, the same Drive
folder), not yet on two machines. A plain popup for a failure is #128.
The app must be opened from Applications, never from inside the Drive folder:
Drive drops the links inside it and every save fails.

Before it, PR #60 (version 0.24.0): Savings is the owner's four steps, each with the
picture they drew (ADR 0004 "Four Savings steps"): Build a safety net, Eliminate debt,
Build three to six months of savings, Save for the future. A month of expenses comes
from the budget. The safety net is one budget category, **built in as Income is**,
whose Left is the count, set apart on the Budget page under "Saved"; the owner's
ledger got it the first time this build opened it. **The owner is using it to see
whether it works** ("I'll need to use it to see if it works") and has not yet said;
expect corrections. Three questions asked with the steps are under "Waiting on the
owner" (17). The steps' own work after that is whatever those answers ask for (a
rate and payment per debt; what Save for the future holds).

Before it, PR #59 (version 0.23.0): a computer no longer writes the folder's ledger
without looking at it first: step 1 of two computers on one ledger is built (item 1
below). Before it, PR #58: the phone records money moved
between two accounts (cash from an ATM, a card paid): the accounts are at the foot of
its Category list under "Move to an account" (ADR 0004 "Phone screens: Ledger first").
**Not yet on the owner's Pixel**, which still has the build from before PR #55:
`adb install -r` keeps what the phone has stored; install when they ask. Before it, PR #57: the register's notes, the already-in
check on Confirm, the backup reminder, the Mac's navy icon.
The computer wears the owner's logo and its
colors from the first launch: a navy sidebar, green main buttons, and gold kept as an
accent for what is done (the reconciled diamond, the saved popup, the sidebar's marks);
a scheduled bill is gray with a blue Confirm (ADR 0004 "The logo's colors" and "Gold is
an accent, and the new colors come first"; the screens compared are at
<https://claude.ai/artifact/1xJW37g537PUgA5BRLkzvq>).
The owner's ledger is stored in their Google Drive folder; the Android app records
money out and money in, and what it records reaches the computer's ledger through the
folder.

**The owner's ledger is production data** (since 2026-10-06; rules in
[CLAUDE.md](../CLAUDE.md)). One exception, for the two-computers work only (owner,
2026-10-09): it may be replaced if the design needs it, asked about first (ADR 0005). It holds one tugrik account; the dollar accounts and their
categories were deleted on 2026-10-07. A wordless screenshot from the owner, after
being told something couldn't be checked in the real app, is the result being shown,
not a complaint.

**Git:** `main` has everything through PR #75. Branch, commit, PR, merge. The logo and
the Savings pictures are made by `assets/logo/prepared/prepare.py` from the owner's five
vectors in `assets/logo/Images/`; the rest of that folder (their PNG originals and
copies) is on the owner's Mac only, not in git.

## Questions for the owner

On the [board](https://github.com/orgs/Loveland-Solutions/projects/1) as issues titled "Question: …". Asked and not answered: don't
re-ask; bring one up when its screen comes up again.

## Phase

**A working desktop ledger and budget are built** and run on macOS from
[`app/`](../app/). The owner is using it with real money and refining it by what they
hit. The road to beta and the platforms after it is in [ROADMAP.md](ROADMAP.md); the
work itself is on the [board](https://github.com/orgs/Loveland-Solutions/projects/1).

## What exists (desktop; each line checked against the code on 2026-10-07)

| Area | What works |
| --- | --- |
| Storage | Drift/SQLite at schema v21 (a transaction also holds `made_how` and `made_on`, where it came from; the `changes` log of what this computer changed, each computer's own), encrypted in SQLCipher v4 format, WAL mode. Double-entry ([ADR 0003](decisions/0003-double-entry-schema.md)): a write that doesn't sum to zero is refused. Deletes are soft. Before an upgrade the file is copied beside itself (`Ledger.before-v21-from-v20-<time>.betterbudget`) and the upgrade runs in one transaction. A ledger saved by a newer build is refused |
| Sidebar | Sections Ledger, Budget, Savings, Payees. Under Ledger: All accounts, then accounts grouped Bank, Cash, Credit. A Settings gear above Net worth |
| Accounts | Add account: name, Type (Bank account, Cash, Credit card or loan), Currency. It starts from an opening balance, or from a bank file ("Or import a file from your bank"). Menu: Rename, Change to bank account / credit card or loan, Archive…, Delete…, and "Payments come out of" for a card or loan. A cash account is offered neither Reconcile nor Import |
| Register | One signed amount column (money in green with a plus, money out in ordinary ink with a minus) and a running balance. Tabs All, Uncleared, Scheduled, Not categorized. Search with ⌘F |
| Entry | Add or ⌘N opens the row. Missing fields are named ("needs date"). An amount takes a sum, and `+` in front for money in. `→ Account` as the category makes a transfer. A calendar under the date. A box under the row, "Remember this category for this payee", while there is one to remember: ticked, the payee is remembered with the row, one undo (also in a row's Edit) |
| Editing | Double-click a row to edit it in place, with Cancel. A reconciled row's date and amount are locked. A split's categories are edited in its card |
| Source | An optional register column, on until Settings → Register unticks "Show where each transaction came from": how a row came to be (typed, imported, from a phone, scheduled, opening balance, reconcile adjustment) and the computer's name or the phone's name; a phone is named in the same panel. Empty for rows from before v21 |
| Row actions | Edit, Categorize, Mark cleared, Move to (its popup has Show), Delete; Confirm on a scheduled row, which names a row already in the account that looks to be the same bill and offers "Delete the scheduled one". Keys Enter, C, Delete |
| Undo | ⌘Z and ⌘⇧Z (Ctrl+Y on Windows) through the session's actions; in a text field they act on typing |
| Popup | A card 440 wide with Undo. After a category is picked it offers "Always file this payee here", and the next import follows the rule |
| Header | Cleared + uncleared = working, the working balance as the large number; "Last reconciled on"; Reconcile and Import… buttons; a credit account reads Owed |
| Forecast | Its span is a dropdown: the pay period, 30, 60 or 90 days, 6 months, a year. It says the lowest point, or "Runs out" or "Below zero now". "N bills · amount through date" opens the list. Late money in is "not counted". Paydays and plan bills are projected past the scheduled ones |
| Reconcile | Statement date and balance; "Add … adjustment and lock" when they differ; "Undo this reconcile" from a locked row. The database refuses changes to locked rows |
| Budget | Spending and Income tabs. The top key: Cash & bank, in categories, Not assigned, and "Assigned too much". Each category reads Assigned · Spent · Left, the three columns parted by two dotted lines, their headings centred. Period arrows and "Back to today". A view by Month or by a pay's periods. "Assign what's planned". Each currency on its own |
| Budget: Saved | The built-in Safety net category is listed last, under the heading "Saved". It can be renamed and edited, not deleted or archived. Made the first time a ledger past setup is opened without one |
| Categories | Add category, Edit, Delete…, Archive. Edit asks "Is there a due date?" and holds How often (with Every payday, Every pay period and Custom…), Stop at, Paid from and Currency. One built-in Income. "+ New category" from the entry row |
| Pay | A pay has a name, an account and Monthly, Twice a month (a second amount allowed) or every N weeks, with a weekend rule (before, after, Keep the day). "No regular pay". Stopping a pay moves the categories that ran by it |
| Savings | Four steps, each with the owner's picture: Build a safety net (one month of expenses, taken from the budget, then the three-month average, or typed; it is what is Left in the built-in Safety net category; the step says how much of it is in the accounts the category is Paid from, and offers money not assigned), Eliminate debt (every card and loan owing but a mortgage or a card paid in full every month; each takes an interest rate, a month's or a year's, there or on Add account, and shows about what it costs a month in interest, listed most first once two have one), Build three to six months of savings, Save for the future (saving for retirement, and paying off the mortgage). Each is done, current, later or set aside. The page fills the window. Counts one currency ("another currency, not counted yet") |
| Payees | Every payee the app remembers a category for, a line each that reads as a sentence ("starts with «Unitel»", "has «Номин» anywhere"), its accounts (column only with more than one), its category, Delete. A click, or Add a payee (⌘N), opens its Edit in place: the words, Where (at the start, or anywhere in the payee or the bank's description), Accounts (checkboxes), Category (pays lead), the count of rows it fits in real numbers, one row drawn as it will read, Cancel and Save (Enter; Esc and a click away close). Save offers to file the rows still in Not categorized; rows already in a category are never moved. Delete keeps the payee as deleted so an import doesn't put it back where it went last. On import the longest words win, then the later-made |
| Import | `.xls`, `.xlsx`, CSV and OFX, told apart by the file's contents. The column choice is saved per account. A check of the bank's running balance. Each row is New, Matches, Already in or left out. A Start from date. One undo for the whole import |
| Currencies | 155, each with its own decimals and symbol ([currencies.md](currencies.md)). A transfer between two currencies takes both amounts, through a hidden exchange account. An account's currency can't be changed after it's made |
| Two computers | The ledger in the folder is read before every write, at launch, when the app comes to the front and every 15 seconds. A newer one is opened by itself ("Opened the ledger saved on …"); when both changed, nothing is written and what the other changed is brought in and both are written ("4 transactions from Tom’s MacBook Air", no Undo; this computer's ledger as it was is in Backups; a second line says "1 looks the same as one already here", with Show, or "₮3,000,000 more is assigned than you have"); only when the two changed one thing two ways, or after a restore here, "Your ledger was changed on two computers" asks which to keep, the other saved first, and Settings says so in red with "Choose which to keep…". A folder that already holds a ledger is never written over on being picked. Restore from… pointed at the folder's `Ledger.betterbudget` offers, ticked, "Share the ledger in My Drive/BetterBudget": one step sets up a second computer. A new row's id is one no other computer gives (`newRowId`), so rows keep their ids everywhere. Row in conflict: asked about (a transaction or one assigned amount), the rest of conflicts ask which whole ledger |
| Backups | A copy a day, keeping the newest 14 and the first of each of 12 months. Back up to… (Settings says when it was last used, and after more than 30 days without it a line under Net worth says "Last backup 41 days ago", unless the ledger is in a folder), Restore from… (undoable), "Erase everything and start over…" (the old ledger is saved first). "Move my ledger to a folder…" stores the whole ledger, encrypted, as `Ledger.betterbudget` in a folder the owner picks (Google Drive, OneDrive, Box, Dropbox), written again 5 seconds after any change. Settings always says where it is: "Stored in · This computer", or "Stored in · My Drive/BetterBudget · Today 10:00" with "Move to another folder…" and "Move it back to this computer", both undoable. Every ledger file the app writes ends in `.betterbudget` (the working file, daily copies, Back up to…, the copies around a restore or an upgrade); older `.sqlite` copies still count and Restore from… opens both. The owner's ledger has been in their Drive folder since 2026-10-07 |
| Security | A recovery key shown at setup (a key shown before 11:50 on 2026-09-29 ends in a check character worked out by an earlier rule; the app takes both, and the owner's key, saved as `BetterBudget recovery key 2.txt`, is one of those); a screen that asks for it when this device has none; Settings → Security has "Check my recovery key…" ([ADR 0001](decisions/0001-database.md)) |
| Appearance | Same as this Mac, Light or Dark; 101 color schemes. What a new install shows is the app's own, “BetterBudget”, the logo's: a navy sidebar, a cool white page by day and blue-black at night, green main buttons, blue for the row and tab you choose. Money's green and red and the reconciled gold are the same in every scheme |
| Language | Same as this Mac, English or Монгол; 1,182 messages, the same keys in both files |
| Shortcuts | ⌘N new, ⌘F search (⌘K also works), ⌘Z undo, ⌘⇧Z redo |
| Setup | A new, empty ledger opens on "Your accounts": one date for every balance, one line per account, × to remove, the cash question, Continue. Then "Your pay": the pay form on the page, answered by "Save pay" or "I don't have regular pay", after which the pays are listed with Edit and "Add other pay", and "Open my ledger" ends setup. The steps are named across the top (Accounts › Pay), with Back. It is on the step it was left on after a quit, and never returns once done. A ledger that already had accounts never sees it. A computer with no ledger and no key opens on "How do you want to start?": Start fresh (a new recovery key), Restore from backup, Open ledger (the folder it is stored in); the last two open in place with the recovery key and go to the file or folder dialog. Where that is cancelled or doesn't work, "Where is your ledger?" asks (folder, backup, Start empty), and again at each launch until a ledger is here, "Start empty" is picked or an account is added |
| Demo data | Tests only (`LedgerScreen.demo`): TDB Checking, Khan Savings, Cash wallet, Golomt Visa. The app no longer seeds it |

Rules behind each: ADR 0004. Where the code is: [MAP.md](MAP.md).

**Not carried over** from the old table, because they weren't checked against the
code: details of Accounts (archive and delete), Entry, Register, Forecast, Budget,
Savings, Import, Backups and Appearance. Before changing behavior in one of those
areas, search `docs/archive/STATUS-2026-10-07.md` for that area's claims and verify
them against the code first (owner, 2026-10-07; this is the one standing reason to
open the archive).

## Known limits, accepted

**Dropped:** putting `+` in the amount when a payee's last row was
money in. It is a guess filled into a field (owner, 2026-10-08: "Don't autofill").

A scheduled split confirms at its planned total only;
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
  Android: the package is `mn.lls.betterbudget` (registered in Play Console,
  2026-10-14; the Mac stays `com.lovelandsolutions.betterbudget`). Release builds sign
  with the upload key `~/betterbudget-upload.jks` (alias `upload`) when the git-ignored
  `app/android/key.properties` holds its password, otherwise with the debug key. The
  owner keeps the key, password and fingerprints in KeePass. `keytool` isn't on the
  PATH: use Android Studio's, `/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool`.
  The first build with the new package installs on the Pixel as a second app, starting
  at setup: let the computer take in the old app's waiting entries first.
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
