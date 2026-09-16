# Where things stand

**Last updated: 2026-09-16**

Start here if you are picking this up cold.

## Phase

Pre-code. Per the README, the **ledger** is being talked through in full before anything
is built; the budget comes after. No Flutter project has been created yet.

## Settled

| ADR | Decision |
| --- | --- |
| [0001](decisions/0001-database.md) | SQLite via Drift, encrypted with SQLCipher. MNT is exponent 2. |
| [0002](decisions/0002-tdb-import-format.md) | TDB import targets the unformatted Excel export. Column map and dedup key recorded. |
| [0003](decisions/0003-double-entry-schema.md) | Double-entry storage, categories as accounts, accounting hidden from the UI. |

Ledger feature scope under discussion: [ledger-features.md](ledger-features.md).

## Open questions

Roughly in the order they will block something.

1. **Does TDB's internet banking offer CSV or modern `.xlsx` anywhere?** Both current
   exports are legacy BIFF `.xls`, which has no mature Dart reader — meaning we would
   have to write one. If a CSV or `.xlsx` option exists, that whole dependency
   disappears. **Check this before anyone starts the BIFF reader.**
2. **Budget model: envelopes or targets?** Envelope-style assigns every tögrög to a
   category and watches it drain; target-style sets a limit and compares against actual.
   The double-entry schema serves envelopes especially well. Blocks the budget, and
   should be pressure-tested against the schema first.
3. **Multi-currency at launch?** USD and CNY savings are common in Mongolia, and
   retrofitting is painful — it touches every balance and report, and with no network
   there are no rate lookups, only manual entry. Current lean: build the data model
   multi-currency-ready, ship the UI MNT-only.
4. **Verify the dedup key is stable across overlapping exports.** Confirmed unique
   *within* one statement period, not yet confirmed stable *across* periods — which is
   the property the importer actually depends on. Two deliberately overlapping TDB
   exports (e.g. Sep 1–10 and Sep 5–20) would settle it.
5. **Which other banks must import at launch?** Khan, Golomt, Khas, State Bank, M Bank
   are candidates. Real or redacted sample exports shape this far better than guessing.
   ADR 0002 is the template to repeat per bank.
6. **v1 scope.** Proposed first slice: accounts, transactions, splits, transfers, the
   register, manual entry, reconcile. Import, rules and attachments second — both still
   before the budget.
7. **Cash-heavy or card-heavy users?** Decides whether wallet-count reconciliation is
   core or a nice-to-have.
8. **Does BetterBudget get its own wordmark?** `assets/logo/` holds the Loveland
   Solutions company mark, not a product mark.

## Next step

The **desktop register layout**. The schema is settled enough to draw against, and the
register is where the README's "polished and professional" bar actually lands. Specific
things to work through: which columns earn their place when running balance, cleared
state, counterparty and description all compete for room at 7–8 digit MNT amounts; how
the desktop grid and mobile list diverge; and what the import preview looks like, since
that is where the dedup and balance-chain checks surface to the user.

## Local setup notes

- `tdb-bank-transaction-exports/` holds **real, unredacted** TDB statements used for
  format analysis. It is gitignored and must stay that way. Anything committed as a test
  fixture must be redacted: real headers, real date format, real Cyrillic payee strings,
  scrubbed account numbers, synthetic amounts.
- Reading legacy `.xls` during analysis needs `xlrd` in a throwaway venv; there is no
  project toolchain yet.
