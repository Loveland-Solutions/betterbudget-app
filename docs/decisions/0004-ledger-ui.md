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
   owner said savings come later.
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
   showing.
8. **Multi-select the desktop way, no checkbox column.** Click selects one row; ⌘-click
   (Ctrl elsewhere) toggles; Shift-click selects a range. A bar replaces the filter tabs
   while anything is selected, and says how to select more. Bulk categorize, mark
   cleared/uncleared and delete all undo. Splits, transfers and reconciled rows are
   skipped, and the message says how many. Delete never removes a reconciled row
   (owner's correction: it once did); "1 transaction deleted · 1 reconciled left
   locked".
9. **Actions confirm themselves with undo.** A toast names what happened ("Unitel
   marked cleared · Undo").
10. **Confirming a scheduled item means it happened now.** Confirming before its due
    date posts it today, never on a future date.
11. **A future-dated manual entry is scheduled**, not posted. It shows in the forecast
    and in Scheduled but in no balance until confirmed. The same applies when an edit
    moves a posted transaction into the future.
12. **Editing happens in place, in the same row as adding.** Double-click a row (or
    select it and press Enter, or click Edit in the selection bar) and it becomes the
    entry row, filled in, with a memo line and the cursor in the cell that was clicked.
    A single click only selects, with no delay, because double-click is detected from
    two single clicks. Enter or Save keeps the changes, Esc cancels, and Undo restores
    the whole transaction. Clicking another row with unsaved changes doesn't discard
    them; it says how to save or cancel. Reconciled rows don't open, and a message says
    why.
13. **Plain-key shortcuts never steal typing.** Delete, C, Enter and Esc act on
    selected rows only while no text field has focus. Clicking a row takes focus out
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

## Consequences

- Desktop and mobile get separate layouts over one data layer
  ([ledger-features.md §J](../ledger-features.md)). These rules are written for desktop;
  mobile must honor 1–7 and 9–14 in its own form.
- A light theme is not planned. Midnight is a stance; revisit only if users ask.
- The 1440×900 window shows about five transactions under the header. Collapsing the
  header on scroll is an open idea, not a decision.
- Golden screenshot tests (`app/test/goldens/`) pin these rules visually. Update them
  only for intentional changes.
