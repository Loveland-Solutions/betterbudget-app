# A replication review

## Three findings before the design

**1. SQLite's session extension is already in the app.** The sqlite3mc binary
the app ships (`app/.dart_tool/lib/libsqlite3mc.dylib`, the release
`sqlite3mc.framework`, Android `libsqlite3mc.so`) exports `sqlite3session_create`,
`sqlite3session_patchset`, `sqlite3changeset_apply_v2` and carries the compile
options `ENABLE_SESSION` and `ENABLE_PREUPDATE_HOOK` (both are in
`_defaultDefines`,
`~/.pub-cache/hosted/pub.dev/sqlite3-3.5.2/lib/src/hook/compile/description.dart:518-519`).
The Dart side (`sqlite3-3.5.2/lib/src/session.dart`) exposes `Session`,
`Session.diff`, and `Changeset` iteration with old and new values per row. One
limit: `applyTo`'s `onConflict` is a single constant, not a per-row callback. So
use it to *find* changes with their before-values; keep applying them in app SQL
(`applyCombined`), where the money checks live.

**2. Today's merge has a silent-loss hole, narrow but real.**
`CloudFolder._combinable` uses `cloud-folder-agreed` (my last write or take) as
the base. That is a true common ancestor only while the folder's history is a
straight line. If two computers write within Drive's propagation window, Drive
keeps one; the loser's base is its own lost write. For edit-only changes,
`_Combine._table` then sees was == here != there and takes theirs: the loser's
edits are reverted, under a popup saying changes arrived from the other
computer. Added transactions are caught by `_checkDescends`, but as the
whole-ledger question.

**3. What a lock file can and cannot guarantee over a sync folder.** Creating a
file is not atomic across machines: both create it locally and Drive reconciles
later. Drive does not order one file's upload against another's, so the lock can
arrive after the data it guards. A lock needs expiry (a laptop lid closes while
holding it), expiry needs a clock, and an offline machine's lock only arrives
when it reconnects, looking fresh and already stale. So it gives mutual exclusion
only when both machines are online and sync lag is shorter than the hold time,
which is when conflicts are rare, and never when one is offline, which is when
conflicts are made. It would also add a "stuck lock" dialog. At most a hint;
never the correctness mechanism.

## 1. Recommended design: one change log per computer, the ledger file derived

The phones already do the right thing: one file, one writer. Extend it to
computers.

**In the folder**
- `Ledger.betterbudget`: same shape (phones and Open ledger keep reading it), now
  a *derived snapshot*. Any computer may write it. It carries one preference,
  `sync.applied` = {computer id: last change number it contains}.
- `Changes <computer id> <segment>.betterbudget-log`: written by one computer
  only, ever. A small encrypted SQLite file (the `phone_inbox.dart` container
  trick, same key) with a table `ops`. A segment closes at ~500 ops or a day and
  is never touched again; only the open segment is rewritten, whole and in place
  as `_put` does. Immutable files cannot get conflict copies.
- Phone files as today.

**An op**: {computer, seq (1, 2, 3… per computer), deps (the applied vector when
it was made), kind (person / app / resolution / fork), rows: [{table,
insert|update|delete, key, old {col: v}, new {col: v}}], hash, prev-hash}. That
is `RowOp` plus old values, named columns rather than raw changeset bytes:
schema-tolerant and testable with plain maps, as `combine_test.dart` already
does.

**Each computer keeps locally** (beside the working file, like `cloud-folder`):
its id; its own log (authoritative, the folder copy is a mirror it can always
rewrite); `local-base.betterbudget` = its ledger as of its last op; the applied
vector; a short "not kept" list (below).

**The cycle** (same triggers as `CloudFolder.check`: launch, foreground, 5 s after
a change, every 15 s, quit):
1. *Capture.* Open a raw read-only connection to the working file, `ATTACH`
   local-base with the key (as `replaceAllFrom` attaches), `Session.diff` each
   table, iterate the changeset into one op (drop `sync.*` prefs), append it with
   deps = applied, then `copyTo` local-base. A crash in between reproduces the
   identical op next time, recognised by hash and skipped. No per-write
   bookkeeping anywhere in the app: a diff cannot forget a write, which was the
   objection to way C's version column.
