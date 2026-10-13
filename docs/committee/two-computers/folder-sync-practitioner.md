# A folder-sync practitioner's report

## What the folder-sync products learned (and what the clients really do)

- **No client merges, and none tells the app.** Two writers on one name in the
  same minute gives Dropbox "Ledger (Tom's conflicted copy 2026-10-12)
  .betterbudget", Google Drive for desktop "Ledger (1).betterbudget", OneDrive
  "Ledger-MACBOOK.betterbudget", iCloud "Ledger 2.betterbudget". The app never
  sees it.
- **In place vs renamed into place, for a shared name:** an in-place rewrite can
  be uploaded half-written (macOS clients watch FSEvents and don't wait for
  close; Dropbox on Windows does), so readers must validate, which
  `cloud_folder.dart` already does (`FolderStanding.arriving`). Rename-over-
  existing on Drive and OneDrive can become delete + new file (new cloud id,
  version history split, old copy in Trash). For a **new, unique name**,
  temp-then-rename is perfect, and it is what every one of these products uses
  for per-device files (as `writePhoneInbox` does).
- **`-wal`/`-shm` in a sync folder:** the three files travel at different
  moments; the other side opens a main file whose WAL is missing or stale, so the
  last commits are silently absent or "malformed". `VACUUM INTO` was the right
  call (ADR 0001). Note that SQLCipher re-encrypts every page on VACUUM, so each
  snapshot is a full upload; fine at household size.
- **Lock files through a sync folder failed everywhere:** KeePass's `.lock`,
  Moneydance's and Banktivity's folder locks all produced the same ticket,
  "locked by a computer that is off". Propagation delay lets both hold it; sleep
  or power loss leaves it; and when it works, it blocks the other person.
  KeePass's real fix was merge-on-save by entry UUID with history, not the lock.
- **How they avoided "which whole file":** 1Password's OPVault was many small
  files each written once; Moneydance's Dropbox sync wrote an encrypted change
  file per device and every device applied everyone's; Joplin's filesystem target
  is one file per item. The question never arises when each device's file has one
  writer and the merge is per item. Obsidian vaults in Dropbox, which do nothing,
  get "conflicted copy" files and people fix them by hand, which is what the owner
  wants to avoid.

The phones already follow the one rule that matters (one writer per file). The
computers broke it, and the counters, seals, `_FolderFileMoved` retry, `(1)`
copies and the lock-file idea are all the price of two writers on one name.

## 1. Recommended design: one writer per file, for computers too

**In the folder**
- `Changes/<computer id>/000123.betterbudget-change`: immutable, one per flush
  (today's 5 s quiet period), temp-then-renamed, never rewritten. Each holds:
  writer id, sequence number, the writer's *applied vector* (the sequence it had
  applied from every other writer), schema version, epoch id, the writer's ledger
  digest after the batch (`ledgerDigest`), and the row changes with old and new
  values. Encrypted with the ledger key the same way the phone's file is.
- `Ledger.betterbudget`: now a **derived snapshot** for phones and new computers,
  carrying the applied vector and epoch in `Preferences`. Written in place (as
  `_put` does) by any computer whose vector dominates the one in the file;
  `decideFolderMove` survives as exactly that rule. A `(1)` copy of it is
  harmless: it's derived, and housekeeping deletes the dominated one.
- Phone files: unchanged.

**On each computer:** the working SQLite as now; `sync.applied` (vector) and
`sync.epoch` in `Preferences`; the computer id in `cloud-folder`. The
`cloud-folder-agreed` file goes: the base is inside each batch.

