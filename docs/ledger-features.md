# Ledger — feature scope

**Status: working map.** A first desktop ledger is built (see [STATUS.md](STATUS.md)).
Settled items graduate to [docs/decisions](decisions/); UI rules are in
[ADR 0004](decisions/0004-ledger-ui.md), which wins wherever this file and it differ.

### Built so far (2026-09-16)

| Section | State |
| --- | --- |
| A. Core record | Built: double-entry, integer minor units, soft delete, transfers. Splits are displayed but can't be created yet. No tags or attachments. |
| B. Manual entry | Built: keyboard-first any-order row, payee autocomplete with last category, calculator. Not yet: templates, recurring, duplicate-last, mobile keypad. |
| C. Import | Built (ADR 0002 "Any bank's file", ADR 0004 "Import"): `.xls`, `.xlsx`, CSV, columns per account, preview, dedup, undo. Rules not yet. |
| D. Register | Built: running balance, filters and search, inline category edit, an action bar under the clicked row (multi-select removed for now), cleared/reconciled symbols, working/cleared/reconciled header. **Changed:** no month grouping or subtotals (ADR 0004). Editing opens the row in place with all fields (ADR 0004 rule 12). Not yet: sorting by column (roadmap). |
| E. Reconciliation | Built: reconcile against a statement date and balance in the header, lock only at zero, locking (no edit, clear or delete, on either side of a transfer), take back the newest reconcile any time (ADR 0004 rule 16). Not yet: adjustment when it won't match, cash wallet count. |
| F. Payees, categories, rules | Payees table only. No merge, category tree or rules. |
| G. Search | Basic search across payee, memo, category and amount, current account only. Full search is on the roadmap. |
| H. Safety | Session undo and redo (⌘Z / ⌘⇧Z) for every ledger action, including reconcile. No encryption, app lock, backup or export. |
| I. Localisation | Cyrillic renders (fonts checked for ₮, Ө, Ү); YYYY.MM.DD dates. UI strings are English only. |
| J. Cross-platform | Desktop (macOS) only so far. |

---

## A. The core record

- **Transaction fields:** date, account, payee, category, amount, memo, cleared status,
  tags, attachments, plus created/modified timestamps.
- **Splits.** One transaction, many category lines. Non-negotiable — a market run is
  groceries plus household plus a SIM top-up on one receipt.
- **Transfers.** Account-to-account as a single linked unit, not two rows that can drift.
- **Amounts** as integer minor units with a per-currency exponent. MNT is exponent 2
  (see [ADR 0001](decisions/0001-database.md)). MNT amounts run to 7–8 digits — a salary
  is ₮2,500,000, a coffee ₮8,000 — so column widths, keypad entry and chart axes must
  assume that, not four digits.
- **Soft delete.** Nothing truly disappears until purged. Makes undo trivial.

Storage model is settled: double-entry, categories as accounts
([ADR 0003](decisions/0003-double-entry-schema.md)).

## B. Manual entry

With no bank syncing, manual entry is a primary input path. It has to be genuinely fast
or the app dies in week three.

- Keypad-first on mobile; keyboard-first row entry on desktop (tab across, Enter commits,
  never touch the mouse).
- Payee autocomplete from history with last-used category pre-filled, so most entries
  become: amount, three letters of the payee, Enter.
- Quick-add from a recent/frequent payee list.
- Templates and recurring/scheduled transactions (rent, salary, loan payment) that land
  as *pending* for confirmation, never silently posted.
- Calculator in the amount field (`12000+8500`).
- Duplicate-last-transaction.

## C. Import

- **CSV + XLSX**, plus legacy `.xls` for TDB (see [ADR 0002](decisions/0002-tdb-import-format.md)).
- **Saved mapping profiles per bank.** Map once, remembered forever.
- **Encoding and date landmines:** non-UTF-8 Cyrillic, and `YYYY.MM.DD` which is standard
  in Mongolia and will silently misparse if ISO or US order is assumed.
- Debit/credit in separate columns *and* single-signed-column layouts both exist.
- **Deduplication** with a visible "N skipped as duplicates" report, never a silent drop.
- **Preview before commit. Always.** No import writes without the user seeing what lands.
- Undo an entire import as one action.

## D. The register

This is where "polished and professional" gets tested.

- Checkbook-register layout: dense rows, tabular figures (critical at 7 digits), running
  balance column.