2. *Mirror.* Write the open segment to the folder.
3. *Read.* List `Changes *`; for each other computer read ops with seq >
   applied[c]; check the hash chain and that seqs are contiguous (a gap or bad
   hash = still arriving: wait, as `arriving` does today). An op is ready when its
   deps ≤ applied.
4. *Apply* each ready op in one DB transaction in `applyCombined`'s shape
   (`defer_foreign_keys`, then `foreign_key_check` and `unbalancedSql`). Per row:
   mine = current row, base = op.old, theirs = op.new. mine == base applies
   cleanly. mine != base is a true concurrent change (deps guarantee I'm not
   merely behind) and goes to the policy in §2. A person's answers are written as
   a `resolution` op naming the unit and chosen rows, so the other computer
   applies the answer instead of asking again.
5. *Derive.* 5 s after quiet, if the folder snapshot's `sync.applied` doesn't
   already dominate mine, `copyTo` and write `Ledger.betterbudget` through the
   existing `_put` path.

**Convergence with no server and no clocks.** Nothing uses a clock: seqs and
vectors only. Every computer applies the same set of ops; automatic policies are
pure functions of (base, mine, theirs), so they land the same everywhere;
anything else is asked once and the answer travels as an op. Two people
answering the same conflict at the same moment produce two concurrent
resolutions: the lower computer id wins and the other is told "the Mac had
already chosen". Each computer also logs a checkpoint (`ledgerDigest` at vector
V); a computer reaching V with a different digest says "the two computers don't
agree on N rows" and offers a repair (take the snapshot). That is a convergence
alarm in place of silent drift.

**Drive slow:** ops wait on their deps; nothing is overwritten, so nothing is
lost; the "not copied yet" line as today. **Offline a day:** both logs grow; on
reconnect each applies the other's; conflicts are asked where detected. **Two
copies of a file:** of the snapshot, harmless, it is derived (delete copies whose
vector ≤ current); of a segment, both come from one writer, so one is a prefix of
the other, take the longer valid chain. **Two writers on one id** (a cloned disk)
appear as two different ops with the same (id, seq): that computer gives itself a
new id and re-mirrors.

**Deterministic ids** for things two computers make on their own, in a reserved
range above `newRowId`'s (≥ 2^62): a scheduled payday or bill from (schedule id,
date); a phone entry's transaction from the phone entry id; a bank row from its
import key; Income and Safety net fixed; a payee from its name (fall back to
`newRowId` if taken). Then "both made the same thing" is an insert of the same
id with the same content, skipped, no heuristic. `_samePayees`,
`_sameScheduled`, `_sameBankRows`, `_samePhoneEntries` become backstops or go.

## 2. Conflict classes (unit = transaction with entries, or category + period)

- **Same transaction edited both sides.** Different columns (payee here, cleared
  there): both stand, as `_byColumn` does; `updated_at` = max. Same column, or
  either side rewrote the entries: ask card (mine / theirs / neither = base).
  Safe: no amount is invented, `unbalancedSql` runs on the result.
