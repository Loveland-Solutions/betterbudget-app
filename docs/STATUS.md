# Where things stand

**Last updated: 2026-10-07**

Start here if you are picking this up cold. For AI sessions, [`CLAUDE.md`](../CLAUDE.md)
summarizes how to work in this repo.

## Phase

**The first working desktop ledger is built** and runs on macOS from [`app/`](../app/).
The owner is refining the ledger by using it and giving feedback; **the budget comes only
after the ledger is dialed in.** **Goal now (owner, 2026-09-24): an alpha the owner can
start using with real money**; see "Next step".

**Branch `popup-review-fixes` (2026-10-07, version 0.13.1, no schema change; committed here, no PR yet): what the reviews of PR #44 found.** The code review, the budget app review, a words pass and a behavior pass were run again on 0.13.0 (their first run was lost when it merged). Fixed, all in ADR 0004 "The popup is a card" and rule 3:
- **The popup and the pointer** (`_toastPointerAt`, `_toastMayLeave`, `_toastClicked`, `_closeToast` in `ledger_screen.dart`): a pointer that only crossed an offer no longer cuts its 12 seconds to 4; a popup that takes the place of one the pointer is on (⌘Z, its Undo, its offer) stays under the pointer; one that appears under a pointer left in the corner leaves in its own time.
- A click on the card isn't a click away from a row open for typing (`TextFieldTapRegion`). Opening a row's Edit or a category's Edit puts the card away, since it lay over Cancel and Save (`onEditOpens` on the Budget page); a new category shows no "added" popup. A row with no payee has no empty second line.
- **A credit card's import preview showed the opposite of its register** (a purchase green with a plus, then red with a minus once in); it now shows what the register will.
- Search finds an amount typed with its sign ("-30000").
- Words: the button reads "Always file this payee here, and 1 more row now"; the offer taken back reads "Undone · Always filed under Income"; three Mongolian strings redrafted with a verb (still unchecked by a native speaker); a glossary line.
- **Undo on the popup sat higher than its sentence in the real app** (owner's screenshot, 2026-10-07): a Mac draws buttons 8 shorter than the tests' platform, which no golden shows. The card's two buttons keep the standard size now. Other buttons in the app may be shorter on the Mac than their goldens; not looked at.
- 453 tests (ten new: the popup group, the card preview, the search); `popup_offer_light.png` redrawn.

**Asked of the owner, not answered (2026-10-07):** (1) how a credit card's own page should sign its rows, now that a purchase reads as a red minus beside an "Owed" that goes up, and whether an opening balance should be plain with no sign; (2) the Always file offer at the foot of a row's category dropdown, as the rule's one visible home; (3) the row's date and amount on the popup's second line, and the same two-line form for the other row popups ("Moved to Khan Savings" over the payee).

**Found by those reviews and left, none fixed:** the mouse wheel does nothing over the card; in dark mode an amount's cents (60% of the red or green) fall to about 2.6 contrast on a hovered row in the worst color scheme, and `schemes_test.dart` checks neither stripe nor hover; the forecast's bill list still shows money out plain (kept so coral there means "runs out"; the comment says so); "1 more row now" counts that payee's waiting rows in every period, while the Not categorized tab counts this period's, and the offer silently replaces an earlier rule for the payee; reconcile's "Add ₮X adjustment" doesn't say which way; coral amounts now sit under the coral "Runs out" line; a transfer shown once in All accounts reads as red spending. The test payee "IB-INTERBANK TRANSFER CHARGE 1.2.3, 1.2.4" (added in PR #44) has the shape of a real statement line: the owner should say whether it's invented.

**PR #44, branch `popup-card-and-outflow-red` (merged 2026-10-06, version 0.13.0, no schema change): the popup is a card in the page's corner, and money out is red with a minus.** Two things from the owner using it. (1) "Not loving the way this looks" about the popup after a category is picked: the design committee ran, two mockups went on a canvas, the owner picked A. `_Toast` in `ledger_screen.dart` is now a 440-wide card at the page's bottom right: what happened with Undo and ×, the row's payee on its own line (`detail` on `_showToast`, `_did` and `_Undoable`, so an undo still names the row), the offer as an outlined button; gold with dark text in both modes (`Mid.toast`, `Mid.onToast`); it stays while the pointer is on it. New words: "Filed under {category}", "Always file this payee here · 1 more row now", "Always filed under {category} · 1 more row filed" (Mongolian drafted, unchecked). (2) "It's hard to tell if the values are negative or positive. Outflow should be red and have a negative symbol in front": `_Amount` in `register.dart` (posted and scheduled rows, every register) and the import's preview. ADR 0004 rule 3, rule 9 and "The popup is a card". 45 goldens redrawn, `popup_offer_light.png` new. **Not built, to ask:** the Always file offer also at the foot of a row's category dropdown. **Merged at the owner's word while the two review passes (and a words and a behavior pass) were still running; they were run again on 2026-10-07 and their fixes are 0.13.1, above.** On a card's page a purchase and the opening balance now read as a red minus: the owner was told and hasn't said.

**PR #43, branch `category-dropdown-currency` (merged 2026-10-06, version 0.12.1, no schema change): the ledger's category lists offer only the row's currency.** The owner saw dollar categories in a tugrik account's dropdown. Now the chip, Categorize and the entry row's list hold the spending categories in the row's currency plus Income and Not categorized (`categoryTakes` in `domain/budget.dart`, used by `categoriesFor` in `register.dart` and `_listOptions` in `entry_row.dart`); a card's "payments come out of" list is narrowed the same way. A row already under a category in the other currency keeps it, and a name typed in full still finds it. ADR 0004 rule 28. 440 tests. The two review passes weren't run (a fix to a list, not a feature).

**PR #42, branch `uncategorized-on-ledger` (2026-10-06, version 0.12.0, no schema change): import reads OFX, a new account can start from its bank file, and income is assigned to a paycheck.**
The owner's US credit union download (`.ofx`; `.qfx` and `.qbo` are the same thing) was
greyed out in the open dialog and, renamed `.txt`, "has no rows with a date in them".
It now opens on its rows like any bank file: Date, Amount, Name, Memo, the bank's own id
as the key so a later overlapping download brings nothing twice (ADR 0002 "OFX").
**All four of AFCU's downloads read the same** (CSV, `.xls`, `.qfx`, `.qbo`; ADR 0002
"A credit union's four downloads"): cents written `.37` are an amount (the CSV lost 91
rows and failed its balance check), Description is the payee (it
was the memo, and every row was paid to "FOOD"), and an empty named column
no longer shifts the names after it. **The owner's three calls, built** (ADR 0002 "The
owner's calls", ADR 0004 "Import"): the bank's own category is left out; an OFX file's
one balance shows with its day against the cleared balance; rows already imported from
the bank's other kind of file are caught by day and amount ("Already in · same day and
amount", a click brings one in). A column choice saved before 0.12 is guessed again
once. Rows the owner already imported keep the memo they came in with.
**A new account can be answered by its bank file** (owner's pick, A of three; ADR 0004
"Import"): "Or import a file from your bank" beside Start account; the window says where
the file starts and ends, and Import makes the opening balance (the day before the
first row) and the rows in one undo; a file with no balance asks for today's in the
window. A **Start from** date, first set to the current budget period, leaves the
earlier rows out and takes the file's balance for that day; "The whole file" brings them
back.
**The Not categorized tab holds only the current budget period's rows** (owner's call).
**"Always file LoveSol under Income"** is offered in the popup after a category is
picked from a row's dropdown; it moves that payee's waiting rows and the next import
follows it, names matched by how they start (ADR 0004 "Import"). **Each pay is in a
row's category dropdown by its name** ("Income · Loveland Solutions"), first on money
in; picking it makes the row that pay's paycheck (`takeAsPay`: Income, counted as
received, its payday no longer expected, the next scheduled), and the Always-file offer
carries the pay to the next import. **A new row can be typed under a pay's name too**
(the Category field lists the pays; with `+` before the amount the income choices lead,
otherwise the spending categories); one dated ahead is only scheduled and stays plain
income.
Both review passes done on the readers, their fixes in (ADR 0002 "From the reviews");
they were not run again on the owner's three calls or on the new-account import.

**PR #41 merged (2026-10-06, version 0.11.1, no schema change): "Not assigned"
on the Budget page never shows a minus.** With more assigned than there is it reads
$0.00, and a coral row under it, **"Assigned too much"**, holds the amount (in the
column of the currency that is over). The sentence "Spend what the categories hold and
cash and bank go $X below zero." is gone. The owner picked this of three sketches (ADR
0004 "Assigned too much").

