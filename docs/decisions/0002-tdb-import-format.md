# 0002 — TDB statement import: target the unformatted Excel export

**Status:** Accepted
**Date:** 2026-09-16

## Context

BetterBudget never connects to a bank, so statement import is one of only two ways
data enters the ledger. That makes the choice of source file a product decision, not
just a parsing detail.

TDB (Trade and Development Bank) currently offers account holders three export options
for the same statement. A sample covering one account for 2026.09.01–2026.09.15 was
analysed; all three files contained **the same 79 transactions and identical totals**.
Only the packaging differs.

| Export | Shape | Sample |
| --- | --- | --- |
| **Форматгүй excel файлаар татах** ("download as unformatted Excel") | Dense: one row per transaction, 9 columns, no padding | 82 rows |
| Formatted Excel | Print layout: merged cells, 30 columns, blank spacer rows, paginated | 155 rows, 68 blank |
| PDF | Printed statement, 3 pages | — |

## Decision

- **Steer TDB users to "Форматгүй excel файлаар татах."** This is the primary supported
  path and what in-app guidance should name, verbatim, in Mongolian.
- **Also accept the formatted Excel export.** Same parser, different column map. A user
  who clicked the wrong button should not get "unsupported file" as their first
  experience of the app.
- **Do not build a PDF import path for v1.**

### Why the unformatted export

- **Dates are real Excel serial values, not text.** This is the decisive factor. The PDF
  renders the same timestamp as `2026.9.1 2:49:04AM` — unpadded month and day, 12-hour
  clock with AM/PM. The serial date removes date-format ambiguity entirely, which is the
  single largest source of silent import corruption.
- **Separate credit/debit columns**, zero-filled, so signed amount is `credit − debit`
  with no sign convention to infer.
- **A running balance column**, plus opening/closing balances and a totals footer. This
  gives a free exact integrity check (see Consequences).

### Why not the formatted export

Its only advantage is splitting the counterparty account number and name into separate
cells, where the unformatted export concatenates them. That split is fully recoverable:

> **Rule:** if the field begins with whitespace there is no account number and the whole
> field is the counterparty name. Otherwise the first whitespace-delimited token is the
> account identifier and the remainder is the name.

Validated against the formatted export as ground truth: **79/79 exact matches**,
including an IBAN-format counterparty (`MN70…`) and an account with no name. The
formatted export therefore costs 21 extra columns and 68 blank rows to convey nothing
that cannot be derived.

### Why not the PDF

Long fields wrap across multiple physical lines, so rows are not rows; columns are
positional rather than structural; and timestamps are locale-ambiguous text. It is a
good archival record for a human and the worst available machine input.

## Column map — unformatted export

Row 0 holds nine labelled metadata fields (customer, account number and currency,
period, opening/closing/available balance). Transaction rows follow. The final two rows
are a `Нийт:` totals footer and a `Хуудас:` page footer, both of which must be skipped.

| Col | Header | Type | Notes |
| --- | --- | --- | --- |
| 0 | Огноо | Excel serial datetime | datemode 0 (1900 system); carries time |
| 1 | Теллер | text | teller/channel code, e.g. `100 - 10` (invented) |
| 2 | Орлого | number | credit in; `0.0` when unused |
| 3 | Зарлага | number | debit out; `0.0` when unused |
| 4 | Ханш | number | FX rate; `1.0` throughout an MNT account |
| 5 | Харьцсан данс | text | counterparty; split per the rule above |
| 6 | Үлдэгдэл | number | running balance after this transaction |
| 7 | Гүйлгээний утга | text | description |
| 8 | — | — | unused |

Formatted export, for the fallback path: header row at index 10, data rows interleaved
with blanks, same fields at columns 0, 4, 7, 11, 16, 21 (counterparty account), 23
(counterparty name), 26, 28.

## Consequences

- **Use the bank's own running balance as an import integrity check.** Opening balance
  plus credits minus debits must land exactly on the stated closing balance, and the
  per-row balance chain must reconcile. Verified on the sample: exact match, zero drift
  across all 79 rows. If our arithmetic disagrees with the bank's, we have mis-parsed —
  and we know it before showing the user a number. ~~This check should block the import
  preview from committing.~~ Under the owner's "warn, don't block" (2026-09-18) it is a
  big warning naming the row and both amounts; the import can still go ahead.
