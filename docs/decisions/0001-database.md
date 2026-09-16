# 0001 — Local data store: SQLite via Drift, encrypted with SQLCipher

**Status:** Accepted
**Date:** 2026-09-16

## Context

BetterBudget is offline-only by rule: nothing leaves the user's machine, no telemetry,
no bank syncing, no update checks. Two consequences shape this decision more than
normal app-architecture taste would:

1. **There is no server copy.** If the local file is lost or corrupted, the data is
   gone. Durability and backup are product features, not infrastructure details.
2. **There is no update channel.** Users will run different versions indefinitely, so
   a file written by v1.0 must still open cleanly in v1.6 years later.

The domain is relational. Accounts → transactions → splits is one-to-many-to-many,
transfers are a self-referencing pair, and every report is an aggregation. The app
targets iOS, Android, Windows and macOS through Flutter. Launch market is Mongolia,
so amounts are large integers in MNT.

## Decision

- **SQLite** as the storage engine.
- **Drift** as the Dart access layer.
- **SQLCipher** for encryption at rest.
- Database key held in platform secure storage (Keychain / Keystore / DPAPI), with a
  **separate passphrase-derived key path for backups**.

### Why SQLite

- **ACID transactions.** A split must land completely or not at all; a transfer must
  create both legs or neither. A half-written split is books that silently don't
  balance — the strongest argument against any non-transactional store.
- **Relational queries.** Reporting is `GROUP BY`; running balance is a window
  function. In an object store this becomes hand-written Dart aggregation that is
  fine at 500 transactions and painful at 50,000.
- **File format longevity.** SQLite's maintainers commit to the format through 2050.
  With no server copy to rebuild from, that durability is a real feature. It also
  means the user can open their own budget file in any SQLite tool without us, which
  matches the anti-lock-in posture of the privacy rules.

### Why Drift

- Migration tooling with schema dumps and verification tests — load-bearing here (see
  Consequences).
- Compile-time-checked SQL and typed rows: schema mistakes surface at build time, not
  in a user's ledger.
- `watch()` returns streams, so the register updates reactively. That is most of the
  ledger UI plumbing.
- Single package covering all four targets. Plain `sqflite` needs `sqflite_common_ffi`
  glued on for desktop anyway.
- Raw SQL escape hatch remains available.

### Rejected alternatives

| Option | Why not |
| --- | --- |
| Realm | MongoDB deprecated the Atlas Device SDK. Dead end. |
| Isar | Maintenance went quiet and v4 fragmented into community forks. An uncertainly-maintained engine is the wrong risk for an app that cannot ship fixes. |
| Hive | Key-value. Fine for settings, wrong for a queryable ledger. |
| ObjectBox | Well-maintained and fast, but sync is its selling point and sync is forbidden here. Pays in query/reporting ergonomics for a feature we will never enable. |
| Raw `sqflite` | No desktop support on its own; no migration test harness. |

## Consequences

These are binding implementation constraints, not suggestions.

- **Money is `INTEGER` minor units, never `REAL`.** Store a per-currency exponent
  (**MNT = 2**, USD = 2). Floating-point cents is how a ledger ends up off by ₮1.

  > **Corrected 2026-09-16.** This originally said MNT = 0, on the assumption that
  > tögrög is effectively a zero-decimal currency since the möngö is obsolete. Real TDB
  > statement data disproves that: balances and transaction amounts carry two decimal
  > places, and 10 of 79 transactions in the sample had a non-zero fractional part.
  > Storing MNT at exponent 0 would silently round real bank data on import. See
  > [0002 — TDB statement import format](0002-tdb-import-format.md).
- **Two kinds of date.** A transaction's calendar date is `YYYY-MM-DD` `TEXT`.
  Created/modified timestamps are epoch millis `INTEGER`. Storing a calendar date as
  a timestamp shifts it a day across timezone changes, which Mongolia at UTC+8 will
  surface immediately.
- **WAL mode on; back up with `VACUUM INTO`.** WAL creates `-wal` and `-shm` sidecar
  files, which breaks "copy the one file" backup. `VACUUM INTO 'backup.db'` produces a
  consistent single-file snapshot while the app is running, keeping the user's backup
  something they can drop on a USB stick.
- **Forward-only migrations, every version gap tested.** Set up Drift's schema
  verification on day one. Because there is no update channel, a v1.0 file may need to
  jump six schema versions at once, and each path has to work.
- **Splits and transfers write inside a single SQL transaction.** No exceptions.
- **The backup key path is not optional.** If the DB key lives only in the platform
  secure store, a user who copies their file to a new machine has data that is intact
  and permanently unreadable. With no cloud copy, that is data loss.

## Open items

- **Verify SQLCipher on Windows before building on it.** Mobile and macOS are
  well-trodden; Windows needs a bundled compiled library and has historically been the
  rough edge. A throwaway spike opening an encrypted DB on all four targets is a cheap
  answer to an expensive-to-discover problem.
- **Attachment storage** (receipt photos as BLOB vs. on disk) is a separate decision.
  It affects whether the single-file backup story holds.
- **Double-entry vs. transaction + splits** is a separate decision. It does not change
  this one.