**Capture: the database does it.** Verified: the `sqlite3mc` build this app
selects (`pubspec.yaml` `source: sqlite3mc`) is compiled with
`SQLITE_ENABLE_SESSION` and `SQLITE_ENABLE_PREUPDATE_HOOK`
(`~/.pub-cache/.../sqlite3-3.5.2/doc/hook.md`,
`lib/src/hook/compile/description.dart` line 518), and
`build/native_assets/macos/libsqlite3mc.dylib` exports `sqlite3session_create`,
`sqlite3session_diff`, `sqlite3changeset_apply`, `sqlite3_preupdate_hook` (38
session symbols). The Dart API is `package:sqlite3/src/session.dart`:
`Session(db)`, `changeset()`, `Changeset.fromBytes`, an iterator giving table,
op, old and new values. All 12 tables have primary keys (sessions skip tables
without one). Two caveats: `applyTo` offers only a blanket abort/replace/omit, no
per-row callback, so decide in Dart and apply through our own SQL (today's
`applyCombined`); and drift_flutter opens the ledger in a background isolate
(`NativeDatabase.createBackgroundConnection`), so create the session in
`DriftNativeOptions.setup` and pull its bytes through a registered SQL function
(`SELECT bb_changeset()`), which runs where the connection lives.

**The cycle.** Write: the session records. Flush: pull the changeset, write file
n+1, bump own sequence. Look (launch, foreground, 15 s, before each flush): list
`Changes/*/`; for each writer take files `applied+1, applied+2…` contiguously (a
gap means still arriving: wait); apply each batch in one transaction with the
per-row rule below, then run `unbalancedSql` and `foreign_key_check` as
`applyCombined` does; then rewrite the snapshot if this computer's vector now
dominates it.

**Per row:** current == old → apply; current == new → already done (idempotent);
otherwise both changed → a *unit* (reuse `combine.dart`'s `_Unit`, `_byColumn`,
`_checkTransactions`, reconcile rules). Changesets carry only the changed columns
of an UPDATE, so "one renamed, one archived" merges for free.

**Converge first, ask second.** Today only one computer is asked because nothing
is written until answered. With logs both see the same two batches, so both
would be asked and could answer differently, which is the one thing that must
never happen. Rule: a deterministic provisional winner on every computer (the
batch made with more knowledge, i.e. whose vector dominates; else the lower
writer id; a reconciled row always). Both ledgers are then identical the moment
both have read the same files, and the phones agree. The person whose change
lost gets today's card window ("Keep this computer's / Keep the laptop's /
Neither: as it was", `rows_dialog.dart`), and the answer is an ordinary change
file. Nobody is blocked; nothing is lost (the losing version is on the card and
in Backups). This is "warn, don't block" applied to merging.