- **MNT must be stored at exponent 2.** TDB reports tugrik to two decimal places. This
  corrects [ADR 0001](0001-database.md).
- **A legacy BIFF reader is required, and this is unscoped work.** Both exports are
  OLE2/BIFF compound documents produced by Crystal Reports — the old binary `.xls`
  format, not the modern zipped XML `.xlsx`. The Dart `excel` and `spreadsheet_decoder`
  packages read `.xlsx` only. **There is no mature Dart reader for legacy `.xls`**, so we
  must write a focused one. Tractable — a handful of record types (SST, LABELSST, NUMBER,
  RK, MULRK, DATEMODE) and we already know column 0 is a date — but it is a hard
  dependency for TDB import and was not in the original estimate.
- **Counterparty data is sparse.** Only 19 of 79 sample rows carried a counterparty
  account number; 5 had no counterparty at all. Payee identification cannot rely on it
  and must fall back to the description field.
- **Descriptions carry structured content worth mining** for the rules engine: QPay
  references, POS terminal identifiers, bank-masked card numbers (`4000XXXXXXXX0000`, invented),
  and embedded fee notes (`CHARGE: <amount> ₮`). Fees generally also arrive as their own
  separate transactions.
- **Own-account transfers are identifiable** — the account holder's own name appears as
  the counterparty — which feeds transfer auto-matching.
