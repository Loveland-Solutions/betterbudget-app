# Where things stand

**Last updated: 2026-11-23** · version 0.155.0 · schema v28 · 1442 tests pass

**This file holds the current state, nothing else.** What's left to do (features, bugs,
questions for the owner) is on the [BetterBudget board](https://github.com/orgs/Loveland-Solutions/projects/1), one issue each. No log of PRs:
git, the PRs and [ADR 0004](decisions/0004-ledger-ui.md) hold the history. When a PR
merges, rewrite "Next step", "In the stores" and the table; don't add a block about the
feature. Keep it under about 20,000 characters. What this file said before is in
`docs/archive/STATUS-2026-10-07.md` and `docs/archive/STATUS-2026-11-13.md`, which are
not for reading unless the owner asks.

## Next step

The Budget page (0.92.1–0.103.0). Budgeting by month or by paycheck is chosen in setup's
pay step and in Settings' Budget card, and a month's title is "November 2026" (#474). By
paycheck, a month's Assigned is kept where each paycheck it pays for is; a paycheck asks
only its days' share of months still running, a finished period offers no Assign, and
spending past a paycheck's part that its month still covers isn't red (#468). The owner's
months from November on were split once at launch, after a copy
(`before-paycheck-split-…`) was kept in Backups. The Spending tab is in sections by type
(#469). The sum at the top has no pane round it, Clear November's Assigned ends its row,
and the result's box has an edge; below zero it names what made it short, **Over budget**
when that is spending (#470, #464). Every category's bar is the same length, an outlined
capsule filled inside (#491), in three colors showing what's left of its own money, and a category that had nothing has
none; the phone's ring follows, an outlined circle with a slice filled inside (#465, #491). No line sits under a
category's Left: "from before" is gone, and a paycheck spent ahead says so in Left's
tooltip, so those rows are one height (#471). Each section's name is a line above its rows, which
take the whole width, and stays at the top while they scroll, with Assigned, Spent and
Left fixed over the list (#482, #489). Every row is one line, 40 points: after the name, one spot holds a warning, else
the Assign link, else the bar, the plan's sentence is in their tooltips and in Edit, and
a note is a mark after the name (#483). A category can start with an emoji: a spot before
each row's name (a + while pointed at) opens every emoji with a search in English and
Mongolian, the budget's 48 first; Edit, New category and the phone's New category have a
square before the name; the emoji is the first thing in the name, and sorting and finding
go by the words (#486). The budget counts income against what goes out, never the bank (#461): a card's payment counts only for what it owed when the budget began, money exchanged leaves one currency and comes into the other, Settings' Budget card has **Had before the budget**, and the Income tab reads "₮… received · ₮… still to come", the same figure as the sum at the top. What's left of #461 is #499. The owner is combing the Savings page (#487): under the sum, a band shows the Savings step they're on, its progress, and Savings' own Assign for what is really spare (not spoken for by a plan, last month's amount or a debt's payment, and not pay still to come); a full safety net stays done until it is a tenth short. On step 2 the band offers the month's extra to the category that pays the debt extra goes to first; the row's own ask is unchanged. The phone's Budget opens with the same band, step and progress only, counting what the phone has put in the Safety net since the computer's copy. The owner closed #487.

The owner is combing the Payees page (#488). Tab goes round a payee's Edit and stays in
it, Delete last, and the box under a row that remembers its category is a Tab stop
(0.103.1). A row's Category list has a box under New category that remembers the
payee with the pick, in one undo (0.104.0). A payee's Edit is the payee's card, the
owner's pick of three sketches (0.105.0, schema v27): its name as the heading, a line
per way the bank writes it, each with contains, starts with or is exactly and its own
count, and the row as the bank sends it and as the ledger shows it. A bank row that
fits a named payee takes the name and keeps the bank's words in its memo and apart on
the row; rows already in take it only from the offer after Save or in the Edit. The
owner's ledger was upgraded to v27 on 2026-11-18 (a copy, `before-v27-from-v26-…`,
beside it). What the reviews left is on #488. A payee can be money moved to another
account in its currency, "→ Khan Savings" in its Category list (0.106.0, #117 closed):
its bank rows come in as transfers, and the other account's row of the same money
still in Not categorized, when exactly one fits, becomes that transfer instead of a
second copy, on import and on File; what the reviews left was done in 0.106.1 (#516). A
payee's name is required, and one remembered from a row is named what the row calls
it (0.106.2, #521).

A cash account is counted (0.107.0, schema v28, #119, ADR 0004 "Counting a cash
account"): Count the cash… where Reconcile is; the difference from the rows is saved
once as an ordinary row (owner: "treat it the same way we treat the other accounts"),
to Not categorized unless a category is picked; a first count of an account with no
opening balance that finds more makes the opening balance. Cash rows have no tick or
Uncleared tab; the header says the newest count. The owner's ledger was upgraded to
v28 on 2026-11-18 (`Ledger.before-v28-from-v27-…` beside it). The phone counts too
(0.108.0): Count the cash under a cash account on Accounts, the count waiting with the
phone's entries, and the computer saving it as its own Count, in the order the phone
made things. Each computer's change file is compacted (0.109.0, the first of #451's three parts, ADR 0005 "step 5, first part"): it holds only what a computer seen in the last 45 days, or the folder's ledger, hasn't taken yet, and a computer away longer takes the folder's ledger whole when it is back. A Restore of this ledger and Erase everything reach the other computers as ordinary changes (0.110.0, the second of #451's three parts, ADR 0005 "step 5, second part"): each dialog says so first while the ledger is shared, and a row one took out and the other changed is asked about in the window. A question answered on one computer, either way, is taken on the others, which stop asking (0.110.1, #540). Next: phone parity (ADR 0005, #402). #526, the phone joining the folder as another computer, is cut into five pieces (ADR 0005 "How #526 is cut"); the first is built (0.111.0): the folder cycle and change files reach the folder through one `FolderIo`, by path on a computer and through the picker on a phone, whose Android and iPhone channels now also list and delete. The second (0.112.0): `PhoneOwnLedger` keeps a whole encrypted ledger on the phone, taken from the folder's the way a second computer joins, with its own `changes` log. The third (0.114.0): the phone shows that ledger and keeps it up with the folder as a computer does, through `PhoneSync` (`data/phone_sync.dart`): its change file written, the others' brought in, never the folder's whole ledger; a row changed two ways waits for piece 4's asking window. Piece 4 is in three parts: the first is built (0.115.0): what the phone makes (entries, categories, counts) is taken into its own ledger at once, by `takePhoneEntries`, and its change file carries it, so nothing waits in a file for a computer and the phone's own file of entries is no longer written; the Waiting list is empty. Part 2 is built (0.116.0): the toast's Undo takes an entry, count or category back out of the phone's ledger and the undo goes to the computers in its change file; what another computer brought in is said in a snack bar in the computer's words, with no Undo; "isn't on your computer yet" says what no computer has applied of the phone's own entries, and that list opens each to be fixed or deleted until one has it. Part 3 is built (0.117.0, sketch C): a thing changed on the phone and on a computer both is asked about in the phone's own window (`ui/phone/phone_asking.dart`), this phone's kept unless changed, one Save; two ledgers that can't be put together are asked on the same page, with the folder's ledger the one choice. Next are the phone's screens one by one, sketches at phone size first; the register is first (#527, 0.118.0, owner's pick of sketch C): the phone's Ledger tab shows every account's rows with an account chip, the computer's filter tabs and a search, a tapped row opens where it is as its fields, saved into the phone's ledger with Undo (0.119.0); its ⋯ beside Save and Cancel has Mark cleared, Move to (the accounts in its currency) and Delete, each a change the computers see, with Undo (0.120.0); an open split row has a Category box, "Split · 3 categories", that opens the entry's split page on its lines (owner's pick of sketch A), the total fixed and a sum that is off said before Save (0.121.0); a scheduled row opens to be confirmed, its button Confirm, its ⋯ No bill this time on a category's bill, each with Undo (0.122.0, owner's pick of sketch A); a row that may have paid a bill is asked about, under the bill and under the row, with a page for a part or several, and **Not this bill** in its ⋯ (0.123.0, owner's pick of sketch A); money confirmed for less than planned offers Still owed or Paid in full, and a box under the category remembers it for the payee, in the open row and on the amount screen (0.124.0, #403), the phone's Budget opens with the sum, the computer's terms and result on lines with their signs, above the step and the categories (0.125.0, #528, owner's pick of sketch A; the phone's categories carry Assigned and Spent, 0.125.1; a tapped row opens where it is with Assigned, Spent, Left and Add a transaction, 0.126.0; its Assigned is a field, with Assign what's planned and Clear Assigned, each with Undo and written as the computer writes it, 0.127.0; Move money is a page from the open row, 0.128.0; a category's Edit opens the New category page filled in from its plan and type, with the four type cards, saved into the ledger as one change with Undo, 0.129.0; a bill's Edit has a switch for each of the period's bills, saved with it, 0.130.0; its Edit has a Group (for a Day-to-day category) and a Note saved with it, and Archive and Delete… with Undo, Delete asking where its rows move and saying its money first, archived ones brought back from Show archived, 0.131.0; the sum's Income line opens a page of the period's paydays by date, each came, still to come or didn't come, with what is still in Not categorized, owner's pick of sketch C, 0.132.0; under them the regular incomes, each with Edit, Add regular income and I don't have regular income, the computer's pay form on one page with Save pinned, Stop asking first, each with Undo, owner's pick of sketch A, 0.133.0; both review passes on the Income page are done; next #529's accounts, the owner's pick of sketch C, 0.134.0: Net worth and Runs out on the Accounts page, a tap opening the Ledger on one account with its header (Working, Cleared, Uncleared, last reconciled) and Forecast over its rows, Add account, and a ⋯ with Edit… (name, type with its warning before Save, rate, Payments come out of), Archive… and Delete…, on the computer too, whose Delete now has Undo on its toast; then #530, the owner's pick of sketch A, 0.135.0: Reconcile in that header on a bank account or card, the card becoming Statement date, Bank balance, Cleared here and Off by, the rows not yet reconciled under it cleared by a tap on their symbol, Cancel and Lock where the tabs are, a difference that can't be found added as an adjustment, Undo this reconcile in an opened locked row, and a cash account's header with its newest count and Count the cash), then #531, the owner's pick of sketch A, 0.136.0: **Import transactions…** in a bank account's or card's header beside Reconcile, the phone's own file picker, and the computer's import window as a page (the file's table scrolled sideways with a choice over each column, skipped when the columns are already set, on the computer too; the two counts and the computer's lines under them; Cancel and Import pinned; the computer's sentence after, with Undo, a bill its rows paid undone with it); "Or import a file from your bank" on the phone's Add account, and any import into an account with no rows yet starting it from the file, as the computer's does, 0.137.0; a file sent to BetterBudget from another app asks "Which account is this file for?" with its days, nothing picked and not asked with one, a statement locked with a password says so on both, and the import's bar has Show for a row to check, 0.139.0, working on the owner's Pixel 2026-11-22), then #532, the owner's pick of sketch A, 0.140.0: a Payees page from Accounts, the computer's list and payee's card (ways the bank writes it, accounts, category), Delete in its ⋯, the offer above the list to file what waits in Not categorized this period, saying where each payee's rows go, and on a payee's card the offer to show its name on rows already in, each with Undo; then #533, the owner's pick of sketch B: Savings is a third tab, five stops across the top (the four steps' pictures and Goals) over one step at a time, a swipe or a tap from the next, each step saying what the computer's Savings page says, and Budget's step band opening it on its step (0.141.0); each step's own answers, with Undo: the month of expenses, Assign to Safety net, Skip this step for now, three to six months, retirement and the mortgage (0.142.0); step 2: a debt's rate, payment and what it counts as, Pay extra on this one, Extra each month, the way followed and Compare the two ways on a page of its own (0.143.0); Goals with Add a goal (New category on its Goal card), Edit, Move the date and the choices for a date passed short (0.144.0), with both review passes done and what they found fixed (ADR 0004 "Savings on the phone"); then a phone on its own (#534). The first-time setup walkthrough (#475, the owner's pick of sketch B) is built on the computer (0.145.0): setup ends with **Money you have** (All of it, Some of it or None of it of what the accounts hold, and what is kept for emergencies, assigned to the Safety net), then Budget shows a band with the first steps one at a time (bills, a card or loan's paying bill, day-to-day, assign) for ledgers set up from now on; the phone's Budget shows the same band, phone-sized, from the same reckoning (0.146.0), and Add the bill that pays a card ties the card to it there too. A phone on its own (#534) is cut in five pieces (ADR 0005 "How #534 is cut"); the first is built (0.147.0, the owner's pick of sketch A): a phone with no key opens on the computer's "How do you want to start?", Start fresh shows a new key once and makes a ledger kept on the phone with no folder, Restore from backup makes one from a backup file, and Open ledger takes the key and then the folder. The second is built (0.148.0): a ledger started on the phone opens on the computer's setup in the phone's form (Accounts, Income, Money you have), and finishing it opens Budget with the walkthrough's band; the finish is one write both platforms call (`data/setup_finish.dart`). Setup's Money you have, on both, asks which currency is saved in when the accounts hold more than one (#616), starts an overdrawn budget short (#617), and lets All of it follow the accounts from the balances' day to the budget's first day (#618) (0.149.0). Settings' Had before the budget takes a minus typed in, the phone copies the recovery key as a secret (Android 13+ keeps it out of the copy preview; iPhone keeps it to the phone and lets it expire after a minute), and a phone on its own says "isn't in your ledger yet" instead of naming a computer (0.149.1). The third is built (0.150.0, the owner's pick of sketch A, ADR 0004 "Backups on the phone"): a phone on its own makes a copy a day kept on the phone, and Accounts has a Backups page (the computer's card, Back up to… through the phone's own Save to, Restore from… with Undo, and the copies on the phone listed to restore); under Net worth, "No backup yet" until a copy is saved off the phone, then "Last backup 41 days ago" past 30 days. A phone on its own schedules its next paydays and bills when it opens or comes back, at most hourly, as a computer does at launch (0.150.1, #624). The fourth is built (0.151.0, the owner's pick of sketch B, ADR 0004 "Another phone or computer"): Accounts has **Use it on another phone or computer** under Backups, a page of two steps: Move my ledger to a folder… on this phone, with Undo (the folder's whole ledger written once, then the phone a member like any other), and what to do on the other phone or computer, then who has opened it. Move it back to this phone warns while another uses it. A ledger restored from a backup gets an id of its own before its first move. The fifth is built (0.153.0, the owner's pick of sketch A, ADR 0004 "Settings on the phone"): a gear beside Accounts on Budget opens the computer's Settings on one scroll, Appearance and Colors (the phone's turn at the colors: a phone in use before keeps dark Blue eclipse until changed, a fresh one starts as the computer does), Language, Budget (By month or By paycheck, Had before the budget, whose toast names Not assigned), This phone's name, Check my recovery key…, Archived accounts, Recent problems (moved from Budget's foot) and, where the phone keeps Backups, Start over, its copy listed in Backups. All five pieces of #534 are built; what the reviews left is on #534. The computer's Category box opens its whole list on every click, narrows as typed, and closes on a click off it or Esc before the row (0.153.1, #548, #555). A split's parts open inside the entry row, in its Category and Amount columns, and the row's one Add saves them; "Put ₮37,500 here" fills an empty part, and the left figure holds still while an amount is typed; the phone's split page offers "Put ₮37,500 on Clothing" (0.154.0, #542, #543, #545, the owner's pick of sketch A, ADR 0004 "A split's parts in the row"). 0.154.0 went to every store on 2026-11-23 (see below). Play's Sign in details were updated for the new first screen (Open ledger → demo key → Choose the folder…) and the iPhone's Review Notes carry a new recording (2026-11-23). A bill waiting for Confirm is found by a row still in Not categorized of exactly its amount, in its account, from 3 days before to 10 after; it is asked on the bill's line, never paid without asking, and Yes files the row under the bill's category, with Undo (0.154.1, #558, ADR 0004 "A bill paid another way"). A scheduled row's note ("due 7 days ago · not in Working yet", the late count, the account in All, "next of 4 scheduled") goes on a line under its name, as a posted row's memo does, and wraps rather than being cut (0.154.2, #556). A row a bank's file has (brought in, or typed and matched) shows a small blue bank before its cleared mark, on the computer and the phone's Ledger tab, read from the import key a match already saves; its tooltip gives the bank's day when it isn't the row's, and the bank's amount when the row's was changed since (0.155.0, #557, the owner's pick of sketch B, ADR 0004 "A small bank before the cleared mark"). Then the board's Next column: a row just added lights up gold (#546), and amounts that take + − × ÷ (#547). Before the next store build, a Back up to… into Google Drive on the Pixel, and Play's Sign in details saying to tap Open ledger. #526 is done: all five pieces, seen working on the owner's Pixel and Mac through Drive (0.131.2, 2026-11-20). An import pays a bill waiting for Confirm when the bank's row is exactly its amount within the typed-row window: the bill is confirmed on the bank's day and cleared, with no second row, in one Undo (0.138.0, #597, owner's call). The Mongolian of everything since #90's last pass is a draft until
Tanan checks it (#90).

## In the stores

| Store | Has | Waiting |
| --- | --- | --- |
| Google Play (`mn.lls.betterbudget`) | 0.154.0 (864) on Internal testing, alpha and production, 2026-11-23 (alpha and production in Google's review): the phone on its own (#534), kept up with the folder (#526), the register, Budget, Accounts, Reconcile, Import, Payees, Savings and Settings, and the split's fill button (schema v28: a phone needs 0.107.0 or later to read the folder's ledger) | Google's review of alpha and production. Sign in details updated 2026-11-23 for the new first screen |
| Microsoft Store (`9NH3HJNFJN4G`) | 0.100.0, published | 0.154.0 in certification since 2026-11-23, set to publish by itself when it passes (owner's call) |
| Mac App Store, "The BetterBudget" | 0.100.0 (731), live; free in 174 countries | 0.154.0 (864) in Apple's review, submitted by the API key 2026-11-23. The EU's 27 until the owner gives the Digital Services Act trader details (#375), which the EU shows publicly |
| iPhone App Store, same record | Nothing yet; TestFlight has 0.154.0 (864) | 0.154.0 (864) in Apple's review since 2026-11-23, replacing 0.73.1 (pulled from review at the owner's word). Review Notes rewritten for the new first screen (Open ledger → demo key → Choose the folder…); a new recording from a real iPhone (Start fresh to Budget) is linked in them. A check with Google Drive on a real iPhone is on #114 |

Listings lead with building wealth (ADR 0004); Play's and the Microsoft Store's follow
when next changed (#377). Every store lists it free. No downloads from GitHub (owner, 2026-10-20,
ROADMAP); old Windows ones are still on the public repo's releases page (#452).

## How a release goes out

A release is the owner's say each time, in every store. Run each script from a clean,
pushed commit on main; `--check` does everything but the last step.

- **Play:** `app/tool/release_play.sh "What changed."` builds the signed `.aab` (build
  number = commit count, ADR 0006), checks it asks for no network, and makes it the only
  build in Internal testing; alpha and production go by Play's edits API. Before offering
  one, compare the table above with `git log` on `app/lib/ui/phone/`. Play's review gets
  past the recovery key with the demo key `DEMO-DEMO-DEMO-DEMO-DEMO`, kept in App access →
  Sign in details (#303; ADR 0005 "A demo key for Play's review"). **A schema bump means a
  phone needs a build at or after it before it can read the folder's ledger again.**
- **Microsoft Store:** `app/tool/release_store.sh` tags main `vX.Y.Z`, which starts
  `.github/workflows/windows.yml` on GitHub (its download kept 14 days), waits for the
  build, checks the `.msix`, deletes any submission still waiting (owner, 2026-10-30), and
  sends the new one to certification, set to publish only on the owner's Publish now.
- **Apple:** `app/tool/release_mac.sh` and `app/tool/release_ios.sh` build, check and
  upload, signing with the team's App Store Connect API key in `~/.config/betterbudget/`
  (#380; Xcode 27.2's command line can't use Xcode's sign-in). Both apps' Info.plist
  answers the encryption question as exempt (`ITSAppUsesNonExemptEncryption` false, #456),
  so App Store Connect no longer asks it per build. France also waits on the French
  encryption declaration.

## Phase

**A working ledger and budget are built**, on the computer (macOS, Windows) and the
phone (Android, iPhone), from [`app/`](../app/). The owner uses it with real money and
refines it by what they hit; their wife enters receipts on her Android phone. The road
to beta and after is in [ROADMAP.md](ROADMAP.md). The repo is public under GPL-3.0 or
later (owner, 2026-10-16); anything pushed is published. Two computers on one ledger
are built through step 4 and two of step 5's three parts; the third is on #451.

**The owner's ledger is production data** (since 2026-10-06; rules in
[CLAUDE.md](../CLAUDE.md)). It holds one tugrik account and lives in their Google Drive
folder. A wordless screenshot from the owner, after being told something couldn't be
checked in the real app, is the result being shown, not a complaint.

## Questions for the owner

On the [board](https://github.com/orgs/Loveland-Solutions/projects/1) as issues titled "Question: …". Asked and not answered: don't
re-ask; bring one up when its screen comes up again.

## What exists (each line checked against the code on 2026-11-13)

| Area | What works |
| --- | --- |
| Storage | SQLite (Drift) at schema v26, encrypted (SQLCipher v4), WAL mode. Double-entry ([ADR 0003](decisions/0003-double-entry-schema.md)): a write that doesn't sum to zero is refused. Deletes are soft. Before an upgrade the file is copied beside itself (`Ledger.before-v26-from-v25-<time>.betterbudget`) and the upgrade runs in one transaction. A ledger saved by a newer build is refused, nothing changed |
| Sidebar | Ledger, Budget, Savings, Payees. Under Ledger: All accounts, then accounts grouped Bank, Cash, Credit, each with its balance and, in coral under it, "Runs out on 12.01" when its forecast goes below zero within 60 days, then **Add account**. Below: the Settings gear (a dot when the folder or daily copy needs attention), **Net worth** per currency, "Last backup 41 days ago" after a month, and **Send feedback…** |
| Accounts | **Add account**: Name, **Type** (Bank account, Cash, Credit card or loan), Currency (can't change later), **Interest rate** for a card or loan. It starts from a balance on a date, or from a bank file. Its menu: Rename, Change to…, **Payments come out of** (card or loan), Archive…, Delete…. Cash gets neither Reconcile nor Import |
| Register | One signed amount column (money in green with a plus, money out ordinary ink with a minus) and a running **Balance** (**Owed** on a card). Filter buttons, each in its color: All, Uncleared, Scheduled, and **Not categorized** while this period's rows wait; Cleared and Reconciled come from the header. Then **Import transactions…**, **Manually add a transaction** and search (⌘F: payee, memo, category, account or amount). All accounts opened from Budget is narrowed to a category and period, with its total |
| Entry | ⌘N or **Manually add a transaction** opens the row. Enter from any field; until it can save, it says what's missing ("2 more to fill in"). An amount takes a sum, and `+` (or Swap) for money in. `→ Account` makes a transfer; to another currency it asks what arrived. **Split** at the top of Category, **New category** beside it. A date after today schedules it. A remembered payee fills its category; otherwise **Remember this category for this payee** sits under the row |
| Editing | Double-click a row (or Enter) to edit in place, with **Save** and **Cancel** (Esc). A reconciled row's date and amount are locked; its category, payee and memo can change. A split's lines are edited in its card. A memo wraps under the payee, whole |
| Source | An optional column, on until Settings → Register unticks "Show where each transaction came from": Entered or Imported locally or on a named computer, From a phone, Scheduled. Blank for opening balances, adjustments and rows from before v21 |
| Row actions | Edit, Categorize, Mark cleared / uncleared, Move to (same currency), Delete; the category pill opens the same menu. **Confirm** on a scheduled row; **No bill this time** in place of Delete on a category's bill. A bill a row may have paid asks "Paid on 10.13? … Yes / No"; a row taken as the bill has **Not this bill**. The newest reconcile's rows have **Undo this reconcile**. Keys ↑ ↓, Enter, C, Delete, Esc |
| Undo | ⌘Z and ⌘⇧Z (Ctrl+Z, Ctrl+Y on Windows) through this session's actions; in a text field they act on typing. A popup's Undo works only while its action is the newest. Changes brought in from another computer clear the list |
| Popup | Gold, 440 wide, bottom right, with Undo, for a saved change; it stays while the pointer is on it. After a category is picked it offers "Remember this for next time". A failure is a plain card with a coral edge, **Show details** and Copy |
| Header | **Working** is the large number (coral below zero; Owed on a card), Cleared and Uncleared under it, each a click that picks out its rows. "Last reconciled on" and Reconcile (not on cash). The forecast chart fills the rest of the card |
| Forecast | Range buttons To income (with a payday ahead) · 30 days · 90 days · 1 year · Custom…. The line steps at each dated row and slopes with the budget's day-to-day spending, drawn as a band; coral below ₮0, its dip marked Lowest. The key, Money out · Day-to-day · Transfer · Money in, lights its marks and opens every bill with the balance after each. Hover reads any day; a click on an event opens its row. Words only where the chart can't speak: nothing scheduled, a wallet to fill, what a card is owed, running out past the range |
| Reconcile | Takes the balances' place: Statement date, Bank balance, Cleared here and Off by, with a hint at the likely row. When they differ, "Add ₮… to the balance and lock"; when they match, Lock N transactions. The database refuses changes to locked rows |
| Budget | Spending and Income tabs; period arrows and Back to today; the title picks Month or an income's pay periods. At the top, one sum in boxes with no pane round them, counted from income and never the bank (#461, #464): Income + From October − Assigned − Saved − Overspent = Not assigned, its box edged in its color, or in its place what made it short (Assigned too much, Over budget, Still short from October, Short); Clear September's Assigned ends the row; what a period leaves, short or spare, carries into the next; under it Assign what's planned (its warning inside the button). Each category reads Assigned · Spent · Left; Left is green, gray at zero, coral when short, and **Move money** moves it. A capsule after the name, the same length for every category (#465): the colored part is what's left of what it had, whole green untouched, gold as it's spent, whole coral when over, and none where it had nothing (the phone's ring follows the same rules). Add category sits on the tabs' row. Everyday categories, then the person's groups, then **Bills**, one line each: its amount, one word when something is up ("paid 10.20", Late, Skipped, short, Paid from archived) and Assign; skipping is a switch for each of the period's bills in its Edit, then **Saved**; a **Total** row; each currency on its own |
| Budget: Saved | The built-in Safety net, listed last under "Saved"; its money builds up. Renamed and edited, not deleted or archived. Made the first time a ledger past setup opens without one |
| Categories | Add category and "New category" in the entry row open the same window, with Add, then start another. It and Edit open on four type cards with pictures (#429): **Day-to-day** (an amount each month or pay period, Just for September, what's left at month's end), **Fund** (an amount each period, Most it holds), **Bill** (Amount due, How often: Twice a month with Starts, Every payday, Custom…, On these dates…; Ends), **Goal** (Amount to have ready, Ready by, once or repeating, shown on Savings by what was put toward its next date, never marked paid). The phone's New category has the same cards, two to a row. Also one **Paid from**, Currency; in Edit, Group, Note, In a month of expenses?, Archive, Delete…. The type isn't stored: it comes from the plan. One built-in Income |
| Regular income | On the Income tab, under "received · still to come" per currency: a name, who it's from, Paid into, the amount (About the same each time, or It varies), How often as a category's or No set day, the first payday, a weekend rule, Ends, each with an ⓘ. "I don't have regular income". "Stop counting on this income" asks what its categories go by from then |
| Savings | The owner's four steps with their pictures: Build a safety net (a month of expenses from the budget; what's Left in the Safety net), Eliminate debt (each card and loan's rate, interest and payment; Smallest first or Highest rate first, with when each pays it all off), Build three to six months of savings, Save for the future. Each is done, current, later or skipped for now. Goals under the steps: what for, how much, by when; on track or behind, and what each asks a month. One currency |
| Payees | Every payee the app remembers a category for, a line each that reads as a sentence ("starts with «Unitel»"), its accounts, its category, Delete. A click or Add a payee opens its Edit in place: the words, where to look, Accounts, Category, how many rows it fits, one drawn as it will read. Save offers to file this period's rows in Not categorized; rows in a category are never moved. On import the longest words win, then the later-made |
| Import | `.xls`, `.xlsx`, CSV and OFX, told apart by contents; the column choice is saved per account. Two counts, to import and skipped. A typed row the file has is cleared, not added; one at another amount is offered ("Same purchase: take the bank’s ₮…"). A check of the bank's running balance; a warning when rows overlap an earlier import. Remembered payees file the rows; one in a bill's category pays it. One undo |
| Currencies | 155, each with its own decimals and symbol ([currencies.md](currencies.md)). A transfer between two takes both amounts and shows the rate, through a hidden exchange account. Net worth has a line per currency |
| Two computers | The folder holds the whole ledger and one change file per computer, written only by it. Each looks at launch, on coming to the front and every 15 seconds, and brings in the others' changes ("4 transactions from Tom’s MacBook Air", no Undo; what was here is in Backups). A row or Assigned amount changed two ways is asked first, one window: Keep this computer's, Keep the other's, Neither: as it was; answered on one, the others aren't asked. Only a ledger that can't be put together asks which whole ledger to keep. A second computer joins by Open ledger, or Restore from… with "Share the ledger in My Drive/BetterBudget". Open the app from Applications, never from inside the Drive folder |
| Backups | A copy a day, keeping the newest 14 and the first of each of 12 months. Back up to… ("Last backup 41 days ago" after 30 days, unless in a folder). Restore from… and "Erase everything and start over…" save what was there first, and undo; shared in a folder, both reach the other computers and phones as ordinary changes, which their dialogs say first. "Move my ledger to a folder…" keeps it, encrypted, as `Ledger.betterbudget` in a Drive, OneDrive, Box or Dropbox folder, written 5 seconds after a change; "Stored in" says where |
| Security | A recovery key shown once at setup (the clipboard cleared a minute after a copy; on a phone, copied as a secret that expires); a key from before 11:50 on 2026-09-29 ends in an older check character, and the app takes both (the owner's is one). A screen asks for it when this device has none. Settings → Security, "Check my recovery key…" ([ADR 0001](decisions/0001-database.md)) |
| Appearance | Same as this Mac, Light or Dark; 101 color schemes, the app's own first: the logo's navy sidebar, a cool white page by day and blue-black at night, green main buttons, blue for what you click, the coins' gold for what was saved. In every scheme money in is green, money out ordinary ink, coral a shortfall or failure, gold reconciled |
| Language | Same as this Mac, English or Монгол; 1,662 messages, the same keys in both files |
| Setup | "Your accounts": one date for every balance, a line per account, "How do you pay for everyday things?", Continue. "Your regular income": the form, with a card beside it of what it does to the forecast and budget, then "Open my ledger". It resumes where it was left and never returns once done. A computer with no ledger and no key opens on "How do you want to start?": Start fresh, Restore from backup, Open ledger; cancelled, "Where is your ledger?" asks |
| Settings | Appearance, Colors, Language, Backups, Security, Register (the Source column; a name for each computer and phone), Archived accounts, Start over, the version. **Recent problems** while there are any: the newest five, on this computer only, no amounts, with Copy all. **Send feedback…** under Net worth opens lls.mn's contact form with the version, platform and system |
| Phone | Android and iPhone, to record and check ([ADR 0005](decisions/0005-mobile-companion.md)). Set up once with the recovery key and the folder; reads `Ledger.betterbudget` there every half minute and says how fresh it is. **Ledger**: an amount pad, payee, account, a Category dropdown (Split at the top, each regular income by name, transfers, + New category), Save; "1 entry isn't on your computer yet". **Budget**: what's left in each category with its ring, Accounts, Send feedback…, Recent problems. Entries go to the phone's own file in the folder and come in on the computer as uncleared rows. `DEMO-DEMO-DEMO-DEMO-DEMO` as the key opens made-up figures |
| Windows | The Store app keeps the ledger, its copies, the saved key and settings in its package folder, so uninstalling leaves nothing; the old zip download's ledger comes over with Open ledger |
| Demo data | Tests only (`LedgerScreen.demo`): TDB Checking, Khan Savings, Cash wallet, Golomt Visa, the Safety net. The app never seeds it |

Rules behind each: ADR 0004 and ADR 0005. Where the code is: [MAP.md](MAP.md).

## Known limits, accepted

**Dropped:** putting `+` in the amount when a payee's last row was
money in. It is a guess filled into a field (owner, 2026-10-08: "Don't autofill").

A scheduled split confirms at its planned total only;
"Back up to…" overwriting a file isn't atomic in the sandbox; the newest 5
`before-restore` copies are kept, not the oldest; undoing a reconcile in a later
session loses the statement balance.

## Local setup notes

- **Toolchain:** Flutter via Homebrew (`brew install --cask flutter`). Xcode is selected
  (`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`). If the macOS build
  fails with `tapi error … MacOSX27.0.sdk`, `xcode-select` is pointing at the Command Line
  Tools again.
- **Signing:** the Mac and iPhone apps sign with the paid team "Loveland Solutions, LLC"
  `44H5SLX8KR`, needed for the Keychain entitlement and the App Store; a build signed by
  another team can't read the ledger's key (ADR 0001). No iPhone is registered, so an
  iPhone build reaches a phone only through TestFlight. If Xcode asks for a new
  provisioning profile, run once from `app/macos`: `xcodebuild -workspace
  Runner.xcworkspace -scheme Runner -configuration Debug -allowProvisioningUpdates build`.
  Android's package is `mn.lls.betterbudget` (the Apple one,
  `com.lovelandsolutions.betterbudget`). Release builds sign with the upload key
  `~/betterbudget-upload.jks` (alias `upload`) when the git-ignored
  `app/android/key.properties` holds its password, otherwise with the debug key; the owner
  keeps them in KeePass. `keytool` is Android Studio's,
  `/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool`.
- **Goldens** are drawn on macOS 27; another macOS version differs by about 0.1%.
- **If tests stall** (widget tests time out with the CPU idle), look for leftover
  `flutter_tester` or `dart pub get` processes (`ps -ax | grep -E "flutter|dart"`), then
  restart the Mac.
- **Checks on GitHub:** `.github/workflows/check.yml` runs analyze and test on each pull
  request touching `app/`, about 17 minutes, not required for merging (MAP.md "Checks on
  GitHub").
- **The logo** and the Savings pictures are made by `assets/logo/prepared/prepare.py` from
  the owner's five vectors in `assets/logo/Images/`; the rest of that folder is on the
  owner's Mac only, not in git.
- **Run:** `cd app && flutter run -d macos`, or build with `flutter build macos --debug`
  and open `app/build/macos/Build/Products/Debug/BetterBudget.app`.
- **Rebuild and relaunch** (from `app/`): the owner runs a Release build signed by the
  company team (44H5SLX8KR), so build that, then quit and open it: `xcodebuild -workspace
  macos/Runner.xcworkspace -scheme Runner -configuration Release -derivedDataPath
  build/macos-company -allowProvisioningUpdates build && pkill -f
  "BetterBudget.app/Contents/MacOS"; open
  build/macos-company/Build/Products/Release/BetterBudget.app`.
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