- Sort by any column; filter bar always present. **On the roadmap**, see
  [ROADMAP.md](ROADMAP.md#sorting).
- Inline editing — click the cell, change it, move on. No modal for a typo.
- Multi-select with bulk edit (recategorise 40 rows at once) and bulk delete.
- ~~Group/collapse by month with subtotals.~~ Dropped at the owner's request: every row
  shows its full date instead (ADR 0004).
- Distinct visual states for uncleared / cleared / reconciled, and for pending or
  future-dated rows, which are excluded from the cleared balance.
- Compact glyphs for attachment, split, and transfer.
- Account header showing working, cleared and reconciled balances at once — they are
  different numbers and that difference is the point.

## E. Reconciliation

- Statement-based flow: enter closing balance and date, tick rows, watch the difference
  count down to zero.
- Lock reconciled transactions against casual editing.
- **Cash reconcile** — count the wallet, enter it, app offers an adjustment. A meaningful
  share of spending in Mongolia is cash, so cash accounts are first-class.

Note: `cleared` lives on the entry, not the transaction — each side of a transfer clears
when its own statement arrives ([ADR 0003](decisions/0003-double-entry-schema.md)).

## F. Payees, categories, rules

- Payee list with one-click merge. Real data will produce "Nomin", "Nomin Supermarket"
  and "НОМИН" as three payees.
- Category tree, at least two levels, renameable without orphaning history.
- **Rules engine:** if payee contains X → category Y, optionally rename to a clean display
  name. Purely local and deterministic. No ML, no cloud, no surprises. Rules run on import
  and on manual entry, are visible and reorderable, and you can see which rule fired.
- TDB descriptions carry minable structure: QPay references, POS terminal IDs, masked card
  numbers, embedded fee notes.

## G. Search

**On the roadmap.** Scope and open design questions are in
[ROADMAP.md](ROADMAP.md#search).

- Instant full-text across payee, memo, amount and notes. Cyrillic-aware.
- Structured filters: date range, amount range, account, category, cleared status, tag,
  has-attachment.
- Saved filters and views.

## H. Safety

Downstream of the unbreakable rules: if data lives only on their machine, we are the only
thing between the user and total loss.

- Undo stack for destructive actions.
- Encrypted at rest, plus app lock (biometric/PIN).
- **Backup and restore the user controls** — export the whole file anywhere they like.
  This is the escape hatch that makes local-only survivable.
- Full CSV export so they are never hostage to our format.
- Attachments inside the encrypted store, not loose on disk.

## I. Mongolia and localisation

- **Mongolian Cyrillic and English**, switchable, with a font that renders Cyrillic
  correctly on all platforms — Flutter's default will not.
- ₮ placement, locale thousands separators, `YYYY.MM.DD` display.
- Localised category names shipped as defaults, not English categories translated later.
- Traditional Mongolian script: explicitly deferred. Vertical-script rendering would
  derail the ledger.

## J. Cross-platform shape

Flutter across iOS, Android, Windows and macOS means **two real layouts over one data
layer**: a dense multi-column register with keyboard navigation on desktop, and a
scannable list with a thumb-reachable entry sheet on mobile. One "responsive" screen for
both is the usual trap — the desktop register ends up finger-sized and the mobile list
unreadable.

---

## Consequences of the unbreakable rules

**"No checking for updates"** means there is no channel to push a fix. If v1.0 ships with
an importer bug that miscategorises a month of data, that user keeps the bug until they
happen to redownload. The rule is right, but it raises the bar on correctness at ship and
argues hard for the import preview and undo-entire-import.

**"Nothing ever leaves their machine"** can be made *verifiable* rather than merely
promised: ship with no network permission declared on any platform. The OS then enforces
the claim and a sceptical user can confirm it. It also means no crash reporting — a
local-only, user-readable error log they may choose to send is the substitute.

**"I need to see its development"** is satisfied by the repo and test data, not by
anything in a shipped build. Stated explicitly so no telemetry is ever rationalised in as
"just for development."

---

## Brand palette

Measured from the pixels of `assets/logo/logo-english.png` (2026-09-16). How the app
adapts these for the dark Midnight theme is in [ADR 0004](decisions/0004-ledger-ui.md).
The logos are the Loveland Solutions company mark, not a BetterBudget product
mark.

| Role | Hex | Use |
| --- | --- | --- |
| Deep navy | `#03173E` | primary, text, chrome |
| Royal blue | `#0342B2` | accent, interactive, links |
| Gold | `#C9A96B` | sparing highlight, attention states |
| Slate grey | `#707784` | rules, dividers, secondary text |

Conservative and bank-like, which suits a ledger — it should read as a financial
instrument. There is no red or green in the mark, so a restrained pair needs adding for
debit/credit rather than overloading gold to mean "negative."