- **Imported transactions come in cleared** (owner's call, 2026-09-17). A bank
  statement lists what the bank has settled, so every imported row is cleared, never
  uncleared. Reconciled stays a separate, deliberate step. When an imported row matches
  one the user already typed in (still uncleared), the match should mark that row
  cleared rather than add a duplicate; how rows are matched is not designed yet.

## Deduplication key

**TDB supplies no transaction identifier.** Verified against the sample: the 9th column
of the unformatted export is empty on all 79 rows, and the descriptions yield nothing
usable either — 18 of 79 rows contain no long numeric token at all, and the tokens that
do appear repeat across rows (QPay references, phone numbers, terminal IDs). The
`NNNNNNNN:` prefix on POS rows is a merchant/terminal ID, not a transaction ID: 48 rows,
26 distinct values.

The key must therefore be synthesised from content:

> **Dedup key:** `(account_number, timestamp, credit, debit, running_balance)`

Unique across all 79 sample rows. Each component earns its place:

- **Timestamp alone is not enough** — 3 collisions in 15 days. Every one is a transfer
  posting in the same second as its own fees, which is routine rather than exceptional.
- **Amount separates those**, since the fees differ from the principal.
- **Running balance encodes sequence position**, separating even identical amounts in the
  same second. It is an *absolute* account state, so the same transaction yields the same
  balance regardless of which statement period it was exported in — which is precisely
  what a row number or file offset could never give us.
- **Balance alone must not be used.** It was unique in the sample, but a balance can
  return to a previous value (spend ₮10,000, get refunded ₮10,000). Fifteen days did not
  surface that; a year will.

### The failure mode that matters

Two opposite failures are possible, and they are not equally likely.

*Two different transactions colliding on one key* (wrongly skipping a real transaction)
is negligible. It requires the account to return to an exact prior balance **and** both
transactions to post in the same second with the same amount. No mitigation warranted.

*One transaction producing two different keys across exports* (importing it twice) is the
real risk, and timestamp precision does nothing to help. If TDB reverses or restates a
transaction mid-period, every balance below it shifts, every downstream key changes, and
a re-import presents them all as new. This is inherent to any content-derived key.

**Mitigation — overlap reconciliation.** The export header states the statement period,
so we always know when an incoming file overlaps an already-imported range. Over that
overlap we should expect a near-total key match. A low match rate means the balance chain
moved, and the import must stop and say so rather than silently duplicating. The
balance-chain check above catches the same condition within a single file.

**Standing rule:** deduplication results always surface in the import preview
("63 new, 16 already imported"). Never a silent drop. A synthesised key will eventually be
wrong, so the user must be able to see the decision and override it.

## Any bank's file (owner, 2026-09-30)

The owner asked for import that works for any bank, not TDB only: the person matches
the file's columns once per account, and the app remembers. The screen is in
[ADR 0004](0004-ledger-ui.md), "Import".

- **Every file becomes a grid of cells** (`app/lib/import/`): a BIFF8 `.xls` reader
  written for this (OLE2 container, SST with CONTINUE, LABELSST, LABEL, NUMBER, RK,
  MULRK, FORMULA results, dates by XF number format), `.xlsx` (zip and XML), and
  CSV (comma, semicolon, tab or bar; UTF-8, UTF-16 with a byte-order mark, or
  Windows-1251). The mapping only sees cells, never the file.
- **Columns, not banks.** A mapping names the date, amount (one signed column or money in and out),
  payee, memo and bank's balance by column. Rows whose date cell isn't a date are left
  out and counted, which drops headings, `Нийт:` and `Хуудас:` footers and blank spacer
  rows without a per-bank rule. Files listed newest first are turned around.
- **Guessing:** the date column is the one with the most dates; the header row is the
  nearest row above the first transaction holding only short text without figures
  (TDB's plain export has none, its metadata row has account numbers in it). Named
  columns are matched by the banks' words (Орлого, Зарлага, Үлдэгдэл, Гүйлгээний утга,
  Харьцсан данс, and English equivalents). A print-layout name a column or two from its
  figures goes to the nearest column with data. Otherwise, the amount and balance come
  from the number columns whose running balance adds up on the most rows, in
  either order. A column that often starts with an account number is the payee. When
  the counterparty's name sits in an unnamed column beside the account numbers, the name
  column is the payee. The longest remaining words are the memo.
- **Payee:** the counterparty without the account number in front (the rule above,
  widened to any first token of six or more digits, or an IBAN). With no
  counterparty, the description is the payee and there's no memo.
- **Remembered per account** in preferences (`import.mapping.<account id>`), with the
  file's shape: the header names when there is a header row, otherwise what each
  column mostly holds (`DTNNNTNT.` for TDB's plain export). A file of the same shape
  uses the saved columns.
- **Keys are on entries** (schema v8, `entries.import_key` with a unique index; SQLite
  can't add a unique column), so each side of a transfer matches its own bank's file.
  The old `transactions.import_key` is unused.
- **Card files** that show what's owed as a positive balance: when the chain adds up
  with the balances turned around, they're read that way.
- **Dedup key, any bank:** `a<account>|<date, with time when the file has it>|<amount>|<balance>`.
  Without a balance column: `…|<amount>|<payee>|<memo>`. Rows alike in one file get
  `#2`, `#3` in file order. Keys on deleted rows still count, so a row the user deleted
  stays deleted on the next import. Undoing an import frees its keys.
- **Matching typed rows:** a bank row matches a row on the same account (any state,
  so a reconciled one isn't brought in twice; it only takes the key) that has no key, isn't scheduled and has exactly the same
  amount, dated from 3 days after to 10 days before the bank's date. The closest date
  wins, and each typed row matches at most once. The match keeps the user's
  payee, category and date (the bank's date when it's in another month, owner
  2026-09-30), takes the key, and becomes cleared. Scheduled rows (bills,
  paydays) aren't matched yet.
- **Checked on the owner's real files (2026-09-30):** the plain and the formatted TDB
  export give identical rows, keys, payees and memos (79 of 79), both with an exact
  balance chain. Two different exports shared all 78 overlapping keys, the first
  evidence that the key is stable across overlapping exports.

## Open items

- ~~Check whether TDB's internet banking offers CSV or modern `.xlsx` anywhere.~~ Moot:
  the BIFF reader is built (2026-09-30).
- **Verify key stability across overlapping exports.** Two of the owner's exports
  shared all 78 overlapping keys (2026-09-30). Two deliberately overlapping periods
  (e.g. Sep 1–10 and Sep 5–20) would settle it for good.
- ~~Equivalent format analysis for the other launch-relevant banks.~~ The column
  mapping reads them without it; a real Khan or Golomt file is still worth a test.
- Sample data in this repo must be redacted fixtures, never real statements. See
  `.gitignore`.
