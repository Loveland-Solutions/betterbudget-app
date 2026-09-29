# 0004 — Ledger UI: Midnight, and the rules the register follows

**Status:** Accepted
**Date:** 2026-09-16

## Context

The README asks for a ledger that is polished and professional. The owner added a sharper
brief while reviewing designs: *sexy, professional, beautiful*, and **"Everything has a
purpose. I don't want to just copy other budget apps."**

Three desktop register directions were mocked up from the same synthetic data:
*Private Banking* (light, serif figures), *Midnight* (dark), and *Precision* (dense
Swiss grid). The mockups and their generator are in [`design/ledger/`](../../design/ledger/),
and the published canvas is at https://claude.ai/artifact/PVysW4N9RyarWTr4zZMgV5.
Midnight was chosen. The decisions below came out of reviewing the mockups and then
using the working app. Each one was a correction the owner made, so none of them should
be quietly undone.

## Decision

### Visual direction: Midnight

- A dark ground derived from the logo navy. Tokens live in `app/lib/ui/theme.dart` (`Mid`).

  | Token | Hex | Role |
  | --- | --- | --- |
  | ground | `#060D1E` | window background (brand navy `#03173E`, deepened) |
  | panel | `#0B1630` | cards |
  | raised | `#10204A` | hover, menus, active tabs |
  | ink / ink2 / ink3 | `#EEF1F8` / `#A3AEC6` / `#66728E` | text, three levels |
  | blue | `#4F7BFF` | interactive (brand royal `#0342B2`, lifted to read on dark) |
  | gold | `#D9B878` | reconciled, scheduled (brand gold `#C9A96B`) |
  | green | `#5CCB9A` | money in |
  | coral | `#F08A8A` | below zero, errors |

- Brand colors were measured from the pixels of `assets/logo/logo-english.png`: navy
  `#03173E`, royal `#0342B2`, gold `#C9A96B`, slate `#707784`.
- **Type: Onest, with Manrope as fallback.** Both are bundled; no font is fetched at
  runtime. **Onest has no ₮ (U+20AE) glyph.** Without the fallback every tögrög sign
  renders as a box. Browsers hide this by substituting a system font, which is why the
  HTML mockups looked fine. Any future font change must be checked for ₮, Ө and Ү.
- The macOS title bar is transparent over the ground color. The native title bar is kept
  so window dragging works.

### Rules the register follows

1. **Every element earns its place.** Before adding a chart, column, badge or avatar,
   name the decision it helps the user make. Removed on these grounds: a decorative
   running-balance chart, letter avatars, and a breadcrumb that repeated the sidebar.
   (Nav for unbuilt screens was removed at first, then brought back deliberately as
   placeholders by the owner; see rule 14.)