**PR #40 merged (2026-10-05, version 0.11.0, schema v18): what's owed left the
Budget page, and Cash became a Type.** The top pane's first figure used to be cash and
bank *less what the credit cards owe* — an intermediate subtotal no bank shows and
nothing can be checked against. The owner asked twice what it meant, which was the
answer. Now: **"Cash & bank" (or "Bank", or "Cash" — it names what the ledger actually
holds) is the money in the asset accounts, nothing subtracted.** A credit card or loan
is budgeted by its *payment*, as a category like rent, through the account menu's
"Payments come out of ▸"; what is owed, and paying it down, belong to the Savings page
(barely built). Cash is its own account Type, so a wallet is no longer offered
Reconcile or Import. Accepted consequence, tested and in the ADR: buying on a credit
card raises Not assigned until the card is paid. This **reverses the 2026-09-30 call**
("Card debt reduces the money"). See ADR 0004 "What's owed is not the Budget page's job".

**PR #39 merged (2026-10-05, version 0.10.0, no schema change): the Budget page's top
pane as "the key".** "You have · In categories · rule · Not assigned", one column per
currency, each note on its row, the first-period offer a strip in the card, the period
title as the view dropdown, ⌘N adds a category (ADR 0004 "The top pane"; mockups in
`docs/mockups/budget-top-pane.html`, the owner picked B of three).

**PR #38 merged (2026-10-05, version 0.9.0, no schema change): the owner's two calls
on two earners.** A share bigger than the amount says why ("₮600,000 still to put in
for 10.23–11.24 · plus about ₮180,000 toward the next"), and stopping a pay that
categories are per warns, names them and moves them to another pay or the month, one
⌘Z (ADR 0004 "Two earners", last two points).

**PR #37 merged (2026-10-05, version 0.8.0, schema v17): two earners.** The owner
asked "Jeff and Jenny are married. They both get paychecks. Can they use this
budget?" and designed the answer (ADR 0004 "Two earners"): Budget by is gone from
Settings and the pay setup; it's a **view dropdown on the Budget page** beside the
period ("Month ▾" or a pay's name, once there's pay; no toast, ⌘Z goes back). A set
amount's Edit has a **How often** row, "Every month" (default) or "Every pay period ·
Jenny": the category's own period (its amount, its month-end emptying, its words).
Seen by another period it's **prorated by days**, said "about", of what its own
period still wants; bills divide as before. A **pay has a Name** (the setup's first
line) that the dropdown, How often, the note and the Income tab use. Schema v17:
`pay_schedules.name`; set amounts of a ledger that budgeted by pay period get that
pay. Both review passes done, fixes in (see Next step).

**PR #36 merged (2026-10-05, version 0.7.0, schema v16):** the owner's
notes from a call with Cynthia G. Loveland about the Budget page. Its first commit is the
credit line at the bottom of Settings ("The Budget page was laid out with help from
Cynthia G. Loveland.", both languages, a Thanks section in the README, ADR 0004
"Credits"; 0.6.1). Then four of her six notes, built (ADR 0004 "From the 2026-10-05
call"): Add category opens the new row's Edit; one **Paid from** row of checkboxes
replaces the two account dropdowns in a category's Edit (a dated plan's bill is
scheduled in the one account left checked); the forecast's small title is a dropdown
of spans (the pay period, 30, 60 or 90 days, 6 months, a year; paydays and plan bills
projected that far); a coral dot in the sidebar beside an account whose forecast runs
out. The owner's calls on the rest came the same day and are built: a coral line above
an account's forecast when it runs out past the view (accounts pay goes into are looked
at a year of paychecks ahead; landing on zero counts); **Spending and Income tabs on the
Budget page, pay listed and added on Income** (Settings → Budget kept only Budget by,
until 0.8.0 moved it to the Budget page);
and How often's "Every…" is an Outlook-style **Custom…** block (weekday chips, the nth
weekday of the month, Ends never / on a date / after N times; schema v16). **Both
review passes done, their fixes in** (ADR 0004 "From the reviews (2026-10-05)").
The owner then asked what "No" to the due date means, so the question says what each
answer means beside it, "What's left at month's end" shows under No always, and the
Income tab reads "₮2,100,000 received of ₮4,200,000 expected this period" (the owner's
words). **Open (Next step):** two questions, in plain examples.

**Git state:** `main` has everything through PR #39 (2026-10-05, version 0.10.0: the
Budget page's top pane as the key), PR #38 (2026-10-05, version 0.9.0: the
owner's calls on two earners), PR #37 (2026-10-05, version 0.8.0, schema
v17: two earners, see above), PR #36 (2026-10-05, version 0.7.0, schema
v16: the Budget page from the call with Cynthia), PR #35 (2026-10-04, version 0.6.0: two budget plans behind "Is there a due date?", How often for every case including Every payday, Paid from scheduling the bill in its account, the Edit panel designed as one thing, "Type" on the New account page; schema v14 and v15; ADR 0004 rule 27 rewritten), PR #34 (2026-10-03, version 0.5.1: ledger fixes from the owner's use: the search key, why a row can't be saved said in the popup, one row open at a time, Cancel on an Edit; no schema change), PR #33 (2026-10-03, version 0.5.0: one built-in Income instead of income categories, schema v13; ADR 0004 rule 30), PR #32 (2026-10-02, version 0.4.0: one Edit per category, every currency; ADR 0004 rule 29 and "Every currency"; no schema change), PR #31 (2026-10-02, version 0.3.0: a category's currency and accounts, schema v12; ADR 0004 rule 28) and PR #30 (2026-10-01, version 0.2.0: plans, the four budget types, schema v11; ADR 0004 rule 27), PR #29 (2026-10-01, version 0.1.1: the Budget page fills the window with striped rows, and the window stops at 1360 × 760; ADR 0004 "The smallest window"), PR #28 (version numbers: 0.1.0, build = commit count, shown at the bottom of Settings; ADR 0006), PR #27 (color schemes: Blue eclipse the default, Figma's 100 combinations in Settings → Appearance, a dark-mode logo in the sidebar), PR #26 (the Budget page's first slice:
envelopes with Assigned · Spent · Left, schema v10; the account page's overflow noted), PR #25 (the items tabled 2026-09-30: the
forecast through the next pay period, Keep the day, search in the tab row, wording),
PR #24 (import, currencies), PR #23 (Mongolian interface, Settings →
Language), PR #22 (roadmap to beta), PR #21 (blue Add button, the bee beside
the wordmark), PR #20 (logo wordmark, Steppe night dark mode, light mode and Settings →
Appearance), PR #18 (pay options, schema v7) and the
app icon (the bee, tilted; logo SVGs cleaned). Keep the pattern: branch, commit, PR,
merge. The owner's data file is at schema version 17 (upgraded 2026-10-05 by the 0.8.0 build, from
v16; the copy before it, `before-v17-from-v16-…`, is beside it).

Visual direction and the register's UX rules are settled in
[ADR 0004](decisions/0004-ledger-ui.md). Read it before changing any UI.

## What exists

### Built and working (desktop, macOS verified)