**Deterministic ids for rows the app makes on both:** payday/bill = hash(pay or
plan id, date); phone entry = hash(phone entry id); bank row = hash(import key);
payee = hash(lowercased name); Income and Safety net fixed. `newRowId` has one
call site (`database.dart`'s `clientDefault`), so this is a handful of explicit
ids at `ensurePaydays`, `ensurePlanBills`, `takePhoneEntries`, import. Then "the
same thing made on both" is a plain duplicate insert, and `_oneOfEach`'s
heuristics go.

**Drive slow:** files arrive in any order; contiguity waits. **Offline a day:**
the laptop keeps writing its own files; Drive catches up; both apply. **Two
copies of a file:** impossible for change files (unique names, written once);
harmless for the snapshot.

## 2. Conflict classes

| Case | What happens | Why safe |
|---|---|---|
| Same transaction edited both | Different columns: both stand. Same column or entries rewritten: unit; provisional winner; card on the losing side | Both versions kept; sums checked before commit |
| Deleted one / edited other | Unit; the edit wins provisionally (a delete is a mark, cheap to redo); card says "Deleted on the laptop" | Nothing erased either way |
| Same bank row imported both, filed differently | Same id (import key) so one row, never two; the category entry differs: unit, card "Groceries here / Eating out on the laptop" | Never double-counted |
| Pay or plan edited both | Per column; same column: a new small card kind. Waiting paydays are regenerated from the winning plan (deterministic ids), replacing `_staleScheduled` | No stale or doubled salary |
| Account renamed both | Two different names: card; rename + archive: both stand | Names only |
| Same category assigned, same period | Unit as today (sum per category and day); card; the "more assigned than you have" line stays | |
| Reconciled one side, other edits inside the statement | Reconciled side always wins provisionally (the owner's lock); card on the editing side. A new or newly cleared row the other added inside the statement comes in **uncleared**, with a note | Statement still matches; nothing hidden |
| Both confirm the same payday | Same id, same row; identical: nothing; different amounts: card | |
| Restore / erase on one side | A new **epoch**: the restoring computer writes a snapshot with a new epoch id and starts its log afresh. Another computer takes that snapshot in, then replays its own change files since the last shared point through the same per-row rule: one popup, "The Mac restored a backup from 3 Oct; your 6 changes since Monday were put back on top", with Show; conflicts become cards | The only whole-ledger moment left is the one a person chose, and the other side's work is not retyped. KeePass's famous failure is the opposite: a restored file merges and the restore is silently undone |

## 3. Failure modes, ranked

1. **Silent divergence** from a bug in the per-row rule or tie-break. Guard:
   every batch carries the writer's digest after it; when a reader's vector
   equals the writer's at that batch, digests must match, or the app says so that
   day. Cheap and decisive.
2. **A write the session misses:** schema upgrades (disable the session; each
   upgrade is a new epoch snapshot), a future table without a primary key. Guard:
   a test that every write path yields a non-empty changeset.
3. **A cloned computer id** (disk image to a second Mac): two writers under one
   folder name again. Guard: at launch, if `Changes/<me>/<n+1>` exists and isn't
   mine, take a new id.
4. **Client quirks:** dataless files under macOS File Provider block on read (read
   in the queue, treat failure as arriving); Drive on Android answers from a stale
   listing (already seen); OneDrive forbids `:` in names; thousands of small files
   slow listings, so fold own files older than 30 days into one, keep 90 days,
   the snapshot covers the rest.
5. **Schema skew:** a batch from a newer build is never applied by an older one
   (`newerApp` standing survives).
6. A person who never opens the laptop never sees its cards; show "kept over the
   laptop's" on both, with the button on the losing side.

## 4. Cost

- **Schema:** no table change; two preferences. **Owner's file:** rows untouched;
  first run writes the first epoch snapshot and the first change file. **Phones:**
  untouched (same snapshot name, same inbox).
- **Work, one developer, 6–9 weeks:** capture + change files + apply loop 2–3;
  deterministic ids and removing dedupe heuristics 1; converge-then-ask and the
  pay/plan/account/setting cards 1–2; snapshot, new-computer bootstrap, epochs,
  compaction 1–2; soak on two Mac accounts with Drive and OneDrive 1.
- **Survives:** `combine.dart`'s units, `Ask`/`Pick`, `_byColumn`,
  `_checkTransactions`, reconcile and reference checks; `applyCombined`;
  `rows_dialog.dart`; `ledger_seal.dart`; `newRowId`; `cloud_folder.dart`'s
  queue, scratch copy, arriving/stuck, `FolderAccess`, `_put`; `decideFolderMove`
  as the snapshot rule; `phone_inbox.dart`. **Goes:** `cloud-folder-agreed`,
  `_oneOfEach`, `_FolderFileMoved` retry, `_askAbout`, `_decided` persistence,
  the whole-ledger question except at an epoch.

## 5. Verdict on the master/child + lock-file proposal

**Right in it:** a local working copy (already so); check whether the master
changed since you last looked (already so: counters and seal); check for
conflicts rather than overwrite (already so: `combine`); and "databases are made
for this": they are, and the change tracking is already compiled into this app's
SQLite.

**What breaks:** the lock. Through Drive a lock file arrives seconds to minutes
late, so both machines hold it; a crash or a closed lid leaves it forever (the
top support ticket of every product that tried); and when it does work it stops
Jen saving because Tom's Mac is asleep, which is blocking, not warning. A single
rewritten "master" file is the second break: `(1)` copies, half-uploaded files,
split version history. "Every X minutes" is the third: a lid closed mid-interval
widens the conflict window; 5 s is better.

**What makes it work:** a lock exists to serialize writers; give each writer its
own files and there is nothing to serialize. Keep the child DB, replace the
master with snapshot + per-computer change files, and make "check for conflicts"
per batch with the base recorded in the batch by the session extension. That is
the proposal with the one unreliable part removed, and no one is ever asked
which whole ledger to keep.