2. **The header's chart is a forecast, not history.** It runs from today to the next
   scheduled income, steps down on each scheduled bill, and names the lowest point. It
   turns coral only when the balance will go below zero. **The line under the headline
   never names payees** (owner's correction: names can be any length, and several bills
   won't fit). It reads "3 bills · ₮2,790,200 before 10.10". Clicking it opens a list of
   every bill before that date, then the income that ends it, each with date, payee,
   amount and the balance after it (coral below zero). Clicking a bill opens it, like
   a dot; Esc or clicking outside closes the list. Rejected: naming the two biggest bills
   plus "and N more" (A), and naming the bill that tips it under (C).
   With no bank sync, "will I make it to payday?" is the question only the user's own
   ledger can answer. **It makes no suggestions about savings or moving money.** The
   owner said savings come later. **Each dot is a way into its bill** (owner's request):
   hovering shows a card with date, payee, memo or category, amount and the balance
   after (bills on the same day share a dot and a card); clicking the dot, or the payday
   label, switches the register to Scheduled and selects that transaction. No link
   inside the card, since the dot itself is the click. **The chart's ends are labeled
   with plain dates** ("09.17" … "10.10"), so it's clear what span it covers. They
   replaced "Today" and "10.10 Salary" (owner's correction: the end label was unclear,
   and the income's name added nothing the headline doesn't already say). Short dates
   are month.day, as in YYYY.MM.DD, so "10.10" is 10 October; the owner, still getting
   used to that format, first read it as an amount.
   Hovering the end date still shows the income, and clicking it opens it. When the account is already
   under zero the headline says "Below zero now", not a future "runs out" date.
   **Scheduled money coming in lifts the line** (owner's call, from the budget-app
   review): a transfer from another account, or a refund, is a step up, and the line
   under the headline adds it ("2 bills · ₮990,200 before 10.10 · +₮1,000,000 in").
   **Late money in isn't counted until it arrives** (owner's call, option A of three,
   from review finding 1 on PR #6). A salary or refund due today or earlier and not
   confirmed is left out; the forecast runs to the next salary not yet due, or 30 days.
   The small label above the headline says so in gold, with the amount and how late:
   "Next 30 days · +₮2,500,000 in, 2 days late · not counted" ("in, due today"; several:
   "+₮2,650,000 in, 2 not arrived · not counted"). The amount, not a name or a date: it
   says whether the warning would clear if the money came, and "10.10" beside amounts
   read as money (owner's call, from its review); "+… in" because late bills use the
   same gold (owner's call). Only the amount part shrinks, so "not counted" always
   shows. **On payday the warning is conditional** (owner's call): "Runs out 10.15
   unless ₮2,500,000 due today comes". The bill list marks bills and transfers past due
   and counted as today ("· due 3 days ago"), so money the user forgot to move doesn't
   look covered (owner's call). Clicking the note opens that row (the first, when
   several), like a dot, so it can be confirmed. **Salary due today waits too** (owner's
   call): on payday morning it may still be late, and ending the forecast there hid
   rent due in two days. **A late transfer between the user's own accounts counts** on
   both sides, as due today (owner's call): leaving it out of the receiving account
   while the sending one still took it off put the money in neither. Before, a late
   salary counted as arriving today and ended the forecast there, so next week's rent
   vanished from it just when pay was late. Late bills still count, as due today.
   Confirming the money when it lands brings it back. A card is unchanged, since owing
   never warns. Rejected: counting it as today but running on past it (B), which says
   you're fine while rent bounces if pay is later still, and a second dashed line for
   "if it arrives today" (C), one more thing to explain.
   **Only a row in a payday income category (Salary; see rule 24) ends the forecast.** It used to ignore
   transfers in, so moving money from savings before rent still showed "Runs out", and any
   scheduled money in, even a ₮5,000 refund, ended it as if it were payday.
   **A credit card forecasts what will be owed** (owner's call): "Next 30 days",
   "₮0 owed after 09.25", "1 payment · ₮640,200 before 10.16", a blue line, never coral
   and never "runs out". Owing on a card is normal.
3. **One signed amount column, not In/Out.** A transaction moves money one way in one
   account. The two-column layout is a paper-checkbook and bank-statement habit. Money
   out is plain; money in is green with a `+`.
4. **Every row shows its full date (`YYYY.MM.DD`). No month subheadings or month
   subtotals.** The owner asked for these to be removed; don't reintroduce them.
   **Every other posted row is tinted a faint royal blue** (`Mid.stripe`, blue at 4.5%;
   owner's request, so transactions are easy to tell apart across the wide row). The
   first row is plain. **Hovering a row lifts it clearly above the stripe**
   (`Mid.rowHover`, a pale tint at 8%, laid over the stripe on tinted rows). The old
   hover was as faint as the stripe, so a hovered plain row looked like its striped
   neighbour (owner's correction). A selected row keeps its blue wash and outline. The dashed scheduled rows aren't striped; their
   dashed border already sets each one apart.
5. **Cleared-state symbols must not look like checkboxes or like math.** An empty circle
   beside a row reads as "select me", and a dash reads as a minus sign in the header's
   sum. The owner caught both. The symbols are: a small clock for uncleared (waiting to
   clear), ✓ cleared, ◆ reconciled (gold, from the logo's diamond).
6. **The header is the key to those symbols, written as a sum.** It reads like a
   receipt: *Cleared* (settled at the bank), then *Uncleared* as a signed amount (not
   settled yet), a rule, and *Working* as the total. **The total is the header's one
   big number**; there's no separate large balance above the sum (owner's call). It teaches why working and cleared differ. Below that,
   *Reconciled* shows **only when**: "Last reconciled on 09.10". The amount was dropped
   as unimportant (owner's call). Each line
   shows symbol, name, amount and meaning. Hovering
   a line fades non-matching rows; hovering a row's symbol lights up its line; clicking a
   line filters. Discoverable meaning beats a legend or a help screen. **Uncleared
   doesn't mean the bank hasn't seen it.** Banks often show a transaction as *pending*
   before it clears, so copy must say "not cleared yet" or "not settled", never "not
   posted" (an owner correction).
   **On a credit card every amount is what's owed, positive**, as the bank shows it
   (owner's call, from the budget-app review): the total reads "Owed ₮640,200" in
   normal ink, the register's last column is "Owed", and the sidebar says "₮640,200
   owed". Coral on a card read as an emergency, which teaches people to ignore coral
   where it matters. Rejected: keeping the minus signs and only dropping the coral.
7. **Data entry works in any field order.** Enter in any field adds the transaction if
   complete, otherwise it moves to the first missing field. Started rows outline the
   required fields still empty and say "needs N more". There is a visible Add button.
   Autocomplete gets the first Enter only while a half-typed name has suggestions
   showing. **The new-transaction row is hidden until the gold Add button (or ⌘N)
   opens it**. Add sits at the right end of the register's tab row, just above where the
   row opens (owner's call; it started in the page header beside search) (owner's call: the always-there blank row was clutter). It opens with the
   cursor in Payee, stays open after each add so a batch goes quickly, and closes on
   Esc or when you click away from it empty; with anything typed it stays. **A memo
   line sits under Payee while the row is in use** (option A; rejected: a memo field
   beside Add, too narrow). **No "+ for money in" hint** (owner: it only made sense in
   retrospect); `+` before an amount still means money in.
8. **One row at a time; its actions attach under it.** Clicking a row selects it and
   opens a bar inside its highlight with only what applies: Edit, Categorize (not on
   splits or transfers), Mark cleared *or* Mark uncleared, Delete, and ✕. Buttons are
   outlined (owner's call) so they read as buttons; Delete's outline is coral.
   **A reconciled row keeps Edit and Categorize, but its date and amount are locked**
   (owner's call: "sometimes I maybe want to change the payee; changing the amount would
   be a problem"). A statement confirms date, amount and account, not payee, memo or
   category. The bar reads "Reconciled on 09.10 · date and amount locked"; the editor
   shows the date and amount as plain text. A reconciled transfer can't move to another
   account, and a category can't turn into a transfer. Delete and clearing stay off.
   Rejected: locking everything, category chip included. Clicking the row again, ✕ or Esc closes it;
   the filter tabs stay put. Tab counts are in parentheses, "Uncleared (2)" (owner's call). No hint text: it should be obvious. **Multi-select was
   removed** (owner: not wanted now; ⌘-click, Shift-click and the bulk bar that
   replaced the tabs). It may come back with bank import, where categorizing or
   clearing a batch could be real work. Delete never removes a reconciled row (owner's
   correction: it once did), enforced in the database. **A transfer reconciled on one
   side is locked on both.** From the other account the row keeps its own ✓ or clock and
   can still be cleared there, and its payee and memo edited, but its bar reads
   "Reconciled in TDB Checking · date and amount locked" and there's no Delete. Editing it from that side once changed the locked side's
   amount; the database now refuses.
9. **Every action can be undone; only real changes get a toast.** **⌘Z (Ctrl+Z on
   Windows) undoes the last action**, then the one before, back through the session:
   add, edit, categorize, clear or unclear, delete, confirm, reconcile (owner's call).
   In a text field it undoes typing instead (rule 13). An undo says what it undid
   ("Undone · Unitel marked cleared"), because it may change a row that isn't in view.
   **Toasts appear only when a record was changed and saved or removed** (edit,
   categorize, delete, confirm, reconcile), with an Undo button for that one action.
   **A toast's Undo works only while its action is still the newest.** Otherwise it says
   "Undo the newer changes first · ⌘Z": undoing an older action out of order once wiped
   a later clear without saying so (code review, 2026-09-17). An undo the database
   refuses says "Couldn't undo … it changed since" instead of pretending it worked.
   **Clearing a row is quiet** (owner's correction: a toast on every symbol click was
   noise, especially while reconciling). The symbol changing is the confirmation.
   Adding stays quiet too, because the row appears. **Toasts are gold with dark
   text** (owner's call) so they get noticed; the dark toast they replaced was easy to
   miss. Undo is bold and underlined. **⌘⇧Z redoes** (Ctrl+Y or Ctrl+Shift+Z on
   Windows), and any new action clears what could be redone. The history lasts for the
   session and isn't saved.
10. **Confirming a scheduled item means it happened now.** Confirming before its due
    date posts it today, never on a future date, and the toast says so ("Zaisan
    Residence confirmed early · ₮1,800,000 · posted today, 09.16").
    **Confirm opens the bill to check its amount** (owner's call, option A of three,
    from review finding L: "some bills are hard to predict"). It turns the row into
    the editor with the amount selected (after its `+`, so typing the figure can't
    turn money in into money out). **A bill not due yet is dated today; an overdue bill
    or transfer keeps its due date**, since a standing order or auto-pay left then, and
    a statement will show it then (both review passes: dating it today moved it
    silently and broke the next reconcile). **Overdue money in is dated today** (owner's
    call): late means it didn't come on its date, and dating a late salary back put
    money in the balance before it arrived; Enter (or the row's Confirm
    button) confirms whatever it says, so a bill that matched costs one keystroke. The
    date can be changed to the day it really went out, but not to a future day (the
    calendar greys them). When the amount changed, the toast names the plan:
    "Electricity confirmed · ₮64,210, planned ₮60,000", and when the date isn't the
    planned one it says so ("· posted 09.12"). Esc leaves it scheduled.
    Rejected: posting at once with "Change amount" in the toast (B), easy to miss for
    bills that usually vary, and marking some scheduled items "amount varies" (C), a
    setting to maintain.
    **Money in confirmed short can stay owed** (owner's call, after a committee of three:
    household money, design, ledger integrity). When a salary or refund is
    confirmed below plan, a line under the amount reads "₮1,250,000 less than planned:
    (•) Still owed, due 10.10 ( ) Paid in full". **Still owed is chosen when more than a tenth is
    missing** (owner's call; otherwise Paid in full, since take-home pay and refunds
    after an exchange rate move vary a little), so Enter keeps
    the rest scheduled on the planned date (payee, memo and category as confirmed) in
    the same write. Past that date it's late, so rule 2 leaves it out of the forecast and names
    it. A remainder nobody wanted is visible and one Delete away; a forgotten one would
    vanish. The toast says "· ₮1,250,000 still owed, due 10.10", and one Undo puts back
    the single planned row. Bills never see the line: one that came in lower owes
    nothing more. Nor do transfers between the user's own accounts: moving less is
    their own decision, and a kept remainder would count in the forecast (late
    transfers count) as money that was never going to move (both review passes). Wording was the owner's pick ("Rest still coming" was disliked;
    rejected: "Expect the rest / That's all", "Keep ₮X scheduled / Drop it"). Rejected
    designs: a toast action (toasts are missed), keeping the rest automatically (varying
    income would leave a remainder every month), "Paid in full" as the default (a
    forgotten remainder disappears), and waiting for recurring schedules (they make next
    month's salary, not this month's shortfall).
11. **A future-dated manual entry is scheduled**, not posted. It shows in the forecast
    and in Scheduled but in no balance until confirmed. The same applies when an edit
    moves a posted transaction into the future.
12. **Editing happens in place, in the same row as adding.** Double-click a row (or
    select it and press Enter, or click Edit in its action bar) and it becomes the
    entry row, filled in, with a memo line and the cursor in the cell that was clicked.
    A single click only selects, with no delay, because double-click is detected from
    two single clicks. **A row opening into the editor, or its action bar, grows smoothly** and
    shrinks back when it closes (owner's request): 180 ms, ease out, from whatever
    height it has at that moment, so a double-click (bar, then editor) eases the whole
    way instead of jumping. The new-transaction row opens the same way (160 ms). A
    window resize doesn't animate. Instant with the OS reduced-motion setting. Enter or Save keeps the changes, Esc cancels, and Undo restores
    the whole transaction. Clicking another row with unsaved changes doesn't discard
    them; it says how to save or cancel. Reconciled rows don't open, and a message says
    why.
13. **Plain-key shortcuts never steal typing.** Delete, C, Enter and Esc act on the
    selected row only while no text field has focus. Clicking a row takes focus out
    of any field.
14. **The sidebar is organized by section (option A of three considered).** Ledger,
    Budget and Savings are section headers in one sidebar. The section you're in
    expands; the others collapse to one line. Under Ledger are the accounts, grouped.
    Net worth stays pinned at the bottom. Budget and Savings are placeholders marked
    "Later" that open a "Not built yet" page. **"Savings" is a working name** until the
    section is defined. Rejected: an icon rail plus a per-section panel (B), and
    accounts-only sidebar with sections as a top switch (C). "All accounts" was first held back
    for cross-account search; the owner asked for it with categories (rule 23).
    **Opening a section spills its contents down** (owner's request): the space opens
    and the items fade and drop into place one after another, top to bottom, while
    the sections below slide down. Opening takes 360 ms and
    closing plays back in 200 ms. With the OS reduced-motion setting on, it opens
    instantly. Any section's contents can use it (`_Spill`); only Ledger has
    contents today. The timing is a first version and can be tuned.
    **No chevron on section headers** (owner's correction): a chevron promises a
    toggle, where clicking an open section closes it again. Here clicking a section
    switches to it, and it stays open until you pick another. The blue icon and bold
    label already mark the current section. Accounts line up with the section label.
15. **The date field opens a calendar under it (option A of three considered).** It
    shows while the date field has focus, styled in Midnight, Monday first. Typing
    still works and the calendar follows it to the typed month. Clicking a day fills
    the date and moves to Payee; Esc closes the calendar first, and a second Esc
    reaches the row. The selected day is filled blue and today is underlined. **Days
    after today are gold**, because picking one schedules the transaction (rule 11);
    hovering or selecting one says "After today · it will be scheduled". It marks
    nothing else. The same calendar opens when editing a transaction's date. Rejected:
    Today/Yesterday buttons under the calendar (B), since the field already starts on
    today, and Flutter's modal date picker dialog (C), which looks stock, blocks
    typing and pulls you out of the row.
16. **Reconcile happens in the header (option A of three considered).** An outlined
    Reconcile button sits beside "Last reconciled on…". The reconciled line itself
    still filters, like the other key lines. The balance sum is replaced by
    Statement date (today by default; the calendar can't pick future days), Bank
    balance ("Bank says you owe" on credit accounts, entered as a positive number),
    Cleared here, and **Off by**. The forecast stays beside it. Bank balance starts
    filled with the cleared total, so if it already matches, reconciling takes one
    click. The register narrows to rows not yet reconciled up to the statement date,
    labeled "Not reconciled, through …", where rows are marked cleared the usual way
    (symbol click or C). "Off by" updates live and reads "Matches" in green at zero.
    **Bank balance starts empty, with the cursor in it** (owner: "that's bad" about the
    old prefill). It used to start at the cleared total, so Reconcile then Enter locked
    everything without anyone reading the bank's number. Next to the empty field: "Not
    the “available” balance" (bank apps show one that takes off pending holds and won't
    match). **Lock stays disabled until the numbers match.** When they don't, the panel
    helps find why: "Bank is lower" or "Bank is higher" (opposite causes), and a line
    naming the one row whose amount is exactly the difference, if exactly one is ("Unitel
    on 09.16 is ₮30,000 and isn't cleared", "… cleared here · not at the bank yet?",
    "… dated 09.18, after the statement"); otherwise "Clear the rows your bank shows".
    While reconciling, the last column is **Cleared balance**, a running total of cleared
    rows only, to compare line by line with the statement; uncleared rows show none.
    **A difference nobody can find goes in as a named adjustment** (owner's call). In
    place of the disabled Lock, an outlined (not gold) "Add ₮30,000 adjustment and lock"
    posts one cleared "Reconcile adjustment" row on the statement date against a
    "Balance adjustments" account (equity, like opening balances, so never spending), and
    locks it with the rest. Its toast says "· ₮30,000 adjustment added", and Undo removes
    the adjustment with the locks. Rejected: staying strict with only the finding aids
    (people would make up a spending row to force a match). The button
    names how many rows it locks. Locking marks this account's cleared entries up to
    the date reconciled, records the statement, and offers Undo. The other side of a
    transfer isn't locked. Esc cancels (after closing the calendar). A date before the
    last reconciliation or after today is refused with a reason. Rejected: a yes/no
    "does your bank show X?" first step (B), which invites clicking Yes without
    checking, and waiting for bank import (C). Import can reuse the "Off by" line.
    **A reconcile can be taken back at any time, not just this session** (owner's
    call). A locked row's bar says "Reconciled on 09.10 · locked because it matches
    that statement". Rows locked by the account's newest reconcile also get **Undo this
    reconcile**, which puts that reconcile's rows back to cleared. Reconciles come
    undone newest first, so every lock left in place still matches its statement.
    Later reconciles that locked nothing go with it. The toast has Undo, and ⌘Z / ⌘⇧Z
    work too. Each entry stores the reconcile that locked it (schema version 2);
    older data was linked to the first statement dated on or after each row. **Only
    an account's own side is ever reconciled**, and always by a statement. Older data
    also locked category, opening-balance and statement-less sides, which made rows
    look unlocked but refuse edits, or stay locked forever. Schema version 3 puts those
    back to cleared. The database also refuses statement dates out of order, and
    forecast dots do nothing while a reconcile is open (the register hides scheduled
    rows then).

17. **A transfer says which way it goes before it's added** (owner's call, from
    budget-app review finding H). While the category is "→ Account", a line under
    category and amount, level with the memo line, reads "₮640,200.00 from TDB
    Checking to Golomt Visa", and "Swap" turns it around (it adds or removes the
    `+`). The category reads "→ Golomt Visa" whichever way the money goes, so a
    transfer entered from the receiving account used to go the wrong way unnoticed.
    Editing a transfer shows the same line; on a reconciled one there's no Swap.
18. **"Move to" fixes a transaction entered in the wrong account** (owner's call,
    finding I). It sits in the row's action bar, after clearing, and lists the other
    accounts. Only this account's side moves; date, amount, payee and category stay.
    **The moved side starts uncleared**, because the other bank hasn't been checked,
    and the toast says so ("· uncleared there until it clears"). Not offered on
    reconciled rows (either side), opening balances, or onto a transfer's own other
    side. ⌘Z puts it back as it was, cleared state included.
19. **Backups stay on this machine** (owner's call, finding K). Once a day, when the
    app opens (and hourly while it stays open), a copy goes to `Backups/` beside the
    database. **Kept: the newest 14, plus the first copy of each of the last 12
    months** (owner's call, from the review: a mistake found a month later still has
    a copy from before it). **Backups live in Settings** (owner's call: "where we'll
    have other settings"). A gear labelled "Settings" sits at the bottom of the sidebar, just above the Net
    worth section, lined up under the section icons (owner's corrections: it started
    right of Net worth, then left of it, and got its label), and opens a Settings page in the main area (option A; rejected: a menu
    from the gear, too small for status or later settings, and a gear beside search
    in every account's header). The page's first section, Backups, shows the daily
    copy ("Today 09:30 · on this computer"), what's kept, and two buttons. They first
    sat as links under Net worth. **"Back up to…"** saves a copy wherever the user
    picks (another drive, a USB stick); the toast names the file. The automatic copies
    share a disk with the data, which is why it exists. **"Restore from…"** sits beside
    it (owner's call). The picker opens on the daily
    copies. Nothing is replaced until a dialog shows the backup's date and time, what
    it holds and what's here now ("19 transactions · 4 accounts"); Enter or Restore
    confirms. What's here is saved first, the toast says so, and Undo (or ⌘Z) brings it
    back. A restore clears the earlier undo history, since those actions point at rows
    it replaced. A backup from an older version is upgraded on the way in; one from a
    newer version, a damaged file, or a file that isn't a BetterBudget backup is
    refused with a reason. Rejected: copying a file over the data by hand, which can
    corrupt it (SQLite's `-wal` file stays behind). **A failing daily copy says so**
    (owner's call), once the newest copy is over two days old; a single failed hour
    stays quiet. The gear gets a coral dot, and Settings says "Failing · the last one
    is from …" in coral.
    Backups are unencrypted until SQLCipher; that work must encrypt or remove them.
    **Start over** (owner, 2026-09-24, for the alpha: "a clean start with no demo
    accounts") is the last section of Settings: "Start a new ledger…" opens a coral
    warning with what goes ("19 transactions · 4 accounts · 1 reconcile", then pay,
    payees, and the Budget and Savings settings) and a box, ticked by default, to
    keep the open categories with no rows (a default, not a required choice). What's
    here is saved first as `before-new-ledger-….sqlite` in `Backups/`; Undo or ⌘Z
    puts it back, and Restore from… can later. It clears the undo history like a
    restore. A ledger emptied this way stays empty: the demo data only fills a file
    that has never had a ledger started in it.
    **Made plain that everything goes** (owner, 2026-09-29: "it needs to be more clear
    that all their old stuff will go away"; option A of three). "Start a new ledger"
    read like adding a second ledger, so it's **"Erase everything and start over…"**,
    and the card says it erases every account and transaction (no "Done trying
    things out?" in front: owner removed it, 2026-09-29). The dialog, titled
    "Erase everything and start over?", lists under "All of this is erased:" each
    account by name with its balance as the sidebar shows it ("₮640,200 owed"), the
    transactions with their first and last dates, then pay, reconciles, payees and
    settings, and says "You start with no accounts and no money in the app." **The
    categories are a visible choice** (owner: "the option to leave the categories or
    delete them should be clearly visible"): "Your 15 categories" with "Keep them,
    empty" (default) or "Erase them too", and a line saying what each means. The
    button reads "Erase everything"; the toast "Everything erased · what you had is
    saved in Backups". Still one click, saved first, undoable (warn, don't block).
    Rejected: stronger words with counts only (B), and a before/after comparison
    (C). The recovery-key screen's "Start a new ledger instead…" keeps its name: it
    moves the old ledger aside, not erasing it.

20. **Old items say on the row why Working may be off** (owner's call, option A of
    three, from review finding G). Working leaves out scheduled rows and keeps
    uncleared ones, so two kinds of old row skew it without a word. **A scheduled row
    past its date** says "· due 7 days ago" in gold after the payee, in place of "next
    of N scheduled" (the Scheduled tab counts them). It isn't in Working until
    confirmed, though it probably happened; the forecast already counts it as due today.
    **An uncleared row 14 days old or more** says "· not cleared for 34 days" after its
    memo, a shade brighter than the memo. Card holds usually drop within that, so it
    may never have happened (cancelled, or entered twice) yet still lowers Working.
    Nothing changes Working by age on its own. Rejected: a header line that filters to
    these rows (B), and both (C).

21. **Accounts are added and managed where they're used** (owner's call, option A of
    three). A quiet "+ Add account" sits under the accounts in the sidebar and opens a
    form in the main area: a name ("New account" if left empty) and a kind, Bank account
    (already chosen) or Credit card. A bank field was left out because nothing shows it.
    **A new account's first screen asks what's in it** ("What do you owe on it
    today?" on a card), with a date. The answer becomes a cleared opening balance, so
    the first reconcile starts from it. Left empty, the account starts at ₮0 with the
    entry row open. **The name renames in place** when clicked (Enter or leaving the
    field saves, Esc cancels). A ⋯ beside it holds Rename, Change to credit card / bank
    account, Archive… and Delete…. **Right-clicking an account in the sidebar opens the
    same menu** (owner's request, after trying it). The account stays lit while the
    menu is open, and Rename there opens the account with its name ready to edit.
    Every action undoes with ⌘Z. Rejected: an Accounts
    page in Settings (B, managing accounts away from the ledger) and typing a new
    account straight into the sidebar (C, no place to ask the kind).
    **Warn, don't block** (owner, 2026-09-18: "I really hate it when a developer tries
    to save me from myself"). The first design allowed archiving only at a zero
    balance and deleting only an account with no rows. Now both are always allowed,
    and a dialog says exactly what will happen first. **Archive** takes the account
    out of the sidebar, transfers and Move to, but keeps it in net worth. It asks
    only when something is left behind ("₮4,182,450 is still in it…", "4 scheduled
    rows … won't show in any forecast"). Settings lists archived accounts with "Show in
    sidebar". **Delete is stark and final** (owner's correction: don't promise it
    can be brought back). The title is coral, and the dialog gives the rows that go and
    how many were reconciled, how far net worth moves, and where transfers stay. The
    button names the account, and Enter doesn't press it. The toast has no Undo,
    though ⌘Z still works as it does for everything in the session (the dialog doesn't
    say it can't be undone, since that wouldn't be true). **Deleting an account never
    changes another account** (owner's call). Its transfers stay on the other account
    as "TDB Checking (deleted)", so balances, cleared totals and reconciles there are
    untouched, and a lock that came from the deleted account's statements lifts.
    Rejected: turning those transfers into ordinary rows with no category, which hides
    where the money came from.
    **From the reviews** (decided along the lines above):
    - The second kind is **"Card or loan"**, with a hint naming loans and Storepay.
      Salary loans, mortgages and buy-now-pay-later all show as owed. The form says
      accounts are in tögrög for now.
    - The start hint shows before anything is typed. On a card it says "what you've
      used, not the available limit". The question follows the date ("What was in it
      on 08.31?").
    - After a balance, the entry row opens and the toast says "add only what hasn't
      settled yet", because the bank's number already includes everything settled.
    - **Changing the kind flips an unreconciled opening balance**, since it was typed
      in the kind's own sign. Changing back flips it back.
    - The archive warning separates bills (dropped from every forecast) from scheduled
      transfers (still on the other account's forecast). The delete warning names
      scheduled transfers that stay.
    - Balances in the warnings read "₮3,000 overdrawn" or "₮5,000 in credit: the bank
      owes you", and show the fraction when there is one.
    - Net worth adds "incl. ₮X in archived" when archived accounts hold anything.
    - Deleting an account with no rows and no transfers skips the dialog.
    - Undo of adding an account only works while it is still empty.
    - The database refuses new rows in a deleted account.

22. **Categories are managed on the Budget screen** (owner's call). Categories belong
    to both the ledger and the budget, and one place should own them. The Budget
    screen is where every category will be a line, so its first version is just the
    list. It is grouped Spending and Income, and each category shows "42 rows · last
    09.12 · 1 scheduled", which is what decides whether to keep, merge or archive it.
    There are **no ₮ amounts yet**; the budget model (envelopes or targets, still open)
    adds its columns to these rows. Budget no longer says "Later". Rejected, and
    first recommended: a Categories page under Ledger, which would have become a second
    place once the budget came; and a top-level Categories section, for the same
    reason. **Add category** opens an inline row (name, Spending or Income; income ends
    a forecast, like payday). **Click a name to rename it**; ⋯ or a right-click gives
    Rename, Change to income / spending, Archive and Delete…, like accounts (rule 21).
    **Archive** needs no dialog, since nothing is lost: the category leaves the menus
    and the entry row, and its rows keep its name. "Show archived (n)" lists archived
    categories with "Show in menus". **Delete with rows asks where they go** ("1 row is
    filed under it. It moves to: [Groceries]"), then merges. The rows are moved, not
    lost, so this isn't a block. Deleted rows move too, so undoing their delete
    later finds a live category. An empty category just goes, with ⌘Z.
    **A new category can be made while typing a transaction.** In the entry row, a
    name that isn't a category shows "+ New category 'Coffee'" in the list and a gold
    "new category" note, so a typo is visible before saving. Saving makes it (income
    if the amount had `+`), and the toast says "Nomin Coffee added · new category
    'Coffee'". One ⌘Z takes both back. "Gro" plus Enter still picks Groceries: the
    "+ New" line never counts as a match.
    **From the reviews** (decided along the lines above):
    - An archived category's name is still known. Editing or confirming one of its
      rows keeps it; only the lists leave it out. The first build treated it as new
      and quietly made a second one.
    - A typed name becomes a category only when that's clearly meant: "+ New" was
      picked, or the name looks like nothing else. If it's part of another name,
      saving from another field says "'Gro' isn't a category · pick Groceries, or +
      New category". If it's an account's name, it says "Did you mean '→ Golomt
      Visa'?". This protects against slips; it doesn't refuse anything, since "+ New"
      is always there.
    - The note says "new income category" when the amount has `+`, and it stays
      beside a calculator sum.
    - The category and its row are one write, and one undo takes both.
    - No duplicates: adding a name that exists (any case) says so. If it's archived,
      it comes back instead. Renaming onto another category's name offers "Merge
      Gifts into Entertainment?", the same operation as delete-with-move.
    - Delete counts deleted rows too, so undoing their delete later finds a category.
      The dialog says how many are scheduled, and when moving between spending and
      income it says what changes.
    - A split merged into its own other line shows the category twice. Balances are
      right; accepted until splits can be edited.
    - The Add category row stays open for the next one. Dates from another year show
      in full. Names sort ignoring case.
    - The database refuses category actions on anything that isn't a live category.

23. **All accounts is a view under Ledger** (owner's request, from clicking a
    category's usage). "All accounts" sits above the account groups in the sidebar
    and shows every account's rows in one register. **The last column is Account**,
    in place of Balance: a running total mixing checking, a card and cash means
    nothing. **A transfer shows once**, from the account the money leaves ("To Khan
    Savings" in TDB Checking's row). Scheduled rows name their account where one
    account's register says "next of 4 scheduled". **Adding a row asks for the
    account** (owner's call: the dropdown is for adding, not filtering). It's a
    dropdown in the Account column that starts on the account last open and stays
    on the last one picked, so a batch from one account is picked once. The note and
    Add move to a line under it. A row's own actions (edit, clear, categorize, Move
    to, delete, confirm) work on its own account. **Nothing sits above the register
    but filters** (owner's call, option A): net worth is in the sidebar, and the
    forecast and reconcile stay per account, since "will I make it to payday?" and a
    statement are about one account. Rejected: a slim summary line (B) and a
    combined forecast (C). **Clicking a category's usage on the Budget screen**
    ("2 rows · last 09.16") opens All accounts with a chip, "Category: Groceries ✕",
    and what matched: "2 rows · ₮276,650.50 spent". A split counts only its line in
    that category. ✕ or Esc takes the filter off. This is the first slice of Search
    (roadmap item 10): chips for account, date and amount can join it.
    **From the reviews** (decided along the lines above):
    - **The picker starts on the account last open each time All accounts is
      opened, then stays on the last pick for the batch.** A pick from days ago
      doesn't carry on. (The first build reset after every save, so the second row
      of a batch went to the wrong account.) It comes after Amount in Tab order.
      With an account chosen, Enter adds; Space or ↓ opens the list. Keys pressed
      on it never reach the row shortcuts, and hovering its list doesn't close an
      empty row.
    - Nothing moves money to its own account (enforced in the database). "→ Cash
      wallet" from Cash wallet says "Can't transfer to the same account".
    - **A transfer's symbol shows the less settled side**, with a tooltip naming
      it ("In Golomt Visa: Uncleared…"). Clicking clears that side, and
      Uncleared counts it. "Has my card payment landed?" can be answered here.
    - A transfer is shown from an open account's side before an archived one's.
    - Scheduled rows name their account even when overdue ("· due 3 days ago ·
      TDB Checking"). Search matches account names too.
    - **A new row that won't show under the filter or search says where it
      went** ("Nomin added to Cash wallet · not in this view"), so it isn't typed
      twice.
    - The filter line counts the posted rows its total covers, gives the span,
      and counts scheduled rows apart: "2 rows · ₮276,650.50 spent since
      2026.09.12 · 1 scheduled". More back than spent reads "refunded".
    - Rename, Add account and "Show in sidebar" from All accounts open that
      account. Switching views with an unsaved edit stops, as clicking another
      row does.

24. **Pay: paydays end the forecast, and the app asks for pay** (owner's calls,
    2026-09-19). **Only a payday income ends a forecast** (option A of three).
    Income categories carry a payday mark: on for Salary and Pension (every existing
    income category kept it when upgraded), off for the rest. Child allowance on the
    12th no longer ends the forecast before rent on the 20th. Toggle it with "Mark as
    payday" / "Not a payday" in the category's ⋯. Rejected: ending the forecast at
    the first income big enough to cover the bills (B), and always forecasting 30
    days (C). **Putting in pay** (option A): a pay setup names the category, the
    account it's paid into, who from (optional), whether it's about the same each
    time or varies, the amount, and when it comes (monthly on a day, twice a month,
    or every N weeks from a payday), with a weekend payday moved to the Friday
    before or the Monday after. It opens from the forecast, from a payday category
    on the Budget screen ("payday · pay not set up", gold, until it is; or
    "payday · ₮2,100,000 or more on the 10th and 25th · next 09.25"), and from
    Settings. **The next payday is always scheduled from the plan**: saving
    schedules one, and confirming it schedules the one after at the planned
    amount, whatever came. Rejected: a Pay section only in Settings (B), and
    prompting after each payday with nothing scheduled (C). **The app keeps asking
    until there's pay:** an account's forecast with no payday to run to says
    "Next 30 days · no payday ahead · Add your pay →" in gold.
    **Pay that varies is an estimate on the low side** (owner: "better to have too
    much money than too little"). The setup's amount reads "Expect at least", with
    the advice that the forecast counts on it. Your last paychecks' lowest and highest
    show beside it. Typing more than some of them says so in gold ("Higher than 2 of
    your last 6 paychecks: the forecast may look better than it'll be"), and it
    still saves. Confirming under the estimate isn't "still owed". The toast says
    "₮180,000 under the estimate", and the payday card says "at least, an
    estimate". When the last three came in over 5% above it, the Budget screen line
    says "Last 3 came in above ₮X · raise the estimate?". Nothing changes the
    estimate but the user.
    **Budget by month or pay period, the user's choice** (owner's call: people
    paid every two weeks). It's in the pay setup and in Settings ("Budget by: Month
    / Pay period"), and it starts on Month. A pay period needs a pay schedule; with
    two earners, whose pay it follows is the choice. Every-two-weeks pay notes "26
    paydays a year: two months a year have three". For now it decides the span of a
    category's rows opened from Budget: a "This month · 09.01–09.30" (or "This pay
    period") chip, removed with ✕ or Esc for all time. The budget's periods will use
    the same setting.
    **From the reviews** (decided along the lines above):
    - **Early or late pay belongs to its planned payday.** Pay confirmed on the
      23rd for the 25th schedules next month's, not the 25th again. A payday the
      user deletes (unpaid leave) stays skipped. Paydays the app takes away itself
      (a changed plan, an undo) are unlinked, so they don't count as skipped.
    - **A salary the user had scheduled by hand** within a week of the first
      payday is taken over by the new schedule, and undo brings it back.
    - While a payday is overdue, the next one is scheduled too, so the forecast
      still has a payday to run to.
    - Confirming a bill never touches pay; confirming a payday schedules only its
      own schedule's next one.
    - An every-N-weeks start date later than today is the first payday.
    - **"Add your pay" asks only while there's no pay set up anywhere.** Once
      there is, accounts that pay doesn't go into say plainly "Next 30 days". A
      click can't start a second Salary by mistake.
    - The amount is labelled "Each payday". For twice a month and every N weeks,
      the summary adds "about ₮X a month", so a monthly figure typed by mistake
      shows as double before saving. "It varies" says to leave bonuses out.
      Estimates and history come from the schedule's own paychecks, not
      everything filed under Salary.
    - **Nudges point the safe way.** Pay that varies suggests raising the
      estimate only when the *lowest* of the last six beat it by 5%. Pay that's
      the same notices when the last two came in alike and off the plan ("Last 2
      came in at ₮X, less than planned · update it?").
    - Undo puts back exactly which schedule the budget ran by, and a category's
      payday mark. Editing a schedule no longer re-marks a category the user set
      to "Not a payday".
    - Paydays skip archived or deleted accounts and categories. Settings says
      so ("(archived · no paydays until it's back)"), names two earners by
      employer, and the dialog says which pay the budget follows when it's
      another's.
    - Date arithmetic is in calendar days, safe across daylight saving. A
      restore schedules paydays as a launch does.
    **Two amounts, and no regular pay** (owner said yes to both, 2026-09-29):
    - **Twice a month can have a different amount each paycheck** (an advance on
      the 10th, the rest on the 25th). The default stays one amount: "The same each
      paycheck" / "A different amount each paycheck" shows under the amount once
      "Twice a month" is picked, and the second choice turns the amount into
      "On the 10th" and "On the 25th", earlier day first. (Owner's correction,
      2026-09-29: "a different amount each day" was misleading; it's each
      paycheck.) Each payday is
      scheduled at its own day's amount, a weekend move included; the summary
      shows the next payday's amount and "about" the two added together. The
      Budget screen and Settings say "₮500,000 on the 10th and ₮1,600,000 on
      the 25th". Estimates and nudges compare each paycheck with its own day's
      plan, so an advance never reads as a short paycheck. The "higher than
      your last paychecks" warning is off for split pay (its history mixes
      advances and the rest). The same amount typed twice saves as one.
      Stored as a second amount on the schedule (schema v7).
    - **"I don't have regular pay"** sits bottom left in "Add your pay" while
      there's no pay anywhere (self-employed, between jobs). It turns off the
      forecast's "Add your pay →" and the Budget screen's gold "pay not set
      up" (it reads "payday · no regular pay"). Settings says "You said you
      don't have regular pay, so the forecast doesn't ask for it" with **Ask me
      again**; "Add your pay" stays in Settings the whole time. ⌘Z undoes
      either.
    - From the code review (decided along those lines): going back to one
      amount (same both days, or another rule) keeps the larger of the two,
      since the advance alone would undercount pay. Split pay confirmed late
      belongs to the payday whose amount it matches (an advance on the 18th is
      still the 10th's, and the rest on the 25th stays scheduled). Both days on
      the 28th or later warn in gold that shorter months have one payday, not
      two. Adding pay after "I don't have regular pay" clears the saying, and
      undo brings it back; the button isn't offered again once it's set.
25. **Savings is the steps to getting financially prepared** (owner's calls,
    2026-09-19). It follows the order of the Church's *Personal Finances for
    Self-Reliance* course ("What Is My Current Financial Priority?", chapter 5;
    see [self-reliance-course.md](../self-reliance-course.md)), **for everyone**.
    Tithing is left out: "I'm not going to push tithing. I want to push getting
    financially prepared." Six steps: one month of expenses set aside; health
    coverage; no consumer debt; 3 to 6 months set aside; saving for retirement;
    paying off the mortgage and student loans. **Option A of three** (a ladder).
    Rejected: B, the payday split (tithing, then the fund, then the rest) as the
    section itself (it may come with the budget), and C, a course companion with
    weekly lessons (courses may be added later). Also set aside for now: the
    earlier Growth page, balance sheet and goals concepts
    ([personas.md](../personas.md) §2).
    **How it works** (decided along those lines):
    - Every step shows. **The current step is the first not done** ("Now",
      outlined in blue); done steps have a green check. Nothing is locked: any
      step can be **set aside** from its ⋯ and brought back (warn, don't block).
    - **A month is a month of expenses, not pay** (the course's own wording):
      the average of spending categories over the last 3 months (or since the
      ledger began, from 4 weeks), rounded up. Refunds count against it; transfers,
      card payments and opening balances don't. The user can type their own
      ("as you typed it"); emptying it goes back to the average. With under 4
      weeks of rows it asks for one.
    - **The fund lives in accounts the user picks** ("Kept in Khan Savings",
      a menu of bank accounts). Until one is picked, step 1 isn't done whatever
      is saved.
    - **Consumer debt** is every card or loan owing, unless marked a mortgage, a
      student loan, or "paid in full every month" (a card used for convenience).
      Each shows its balance, smallest first, with the course's advice: extra
      on one at a time, smallest balance or highest interest first, then roll
      its payment into the next. While step 1 is current, it names the debts to
      pay only minimums on.
    - **Health coverage and retirement are the user's answers** (the money
      usually never passes through the ledger). "Not yet" is the default.
    - The bigger fund aims for 3 months unless the user picks 4, 5 or 6.
    - Answers are quiet clicks (like clearing a row); marking an account, a
      typed month and setting a step aside toast. All of them undo and redo.
    - Stored as an account role and a small preferences table (schema v6).
    **From the reviews** (decided along the lines above):
    - The month's average starts at the first spending row, so an opening
      balance dated months back doesn't shrink it and tick step 1 early.
      Payments into a marked mortgage or student loan count as a month's
      expenses ("loan payments included"); card payments don't, since the
      card's own spending already counts. Worked out in whole integers.
    - **A check means paid off or yes, never "not marked".** With no loan
      marked, step 6 asks: "I have none", "Paying extra on them" or "Not yet".
    - A card marked "paid in full every month" that has owed something every
      day for over five weeks says so in gold ("Owed every day since …"). It
      stays the user's call.
    - Step 3 marks one debt **"Pay extra here"**: the smallest, or one picked
      from its menu ("Pay extra on this one").
    - One word for the figure: "a month of expenses", the course's word.
    - The fund and the month are set on step 1 only; step 4 adds the months.
      Archived accounts count nowhere in Savings (they can't be seen or
      changed there).
    - Row keys (Delete, C) act only on the ledger, so they can't reach a
      hidden row from Savings; answers read the newest ledger, so quick
      clicks both count.
    - **Later:** showing the three monthly totals under the average (a
      student's swings); keeping the "a separate account works best" hint
      when the fund's account is also spent from; the rate and minimum payment
      per debt (with card due dates, personas §1).

## Consequences

- Desktop and mobile get separate layouts over one data layer
  ([ledger-features.md §J](../ledger-features.md)). These rules are written for desktop;
  mobile must honor 1–7 and 9–16 in its own form.
- A light theme is not planned. Midnight is a stance; revisit only if users ask.
- The 1440×900 window shows about five transactions under the header. Collapsing the
  header on scroll is an open idea, not a decision.
- Golden screenshot tests (`app/test/goldens/`) pin these rules visually. Update them
  only for intentional changes.
