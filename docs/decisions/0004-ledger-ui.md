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
   turns coral only when the balance will go below zero, and says which bills cause it.
   With no bank sync, "will I make it to payday?" is the question only the user's own
   ledger can answer. **It makes no suggestions about savings or moving money.** The
   owner said savings come later. **Each dot is a way into its bill** (owner's request):
   hovering shows a card with date, payee, memo or category, amount and the balance
   after (bills on the same day share a dot and a card); clicking the dot, or the payday
   label, switches the register to Scheduled and selects that transaction. No link
   inside the card, since the dot itself is the click. When the account is already
   under zero the headline says "Below zero now", not a future "runs out" date.
3. **One signed amount column, not In/Out.** A transaction moves money one way in one
   account. The two-column layout is a paper-checkbook and bank-statement habit. Money
   out is plain; money in is green with a `+`.
4. **Every row shows its full date (`YYYY.MM.DD`). No month subheadings or month
   subtotals.** The owner asked for these to be removed; don't reintroduce them.
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
   outlined (owner's call) so they read as buttons; Delete's outline is coral. Reconciled
   rows show "Reconciled · locked" instead. Clicking the row again, ✕ or Esc closes it;
   the filter tabs stay put. No hint text: it should be obvious. **Multi-select was
   removed** (owner: not wanted now; ⌘-click, Shift-click and the bulk bar that
   replaced the tabs). It may come back with bank import, where categorizing or
   clearing a batch could be real work. Delete never removes a reconciled row (owner's
   correction: it once did), enforced in the database.
9. **Actions confirm themselves with undo.** A toast names what happened ("Unitel
   marked cleared · Undo"). **Toasts are gold with dark text** (owner's call) so they
   get noticed; the dark toast they replaced was easy to miss. Undo is bold and
   underlined.
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

## Consequences

- Desktop and mobile get separate layouts over one data layer
  ([ledger-features.md §J](../ledger-features.md)). These rules are written for desktop;
  mobile must honor 1–7 and 9–14 in its own form.
- A light theme is not planned. Midnight is a stance; revisit only if users ask.
- The 1440×900 window shows about five transactions under the header. Collapsing the
  header on scroll is an open idea, not a decision.
- Golden screenshot tests (`app/test/goldens/`) pin these rules visually. Update them
  only for intentional changes.
