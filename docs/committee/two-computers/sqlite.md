# The database angle

## (a) Is the session extension in the build this app links? Yes, on every platform, and Dart exposes it.

**How the library is obtained.** `app/pubspec.yaml` sets `hooks: user_defines:
sqlite3: source: sqlite3mc`. In
`~/.pub-cache/hosted/pub.dev/sqlite3-3.5.2/lib/src/hook/compile/description.dart`
(`SqliteBinary.forBuild`, lines 29–34) that picks
`PrecompiledFromGithubAssets(LibraryType.sqlite3mc)`: a prebuilt library
downloaded at build time from `github.com/simolus3/sqlite3.dart/releases` (line
~58). It is not compiled on this Mac, so the package's define list is only
indirect evidence; it does include `SQLITE_ENABLE_SESSION` and
`SQLITE_ENABLE_PREUPDATE_HOOK` (`_defaultDefines`, lines ~500–527, "keep in sync
with tool/compile_sqlite.dart").

**The binaries settle it.** `strings` on
`app/build/native_assets/macos/libsqlite3mc.dylib` and on the framework inside
`app/build/macos/Build/Products/Release/BetterBudget.app/Contents/Frameworks/sqlite3mc.framework`
both list the compile options `ENABLE_SESSION` and `ENABLE_PREUPDATE_HOOK`
(SQLite 3.53.4, SQLite3 Multiple Ciphers 2.5.0). `nm -gU` shows 44 exported
session symbols, among them `sqlite3session_create`, `sqlite3session_diff`,
`sqlite3changeset_apply_v2`, `sqlite3changegroup_add`, `sqlite3_preupdate_hook`.
The Android `libsqlite3mc.so` (arm64-v8a) and the iOS `sqlite3mc.framework` under
`app/build/` carry the same two options. The Linux linker allow-list
(`lib/src/hook/compile/used_symbols.dart`) keeps 17 session symbols, so a Linux
build would not hide them. `sqlite3_flutter_libs 0.6.0+eol` and
`sqlcipher_flutter_libs 0.7.0+eol` are in `pubspec.lock` only as end-of-life
shims; nothing in `app/macos/` links SQLite separately.

**Dart API.** `package:sqlite3` exports `Session`, `Changeset`, `Patchset`
(`lib/common.dart` → `lib/src/session.dart`): `Session(db)`, `attach()`,
`changeset()`, `patchset()`, `diff(fromDb, table)`, `Changeset.fromBytes`,
`-changeset`, `applyTo(db, ApplyChangesetOptions(filter:, onConflict:))`, and
iteration as `ChangesetOperation(table, operation, oldValues, newValues)`.
Runtime guard: `sqlite3.usedCompileOption('ENABLE_SESSION')`. All 12 ledger
tables have declared primary keys (8 `INTEGER PRIMARY KEY AUTOINCREMENT`, 4
explicit, per `database.g.dart`), which sessions require.

**Three limits that shape the design.**
1. `ApplyChangesetOptions.onConflict` is one enum (abort / replace / omit)
   applied to every conflict (`lib/src/implementation/session.dart` ~line 137),
   not a per-conflict callback. "Ask the person about this row" cannot go through
   `applyTo`; you would iterate the changeset yourself and apply with your own
   rules.
2. `drift_flutter 0.3.1` opens the connection with
   `NativeDatabase.createBackgroundConnection` (`lib/src/native.dart` ~line 130).
   A `Session` on the live connection would live in that background isolate
   (`DriftNativeOptions.setup` runs there); the main isolate can't call
   `changeset()` on it without extra plumbing.
3. Raw changesets are positional: table name, column count, PK flags, values by
   index, no column names. The owner's file was upgraded with `ALTER TABLE ADD
   COLUMN` (`_addColumnOnce`), a fresh file has Drift's declared order, and
   `replaceAllFrom` copies by name into whatever order the local file has;
   `ledger_seal.dart` line 19 already notes the orders differ. A raw changeset
   from one applied to the other would put values in the wrong columns silently.
   So: either a one-time canonical-order rebuild of every table on every
   computer, or a name-keyed log. I recommend the latter below.

## (b) The design I'd recommend

**One line.** The owner's instinct is right: the database should record what
changed instead of the app inferring it from three whole files. But the lock
file isn't what makes it safe; "one writer per file" is. What is built today
already *is* the master/child model minus the lock. The step up: record every
change in the ledger with old and new values; each computer publishes its own
log to the folder in a file only it writes (exactly as the phones do); every
computer applies the others' logs; `Ledger.betterbudget` becomes a derived
snapshot. That removes the contended file, the agreed-base file
(`cloud-folder-agreed`), and the no-base fallback.

### 1. Concretely

**In the ledger (schema v20; upgrade keeps every row, with a test):**
- `changes(seq, computer, tbl, pk, op, old JSON, new JSON, at, schema)`, one row
  per row-change, name-keyed (JSON1 is built in).
- Preferences `sync.applied` = `{computerId: seq}` (the version vector; today's
  `sync.computers` counters become this), `sync.applying` (flag), `ledger.id`.
- 36 triggers (AFTER INSERT/UPDATE/DELETE on 12 tables), `WHEN sync.applying IS
  NOT '1'`, writing `json_object(...)` of all columns, generated from Drift's
  table info. A test asserts every table in `allTables` has three and is in
  `combine.dart`'s `_keys`. Triggers rather than a `Session` for capture because
  they are name-keyed, commit inside the same SQL transaction as the write, see
  raw SQL, need no isolate plumbing, and live in the encrypted file so backups
  and snapshots carry them. Use the session extension where it is unbeatable:
  `Session.diff` to compute what a Restore changes, and in tests to prove two
  files identical.

**In the folder:**
- `Ledger.betterbudget`: the snapshot as today, plus a 30-day tail of `changes`
  and `sync.applied`. Written only by a computer whose vector is ≥ the
  snapshot's, 5 s after quiet. Phones unchanged.
- `Computer <id>.betterbudget-changes`: one per computer, encrypted SQLite like
  the phone file, rewritten whole only by its owner: a header (its applied
  vector, schema, ledger id) and its `changes` rows since the lowest
  `applied[me]` any other known computer has reported. One writer per file means
  Drive never makes a "(1)" copy of it and no lock is needed.

**Locally:** the ledger (full `changes`) and the computer id in `cloud-folder`.
Nothing else.

**The cycle** (replaces `CloudFolder._sync`; same triggers: launch, before a
write, foreground, 15 s, one at a time):
1. Copy out each other computer's file whose mtime/size moved (`_read` as now).
   Unreadable (torn copy) → "arriving", retry.
2. Take rows with `seq > applied[them]` in order. If the file's header says it
   depends on records I lack (`their applied[X] > my applied[X]`), hold the whole
   file until they arrive: causal order, so a change never names a row that
   hasn't come.
3. Apply in one SQL transaction (the shape of `applyCombined`):
   `sync.applying=1`, `defer_foreign_keys=ON`, parents first / children last by
   `combineOrder`, then `foreign_key_check` and `unbalancedSql`; any failure,
   nothing changes and the batch is held. Per row: current == old → apply;
   current == new → nothing; else a conflict (§2). Advance `applied[them]`.
4. My `changes` has rows beyond my folder file → rewrite it.
5. My vector > the snapshot's → write the snapshot (`_put`; the seal stays as a
   tamper check).

**Zero-sum and foreign keys, out of order.** `sqlite3changeset_apply` would apply
in recorded order, not parent-first, so SQLite itself says to defer FKs and
report violations at the end; our own apply does the same, which `applyCombined`
already does. Across computers there is no total order, only per-computer order
plus the causal wait above; never apply half a batch. A file holds only committed
rows, so a batch never splits a transaction's entries. Two balanced edits to
different entries of one transaction can union to an unbalanced one: that is why
the transaction stays the unit of asking and `unbalancedSql` runs after every
apply.

**Drive slow / offline a day / two copies.** Nothing waits on Drive: each side
writes only its own file and applies whatever has arrived, so conflicts can only
be between changes that truly crossed. A laptop offline a day uploads its file on
return; nobody depended on records they never saw, so nothing stalls.
Per-computer files can't get a conflict copy; a `Ledger (1).betterbudget` is
harmless (derived) and is deleted when its vector ≤ the snapshot's. A computer
that finds its own id in a file it didn't write (cloned disk) re-ids itself and
says so.

**Asked on both.** Both computers receive each other's change, so a crossed edit
would be asked on both. Rule: an answer is logged (`op='decide'`, unit, choice);
a computer receiving one for a question still open withdraws it ("The Mac
already chose"); if both answered before seeing the other's, the lower computer
id's stands and the other is told, with Show. In practice one person answers.

### 2. Conflict classes

`combine.dart`'s per-column merge (`_table`, `_byColumn`), the unit machinery
(`_Unit`, `_freeze`, `_resolve`, `_describe`), the "what must still hold" checks
and `rows_dialog.dart` survive; `base` becomes the old values in the log.

- **Same transaction edited both** → different header columns merge; amounts or
  rewritten entries → the existing card (mine / theirs / as it was). Nothing of
  the unit applied until answered; sums checked after.
- **Deleted one side, edited other** → a delete is `deleted_at`, a column
  conflict → the card. Safe: "theirs" loses nothing, the row is only marked.
- **Same bank row imported both, filed differently** → `import_key` is UNIQUE;
  the row with the earlier id (ids are time-ordered, `newRowId`) is kept on
  *both* computers, so they converge without a word; filed differently → a new
  card ("Nomin ₮45,000, 3 Oct: Groceries here, Eating out on the laptop"). One
  row either way.
- **Pay or plan edited both** → new unit kinds (pay, plan) with both versions;
  waiting paydays and bills regenerated (`_staleScheduled` stays). Not money
  until confirmed.
- **Account renamed both** → account unit, both names, "as it was".
- **Same category assigned both, same period** → `_budgetAmounts`'
  sum-by-(category, day) unit stays an ask; two inserts must not be summed as if
  both were meant.
- **Reconciled on one, row inside edited on the other** → the lock wins on the
  reconciler automatically (the edit is held, not applied, not lost); the editor
  is asked once the reconciliation arrives: keep the reconciled amount (default)
  or keep mine and un-reconcile, their own act, logged, applied cleanly
  elsewhere. A new cleared row dated inside the statement arrives uncleared, with
  a note. Both rules deterministic, so both computers end the same.
- **Both confirm the same payday** → give app-made scheduled rows a deterministic
  id (hash of schedule id + date, in a reserved id range) so both computers hold
  one row; two confirmations are two updates of it: same → no-op, different
  amounts → the transaction card. `_sameScheduled` stays as the dedupe for rows
  made before.
- **Restore / erase** → Restore: the difference against the attached backup is
  computed with `Session.diff` inside one transaction, so it is logged as one
  batch; the restoring computer is told what it will also undo elsewhere ("the
  laptop's 23 rows since Monday"), warn-don't-block; rows the other side changed
  since → cards. Erase and start over gives a new `ledger.id`; computers never
  merge across ids: "The Mac started a new ledger: open it / keep this one".

### 3. Failure modes, ranked

1. **A write that escapes the triggers** (a new table without them, another
   tool, an older build) → silent divergence. Guard: when two vectors are equal
   their digests must be equal (`ledger_seal.dart` stays); if not, red line and
   the old three-way compare as the fallback, asked about.
2. **Rules that aren't symmetric** (A and B compute different results from the
   same two logs) → divergence that looks fine. Guard: property tests `apply(A,
   logB) == apply(B, logA)` over random histories, equality proved by
   `Session.diff` returning nothing.
3. **A dependency that never arrives** (a file deleted from Drive) → a batch held
   forever. Guard: any computer holding those records (they are in its
   `changes`) republishes them; the snapshot carries the tail.
4. **Echo** if `sync.applying` is mishandled → changes re-logged as mine. Guard:
   set and cleared inside the one transaction; a test.
5. **Snapshot size** (phones download it whole): keep only a 30-day tail in the
   snapshot (`VACUUM INTO`, then prune in the copy).
6. **Schema skew**: rows carry `schema`; a newer one is held and the snapshot not
   overwritten (as `newerApp` today).
7. **Both answered differently** → id tiebreak; rare and visible.

### 4. Cost

- Schema v20: `changes`, triggers, three preferences. No column rebuild; the
  owner's rows untouched; upgrade test with a v19 file. `ledger.id` is adopted
  from the folder when a computer's rows equal the snapshot's (as `adoptSeal`
  does), never invented twice.
- Folder: one new file per computer; phones ignore it (`isPhoneInboxName`) and
  keep reading `Ledger.betterbudget`. Phone apps unchanged.
- Transition: both computers must be on v20 (the schema gate enforces it); the
  first meeting after upgrading uses today's path once, then logs. Remove the old
  path a release later.
- 4–6 weeks for one developer: week 1 table, triggers, upgrade, tests; week 2 the
  folder cycle (`cloud_folder.dart` about 60% new), vector and causal apply,
  snapshot rules; week 3 port `combine.dart` to (old, new, current) and the five
  new card kinds; week 4 convergence tests and two Mac accounts on real Drive;
  buffer.
- Survives: `sync.dart` (`compareCounters`, `newRowId`), most of `combine.dart`,
  `applyCombined`, `rows_dialog.dart`, `ledger_seal.dart`, all phone code,
  `Backups`. Goes: `cloud-folder-agreed`, `_combinable`'s base reads,
  `keepMine`/`undoKeepMine` and the whole-ledger question (kept only as the bug
  fallback), `_writingMark`/`expected`-stat races, `theirsIsMyOldWrite`.

A smaller step exists: keep the single file and only add the `changes` log
inside it, so merging needs no agreed base. It fixes restore/no-base and
precision, and keeps the write race and the "(1)" copies. I would not stop there.

### 5. The owner's proposal, frankly

**Right in it:** a local working copy (that is `openEncrypted` plus the folder
file already); check before you write (`decideFolderMove`); on a timer and at
close (15 s and `flush`); "if something wrote, check for conflicts" row by row
(`combine`). Step 2, "load master into child", is `Backups.restore(fromFolder:)`
/ `replaceAllFrom`.

**What breaks:** the lock. Drive has no cross-machine atomic create: each Mac
creates `lock` locally and succeeds, and the two meet in the cloud seconds to
minutes later as `lock` and `lock (1)`, after both have written. A lock held by a
laptop that shut or went offline needs an expiry, which means a clock, which this
design has kept out on purpose. At best a lock is a hint that shortens the
window; it can never be what correctness rests on. And a "master DB" written
whole by whoever holds it keeps the single contended file, the conflict copies
and the agreed-base problem.

**What makes it work:** drop the lock and the single master; let each computer
own one file, treat the ledger as the union of the logs, and derive the snapshot
from it. That is the one arrangement a sync client can't break, it is the rule
the phones already follow (ADR 0005 "One writer per file"), and it is what
"databases are made for this" actually buys here: a log of changes with old
values, which is what a changeset is.
