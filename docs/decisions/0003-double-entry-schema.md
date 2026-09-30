# 0003 — Ledger schema: double-entry storage, categories as accounts

**Status:** Accepted
**Date:** 2026-09-16

## Context

The ledger has to handle splits, transfers between the user's own accounts, bank fees,
and eventually more than one currency. Two models were considered:

1. **Transaction + splits.** One row per transaction with an amount and a category, a
   separate splits table, and a linking mechanism to hold the two halves of a transfer
   together.
2. **Double-entry.** A transaction header plus two or more entry lines that must sum to
   zero, where categories are themselves accounts.

Real TDB statement data ([ADR 0002](0002-tdb-import-format.md)) informed the choice:
only 19 of 79 sample rows carried a counterparty account number, fees post as their own
rows alongside the principal, own-account transfers appear with the account holder's own
name as counterparty, and the export carries an FX rate column.

## Decision

**Double-entry as the storage model. The UI never exposes it.**

```
accounts      id, name, type, currency, ...
              type ∈ { asset, liability, income, expense, equity }

transactions  id, date, payee_id, memo, import_key, created_at, updated_at

entries       id, transaction_id, account_id, amount_minor, currency, rate, cleared
              └─ INVARIANT: SUM(amount_minor) per transaction = 0
```

- **Categories are accounts.** "Groceries" is an expense account; "Salary" is an income
  account. Money is never created or destroyed, only moved.
- **Every transaction balances to zero**, enforced at write time.
- **The entry form stays `date · payee · amount · category`.** The user never sees the
  words debit, credit, or entry, and never sees a zero-sum. The app writes the second
  leg silently.

### Why

- **Transfers stop being a special case.** An own-account transfer is an ordinary
  transaction whose two entries both hit asset accounts. There is no separate transfer
  table and no way for the two halves to drift apart.
- **Splits are just additional entries.** No splits table.
- **It is fewer tables than the alternative**, which needs transactions, splits, and
  transfer linkage.
- **Imbalance is structurally impossible**, rather than a bug to hunt.
- **One query shape serves every report.** Account balance, spending by category, income
  by month — all are "sum entries for these accounts over this date range."
- **The import gap disappears.** The 60 of 79 rows with no counterparty account are not a
  problem: the other side is the category, and an uncategorised row goes to `Unassigned`.
- **Multi-currency has a natural home** — `entries.currency` and `entries.rate`, which is
  exactly what the statement's `Ханш` column provides.

### Cost, accepted knowingly

More conceptual weight for whoever maintains the code, sign conventions to keep straight,
and every query joins `entries` to `transactions` rather than reading one table. This is
accepted in exchange for the correctness guarantees above.

## Consequences

- **`cleared` belongs on the entry, not the transaction.** A bank statement clears one
  *account's* side of a transaction. In a transfer between two accounts, each side clears
  independently when its own statement arrives — so reconciliation status cannot live on
  the transaction header.
- **Sign convention, fixed:** `amount_minor` is signed from the perspective of the account
  named on that entry. Money leaving an asset account is negative; the corresponding
  expense account entry is positive.
- **Every transaction has at least two entries.** A "simple" transaction has exactly two.
- **Zero-sum is enforced inside the same SQL transaction as the write** ([ADR 0001](0001-database.md)).
- **An account's running balance** is the ordered cumulative sum of its own entries.
- **Opening balances need an equity account** to balance against.
- **Import writes two entries per statement row** — one to the bank account, one to the
  rule-assigned category or `Unassigned`.

## Open items

- **The budget model is still undecided** — envelope-style (assign every tugrik to a
  category and watch it drain) versus target-style (set a limit, compare against actual).
  This model serves envelopes especially well, since envelope budgeting wants money to
  live somewhere, but the choice should be pressure-tested against this schema before the
  budget is built. Strict double-entry systems have a poor track record at envelope
  budgeting when the accounting is exposed to the user; keeping it hidden is what avoids
  that trap.
- **Multi-currency zero-sum semantics.** When a transaction spans currencies, the balance
  check must apply in a common currency. The rule needs defining before multi-currency
  ships.
- Whether payees are a table or a denormalised string.
