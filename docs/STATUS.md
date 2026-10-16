# Where things stand

**Last updated: 2026-10-16** · version 0.34.3 · schema v21 · 737 tests pass

**This file holds the current state and the next steps, nothing else.** No log of PRs:
git, the PRs and [ADR 0004](decisions/0004-ledger-ui.md) hold the history. When a PR
merges, rewrite "Next step" and correct the tables; don't add a dated block. Keep it
under about 20,000 characters. Everything this file said up to 2026-10-07 is in
`docs/archive/STATUS-2026-10-07.md`, which is not for reading unless the owner asks.

## Next step

**Open source (owner, 2026-10-16):** the repo is public under GPL-3.0 or later, with its
whole history (ROADMAP "Decided (owner, 2026-10-16)"), and free in every store.
Anything pushed is published. Left in ROADMAP B2: the policy's copy on the website,
the public `betterbudget` README that says the code is private, store listings set
to free.
The privacy policy stays as it is (owner, 2026-10-16: "I don't think it makes a big
difference"); it gains no line about the source being public.

**Where to pick up (2026-10-14): Savings is next** (owner, 2026-10-14: "I'd like to
move on to savings"; ROADMAP D). Four questions were put to the owner and are not
answered yet: what they ran into using the four steps; whether each debt on
Eliminate debt takes its interest rate and monthly payment; whether Save for the
future becomes goals with a date and an amount (recommended) instead of its two
questions; and whether the line "In the order of Personal Finances for
Self-Reliance…" goes (recommended). Build from their answers, two or three options
with sketches first. **Two computers, step 4, waits until after Savings** (the facts-first policy and
the blocks for the cases still asked as a whole ledger; ADR 0005); the first real
run on two Mac accounts worked (owner, 2026-10-14: "this worked"). Show the owner
what step 4 would change on screen before building, with a recommendation.

**Version 0.34.3 (fix, found by the owner on 2026-10-15):** a balance typed in
setup, then the bank's last days imported, came out off by the rows dated on the
balance's own day: the import only held rows dated before it. Rows on that day now
count as held by the balance ("dated on or before"), with the same default move and
"Leave it" (ADR 0004 "Rows on its own day count too"). Running on the owner's main
account; not yet tried on a real import. **The `savings-interest-rate` branch
(0.35.0) needs `main` merged in** before its PR, and its STATUS kept.

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
folder), not yet on two machines. A plain popup for a failure is on the list
([ROADMAP](ROADMAP.md) "Still on the list").
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
folder. Then, in order:

1. **More than one computer on the same ledger: the question about one row.**
   Steps 1 to 3 are built ([ADR 0005](decisions/0005-mobile-companion.md) "More than
   one computer on one ledger": never write blind, combine, look while open). What
   two computers changed apart is brought together and written to the folder; a second computer is set up by **Open ledger** on its first screen
   (one pick of the folder), or, where a ledger is already there, by Restore from…
   the folder's `Ledger.betterbudget` with "Share the ledger in My
   Drive/BetterBudget" ticked. **The first thing to watch with the owner** is Open
   ledger on the second Mac account: the Mac's real folder dialog has only been
   faked in tests.
   **It has not been run on two real computers**, only in tests with two ledgers and
   one folder; the first real run is the owner's to watch. **The design was
   re-chosen on 2026-10-12** (above, and ADR 0005 "the way chosen"): five PRs,
   starting with schema v20. Steps 1 to 3 of those five are merged (#67 to #69);
   the older look still runs alongside until both computers carry a vector.
2. **The rest of the phone.** Its entries and new categories now reach the computer
   (ADR 0005, "Built, 2026-10-08"), seen working on the owner's Pixel and Drive folder
   on 2026-10-08. Not yet seen: whether asking Drive to refresh its listing makes the
   phone's waiting line go within a minute, or only the two-minute fetch does. Money
   in is built: the +/− button beside the amount, with Income offered in the Category
   list (ADR 0004 "Phone screens: Ledger first"); the button was tapped on the
   owner's Pixel, but no real refund or income has been saved there and watched
   arriving. Transfers are built (2026-10-09). Then: the other phone's entries, and the iPhone
   build (its folder access and icon). Two computers that each take the same entries
   in are combined and the entries counted once.
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
4. **From the list of things to do** ([ROADMAP](ROADMAP.md) "Still on the list"):
   a search field at the top of the categories where they are picked from a list
   (owner, 2026-10-12: "there will be a lot of categories"), splitting one
   transaction over categories (owner, 2026-10-12: clothing and groceries on one
   receipt), a plain popup for a failure (owner, 2026-10-10), and no yellow-and-black
   overflow stripe anywhere on the computer or the phone (owner, 2026-10-14; a large
   working balance runs past the account header's box today). Each is designed
   and shown to the owner first.
5. **The rest of the new look.** The computer is fully on the logo's colors (ADR 0004
   "Gold is an accent, and the new colors come first"). **The phone is next when the
   owner asks**: it still always shows dark Blue eclipse (`main.dart` sets it), and
   the Pixel still has the old build and the bee icon: its new icon is drawn in the
   project and arrives with the next install. The Mac's icon is the logo on a navy tile
   (2026-10-09); Android's drawn one is still the white tile. The iPhone and Windows
   builds still have Flutter's icon. The four Savings pictures the owner drew are on the
   Savings page, day and night (`app/assets/brand/savings-*.svg`).


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

## Waiting on the owner

Asked and not answered. Don't re-ask; bring one up when its screen comes up again.

0. **Payees, answered 2026-10-12** (nothing waiting): TDB's export has no shop
   name on a card row ("That's why it's so important for users to enter their
   transactions rather than relying on TDB"); the popup keeps remembering the
   whole payee by its start, the Payees page is where it is fine-tuned; instead of
   a line in a row's category dropdown, a box on the transaction (built: "Remember
   this category for this payee" under the entry row and a row's Edit). Also
   answered no: moving the rows already in the old category when a payee's
   category is changed ("that would be really bad").

1. **Three from the Pay step's budget review** (2026-10-07). Payday today: with pay
   "On the 7th" set up on 10.07, the form says "Next payday 2026.10.07" though the
   balance just typed may already hold that pay, so it would be counted twice; should
   a payday on the balances' date be taken as already in? An irregular earner picks
   "It varies" and is then made to give a day: should When have "No set day", doing
   what "I don't have regular pay" does? And Name is the form's first field though it
   does nothing until there is a second pay: show it only from "Add other pay" on?
2. **"Always file" in the category dropdown** (2026-10-07). The offer also at the foot
   of a row's category dropdown, reading "Always filed here · Stop" once the rule
   exists. Today the popup's 12 seconds are the only chance to make one (the Payees
   page drops one). Asked again on 2026-10-12: "I don't understand this, you'll need
   to explain it better." Ask it with a picture of the row and its open dropdown.
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
16. **Two wordings from the colors review** (2026-10-09). Should a late bill say what
    it means for the balance, "due 22 days ago · not in Working yet"? And should an
    import that doesn't match the bank lead with the amount as its own sentence,
    "₮3,298,850.00 apart from the bank."?

17. **Three about the four Savings steps** (2026-10-09). On Eliminate debt, should
    each debt take its interest rate and its monthly payment, so the page can say
    which costs most and about when it will be gone? What does Save for the future
    hold: it has "Saving for retirement" (I am / Not yet) and "Paying off the
    mortgage", and the budget review says the first means little where everyone
    employed pays social insurance and nobody pays a 6% ипотек early; goals with
    dates (ROADMAP D) were offered instead or as well. And should the line under the
    steps, "In the order of Personal Finances for Self-Reliance…", go now that the
    steps are the owner's own?

## Phase

**A working desktop ledger and budget are built** and run on macOS from
[`app/`](../app/). The owner is using it with real money and refining it by what they
hit. The road to beta and the platforms after it is in [ROADMAP.md](ROADMAP.md).

## What exists (desktop; each line checked against the code on 2026-10-07)

| Area | What works |
| --- | --- |
| Storage | Drift/SQLite at schema v21 (a transaction also holds `made_how` and `made_on`, where it came from; the `changes` log of what this computer changed, each computer's own), encrypted in SQLCipher v4 format, WAL mode. Double-entry ([ADR 0003](decisions/0003-double-entry-schema.md)): a write that doesn't sum to zero is refused. Deletes are soft. Before an upgrade the file is copied beside itself (`Ledger.before-v21-from-v20-<time>.betterbudget`) and the upgrade runs in one transaction. A ledger saved by a newer build is refused |
| Sidebar | Sections Ledger, Budget, Savings, Payees. Under Ledger: All accounts, then accounts grouped Bank, Cash, Credit. A Settings gear above Net worth |
| Accounts | Add account: name, Type (Bank account, Cash, Credit card or loan), Currency. It starts from an opening balance, or from a bank file ("Or import a file from your bank"). Menu: Rename, Change to bank account / credit card or loan, Archive…, Delete…, and "Payments come out of" for a card or loan. A cash account is offered neither Reconcile nor Import |
| Register | One signed amount column (money in green with a plus, money out in ordinary ink with a minus) and a running balance. Tabs All, Uncleared, Scheduled, Not categorized. Search with ⌘F |
| Entry | Add or ⌘N opens the row. Missing fields are named ("needs date"). An amount takes a sum, and `+` in front for money in. `→ Account` as the category makes a transfer. A calendar under the date. A box under the row, "Remember this category for this payee", while there is one to remember: ticked, the payee is remembered with the row, one undo (also in a row's Edit) |
| Editing | Double-click a row to edit it in place, with Cancel. A reconciled row's date and amount are locked. Split lines can't be edited |
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
| Savings | Four steps, each with the owner's picture: Build a safety net (one month of expenses, taken from the budget, then the three-month average, or typed; it is what is Left in the built-in Safety net category; the step says how much of it is in the accounts the category is Paid from, and offers money not assigned), Eliminate debt (every card and loan owing but a mortgage or a card paid in full every month), Build three to six months of savings, Save for the future (saving for retirement, and paying off the mortgage). Each is done, current, later or set aside. The page fills the window. Counts one currency ("another currency, not counted yet") |
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

## Not built yet

- **Setup after pay:** bills, everyday amounts, saved money, assigning,
  "from tomorrow", import. Settings can't be reached until setup ends.
- **Splits** can't be created or edited (`splitNotEditable`). On the list of things
  to do (owner, 2026-10-12).
- **Payees, the rest** ([ROADMAP](ROADMAP.md) "Payees: the real feature"): a payee that is
  a transfer, "Shown as", money in or out only, an amount floor, a second spelling.
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
  in by the computer as uncleared rows with one undo. A transfer between two accounts in one currency is picked at the foot of the Category list. Not built: renaming a category
  made on the phone; fixing a waiting entry; other phones'
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

- **From the reviews of the four Savings steps (2026-10-09), not fixed:** a month of
  expenses taken from the three-month average (nothing budgeted) leaves out payments
  on a car loan or salary loan; a month from the budget counts every category that
  isn't picked as the safety net, a holiday or a new-phone category included; the
  changes made after the owner's corrections had no review pass (owner's rule: once
  per feature); the phone's Budget lists Safety net among the spending categories;
  "in Khan Savings" counts all of that account, though another category paid from
  it may claim part; Safety net is made at launch with no undo, and two computers each make their
  own before the ledgers are combined (Income has the same gap; for step 2 of two
  computers); merging it into another category by renaming removes it until the
  next launch makes a new one; with it the Budget list is a row longer than a
  1440 × 900 window, so the page scrolls; Eliminate debt shows a check when the ledger holds no card or loan, though
  Storepay or a loan taken from pay may not be an account; with a mortgage, Save for
  the future is done only by "Paying extra" or a zero balance, and one click on
  "Paying extra" finishes it with the whole loan left; "Not yet" is lit under "Do you
  have a mortgage?" before any answer; a mortgage account with no balance yet reads
  "Paid off"; "Paid in full every month" is offered on a loan; the smallest debt is
  the one to pay extra on even when it is Storepay at no interest; "pay only the
  minimums" and "employer matches" don't fit loans and pay here. Untested: that an
  account marked a student loan keeps its mark when "Debt to pay off" is picked.

- **From the reviews of Payees, the real feature (2026-10-12), not fixed:** the
  popup on a ledger row remembers the whole payee by its start, so on a TDB card
  row ("12345678: НОМИН") it fits one terminal only, and a month of Remember
  leaves a line per terminal to retype as «Номин» anywhere (fixed in part: a
  second Remember changes the line rather than doubling it; the rest is a
  question under "Waiting on the owner"); Remember is still offered when a wider
  line gives the row another category, and the narrower one made then wins
  without a word; the Latin and Cyrillic spellings of one shop are two lines
  (`samePayeeName` could make them one); the count line names rows the person
  can't see ("2 in another category") with no way to show them; "At the start of
  the payee" is the default on the page though it misses most Mongolian rows
  (the line says what "anywhere" would take); the red Delete on every line
  against "red is for a shortfall" (drawn so in the layout the owner picked);
  Mongolian for the new words is a draft; the ordering of two rules that fit
  alike goes by when each was made, not last changed; the first look after two
  computers both upgrade asks which ledger to keep, as any new version does, and
  the carried rules then agree. Untested: a pay picked in the Edit, a payee on two
  accounts filed from the page (`_fileWaiting` across accounts), a rule on both
  computers in `combine_test.dart`, the v18 upgrade of a pay rule, a hand-filed
  row after Delete with a memo rule, the sidebar at 1360 × 760 with the fourth
  section.

- **From the reviews of how a new computer starts (2026-10-12), not fixed:** the
  three rows can't be reached with Tab (a click opens one; Enter and Esc work
  inside); without a keychain (Linux, no Secret Service) the first screen no longer
  says the key is asked at every launch, only the second launch does; "Where is
  your ledger?" answered In a folder on a computer whose empty ledger is already
  stored in another folder moves it without a word; a ledger half-arrived in the
  folder reads as a key that doesn't open it (the line says it may still be
  copying); a restore that throws leaves its `incoming-…` copy for the daily sweep;
  the popup for a folder with no ledger is the gold one, behind the dialog;
  `ledgerHere` on the key screen is always true now. Untested: Undo and Redo of
  Open ledger, the folder failing to be kept after it, the wrong-key line for a
  folder (the backup's is tested), the first screen in Mongolian past its heading.

- **From the reviews of a second computer in one step (2026-10-12), not fixed:**
  whether the Mac's folder dialog really opens on the folder, and its answer is
  known as the same folder, hasn't been seen in the sandboxed app (tests fake the
  dialog); any file named `Ledger.betterbudget` outside the app's folder gets the
  offer, one downloaded into Downloads included; the checkbox has no key of its
  own (Enter restores, Esc cancels); the first offer's file dialog still opens on
  the app's Backups, not on Drive; untested: the folder failing to be kept after
  the restore, another folder chosen in the Mac's dialog, a computer that isn't a
  Mac, and the offer at first launch with a folder's ledger. The test waits about
  20 real seconds for the 5-second write.

- **From the reviews of combining (2026-10-10), not fixed:** two real
  purchases typed alike on each computer beside a phone entry both took in can be
  paired as that entry (the count stays right); a purchase typed on one and
  imported on the other is in twice and said to look the same, not matched as an
  import on one computer would; a refund recorded to an
  account the other archived lands out of sight; an amount assigned to a category
  the other deleted comes in, and goes back to Not assigned; each picking a
  different pay to view the budget by can leave both marked; a category whose
  amounts were spread over days of one period and changed on both on different
  days isn't seen as one category assigned on both; both taking an "Always file"
  offer in one account, both confirming one payday, or one filing a bank row the
  other imported, is asked about though it needn't be; the popup is up six
  seconds (twelve with Show) and can come and go with nobody looking, and nothing
  afterwards says what came in; Show opens only the first of several rows alike;
  a future upgrade that adds rows with plain SQL would give two
  computers one id (asked about, not silent). Untested on the screen: that Show opens the row.

- **From the reviews of two computers, step 1 (2026-10-09), not fixed:** the
  question shows counts only, not which entries each side alone has; picking a folder
  whose ledger hasn't arrived yet writes this computer's there; a second file the
  sync service makes beside the ledger ("Ledger (1).betterbudget") isn't looked for;
  a disk cloned to another computer gives both one id; undoing "Move my ledger to a
  folder…" after "Replace it" doesn't put the replaced file back (it is in Backups
  as `from-folder-…`); on the first run after the build before this one, a second
  computer's file written within two minutes of this one's last write is taken for
  this one's own; the Mongolian for the new words is a draft like the rest.

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
- **From the reviews of transfers on the phone (2026-10-09), not fixed:** a loan
  payment moved to the loan takes the whole payment off what is owed, interest
  included, so the debt reads low until it is split on the computer; an ATM or
  interbank fee is a second entry nobody asks for; the heading says "Move" where the
  waiting list and the computer say "Transfer", and the row is labelled Category
  though it holds an account (both as sketched for the owner); paying more than is
  owed on a card reads as a minus amount "owed now"; a transfer whose account was
  deleted on the computer waits on the phone for good, named only "Transfer"; an
  account that leaves the ledger while a transfer to it is half typed turns the entry
  back into spending with no category.
- **From the reviews of the backup reminder (2026-10-09), not fixed:** "Erase
  everything and start over" keeps the old record, so a new ledger can be told on
  its first day, or not for a month; "Back up to…" into a folder on the same disk
  counts as elsewhere; a count of 100 days or more may wrap to a second line in the
  sidebar, and the Mongolian line's fit wasn't looked at; no test that a ledger in
  a folder, or setup, hides the line, nor that "Back up to…" records the day.
- **From the reviews of the folder and the phone (2026-10-07), not fixed:** a ledger
  under both names (`betterbudget.sqlite` beside `Ledger.betterbudget`, which an older
  build would make) is ignored without a word; a write already under way when "Move
  it back to this computer" is pressed still lands in the folder (fixed in PR #59,
  as is an old or second computer replacing the folder's ledger); the Backups note still says to use a USB stick once the ledger is in
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
  Confirm adds it again; a refund the bank posts over 10 days later, or for another
  amount, comes in twice on import; a refund dated in an earlier period raises this
  period's "left" on the phone, though the computer may put it in Not assigned; the
  Income toast doesn't say the money is in no category; a category made while the
  entry is money in is a spending one holding a refund; the account list offers a
  mortgage or student loan, which the computer's budget leaves out; the +/− button is
  half under the toast while it shows; the +/− button's spoken label in Mongolian
  ("Орлого болгох") uses Income's own word.
- **`budget_test.dart` "plans paid weekly, a date years ahead is still
  quick" failed once** (2026-10-08) with the Mac busy (it times itself against 200
  ms) and passed three times alone.
- **A blank window at launch** (seen 2026-10-01 with the Mac locked, the Keychain
  refusing the key with -25308, and 2026-10-09 unlocked, cause unknown). Fixed in
  0.34.1: anything that goes wrong between launch and the ledger opening now says
  what, with Try again (ADR 0001 "At launch"). Not covered: a step that never
  returns (it would still sit on the empty screen), and a failure in `main.dart`
  before the window's first screen (reading the appearance or language files).
  The same PR fixed `keys_test.dart`'s two tests that failed now and then: their
  random key's typo fitted the first build's check rule about 1 time in 34.
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