- **Deleted one side, edited other.** Ask card (today's rule), except a waiting
  payday deleted here and confirmed there: confirmed wins, automatic (money that
  arrived beats a plan).
- **Same bank row imported both sides.** Same id from the import key. Filed the
  same: one row, nothing said. Filed differently: ask card ("Groceries here,
  Eating out on the laptop"). Today: whole ledger.
- **Pay or category plan edited both.** Whole-row unit, ask card with the two
  plans in words; waiting rows regenerate after (`_staleScheduled` logic). Today:
  whole ledger.
- **Account renamed both.** Ask card, two names; no money moves. Today: whole
  ledger.
- **Same category assigned both, same period.** Ask card with the three amounts
  (today's). Never summed: each person meant "set to X".
- **Reconciled one side, other edits a row inside the statement.** Deterministic,
  no ask: the reconcile wins on both computers (the owner's lock rule); the
  loser's edit goes to its "not kept" list with the row shown, and they can
  unreconcile and redo. Today: whole ledger. Safe: the statement someone signed
  off stays true, and nothing is dropped silently.
- **Both confirm the same payday.** Same id, so one row; same amount and date:
  one; different: ask card.
- **Restore or erase on one side.** Logged as a `fork` op; the other computers
  get one question, once, in words ("The Mac went back to its backup of 3 Oct.
  Follow the Mac, what is here is saved in Backups / Keep this computer's
  ledger"). A whole-ledger question only after a whole-ledger action; nothing
  else ever asks it.

## 3. Failure modes I'd still worry about, ranked

1. A policy that isn't deterministic (same inputs, different outcome on two
   computers): silent drift. Mitigation: pure-function policy, property tests
   that shuffle op order and assert equal digests, plus the checkpoint alarm.
2. Head-of-line blocking: one op that can't apply (a bug, a schema mismatch)
   stops every later op from that computer. Must surface as the red line
   ("waiting on the laptop's change from Tuesday") with a repair.
3. Two writers on one id if fork detection misses (a `~/Library` restore onto
   another Mac).
4. A computer that dies before mirroring loses its unmirrored ops. Same as today;
   unavoidable without a server. Keep the 5 s mirror.
5. Schema upgrades across computers: an older build holds (applies and mirrors
   nothing) until updated, as `newerApp` does. Named-column ops survive column
   adds; a rename needs an op upgrader.
6. Snapshot briefly behind (B writes a snapshot lacking A's two newest ops): a
   phone's "left" can step back for a minute. Acceptable; the phone's freshness
   line already exists.
7. Log growth: ~100 bytes per row change, a household's year is a few MB. Compact
   only when every known computer has checkpointed past the point.

## 4. Cost

**Schema:** none, v19 stays. One new preference `sync.applied`;
`sync.computers`/`seal`/`saved` retire. **Owner's file:** no row changes; the
first run writes segment 1 with zero ops and a snapshot. Test: a file of the
owner's shape gives the same `ledgerDigest` before and after. Upgrade both
computers while level (only one writes today), so no last old-style merge is
needed. **Phones:** unaffected (same files written, same `Ledger.betterbudget`
read, `phone.taken` as today); deterministic ids make "both took the same entry"
trivial. **Survives:** `FolderAccess`, the queue, scratch copy, `_put`,
`_replace`, arriving handling in `cloud_folder.dart`; `applyCombined`,
`unbalancedSql`, `_checkReferences`/`_checkTransactions`/
`_checkReconciliations`/`_checkDeletedAccounts` as apply checks; `Ask`/`Pick`,
`rows_dialog.dart`; `newRowId`; `Backups.keepBefore`; `ledgerDigest`. **Goes:**
counters, seal, `decideFolderMove`, `cloud-folder-agreed`, the three-whole-ledger
entry to `combine` (its rules move into the per-op policy; `combine_test.dart`
cases port nearly 1:1 as (base, mine, theirs) rows). **Work, one developer:**
capture + log + mirror 1 wk; reader, causal apply, snapshot, bootstrap 1.5 wk;
policy port + deterministic ids 1.5 wk; resolutions, fork, checkpoints, restore
question 1 wk; tests including property tests and the owner-file test 1 wk. About
6 weeks, ±2. The patch alternative (keep today's model; add parent digests and
keep the last ~10 agreed files to close the base hole; turn the remaining classes
into cards; merge in `Ledger (1)` copies) is ~2 weeks, but keeps the
whole-ledger question after restore/erase and whenever no common base is in
store.

## 5. Verdict on the master/child + lock proposal

**Right in it:** a local working copy with the master in the folder (built);
check whether master moved before writing (built: never write blind); on a
concurrent write, compare and merge rather than replace (built: combine); and
"databases are made for this": SQLite's session extension is exactly that and is
already compiled into the app. **What breaks:** the lock file (not atomic over
Drive, needs a clock, meaningless offline, brings a stuck-lock dialog); "load
master at open" makes the merge base a snapshot rather than what each change
actually saw, which is the hole in finding 2; "every X minutes" widens the
conflict window, 5 s is better; and "write master" keeps one file every computer
replaces, which is what Drive turns into conflict copies. **What makes it work:**
drop the lock, because nobody needs a lock to write a file only they write; keep
"load master at open" as bootstrap only; have each computer append its changes
to its own file; make master a derived file anyone may rewrite; check conflicts
per change, against the before-values that change carries. That is the design
above, and it is the owner's own sentence, "entries are ingested without
replacing the entire database", taken literally.