| Area | What works |
| --- | --- |
| Storage | Drift/SQLite (schema version 13: one Income, every income category merged into it; v12: the accounts a category doesn't use, and each spending category in one currency; v11: a plan per spending category; v10: budget amounts per category and period; v9: a weekend payday can keep its day; v8: import keys on each account's entry; v7: twice-a-month pay can have a second amount; v6: account roles and preferences; v5: pay schedules; v4: accounts can be archived or deleted; v3: entries remember the reconcile that locked them; only account sides are reconciled). Before any schema upgrade the file is copied next to itself (`betterbudget.before-v4-from-v3-<time>.sqlite`); the upgrade runs in one transaction, double-entry per ADR 0003; zero-sum enforced inside each write; soft delete; `cleared` per entry; WAL mode |
| Sidebar | A Settings gear above Net worth opens the Settings page (Backups for now). Sections Ledger / Budget / Savings; the current one expands, its accounts spilling down in a short cascade. Ledger lists accounts grouped (Bank, Cash, Credit) with balances. Budget opens the categories (rule 22); Savings opens the steps to getting prepared (rule 25). Right-click an account for its menu. Net worth pinned at the bottom |
| Accounts | "+ Add account" under Ledger: name and Type (Bank account, Cash, or Credit card or loan — cash and a bank account are both assets to the ledger, and the Type is kept in the sidebar-group column). A cash account is offered neither Reconcile nor Import: no statement to check against, no bank file. A new account first asks what's in it (or what's owed) on a date; that becomes a cleared opening balance and the entry row opens. Click the name to rename; ⋯ has Rename, Change kind (flips an unreconciled opening balance with it), Archive…, Delete…. Archive and delete are always allowed and say exactly what happens first (rule 21): archived accounts leave the sidebar and account lists but stay in net worth ("incl. ₮X in archived"), and come back from Settings; delete removes the account's own rows and keeps its transfers on the other accounts as "X (deleted)", so no other account changes |
| Budget | Envelopes (rule 26, first slice, 2026-09-30): each spending category reads Assigned · Spent · Left for the period (month or pay period, ‹ › to step, "Back to today"); overspending carries as minus ("₮X from before"); the top line is money not assigned (cash and bank, less what's in categories; what a credit card or loan owes is not in it at all — ADR 0004 "What's owed is not the Budget page's job", 2026-10-06); typing Assigned is quiet, Tab goes on, sums work, ⌘Z; starting partway through a period offers the next one; "Not categorized" holds no money (a line under the top counts its rows); any credit card or loan's payments come out of a category picked in its menu (it used to be a mortgage or student loan only); Spent opens that period's rows. **Plans** (rule 27, 2026-10-01): a category can be Spend through the month (what's left carries over, or goes back to not assigned), Save up, Due on a date (equal parts up to the due date; repeats every 1–6 months, a year or two) or a Goal (recalculated each period); a note under its name says the plan and "on track" or "₮X short" (gold, only when behind); "Assign ₮X" at the note's end and "Assign what's planned · ₮X in N categories" under the top line fill Assigned (one ⌘Z; allowed past the money there is, said in coral first); the plan is the Type in the category's Edit (rule 29), which the note opens too. **Currency and accounts** (rule 28, 2026-10-02): each spending category is in ₮ or $, there's a "not assigned" line per currency, and its Edit lists the accounts in its currency, all checked; unchecking limits the category to the rest, and the line says so, warns when those accounts hold less than is set aside, and names a payment from an unchecked account or a row in the other currency. Not yet: moving money between categories, goals shown in Savings |
| Categories | Managed on the Budget screen; every one is a spending category, and income is the app's one Income (rule 30, 2026-10-03: in the ledger's dropdown, not listed on the Budget page, can't be deleted). Add category. **One Edit per category** (rule 29, 2026-10-02): right-click or ⋯ gives Edit and Delete… only, a double-click opens Edit under the row, and Edit holds the name, Spending or Income, the Type (No plan or one of the four plans), currency, accounts, payday and Pay…, the usage ("42 rows · last 09.12 · show them") and Archive (leaves the menus, rows keep the name); one Save, one ⌘Z. Delete… (with rows: pick where they move, a merge). A new name typed in the entry row offers "+ New category" and a gold "new category" note; saving makes it, one ⌘Z undoes both (rule 22) |
| All accounts | Under Ledger, above the groups: every account's rows in one register, Account as the last column, a transfer once. Adding asks for the account (a dropdown that remembers the last). Clicking a category's usage on the Budget screen opens it with a "Category: X ✕" chip and "n rows · ₮X spent"; Esc clears (rule 23) |
| Savings | The steps to getting financially prepared, in the self-reliance course's order, tithing left out (rule 25): one month of expenses set aside, health coverage, no consumer debt, 3–6 months, retirement, mortgage and student loans. The current step is the first not done; any can be set aside. A month is the last 3 months' average spending or typed; the fund is the accounts the user picks; cards and loans are consumer debt unless marked mortgage, student loan or paid monthly. Schema v6 (account role, preferences) |
| Pay | Filed under Income (rule 30): a set-up payday ends the forecast, and income typed by hand does only when no pay is set up anywhere; no payday mark and no category in the pay setup. Before 2026-10-03: payday mark on income categories (only paydays end forecasts). Pay setup (forecast "no payday ahead · Add your pay", Budget screen, Settings): account, from, same or varies ("Expect at least", history, warning if high), monthly / twice a month / every N weeks, weekend rule; the next payday is always scheduled from the plan. Since 0.8.0 (ADR 0004 "Two earners"): a pay has a Name; the Budget page's view dropdown is by month or by a pay's periods; a set amount is per month or per one pay (How often in its Edit) and prorated by days when seen by another period. Schema v5, v17 |
| Header | A cleared + uncleared = working sum whose total is the large number, plus the date last reconciled and a Reconcile button; the uncleared line carries "3 not cleared yet" and nothing when all has cleared; on a credit card every amount is what's owed, positive, with "Owed" as the total; the lines double as the symbol key (hover highlights, click filters) |
| Forecast | Today → next scheduled income: lowest point, or a coral warning with the date it runs out (or "Below zero now"); 30-day horizon if no income is scheduled. Scheduled money in (transfers, refunds) steps the line up; only an income-category row ends it. Money in due today or earlier and not confirmed isn't counted (the header says so in gold and opens it); on payday "Runs out 10.15 unless ₮2,500,000 due today comes". A credit card shows what will be owed over 30 days. Under the headline, "3 bills · ₮2,790,200 before 10.10" (never payee names); clicking it lists every bill and the income with the balance after each. Chart ends are labeled with plain dates. Hover a dot for the bill, click a dot or a listed bill to open it |
| Register | Full dates, running balance, one signed amount column, every other row tinted a faint blue with a hover clearly lighter than the tint, transfer and split glyphs, split lines in the memo; tabs All / Uncleared (n) / Scheduled (n); search across payee, memo, category, amount |
| Entry | Blue Add button or ⌘N opens the row (stays open for a batch, closes on Esc or when left empty); any field order; Enter from anywhere; memo line under Payee; missing fields outlined; a transfer spells out its direction ("₮640,200.00 from TDB Checking to Golomt Visa") with Swap; payee autocomplete with last-used category; `+` before an amount for money in; calculator (`12000+8500`); `→ Account` as category makes a transfer; future date → scheduled; calendar under the date field (future days gold); why a row can't be saved shows in the gold popup at the bottom ("Enter the amount arriving in Chase") and goes once the row is edited; only one row is open for typing at a time (Add closes an untouched Edit and Edit an empty new row; one holding changes stays, with "Save with Enter, or press Esc to discard your changes") |
| Editing | Double-click a row (or Enter, or Edit in its action bar) opens it in place with date, payee, memo, category and amount, and the cursor in the clicked field; Enter/Save keeps changes, Esc or the Cancel button beside Save cancels, a click away closes an Edit nothing was changed in, Undo restores; splits edit date, payee and memo only; reconciled rows edit payee, memo and category only (date and amount locked); moving a date into the future schedules it. Also: inline category menu, click a symbol to clear or unclear, Confirm on a scheduled row opens it dated today with the amount selected, so a bill that varied is confirmed as it really was |
| Move to | "Move to" in a row's action bar moves this account's side to another account (entered in the wrong one); it arrives uncleared there; not on reconciled rows, opening balances or adjustments, or onto a transfer's own other side (enforced in the database); undoes with its cleared state |
| Backups | A copy a day (at launch, checked hourly) in `Backups/` beside the database: newest 14 plus the first of each of 12 months, written under a temporary name and renamed once complete. All of it under **Settings** (gear above Net worth; a coral dot when copies stop). "Back up to…" saves a copy anywhere. "Restore from…" checks the file, shows what it holds against what's here, saves what's here first and can be undone. **Start over** (last section of Settings): "Erase everything and start over…" names each account and balance that goes, asks keep or erase the categories (keep by default), saves the old ledger as `before-new-ledger-….sqlite` first, and undoes; an emptied ledger never gets the demo data again |
| Selection | One row at a time (multi-select removed, may return with import). Clicking a row attaches a bar under it with what applies: Edit, Categorize, Mark cleared or uncleared, Delete, ✕; keys Enter, C, Delete, Esc. Reconciled rows can't be edited or deleted, and a transfer reconciled on one side is locked on both (enforced in the database) |
| Undo | ⌘Z / Ctrl+Z undoes the session's actions newest first (add, edit, categorize, clear, delete, confirm, reconcile, undo reconcile); ⌘⇧Z / Ctrl+Y redoes. In a text field both act on typing. Toasts only for saved changes, deletes, confirms and reconciles, each with its own Undo; clearing a row is quiet |
| Reconcile | Reconcile button in the header: statement date, bank balance (starts empty, cursor in it), cleared here, off by with which way and a hint naming a row that matches the difference; the register narrows to unreconciled rows through that date; and its last column becomes Cleared balance. Lock is enabled only at zero and locks those cleared rows; otherwise "Add ₮X adjustment and lock" posts a Reconcile adjustment against Balance adjustments (equity). Credit accounts take what you owe as a positive number. The newest reconcile can be taken back later from any row it locked ("Undo this reconcile"); reconciles unwind newest first |
| Currencies | **Every ISO currency a person can hold, 155 of them** (2026-10-02, [currencies.md](currencies.md), ADR 0004 "Every currency"), built into the app; the database stores each account's code. Each has its own decimals (yen none, a Kuwaiti dinar three) and a symbol, the one its people write (`$` for a Canadian dollar too); two that share a symbol are told apart only while a ledger holds both (`CA$`). A bundled 3 KB font draws 13 signs the app's fonts lacked. Add account picks from a searchable Currency dropdown (symbol, name, code). Each account is in one currency, chosen when it's made (ADR 0004 "Tugrik and dollars"); its amounts show in its symbol everywhere. Net worth and category totals show each currency on its own line. A transfer between currencies takes both amounts (the rate is shown, not stored) through a hidden exchange account. Savings counts the main currency. Schema unchanged (the columns existed) |
| Import | **Import…** beside Reconcile in the account header (ADR 0002 "Any bank's file", ADR 0004 "Import"): TDB's `.xls` (both exports), `.xlsx`, CSV, or a bank's OFX download (`.ofx`, `.qfx`, `.qbo`; no balance check, the file has one balance only). The window shows the file's own columns with a choice over each, the app's guess filled in, and the rows below it as New, Matches (a typed row, which becomes cleared) or Already in. It checks the bank's running balance (a coral warning with both amounts if it doesn't add up, and you can still import) and shows the cleared balance after the import against the bank's. Columns are remembered per account; a file of the same layout opens on the rows. Rows come in cleared, with the payee's last income or spending category or "Not categorized". Click a row's tag to add a match as its own row or leave a row out; overlap with earlier imports and typed rows the file lacks are named. One ⌘Z undoes it all. 270 tests. Not yet: rules, own-account transfers matched between two accounts, scheduled bills matched |
| Appearance | Settings → Appearance: Same as this Mac, Light or Dark, and **Colors**: Blue eclipse (the default), BetterBudget's own or any of Figma's 100 color combinations in its seven groups (ADR 0004 "Color schemes"). Each scheme is made into a light and a dark palette that passes contrast checks; money's green, coral and gold never change. Kept per computer, ⌘Z undoes. The sidebar shows a dark-mode logo (white and light royal, gold body), the same in every scheme |
| Language | Settings → Language: Same as this Mac, English or Монгол (per computer, ⌘Z undoes). Every word is in `app/lib/l10n/`; the Mongolian is a draft awaiting a native speaker's check ([review sheet](mongolian-review.csv), [glossary](l10n-glossary.md)). Dates in sentences read "9-р сарын 30"; rows keep 09.30 |
| Shortcuts | ⌘N new, ⌘F search (⌘K also works, unadvertised), ⌘Z undo, ⌘⇧Z redo (Ctrl+Y on Windows), Esc clear (Ctrl on Windows) |
| Tests | 453 (2026-10-07, 0.13.1): the popup and the pointer (an offer crossed, a popup taking a hovered one's place, one appearing under a resting pointer, a click on it with a row open, an Edit putting it away, a row with no payee), a credit card's import preview against its register, search with a typed minus. 443 (2026-10-06, 0.13.0): the popup's place, width and payee line, an undo that still names the row, the popup staying under the pointer, the popup in light mode with its button (a new golden), money out red with a minus. 440 (2026-10-06, 0.12.1): the ledger's category lists in a tugrik and a dollar account (Categorize on a saved row, the entry row's list, a row already filed in the other currency keeping its tick). 439 (2026-10-06, later): the OFX reader, a credit union's table, repeats from the bank's other kind of file, a new account started from its file with a Start from date, the Not categorized tab's period, "Always file", a row made a pay's paycheck from the dropdown, by a rule on import and typed new. 418 (2026-10-06): the register's Not categorized tab (there only while rows wait in it; the Budget page no longer says them; 0.11.2); what a credit card owes left out of the money to assign, paying one counted as its category's spending, buying on one raising Not assigned until it's paid; the v18 upgrade (the old Cash & bank group becomes Bank, no account made cash behind the user's back); a cash account offered neither Reconcile nor Import. Some 40 goldens redrawn (the sidebar gained a group, the Budget page's first row was renamed). 381 (2026-10-03, later): the search key after a click away, an entry problem in the popup and gone on edit, one row open at a time, an Edit closed by Cancel or a click away; the goldens redrawn for ⌘F in the search box. 378 (2026-10-03): one Income (the v12 upgrade, Income can't be deleted, renamed, archived or budgeted, the forecast's payday with pay set up and without, pay taking over only the same pay, a merge into Income, the Budget page's Income line and pay note); the goldens that show Salary or the Budget page redrawn. 374 (2026-10-02, later): a category's Edit (the two-item menu, double-click, Esc, one undo for several changes, the dropdowns) and every currency (decimals, symbols, two with one symbol, the list); five goldens redrawn or new. 372 earlier: a category's currency and accounts (two pools, rows in the other currency, unchecked accounts, the v12 upgrade, two goldens). 355 (2026-10-01): plans (each kind's maths, a category that doesn't carry over, a bill's parts across repeats, late and early payment, two bills in one pay period, weekly pay to a far date, the v11 upgrade, the Budget page with three goldens). 331 earlier the same day: an account page at the smallest window and on a smaller screen (two goldens). 328 (2026-09-30): color schemes (every scheme's contrast in both modes, money hues kept off buttons, the dark logo on every sidebar, the appearance file, picking and ⌘Z). 322 earlier: the budget (envelopes, carrying minus, cards, refunds, loans paid from a category, Not categorized, the saved start and currency, amounts anywhere in a period, moving to the next period, merges, the v10 upgrade, typing, Tab, ⌘Z, the arrows mid-typing). 288 earlier the same day: import (the `.xls`, `.xlsx` and CSV readers on made-up files, column guessing, the balance check, keys, plan, write, undo and redo, the window), currencies (per-currency sums, transfers between currencies, their edits and undo, the dollar account on screen) and upgrades (v8, a relabeled ledger, a newer one refused). 174 on 2026-09-24, including a new ledger (keep categories, undo, no demo afterwards). Earlier list: rows growing smoothly, reduced motion; payday warning, late money in dated today; late money in, still owed on a short confirm; confirming with a changed amount and date, notes on old rows; restore (damaged files refused, cancel, undo), retention, a failing daily copy; moving between accounts (undo, redo, refusals), card reconcile signs, register speed on 20,000 rows, backups (daily, kept, cut short, saved elsewhere), undo and redo for every action, Windows and Mac keys, switching account mid-reconcile, the transfer sentence; and money parsing, ledger/DB invariants, editing, forecast, reconcile, taking reconciles back, transfer locks, UI lock state matching what the database refuses, statement dates refused out of order, upgrading v1 and v2 files with data (and their backups), screen flows including real key presses, undo and redo, a stale toast Undo refused, sidebar sections and their animation, the date calendar, early confirm, the Add row, row actions, forecast dots and bill list, reconcile with its finding aids and adjustment, credit cards shown as owed, editing a reconciled row, forecast money in, 14 golden screenshots |

Seeded on first launch with **synthetic** demo data dated relative to today: TDB
Checking, Khan Savings, Cash wallet, Golomt Visa, 14 expense categories, Salary, and 4
scheduled items.

### Not built yet

- **Encryption on Windows, Linux and Android** is unverified (no build machines here);
  macOS and iOS are verified. Print for the recovery key isn't wired (Save and Copy are).
- Creating or editing **splits**: split lines are display-only. A split's date, payee and
  memo can be edited.
- **A list of the "Always file" rules**, with a way to drop or rename one (the rules
  themselves are built; [ROADMAP](ROADMAP.md) "Still on the list"), matching scheduled
  bills and own-account transfers on import; **recurring** schedules (scheduled
  items are one-off), payees merge, rules, tags, attachments.
- CSV export, app lock.
- **Phone apps**
  (designed in [ADR 0005](decisions/0005-mobile-companion.md); after the budget),
  Windows build (scaffolded, never built), the bee icon on the phone apps (macOS has
  it).
- **CI.** Nothing runs tests on pull requests.

### Known bugs and loose ends

- **Launched while the Mac is locked, the app stops at startup.** The Keychain
  refuses the key ("User interaction is not allowed", -25308) and `startup.dart`
  doesn't catch it, so the window stays on the startup screen until it's quit and
  opened again. Seen 2026-10-01 relaunching the 0.2.0 build; the ledger wasn't
  touched. Worth a "unlock your Mac and try again" screen.
- **An account's currency can't be changed after it's made.**
  The owner remade theirs by hand (2026-09-30); Change currency stays on ROADMAP E.

## Settled decisions

| ADR | Decision |
| --- | --- |
| [0001](decisions/0001-database.md) | SQLite via Drift, encrypted in SQLCipher v4 format by SQLite3 Multiple Ciphers. One data key in each device's secure store, derived from a recovery key the user keeps (it opens backups and adds devices). MNT is exponent 2. |
| [0002](decisions/0002-tdb-import-format.md) | TDB import targets the unformatted Excel export. Column map and dedup key recorded. |
| [0003](decisions/0003-double-entry-schema.md) | Double-entry storage, categories as accounts, accounting hidden from the UI. |
| [0004](decisions/0004-ledger-ui.md) | Steppe night look (dark) and 24 ledger rules: purpose, forecast (late money in not counted), one amount column, full dates, clock/check/diamond symbols, header as a cleared + uncleared = working sum, any-order entry, one-row selection with an action bar, session undo with toasts only for saved changes, confirm (opens the bill; still owed), in-place editing that grows smoothly, shortcuts that never steal typing, sectioned sidebar, date calendar, reconcile in the header, transfer direction, Move to, backups in Settings, notes on old rows, accounts managed where they're used (warn, don't block), categories on the Budget screen, an All accounts view, pay and paydays. |
| [0005](decisions/0005-mobile-companion.md) | Phone apps record transactions and show what's left in budgets; not a full budget app. Sync through a user-picked Drive/OneDrive folder with one writer per file (Mac snapshot, one inbox per phone), so no merge. Phones see each other's entries. Entries go straight into the register. |
| [0006](decisions/0006-version-numbers.md) | Semantic versions, 0.x until the public release (started at 0.1.0); minor per feature PR, patch per fix. Build number = git commit count, set by a macOS build phase. Settings shows "Version 0.1.0 (134)". |

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
Reconcile, with the difference posted to a category the user picks. **The account Type
now exists** (2026-10-06, schema v18): Cash is one of the three on Add account, it has
its own sidebar group, and a cash account is offered neither Reconcile nor Import.
**Still not built:** the Count flow itself. Until then the difference is typed as an
ordinary row.

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

1. ~~Does TDB's internet banking offer CSV or modern `.xlsx`?~~ Moot: the `.xls` reader
   is built (2026-09-30).
2. **What does the ledger still need before the budget?** The owner is steering this by
   feel. Likely candidates: splits, accounts/categories management, import, recurring,
   plus search and sorting on the roadmap. Ask rather than assume.
3. **What is "Savings"?** A placeholder name in the sidebar; the owner will define it later
   (goals? savings accounts?). Relates to the budget model below. **Options are in
   [personas.md](personas.md) §2** (2026-09-19): A. a Growth page (where each period's
   surplus went, a real savings rate, net worth split into saved and market change),
   B. a balance sheet with Update value, C. goals. Recommended A plus B's Update value,
   renamed "Growth". **Owner's direction (2026-09-19):** Savings guides users through the
   first steps of the Church's *Personal Finances for Self-Reliance* course, starting
   with a one-month safety net; see personas.md §2 and the course itself in [self-reliance-course.md](self-reliance-course.md).
4. **Budget model: envelopes or targets?** **Decided 2026-09-30: envelopes** ([ROADMAP](ROADMAP.md)). The double-entry schema
   suits envelopes. **The budget runs per pay period or per month, not all time**
   (owner, 2026-09-19; which of the two is still open). A category's rows, opened
   from Budget, should show that period, not all time.
5. **Multi-currency at launch?** **Decided 2026-09-30: MNT and USD before beta, totals shown in each currency separately** ([ROADMAP](ROADMAP.md) E). Earlier lean: data model ready (entries carry
   `currency` and `rate`), UI MNT-only. **Live risk:** sidebar net worth adds raw
   balances, so a second-currency account (a USD 401(k)) would add cents to tugrik. Both
   personas in [personas.md](personas.md) are US users paid in dollars.
6. **Is the dedup key stable across overlapping exports?** Two of the owner's exports
   shared all 78 overlapping keys (2026-09-30). Two deliberately overlapping periods would
   settle it.
7. **Which other banks import at launch?** Any bank's table (`.xls`, `.xlsx`, CSV) maps
   by its columns now; a real Khan or Golomt file is still worth a try.
8. **Cash-heavy or card-heavy users?** Decides whether wallet-count reconciliation is core.
9. **Does BetterBudget get its own wordmark?** `assets/logo/` is the Loveland Solutions
   company mark. The app uses a gold diamond plus "BetterBudget" as a placeholder.
10. **Header height.** Smaller since the separate big balance was removed; about seven
    rows show at 1440×900. Collapsing it on scroll was offered; the owner hasn't asked for it.

## Next step

**2026-10-06, branch `budget-debt-and-cash` (version 0.11.0, schema v18): debt off the
Budget page, Cash as a Type.** Started as a question about onboarding, became a rework of
what the Budget page counts, driven by the owner reading the top pane and not being able
to say what its first number was.

- **`Budget.counts` is assets only.** It was `isBalanceSheet && !isLongLoan`, doing two
  jobs at once; it is now split in two. `Budget.spendable` (cash, bank and credit cards,
  never a mortgage or student loan) is the accounts a category can be spent from, and
  keeps the owner's 2026-10-02 correction that a card is an account you may plan to pay
  with. Collapsing them is what dropped the Visa out of a category's **Paid from** list
  mid-change; the two names exist so it can't happen again.
- **Every credit card and loan can name the category its payment comes from** (the loans
  map in `Budget.of` now keys off `isOwed`, and `loanPaidFrom` in `ledger_screen.dart`).
- **The pane's first row is `cashBankLabel()`** in `ui/budget.dart`: "Cash & bank" only
  when the ledger holds both kinds, else "Bank" or "Cash". `planKeyHave` → `planKeyCashBank`
  / `planKeyBank` / `planKeyCash`; `planKeyHaveTip` and the `tip:` parameter it was the
  only user of are gone; `planCardsOweShort` and `cardsOwe()` are gone (impossible now);
  the label column is 150px, measured from the Mongolian, which wrapped at 120.
- **Cash is a Type.** `LedgerGroups.{cash,bank,credit}` in `domain/ledger.dart` with
  `AccountInfo.isCash`; `groupFor(type, {cash})`; `createAccount(..., cash:)`; three
  buttons on Add account (`kind-cash`); `onReconcile` on the balance header is nullable
  and null for cash, which hides the button and the "Last reconciled" line.
- **Schema v18** renames the `Cash & bank` group to `Bank` and makes nothing cash.
- Words: "card" → **"credit card"** throughout (owner: "Are they gift cards?").

**Next:** the onboarding wizard. The design is settled and in ADR 0004 ("Onboarding: the
first half hour"); the four committee reports (layout, words, flow, first-time user) came
back and are **not yet folded into mockups** — that is the next piece of work. Two
findings from them worth acting on regardless: a first-time reader thinks **assigning
moves their money** ("I would open my TDB app to check whether my balance changed"), and
there is still no designed screen for a ledger with no accounts.

**2026-10-05 (later), PR #37 `two-earners` (version 0.8.0, schema v17): two
earners.** Built as the owner designed it in conversation (ADR 0004 "Two earners"):
the view dropdown on the Budget page (`_ViewChoice` in `ui/budget.dart`,
`_budgetBy` in `ledger_screen.dart`, kept in `pay_schedules.defines_period` as
before); a set amount's own period in its plan's `pay_schedule_id` (How often row in
the Edit's No branch, `_eachPayId`); proration and emptying inside a span in
`Budget._planLine` and `Budget._emptying` (`PlanLine.approx`); `pay_schedules.name`
with `payTitle` in `ui/data_words.dart`; Settings → Budget and the setup's Budget by
removed. **Both review passes done, their fixes in** (ADR 0004 "Two earners" → "From
the budget review"): money assigned from another period's view is dated into each of
the category's own periods (`Budget.spread`, `_budgetRows` in `ledger_screen.dart`,
`setBudgetAmount(rows:)`); emptying inside a span stops at today; a new category's How
often starts as the view's period; a cut share rounds to ₮100; a stopped pay reads
"(stopped)"; picking the view it already is writes nothing. Tests: 411 (`flutter test`
passes; `goldens/budget_two_earners.png` new, Settings and pay setup goldens redrawn).
The top pane, built in PR #39 (version 0.10.0): `keyCard()` in `_BudgetPageState.build`
(`you-have`, `assigned-sum`, `not-assigned` keys, `-USD` for a second currency;
`assign-planned`, `assign-planned-over`, `assigned-over`,
`cards-owe`), `_ViewChoice` now wraps the period title, `_StartOffer` a strip,
`addNew()` for ⌘N. Budget goldens redrawn. Before that, the owner's two calls, built in
PR #38 (version 0.9.0): the catch-up share says what the
period before still needs plus the share toward the next (`planStillFor`,
`planPlusNext`), and Stop on a pay with categories per it opens `_StopPayDialog`
(`pay-stop` → `stop-move-month` / `stop-move-<id>` → `stop-pay-confirm`), the plans
moved with `CategoryPlan.movedToPay` in one undo with the stop. Tests: 413. **Next:**
still one person's words in the forecast ("Until your 10.15 paycheck"); the owner's two
questions below stay open.

**2026-10-05, branch `budget-page-layout` (version 0.7.0): the Budget page after the
owner's call with Cynthia G. Loveland.** Six notes came back. Built: a new category
opens in Edit (no wizard: the panel's first line is the question); one "Paid from"
row of checkboxes in Edit instead of two account dropdowns, the dated plan's bill
scheduled in the one account left checked; the forecast's span as a dropdown on its
small title, with paydays and plan bills projected past the scheduled ones
(`projectScheduled` in `domain/forecast.dart`, `RegisterRow.copyWith`); a coral dot
beside a sidebar account whose forecast runs out (the header's warning as its
tooltip). The owner's calls the same day, built: a coral line above an account's
forecast when it runs out past the view (accounts pay goes into are looked at a year
of paychecks ahead; landing on zero counts); **Spending and Income tabs** on the
Budget page, pay listed and added on Income, Settings → Budget down to Budget by; and
How often's **Custom…** block (schema v16: `weekdays`, `nth`, `nth_weekday`,
`end_date`, `end_count`; `Budget.lastDue` and `Budget.over` stop a plan's bills,
counting and projection past its end). All in ADR 0004 "From the 2026-10-05 call",
with both reviews' fixes under "From the reviews". The owner's last two calls: the
Income tab says "₮2,100,000 received of ₮4,200,000 expected this period", and the
panel's question says what No and Yes mean beside it ("A set amount you spend through
each month, like groceries." / "An amount to have ready by a date, like rent or
insurance."), with "What's left at month's end" shown under No always. **Asked, not
answered, in plain examples:** (1) Set the forecast to Next 6 months on TDB Checking:
it shows pay coming in and rent and water going out, nothing else, so the line climbs
about ₮800,000 a month richer than the household will be. Should it also take out
what's budgeted for groceries, transport and the rest each month? (2) Make a new Rent
category, Yes to a due date, ₮1,800,000 on the 20th: Paid from says "All accounts", so
the rent is in no account's forecast until TDB Checking is left checked alone. Should
the app start with TDB Checking checked on its own, because that's where the rent rows
were paid from?

**2026-10-04, PR #35 merged (version 0.6.0, schema v14 and v15):
two budget types instead of four, and the bill in the forecast.** The owner asked what
the five choices under a category's Type were for; Spend and Save up came to the same
number, so a `budget-expert` agent (new, `.claude/agents/budget-expert.md`: how
households plan money, for designing the budget; `budget-app-expert` stays the review
pass) walked the owner's scenarios through. The owner's calls: merge Save up into one
"Any time" type with an optional cap ("up to ₮X", not mandatory); spread a missed part
over the periods left (so Goal merges into "On a date, once"); count what was assigned,
not what's left (a $20 gift in April is part of the $100 birthday in August); repeats up
to every three years; **Paid from** on a dated plan schedules the bill in that account
so the forecast counts it (A of two); the Edit panel is designed as one thing (2026-10-04,
after the owner's "all the features shoved on a page" and a four-agent design
committee): the name as heading, one question ("Is there a due date? No | Yes"), a
short labelled form, "Stop at" for the cap, the monthly amount worked out for a dated
plan, and the row drawn as it will read. "No plan" is an empty amount. **How often**
covers every situation (owner, 2026-10-04): the presets, Every payday (from the pay
schedule, with days after), Every… (a number and days/weeks/months/years), On these
dates… (a typed list, yearly), and a weekend rule; schema v15. All in ADR 0004 rule 27. Also on the
branch: "Kind" → "Type" on the New account page. **Both reviews done, their fixes
in** (rule 27 names them: a bill taken a day early counts on its date, a re-dated
one-time plan reaches the forecast again, undo brings back the very bill, "this month"
in the last period, "Not scheduled", an archived Paid-from account said in gold).
**For the owner to call:** a Paid-from bill that arrives through a TDB import leaves
the scheduled row behind; the import matching a scheduled row would fix it (new). Also to call: the owner's data file is at schema v15 now (upgraded by the
0.6.0 debug build on 2026-10-03 and 2026-10-04; copies from before are beside it).

**2026-10-03, PR #34 merged (version 0.5.1): ledger fixes from the owner using the
app.** "Everything has cleared" is gone from the header. The search box shows ⌘F, and
the screen's keys (⌘F, ⌘Z, ⌘N) no longer go dead after a click on an empty part of
the window: the register takes the focus back whenever nothing on the page holds it.
Why a row can't be saved is said in the popup at the bottom, in plain instructions
("Enter the amount arriving in Chase"). Only one row is open for typing at a time.
An Edit has a Cancel button and closes on a click away when untouched. All in ADR
0004 rule 6 and the toast rule. The review passes weren't run (small fixes). Left for
the owner to call: "needs amount" beside Add is still in the old voice, and the long
gold "new category · money in counts as a refund…" note beside Add still gets cut off.

**2026-10-03, PR #33 merged (version 0.5.0, schema v13): one built-in Income
instead of income categories** (ADR 0004 rule 30). It began as "we
need a better way to organize" a category's Edit; asked what an income category was
for, the owner dropped them. Income is the app's own category, in the ledger's
dropdown, per currency; the Budget page has an "Income: …" line and the pay note where
the Income list was; Edit and Add category lost Spending or Income and the payday
choice; pay setup no longer asks for a category; a set-up payday ends the forecast,
and income typed by hand does only when no pay is set up anywhere; the upgrade merges
every income category into Income and drops the names. Both reviews done, their
fixes in (rule 30, "From the reviews"). The owner corrected "Came in" to
**Income** for the Budget page's line. **Asked, not answered:**
should the Income line also name money in that's still "Not categorized" (imported pay
lands there)?

**Still open from that conversation: the layout of a category's Edit.** Three
mockups were shown (two halves: the category and its plan, recommended; one question
per line; three named bands) and the owner hasn't picked. With Spending or Income
gone, Edit is Name, Currency, Accounts and the Type. Ask which layout once they've
seen this build.

**2026-10-02, PR #32 merged (version 0.4.0): one Edit per category, and every
currency.** The owner said of it "Beautiful". What it holds, all from the owner
using the build and correcting it:

- **A category's Edit** (ADR 0004 rule 29): the menu is Edit and Delete; a
  double-click opens Edit and a second closes it, as Esc does; Edit holds the name,
  Spending or Income, Currency (a dropdown), "Accounts this category uses" (a dropdown
  of checkboxes), the Type (No plan or one of the four), payday and Pay…, the usage
  line and Archive. One Save, one ⌘Z. Both reviews done, their fixes in.
- **Every currency** (ADR 0004 "Every currency", [currencies.md](currencies.md)): 155,
  each with its decimals and its real symbol; the list rows read symbol, name, code.
  No review passes were run on the currency work.

**Open with the owner:**

1. **Currencies in the database?** They asked "You're putting the currencies in the
   database, right?" They aren't: the list is built into the app and the database
   stores each account's code. Asked twice what they want the ledger file to hold
   (editable currencies? rates?); not answered. A table would be a schema change.
   Ask again only when it comes up.
2. **Arabic-script symbols.** The Gulf and North African dinars, dirhams and riyals
   and the afghani show the Latin abbreviation used beside English (`KD`, `Dh`,
   `SR`, `Af`). The owner was told and didn't object.
3. **The 71 symbols not from CLDR** (`SYMBOLS` in `app/tool/gen_currencies.py`) rest
   on common usage; worth a check by someone who uses each.

**Not done with currencies:** Savings counts one currency; import's "this file is in
another currency" warning recognises only tugrik and dollars; changing an account's
currency (ROADMAP E); the Mongolian names are CLDR's, unchecked.

**Seen and not touched:** on the Budget page, "$5,200,000.00 from before" under Left
wraps onto two lines and runs into Spent (it predates PR #32).

"First, there are too many menus" says more corrections to the Budget page are
coming; wait for them rather than guessing.

**2026-10-02: the owner is working through the budget's controls.** Plans (PR #30) and
a category's currency and accounts (PR #31) are merged and running on the owner's
ledger. The owner said "the budgets themselves need more controls" and walked through
what a line has; the list of what a line can't do yet, in the order it came up:

- Move money to or from another category (ROADMAP C; today it's two typed amounts).
- Put categories in an order or a group (the list is alphabetical).
- Skip or change a plan for one period, pause a plan, or pick the period a plan
  starts counting from.
- A note or a color on a category; a cap on what it can hold.
- Take back everything assigned this period in one step.

**Waiting on the owner** (asked, not answered; ask again only when it comes up):

1. **What "dedicated" means.** Limited to Khan Savings, Emergency fund holding
   ₮10,000,000 of its ₮12,600,000: is the other ₮2,600,000 (and interest) the fund's
   too, or free to assign, as built? The panel says the built behaviour with the real
   amounts (rule 28).
2. **Month ↔ pay period switch.** A "₮900,000 a month" plan then reads "₮900,000 each
   pay period": convert it, or leave it with a note to check? (rule 27, left for later)

**Not yet seen by the owner in the app:** the Budget page with plans and the
currency panel (they had the build running; no reaction recorded). Expect corrections.

Earlier:

**The budget page, first slice** (2026-09-30, PR #26): the owner picked
envelopes with Assigned · Spent · Left, overspending carried as minus, and card debt
reducing the money (ADR 0004 rule 26); then, from both reviews, starting partway through a
period offers the next one, "Not categorized" holds no money, and loan payments come out
of a category. The owner corrected "Put in" to **Assigned**. Both reviews done; their
fixes are in. **Also (2026-09-30, PR #27):** a dark-mode logo in the sidebar, Blue eclipse the default, and the color schemes in Settings → Appearance. **Next:** the owner tries it with real money. Then moving money between
categories, "same as last period", the four budget types (ROADMAP C), and the forecast's
"Nothing has been budgeted" sentence switching on the budget.

**2026-10-01, plans (the four budget types):** the owner asked for them built and
picked the note under the name and the top button plus a per-line Assign (ADR 0004
rule 27, version 0.2.0, schema v11). See "Recent work".

**2026-10-01:** the owner started using the budget and sent two fixes (PR #29, above).
Still waiting on their reaction to the Budget page beyond its width ("ugly" was the
word; width was the one thing named). Offered next: recurring bills (options with
sketches), then the budget follow-ups.

**Tabled by the owner (2026-09-30), to address next**, from using the new build:

All five done and merged (PR #25, 2026-09-30):

- [x] The opening row's category says **"Opening balance"**.
- [x] No toast when an account is made (⌘Z still undoes the balance; Esc on the entry
  row now leaves ⌘Z working without a click). "settled" is gone from the status
  tooltips too: the app's word is **cleared**.
- [x] Pay's weekend rule has a third choice, **Keep the day** (schema v9; the owner's
  ledger upgraded 2026-09-30, the copy before it kept).
- [x] "Put in how much comes" is now **"Type how much you're paid"**.
- [x] **The forecast runs through the next pay period** (owner's pick, option A of
  three; ADR 0004 rule 24): the next paycheck is a step, and it ends as the paycheck
  after it lands. Both reviews done, their fixes in; left for later is listed in
  rule 24.
- [x] **The forecast reads for someone new** (owner's corrections, same day): a bold
  "Forecast" title; with pay but no bills, a list (Today's balance, each payday as
  "Expected income" with its amount) and the owner's sentence "Nothing has been
  budgeted. Once you fill out your budget, this area will show you a forecast.";
  with bills, the chart names its start, lowest point and "+₮X pay". **Loose end:**
  no budget exists yet, so that sentence shows whenever no bills are scheduled;
  when the budget is built it should switch on the budget instead.
- [x] **Search moved into the register's tab row** (between the tabs and Add), with
  less padding at the top of the page (owner, same day). 298 tests pass.
- [x] The two import questions, both option a (2026-09-30): rows before the opening
  balance move it (by default), and a match takes the bank's date across a month.
  Change currency isn't needed now: the owner remade AFCU Checking as a dollar
  account; it stays on ROADMAP E.

**Fixed 2026-09-30:** the ledger wouldn't open ("duplicate column name: import_key").
An older build (the Release copy from 09-29) opened the v8 ledger and relabeled it v7;
the next v8 launch tried to add the column again. Upgrades now skip what's already
there, and a build refuses a ledger saved by a newer one instead of relabeling it.

**Beyond the alpha** (owner, 2026-09-30): the list to beta and the platforms after it
(bug link and public releases, the budget page, Savings, MNT and USD, App Store,
Windows, Linux, phones) is in [ROADMAP.md](ROADMAP.md).

**Mongolian** (owner, 2026-09-30, PR #23): built and approved in the app. Before beta a
native speaker goes through [mongolian-review.csv](mongolian-review.csv) (ROADMAP A2).
Screens with no Mongolian screenshot yet: the entry row and its errors, the calendar,
account add/edit, archive and delete warnings, the recovery-key screens, restore. New
text always goes in both `.arb` files, as whole sentences.

**The alpha** (owner, 2026-09-24: "I want to get this alpha version finished so I can
start using it"):

- [x] Merge PRs #14 (persona reviews) and #15 (Savings)
- [x] **A clean start**: Start a new ledger in Settings (ADR 0004 rule 19)
- [x] **Encryption, in the alpha** (merged, PR #17) (owner, 2026-09-24: "build it right the first time",
  for macOS, Windows, Linux, iOS and Android). Designed in ADR 0001: SQLite3 Multiple
  Ciphers writing SQLCipher v4, one data key per ledger in each device's secure store,
  derived from a recovery key shown once at setup and never stored (Save/Copy,
  skippable with a coral warning in Settings, owner 2026-09-28); Linux without a Secret Service asks for the recovery key at launch.
  **Built** (2026-09-29, draft PR #17): keys (`keys.dart`), the cipher and conversion
  (`encryption.dart`), restore of encrypted, plain and other-key backups, the setup
  screen (shown once, Save/Copy, key on one line), Settings → Security (status only).
  **One key per ledger, never replaced** (owner, 2026-09-29: "No. One key or all the
  data is lost"). **First launch run from a plain v5 ledger on the owner's Mac:** a key
  is made without asking, the ledger is encrypted and upgraded to v6, and every plain copy
  in the app's folder is converted (daily copies, upgrade copies beside the database, older
  folders), with none left readable. Fixed during that run: upgrade copies beside the
  database were left plain, and a plain ledger with no key asked for a recovery key it
  never had. **Both reviews done** (2026-09-29), fixes in (ADR 0001, "At launch"):
  a key is checked against the ledger before it's stored (no lockout on a new Mac or a
  wrong key; a stored key that stops fitting asks again); nothing is stored or
  encrypted until Continue; the live file is encrypted as a checked copy and swapped in
  (the `-wal` included; an older build's cut-short conversion is undone); a damaged old
  copy is reported, not fatal; no key in error logs; "saved" is kept beside the key,
  not in the ledger; a stronger check character (every single typo caught) and a
  Cyrillic hint; wording (phones, the other person, copies off this computer). The
  owner said yes (2026-09-29) to **Check my recovery key…** in Settings (type it, get
  yes or no; nothing shown), to **offering a backup on a new computer**, and to
  **restoring a backup under another key** by typing that key. 227 tests pass.
  Merged (PR #17). The owner questioned the Settings check ("the key shouldn't be in
  settings") and then said leave it (2026-09-29). The stronger check character makes keys saved before it invalid (test data only).
- [x] **Pay follow-ups and a clearer clean start** (PR #18, owner tested 2026-09-29):
  a different amount each paycheck twice a month; "I don't have regular pay"; the
  clean start renamed **"Erase everything and start over…"**, naming each account and
  balance that goes, with keep or erase the categories as a visible choice (ADR 0004
  rules 19 and 24). Code review done, fixes in. 232 tests pass.
- [x] **The owner erased the test data** (2026-09-30, Settings → Erase everything and
  start over). It was called real money from here; on 2026-10-03 the owner said the
  app wasn't in production yet; **on 2026-10-06 they began using it for real** (see
  "Local setup notes").
- [x] **Color and a light mode** (PR #20, owner tested 2026-09-29: Light remembered
  across relaunch, "Same as this Mac" opening dark and following the Mac live to
  light). Dark is Steppe night, light is Steppe, both with a gray denim sidebar;
  Settings → Appearance picks Same as this Mac (default) / Light / Dark, kept per
  computer in an `appearance` file beside the ledger (ADR 0004). The logo's wordmark
  is top left. Both reviews done, fixes in. 234 tests pass. Goldens are dark except
  `ledger_light.png` and `settings_appearance_light.png`. Left: category colors
  (liked, not built); a dark title-bar flash at launch under Light (the window starts
  dark until the app tells it); `keys_test` "corrects a typed O or I" is flaky
  (random characters), worth making deterministic.
- [ ] **Recurring bills** (item 4 below). Recommended in the alpha, splits after.
  **Next feature**: it's new, so bring two or three options with sketches.

The rest of the list below can wait until the owner is using it for real. **Phone apps**
are designed ([ADR 0005](decisions/0005-mobile-companion.md)) and come after the budget.

**Earlier context:**

**Persona reviews** (2026-09-19) are logged in [personas.md](personas.md): what a
paycheck-to-paycheck student needs (recurring bills and a forecast past the next payday
top the list) and what a salaried wealth builder needs (the Savings section). The owner
said "we'll address it"; nothing there is picked yet. The student is real (the
owner's daughter), so dollars and US dates are needed.

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
  model. **Both pay follow-ups built** (owner said yes, 2026-09-29; PR #18, rule 24):
  twice a month with **a different amount each paycheck**, and **"I don't have regular
  pay"** (undo in Settings).
- [ ] 5. A better **"not cleared" note**
- [ ] 6. **Duplicate check on Confirm**
- [ ] 7. **Several overdue bills** in All
- [ ] 8. **Backup reminders**
- [ ] 9. Small polish: Show on the Move toast, `+` prefill for refunds, moving into Cash wallet
- [ ] 10. **Search**
- [ ] 11. **Sorting**
- [ ] 12. **Cash accounts** (after 1)
- [ ] 13. **CI** running `flutter test` on pull requests
- [ ] 14. **Encryption**: moved into the alpha (above)
- [x] 15. **Import**, any bank's file (owner, 2026-09-30, option A): merged (PR #24),
  both reviews done and their fixes in; rows before the opening balance move it, and
  a match takes the bank's date across a month (owner's picks). Later:
  rules, the category shown per row, cleaning QPay/POS payees, warning when the file's
  account number isn't this account's, flagging scheduled bills the file pays, and
  keeping incoming money out of spending in "Not categorized" before the budget.

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

- **Two budget types and the bill in the forecast (2026-10-03, version 0.6.0,
  schema v14):** Any time (a set amount each period, carry over or not, an optional
  cap) and On a date (an amount by a date, once or repeating up to every three years,
  a missed part spread over the periods left, counted by what was assigned; Paid from
  keeps the bill scheduled in its account, confirmed like a payday). The four kinds of
  2026-10-01 map onto them in the upgrade. ADR 0004 rule 27 rewritten.

- **A category's currency and accounts (2026-10-02, version 0.3.0, schema v12):**
  the owner's design after asking how car insurance paid in dollars would be
  budgeted (ADR 0004 rule 28). Each spending category is in one currency, with a
  pool and a "not assigned" line per currency; a checklist of that currency's
  accounts, all checked, where unchecking dedicates the rest to the category.
  Built on the plans branch (PR #30). Both reviews done, their fixes in (rule 28 lists what is left). Cards are in the list (owner's correction). 372 tests.

- **Plans (2026-10-01, version 0.2.0, schema v11):** the owner's four budget types
  (ADR 0004 rule 27). A spending category can be Spend through the month (carries
  over, or what's left goes back to not assigned), Save up, Due on a date (equal
  parts, repeating) or a Goal. The owner picked the note under the name and the top
  button plus a per-line Assign. Both reviews done and their fixes in: a goal counts
  what was assigned (reached and spent, it asked for everything again); a bill is
  counted one bill at a time ("short" grew without limit, a late plan was short in
  its first weeks, two bills in one pay period); "on track" only while the money is
  there; not carrying over starts from the plan, not the past; weekly pay periods
  were slow to a far date (`pay.dart` now jumps there). Left for later is listed at
  the end of rule 27. 355 tests.

- **PR #29 (2026-10-01):** two fixes from the owner using the app, version 0.1.1.
  **The Budget page fills the window** (it was capped at 820 px), its rows striped
  like the register's. **The window stops at 1360 × 760** (it was 1200, where an
  account page ran out of room): `FitWindow` draws the app shrunk in any window
  smaller than that (a small screen; Windows and Linux until their windows stop
  too), the register's Category, Amount and Balance columns are narrower so the
  payee has room, and the sidebar's sections scroll with Settings and Net worth
  pinned. Checked in the real window (asked for 900 × 500, it stopped at 1360).
  No review passes: fixes, not a feature. 331 tests.
- **PR #28 (2026-09-30):** **Version numbers** (ADR 0006). Semantic, started fresh at
  0.1.0: minor per feature PR, patch per fix, 1.0.0 is the public release. The build
  number is the commit count, written into the built `Info.plist` by a macOS build
  phase. Settings shows "Version 0.1.0 (133)" at the bottom (`package_info_plus`, reads
  the bundle only). No CI: the owner has no paid GitHub plan yet, so builds and
  releases stay local for now.
- **PR #24 (2026-09-30):** **Import** from any bank's file (TDB's `.xls` with a reader
  written for it, `.xlsx`, CSV): the file's own columns with a choice over each,
  remembered per account, a balance-chain check, dedup keys on each account's entry
  (schema v8), matching typed rows, one undo. **Tugrik and dollar accounts**: chosen
  at creation, each account in its symbol, totals per currency, transfers between
  currencies with both amounts. The sidebar shows cents. Upgrades skip what's
  already there, and a build refuses a ledger saved by a newer one (an old Release
  copy had relabeled the owner's ledger). 288 tests.

- **PR #21 (2026-09-29):** Add buttons are blue (red read as a warning; the `red`
  token is gone). The logo's bee is back left of the wordmark, no tile
  (`app/assets/brand/bee.svg`, 40 px): wings recolored like the wordmark, antennae
  light, body black and gold as in the logo.
- **PR #20 (2026-09-29):** the logo's wordmark top left; Steppe night dark mode;
  Steppe light mode with the same denim sidebar; Settings → Appearance. `Mid` reads
  from a `Palette`, the sidebar has its own `Mid.side*`, `AppearanceScope` switches
  and redraws, the title bar follows over `betterbudget/window`.
- **2026-09-29:** the macOS app icon is the bee from the new logo, tilted 45° on a white
  tile (`design/icon/app_icon.swift` makes it; rebuild, and if the Dock keeps Flutter's
  icon, re-register the app with `lsregister -f` and `killall Dock`). Logo SVGs added
  and their hidden green fills removed. Color exploration started (see Next step).

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
- **Signing:** the Mac and iOS apps sign with the owner's Apple developer team
  `5FJUXAJX9P` ("Apple Development", automatic), needed for the Keychain entitlement.
  This Mac needed Apple's WWDR G3 intermediate installed (done 2026-09-28). If Xcode
  asks for a new provisioning profile, run once from `app/macos`: `xcodebuild -workspace
  Runner.xcworkspace -scheme Runner -configuration Debug -allowProvisioningUpdates build`.
- **macOS 27** (2026-09-28) draws text edges slightly differently: goldens were redrawn on
  it. Goldens made on another macOS version will differ by about 0.1%.
- **If tests stall** (random widget tests time out after 10 minutes with the CPU idle,
  even on older commits), restart the Mac: on 2026-09-29 a stuck `dart pub get` and
  leftover `flutter_tester` processes caused it, and a restart fixed it (227 tests in
  about 1:45). Check first with `ps -ax | grep -E "flutter|dart"`.
- **Run:** `cd app && flutter run -d macos`, or build with `flutter build macos --debug`
  and open `app/build/macos/Build/Products/Debug/BetterBudget.app`.
- **App data:** `~/Library/Containers/com.lovelandsolutions.betterbudget/Data/Library/Application Support/com.lovelandsolutions.betterbudget/betterbudget.sqlite`
  (plus `-wal`, `-shm`). **This file is production data** (owner, 2026-10-06: "I'm going to be
  testing my app by using it. The data that I have is now production data"; from
  2026-10-03 until then it was not). A schema change is weighed against what's in this
  file: its upgrade keeps every row and is tested. Never delete, reseed, erase or
  hand-edit it; tests use demo data, and anything tried by hand goes on a copy.
- **Version:** bump `version:` in `app/pubspec.yaml` in each feature or fix PR (ADR
  0006); the build number comes from git on its own.
- **Rebuild and relaunch:** `pkill -f "BetterBudget.app/Contents/MacOS"; flutter build
  macos --debug && open build/macos/Build/Products/Debug/BetterBudget.app` (from `app/`).
- **Screenshots of the running app** (for checking UI changes): `screencapture -l<window
  id>` works once the terminal has screen-recording permission; get the window id from
  `CGWindowListCopyWindowInfo` for owner `BetterBudget`. Golden PNGs in
  `app/test/goldens/` are the quicker check.
- `tdb-bank-transaction-exports/` holds **real, unredacted** TDB statements, and
  `afcu-bank-transaction-exports/` the owner's credit union's (CSV, `.xls`, `.qfx`,
  `.qbo`). Both are gitignored and must stay that way. Committed fixtures must be redacted: real headers,
  real date format, real Cyrillic payee strings, scrubbed account numbers, synthetic
  amounts.
- Reading legacy `.xls` during analysis needs `xlrd` in a throwaway venv.
- **Workflow:** branch off `main`, commit, open a PR, merge. PR #1 used a merge commit.
