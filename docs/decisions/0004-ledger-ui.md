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
   **Only a row in an income category (Salary) ends the forecast.** It used to ignore
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
    Residence confirmed early · posted today, 09.16").
11. **A future-dated manual entry is scheduled**, not posted. It shows in the forecast
    and in Scheduled but in no balance until confirmed. The same applies when an edit
    moves a posted transaction into the future.
12. **Editing happens in place, in the same row as adding.** Double-click a row (or
    select it and press Enter, or click Edit in its action bar) and it becomes the
    entry row, filled in, with a memo line and the cursor in the cell that was clicked.
    A single click only selects, with no delay, because double-click is detected from
    two single clicks. Enter or Save keeps the changes, Esc cancels, and Undo restores
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
    accounts-only sidebar with sections as a top switch (C). "All accounts" waits until
    cross-account search exists.
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
    a copy from before it). **"Back up to…" sits under Net worth** in the sidebar and
    saves a copy wherever the user picks (another drive, a USB stick); the toast names
    the file. The automatic copies share a disk with the data, which is why it exists.
    **"Restore from…" sits under it** (owner's call). The picker opens on the daily
    copies. Nothing is replaced until a dialog shows the backup's date and time, what
    it holds and what's here now ("19 transactions · 4 accounts"); Enter or Restore
    confirms. What's here is saved first, the toast says so, and Undo (or ⌘Z) brings it
    back. A restore clears the earlier undo history, since those actions point at rows
    it replaced. A backup from an older version is upgraded on the way in; one from a
    newer version, a damaged file, or a file that isn't a BetterBudget backup is
    refused with a reason. Rejected: copying a file over the data by hand, which can
    corrupt it (SQLite's `-wal` file stays behind). **A failing daily copy says so**
    (owner's call): "Daily copy failed" in coral, on its own line above "Back up to…",
    once the newest copy is over two days old; a single failed hour stays quiet.
    Backups are unencrypted until SQLCipher; that work must encrypt or remove them.

## Consequences

- Desktop and mobile get separate layouts over one data layer
  ([ledger-features.md §J](../ledger-features.md)). These rules are written for desktop;
  mobile must honor 1–7 and 9–16 in its own form.
- A light theme is not planned. Midnight is a stance; revisit only if users ask.
- The 1440×900 window shows about five transactions under the header. Collapsing the
  header on scroll is an open idea, not a decision.
- Golden screenshot tests (`app/test/goldens/`) pin these rules visually. Update them
  only for intentional changes.
