# 0005 — Phone apps: a companion for recording and checking, not a second ledger

**Status:** Accepted (not built; comes after the budget)
**Date:** 2026-09-24

## Context

The owner wants iOS and Android apps, with the data kept in a folder synced by Google
Drive, OneDrive or similar so that the service handles versions and off-site copies.
Two constraints shape the design:

- **Nothing leaves the machine** (README). BetterBudget must not talk to Google, Microsoft
  or any server itself.
- **Two people shop at once.** Owner's scenario: Jen in Bayanzurkh and Tom in Zaisan both
  record purchases on their phones and should see each other's spending.

A full two-way sync of the ledger would need a KeePass-style merge: permanent random IDs
on every row, last-modified times, deletion records, duplicate detection, and handling
of changes that land inside a reconciled period. The owner chose to avoid that by limiting
what the phones do.

## Decision

**The phone app is for entering transactions on the go and checking how much is left
in a budget. It is not a complete budgeting app.** (Owner, 2026-09-24.)

### No connectors: the OS does the syncing

The user picks a folder. On the Mac that's the Drive or OneDrive folder on disk; on
phones it's the system file picker (Files on iOS, the Storage Access Framework on
Android). BetterBudget only reads and writes files. The Drive or OneDrive app does all
the network work. Release builds still declare no network entitlement.

### One writer per file

```
Shared folder
├── ledger snapshot     ← only the Mac writes
├── <phone A> inbox     ← only phone A writes
└── <phone B> inbox     ← only phone B writes
```

No file ever has two writers, so there is nothing to merge and device clocks don't matter.

- **The Mac keeps its working database local** and writes a complete snapshot to the
  folder. Never run the live SQLite file out of a synced folder: the sync app could
  upload a half-written set of database files.
- **Phones add transactions to their own inbox.** Each inbox item has a random ID, so
  the Mac never imports one twice.
- **Phones read every other phone's inbox**, so Jen sees Tom's purchases and vice versa.
  Reading is not writing, so it can't cause conflicts.
- **The Mac takes in all inboxes** and lists the imported IDs in its next snapshot. Each
  phone then removes those items from its own inbox.

### All of the data lives in the cloud folder (owner, 2026-10-07)

"The idea behind the app is that all of the data goes in Google Drive/OneDrive/Box/
Dropbox." Said when the Mac's file for the phones was described as a small summary
(categories, what's left, balances) with the ledger staying on the Mac. That was wrong:
**the "ledger snapshot" above is the whole ledger**, a complete encrypted copy the Mac
keeps current in the folder, so the folder is where the data is kept, versioned and
copied off-site, and a new computer needs only the folder and the recovery key. The
phones read what they show from that same copy. The file the Mac works in stays outside
the folder, as decided above, only so the sync app never uploads a half-written
database. Any folder a sync app keeps on the disk will do; the app knows nothing about
which service it is.

**Built on the Mac, 2026-10-07:** Settings → Backups → "Move my ledger to a folder…".
The ledger there is one file, `Ledger.betterbudget`, replaced each time (the sync
service keeps the versions), written at launch and 5 seconds after the last change.
Settings always says where the ledger is: "Stored in · This computer" until it is moved,
then "Stored in · My Drive/BetterBudget · Today 10:00", red with "couldn’t copy" when
the folder can't be written. "Move it back to this computer" leaves the file in the
folder where it is. Which folder is this computer's own setting, in a small file beside
the ledger, not in the ledger.

Three corrections from the owner the same day, after using the first build:
- **It says where the ledger is stored now**, before a folder is picked as well as
  after. The first build showed the line only once a folder was chosen.
- **The word is "move", not "keep"**: "Move my ledger to a folder…", "Move It Here",
  "Your ledger was moved to My Drive/BetterBudget".
- **Not `.sqlite`.** "I don't love the fact that we're just keeping the .sqlite file
  extension." The file is `Ledger.betterbudget`; a `BetterBudget ledger.sqlite` left in
  the folder by the first build is removed once the new file is written.
- **All of them or none** ("If we can't change them all, let's not change any of
  them"), then: all. Every file the app writes a ledger into ends in `.betterbudget`:
  the file it works in (`Ledger.betterbudget`, renamed from `betterbudget.sqlite` at
  the next launch by `ledgerFileIn`, with its `-wal`; nothing in it is read or
  written), the daily copies, "Back up to…" files, and the copies made around a
  restore, a new ledger, a set-aside and an upgrade. Copies already made keep their
  `.sqlite` names and are listed, restored and cleared away as before. Offered and
  not taken: changing only the files a person sees and leaving the working file.

Not built: opening the ledger from the folder on a second computer (today that is
Restore from…, which takes a `.betterbudget` file), and anything that reads the phones'
files.

**Built on Android, 2026-10-07:** the phone asks once for the recovery key (kept only
after it has opened the ledger) and once for the folder, through Android's own folder
picker. It copies `Ledger.betterbudget` out of the folder into its own storage, opens
the copy with the key, and works out what each category holds with the same code as
the Mac's Budget page. It reads again when the app comes back to the front and when
the list is pulled down; a read that fails leaves the figures up, with their time.

**Built, 2026-10-08: the phone's entries reach the computer** (owner, with the
phone saying an entry was waiting for the computer and the computer open: "I want to
see it work… that message isn't going away"). Until then an entry lived in the phone's
memory and nothing took it in.

- **The phone keeps what it has waiting** in its own storage, and writes the same
  file to the folder as `Phone <name>.betterbudget-phone`, where the name is four
  random bytes the phone gave itself. It holds the phone's entries and the categories
  it made, as a small database encrypted with the ledger's key, the way the ledger is.
  It is written again after each change; a write that fails is tried at the next read.
- **The computer looks in the folder** when the ledger is stored in one: at launch,
  when it comes back to the front, and every 15 seconds. Each entry not yet in the
  ledger becomes an uncleared row; a category the phone made is made unless one is
  already called that, whatever its capitals. A popup says "1 transaction from your
  phone", and one undo takes the lot out. Nothing is asked.
- **What is in is written in the ledger itself** (the preference `phone.taken`: for
  each phone, the ids of its entries that are in, and which ledger category each
  category it made became), in the same transaction as the rows, so nothing comes in
  twice. The phone reads that from the ledger's next copy and drops those entries.
  The computer never forgets an id: Drive can hold two files of one name, or an older
  conflict copy, and a forgotten entry in one of those would come in again (the first
  build forgot an id once the phone's file no longer held it). Undone rows stay
  marked as in, so they don't come back by themselves; a category the undo removed
  is made again only when a later entry needs it. Nothing is taken in during a
  restore, a reconcile or setup.
- **While something is waiting, the phone asks the folder every 30 seconds** when the
  ledger was last changed, and fetches it only when that has moved, so the waiting
  line goes without the app being left and without a copy of the whole ledger over
  mobile data each time. With nothing waiting it doesn't ask. Coming to the front
  always reads. **Drive on the phone answers from a listing it keeps**: on the first
  real run (the owner's Pixel, 2026-10-08) it went on giving the old time for five
  minutes after the computer had written the newer ledger, so the waiting line
  stayed. The phone now asks Drive to refresh the listing before it asks the time,
  and every fourth look (two minutes) fetches the ledger whatever the time says.
- **A phone entry is something that happened, never a scheduled row.** The phone's
  date stops at today, and an entry dated after the computer's today (a clock ahead)
  still comes in as an ordinary uncleared row.
- **Money in from the phone** (owner, 2026-10-08, about returning things to a shop;
  the screen is ADR 0004 "Phone screens: Ledger first"). An entry's amount was always
  signed in the phone's file, so the file is unchanged: a positive amount in a spending
  category is a refund to it. Income is filed under the word `income`, not an id: the
  ledger makes its Income the first time it is wanted, so there may be none for the
  phone to read. The computer posts such an entry against its own Income, making it if
  need be, and only when the amount is money in and the account is a real one. A
  computer on a version before 0.18.0 leaves an income entry with the phone. A
  category a phone on an earlier version made under Income's name becomes the
  ledger's Income too, not a second, spending category of that name.
- **An arrival doesn't disturb what the person is doing**: it waits for a popup on
  screen to go, and it leaves redo as it was.
- **⌘Z doesn't take an arrived batch out; its own popup's Undo does** (owner,
  2026-10-08, asked whether ⌘Z pressed for something just typed should be able to
  remove rows the phone has already let go of: "Yes" to leaving them alone). This
  changes "one ⌘Z that undoes the whole batch" below. After the popup's Undo, ⌘⇧Z
  brings the batch back.
- **A new category's popup offers its Edit** (owner, same day): when one category
  came with the batch, the popup has a button, "Edit Coffee", that opens the Budget
  page with that category's Edit open, where money is assigned to it.
- **An entry filed in an archived category brings the category back** (the phone
  can't see archived ones, so it would have made the name again); undo archives it
  again.
- An entry whose account or category was deleted on the computer is left with the
  phone.

**Seen working end to end on 2026-10-08** with the owner's Pixel, Mac and Drive
folder: saved on the phone at 12:23, the phone's file on the Mac at 12:24, in the
ledger at 12:25.

No table was added: the ledger's schema is unchanged. Not built: other phones'
entries shown on a phone, and the iPhone's folder access. **Transfers (2026-10-09):**
money moved between two of the ledger's own accounts is an entry whose category id is
the account it went to (the ledger keeps categories and accounts in one list, so an id
names one or the other), with the amount negative and no payee. The phone's file didn't
change, so a computer on an older build leaves a transfer with the phone until it is
updated. The computer posts it as a transfer when both accounts are live and in one
currency; an account archived since comes back, as an archived category does. With
two computers on one ledger each would take the same entries in (the next section).

### More than one computer on one ledger (owner, 2026-10-07; the way chosen 2026-10-09)

"I definitely want to be able to support multiple machines on the same ledger." Said
when told that a second or out-of-date computer writes its own ledger over the one in
the folder. This record assumed one computer and some phones: the computer is the
folder file's only writer, and the full two-way merge under Rejected was turned down
as too much for a phone that records purchases. Two computers that both edit the
ledger change that.

**The scenario put to the owner.** Monday a week of spending is entered on the Mac,
which writes the ledger to the folder. Tuesday the laptop, still holding its older
copy, fixes one payee and five seconds later writes its whole older ledger over the
folder's. Monday's entries are gone from the folder with no word on either computer,
and the Mac's next change writes over the laptop's fix the same way.

**Decided (owner, 2026-10-09), after an expert's three ways were laid out:**

1. **Two computers changing the ledger apart is ordinary, and the app combines
   them.** "This should be a common practice. The only time this should be a problem
   is if person A does something that conflicts with something person B did. If this
   is a problem, we should ask the user." So: what one changed and the other didn't
   touch is brought together without a question; a row both changed, or one changed
   and the other deleted, or a change to a reconciled row, is put to the person with
   the real values.
2. **Both may be open at once, and the design allows for it.** "Yes, and we should
   prepare for this by design." A computer left running takes in what the other
   wrote while it is open, not only at launch.

3. **The existing ledger may be replaced to get this right** (owner, 2026-10-09,
   told the work would be built with care because their ledger is real data: "It's
   okay if we need to replace the existing ledger to build something that is
   bulletproof. Remove it if you must."). So the design is not held to keeping the
   file's present form: how rows are identified, the schema, or the file itself may
   change if a sounder design needs it. This reopens way C below (a permanent id and
   version on every row), turned down partly for what its upgrade would cost;
   weigh it again before starting step 1. It is leave to do so, not an instruction
   to: keep the owner's rows through an upgrade wherever that is no worse a design,
   and before anything of theirs is actually removed or replaced, say exactly what
   will go and get their word at that moment.

Rejected on 2026-10-09, before decision 3: asking which whole ledger to keep whenever both changed (way A alone: the
other side's work is re-entered by hand), and a file per computer merged row by row
with a permanent id and version on every row (way C: two to three months, a schema
change on every table, the most room for money bugs).

**How it is to be built, in order, each its own PR** (the expert's judgement, taken):

1. **Never write blind.** Each computer has a random id of its own, kept beside the
   ledger in `cloud-folder`. The ledger carries a counter per computer in
   `Preferences` (no table change), raised when that computer writes the folder. No
   clocks. Before every write, at launch, when the app comes to the front and on a
   timer while open, the folder's file is copied to scratch (as the phones' files
   are) and its counters read. Same or older than mine: write. Ahead of mine, and I
   have changed nothing: save a copy of mine, take the folder's in, clear undo, and
   say so with Undo ("Opened the ledger from the Mac, Monday 21:40 · 23 transactions
   newer"). Both changed: don't write; go to step 2 (until it exists: keep both
   files and say so). Can't be read (still arriving): hold the write, say "not
   copied yet", try again. This step alone ends the silent loss.
2. **Combine.** Each computer keeps the exact file both last agreed on. When both
   changed, compare that file, mine and theirs, table by table: rows only in theirs
   come in under new ids (a transaction with its entries as one, so it still sums to
   zero), rows changed on one side are applied, and the rest are the questions of
   decision 1. The same thing made on both sides is one: a scheduled bill by its plan
   or pay and date, a bank row by its import key, a payee by name, a phone's entry
   by its id. All of it is one undo: "Brought in 4 transactions and 1 payee change
   from the laptop".
3. **While open.** The check of step 1 runs while the app is open, and the app's own
   scheduling at launch (`ensurePaydays`, `ensurePlanBills`) runs after the folder
   has been looked at, not before.

Known before starting: every table's ids are counted from 1 on each computer, so two
computers give the same id to different rows, and step 2 must remap; a "change made
by a person" has to be told from the app's own scheduling, or every stale computer
looks as though it changed something; a computer on an older build still writes
blind, and a new build can only notice afterwards; ledgers at two schema versions
aren't combined until both are updated. **Also unsafe today with one computer, to
fix in step 1:** picking a folder that already holds a ledger writes over it (a
second or reinstalled computer destroys the folder's ledger); "Move it back to this
computer" and moving to another folder don't wait for a write under way; moving to
another folder deletes the ledger from the one it left, which a phone may still be
reading; the temporary file is written inside the synced folder.

**Way C weighed again (2026-10-09), as decision 3 asks, before step 1.** Taken from
it: a permanent random id on every row. Without one, step 2 has to match rows by ids
each computer counts from 1, and a comparison against the wrong earlier file would
join one computer's entry to another's account without a word; with one, the worst a
wrong comparison can do is ask a question that wasn't needed. Not taken: a version or
a time on every row, which every one of the app's writes would have to keep right.
What changed is still found by comparing with the file both last agreed on (step 2
as written). The ids arrive in step 2 as a new column filled in by an upgrade, so
**nothing of the owner's is replaced or removed**, and the leave given in decision 3
isn't used. Step 1 needs neither and changes no table. (As built in step 2, the id
is the row's own and no column was added: "Built, 2026-10-10" below.)

**Built, 2026-10-09: step 1, "Never write blind"** (with step 3's look while open,
since the look had to exist anyway).

- **What the ledger carries** (three `Preferences`, `domain/sync.dart`): for each
  computer that has written it to a folder, a count and the computer's name
  (`sync.computers`); a seal, the SHA-256 of every row but these three
  (`sync.seal`); who wrote it last and when by their clock, for the screen only
  (`sync.saved`). A ledger whose rows no longer give its seal was changed since it
  was last written to the folder or taken from it. No clock decides anything.
- **Each computer's id** is 8 random bytes in `cloud-folder` beside the ledger, never
  inside it, so a ledger restored on another computer doesn't bring the id along.
- **The look** (`CloudFolder._sync`): the folder's file is copied out, opened and
  compared, and then one of four things (`decideFolderMove`). The same rows: nothing
  is written, and where only the counts differ this computer takes the folder's
  counts and seal as its own (were each to write, two computers would answer each
  other for good). The folder holds this computer's last write, or an older one: write. The folder is
  ahead and nothing changed here: take it in. Anything else (both changed, or the
  folder's rows aren't what its seal says, which is what a build before this one
  leaves behind): write nothing and ask. It runs at launch before anything is
  scheduled, before every write, when the app comes to the front, and every 15
  seconds, one at a time.
- **Taking it in** happens only if this computer's rows are still the ones that were
  compared, checked inside the same write that replaces them (a click made while
  the folder's file was being read stops it, and the next look asks). It is a
  restore that keeps the folder's counts: what was here is
  saved as `before-restore-…` first, paydays and bills are scheduled afterwards, undo
  is cleared, and a popup says "Opened the ledger saved on Tom’s MacBook Air" over
  "My Drive/BetterBudget · Yesterday 21:40". It had an Undo until 2026-10-10 (ADR
  0004: Undo is only for what the person at this computer did); what was here is in
  Backups. It waits for an open edit, a reconcile, a dialog or a popup to go.
- **Both changed** (until step 2 combines them): nothing is written. A question
  comes up once, "Your ledger was changed on two computers", with what each holds
  (transactions, accounts, who saved the folder's and when) and Not now, Use this
  computer's, Use the folder's. Whichever isn't chosen is saved first
  (`from-folder-…` or `before-restore-…`, both opened by Restore from…), and each
  choice undoes. Undoing "Keep this computer's ledger" puts the other's file back
  only while the folder still holds exactly what was written (after that another
  computer has gone on from it, and the undo says it can't), and the two are then
  asked about again by the file's digest, kept in `cloud-folder`: **a computer's own
  count never goes down**, here or in a restore, or one count would come to stand
  for two different ledgers. Until one is chosen the "Stored in" line is red, "changed on
  another computer too · not copied", with a button, "Choose which to keep…", and
  the phones' entries aren't taken in.
- **A restore, its undo, and "Erase everything and start over"** are changes a
  person made here: they keep the counts and lose the seal, so they are written to
  the folder, never taken for an older ledger and replaced by the folder's.
- **The first run of this build**, with a folder already holding the file the build
  before wrote (no counts, no seal): the same rows are sealed where they are; rows
  one change behind are written over when the file's time is within two minutes of
  this computer's own last write; otherwise it is asked about.
- **The four things unsafe with one computer:** a picked folder that already holds a
  ledger is looked at like any other (taken in, asked about, or, when this
  computer's key doesn't open it, a warning with "Replace it" that keeps the file
  first); "Move it back" and moving to another folder wait for a write under way;
  the ledger in a folder that is left stays there; and the file is made whole in the
  app's own folder, checked against its seal, and written over the folder's in
  place, so the sync service sees one file with a new version. A write cut short is
  remembered (`writing` in `cloud-folder`) and written again; a file that can't be
  read otherwise is waited for ("the ledger there can’t be read yet"), tried again
  at every look, and after three minutes the line is red and the gear has its dot.
- A ledger saved by a newer BetterBudget is neither read nor written over: the line
  says to update this computer's.

Known gaps: a folder whose ledger hasn't arrived
yet looks empty, and this computer's is written there; a second file
a sync service makes beside the ledger when two computers write in the same minute
("Ledger (1).betterbudget") isn't looked for; a disk cloned to a second computer
gives two computers one id, which is caught only as "changed apart"; a computer on
a build before this one still writes blind, and is noticed afterwards by the seal.

**Built, 2026-10-10: step 2, "Combine".** Two computers that each changed the
ledger are combined without a question whenever what they did can both stand.

- **A row's id is its permanent id, and no column was added.** Way C's id was to be
  a new column filled in by an upgrade. Instead every new row is given an id no
  other computer gives one of its own (`newRowId`, `domain/sync.dart`: the time in
  milliseconds, then 20 random bits, each higher than the last made here, so rows
  still sort in the order they were made). A row then has the same id on every
  computer, and nothing that names a row by its id has to be renumbered when two
  ledgers are combined: an entry's account, `budget.from.<id>` and the other
  settings keyed by an id, a bank row's import key (`a<id>|…`), what a phone wrote
  against the folder's ledger. Renumbering was the step with the most room for a
  row joined to the wrong account without a word. **Nothing in the owner's file
  changed**: no upgrade, schema still v18, and rows made before this keep the ids
  counted from 1, which every computer that has the ledger already shares. Two rows
  given one such id on two computers by the build before (each changed apart, then
  both updated) are different rows under one id: that is found as a row "made on
  both, not the same", and asked about.
- **The ledger both agreed on** is kept beside the working one
  (`cloud-folder-agreed`): the file this computer last wrote to the folder, or the
  folder's when it holds exactly what this computer's seal says (after a take, and
  at the first look of this build). It is used only while its contents give this
  ledger's seal. A restore, its undo and "Erase everything and start over" lose the
  seal, so after one of those nothing is combined: the question is asked, as in
  step 1. So is it when the folder's file was written by a build that keeps no
  seal, or under another version of the tables.
- **What comes in** (`domain/combine.dart`, pure, row maps by table): a row only
  the other computer added, changed or deleted. In an account, payee, transaction
  or entry each computer may have changed a different column, and both stand (one
  renamed an account, the other archived it; one cleared a row, the other filed
  it). What a category is assigned for a period is compared as the sum for that
  category and day, never row by row, since a change of it writes new rows.
  Deleted on both, or archived on both, is agreement. `phone.taken` is the two
  put together. A setting that only changes a view (the
  forecast's span) stays this computer's own.
- **Counted once**: a payee both typed (by name); Income, Safety net and a category
  of one name each made (a phone's new category both took in), the other's rows
  moved to this computer's (and on the next round the other computer follows:
  what it still files under its own is moved to the one kept); the payday or plan
  bill each scheduled (one confirmed or skipped since is the one kept, whatever
  day it was confirmed on; two still waiting that differ are asked about; and one
  scheduled here from a pay or plan the other has changed goes, for scheduling to
  make again); a bank row both imported, when both filed
  it the same; a phone's entry both took in, found by what it says, since nothing
  on the row names the phone's entry.
- **Asked about instead, with nothing combined** (the whole-ledger question of step
  1): one column of one row changed two ways; a transaction deleted on one and
  changed on the other (a delete only marks the row, so this is looked for by
  name: a paycheck confirmed here must not go because the pay changed there); one
  transaction edited on both where either rewrote its entries; a
  transaction that wouldn't add up; a row reconciled on one whose amount, account
  or date the other changed; one account reconciled, or its reconcile undone, on
  both; a statement reconciled on one while the other cleared or added a cleared
  row dated within it; a folder's ledger that lacks a transaction or account both
  agreed on (it was replaced whole there: a restore, an erase, "Keep this
  computer's ledger"); an account or category deleted on one and given a row on the other; a pay
  or a category's plan changed on both; one category assigned on both for one
  period; a setting changed on both; a bank row both imported and filed two ways; a
  phone's entry both took in and one changed since; one payday confirmed on both.
  The rows are also checked as a whole before anything is written (every reference
  still names a row, every transaction adds up), and again by the database inside
  the one write that makes the changes; any failure and nothing is changed.
- **On screen** it waits, as a take does, for an open edit, a reconcile, a dialog
  or a popup to go. This computer's ledger is saved first (`before-restore-…`), the
  changes are made only if its rows are still the ones compared, paydays and bills
  are scheduled, undo is cleared, both together are written to the folder, and a
  popup says "4 transactions from Tom’s MacBook Air" (or "… and other changes
  from", or "Changes from"; the count is of transactions that arrived, and one
  changed or deleted there is another change) over the folder and time. **It has no
  Undo** (owner, 2026-10-10; ADR 0004 "Two computers: combined without a question"):
  this computer's ledger as it was is in Backups. In place of the folder and time it
  says "1 looks the same as one already here", with Show, for a row that came and
  has the account and amount of one made here within 6 days (`Combined.alike`), and
  "₮3,000,000 more is assigned than you have" when the two together assign more
  than there is. When everything the folder's has is already here (both took the same
  phone entry, both scheduled the same payday), this computer just writes, and
  says nothing.
- A guard: the same folder file is never brought in twice by itself; if something
  of it were still found missing afterwards, the question is asked.

**Built, 2026-10-12: a second computer in one step.** Restore from… pointed at the
folder's `Ledger.betterbudget` offers, ticked, to keep this computer on it (ADR 0004
"A second computer set up in one step"). The file is taken in as the folder's own
(`Backups.restore(fromFolder: true)`: its counts and seal), and `CloudFolder.keepIn`
runs before anything is scheduled here, so the look finds the two the same and the
which-to-keep question a restored ledger was asked on first meeting the folder
doesn't come up. If the folder's file moved on between the pick and the look, the
later one is taken in there and then, still before anything is scheduled (a row
scheduled first would make the two look changed apart). Undo leaves the folder
first (`stop`), then puts back what was here; Redo does the step again with the
ledger the folder holds then. A sandboxed Mac is given the picked file only, so the
folder is picked once more (`FolderAccess.folderMustBePicked`); it is known as the
same folder by its path, or by holding the very file that was picked. **This door
replaces what is here, on purpose** (the dialog says how much is here, and it is
saved first), where "Move my ledger to a folder…" onto a folder with a ledger
compares the two. If the folder can't be kept after the restore, the ledger here
carries the folder's seal though it is stored on this computer: harmless, since a
later move to that folder then takes, writes or asks as the counts say.

On a computer with no ledger the same is reached by **Open ledger** on the first
screen (ADR 0004 "How a new computer starts"): the folder is picked, not the file,
so the Mac's one dialog gives the app the folder, and `_openLedgerInFolder` brings
its `Ledger.betterbudget` in by the same path (`_finishRestore`). A folder that
holds no ledger is refused there and nothing is written to it, which closes, for
this door, the gap of a folder whose ledger hasn't arrived yet.

**Built, 2026-10-12: asking about the one row** (decision 1, the rest of it; ADR
0004 "Two computers: the one row both changed"). A thing both computers changed in
ways that can't both stand is no longer the whole-ledger question.

- **Units.** `combine` found the conflict at one of a few places and now throws
  an `_Ask` for its unit: a transaction (its header and entries together) or one
  category's assigned amount for one period. The run starts over with that unit
  *frozen*: its rows on the agreed ledger and on the other's are replaced by this
  computer's, so it reads as unchanged there, and everything else is combined as
  before. Its rows as the other had them and as the agreed ledger had them are held
  aside (`_heldTheirs`, `_heldBase`), renamed along with the rest when a payee or
  category both made is counted as one. At most 25 are asked at once; more, or one
  asked twice, is a conflict as before. A unit holding a reconciled entry is never
  asked: the lock stays.
- **Answers** are a `Pick` for each ask by its id (`transaction|<id>`,
  `assigned|<category>|<date>`): `mine` (nothing changes here), `theirs` (the unit's
  rows made as the other had them) or `neither` (as the agreed ledger had them).
  `combine(picks:)` freezes what was picked from the start, applies the choices
  inside the same comparison, and runs the same checks (every reference names a
  row, every transaction adds up) on the result. Without a pick for each ask it
  returns `Combined.asking` and no ops: nothing comes in partly.
- **In the folder code** the standing is `FolderStanding.rows`, held like `apart`
  (nothing is written, phones' entries wait). `CloudFolder.asks` are the questions;
  `bringIn(picks:)` compares again with them, applies the ops, and the write that
  follows goes to the folder. **The choices are remembered for that folder
  ledger's digest** (`_decided`): the write after it compares with them, so it is
  not asked again over what it just chose, and a `neither` that puts every row
  back as the agreed ledger had it counts as a change made here, not as "nothing
  changed here, take the folder's".
- **One computer is asked.** Nothing is written until the answer, so the other
  computer finds the folder ahead of it with nothing changed there (or the same
  rows) and takes it in. Known gap: two computers that both write in the same
  minute and a sync service that keeps both files.
- **Not asked, still the whole ledger**: a row both made under one id, a pay or a
  category's plan changed on both, an account or payee renamed on both, a setting
  changed on both, a reconciled row, an account deleted on one and spent from on the
  other. And a bank row both imported and filed two ways, which is not yet a card.

Two people who each choose "Keep this computer's ledger" replace each other's in
turn; nothing is deleted. A purchase both computers typed by hand is two rows, as
it would be typed twice on one. Not yet run on two real computers.

### Two computers: the way chosen, 2026-10-12 — a change file per computer

**Why it was reopened.** Told that five kinds of conflict (a bank row both
imported and filed two ways, a pay or plan changed on both, an account renamed on
both, a setting changed on both, a reconciled row changed on the other side) still
asked which whole ledger to keep, the owner said: "I don't want them to have to
make this decision. We need to make a way where entries are ingested without
replacing the entire database." They proposed a master database loaded into a
local child copy, the session happening locally, and every X minutes and on
close: check whether the master changed, place a lock file so other machines
don't write, write if nothing did, check for conflicts if something did.
"Databases are made for this type of thing. I feel like we should be able to
leverage that." Four experts were briefed with one text and the same code
([committee/two-computers/](../committee/two-computers/)): a distributed-systems
engineer, a SQLite engineer, a folder-sync practitioner, and the household-money
expert. The three engineers converged, unbriefed on each other. The owner chose
this way on 2026-10-12 ("Let's go with B").

**What all four found.** The proposal is right in every step but the lock. A
local working copy, a check whether the shared file moved before writing, a merge
instead of an overwrite: built already. The lock breaks because creating a file
through Drive is neither instant nor atomic (both Macs create it, both succeed,
they meet in the cloud as `lock` and `lock (1)` after both have written), a lock
held by a closed laptop needs an expiry, an expiry needs a clock, and when a lock
does work it blocks the other person. Every folder-sync product that tried one
(KeePass, Moneydance, Banktivity) removed it. The fix is the rule the phones
already follow, **one writer per file**: each computer appends its changes to a
file only it writes, every computer applies the others', and
`Ledger.betterbudget` becomes a snapshot derived from the logs, which the phones
and a new computer keep reading unchanged. With nobody sharing a file there is
nothing to lock, and Drive can't make a conflict copy of a file with one writer.
SQLite's session extension is compiled into the sqlite3mc build the app links
(checked in the Mac, Android and iOS binaries: `ENABLE_SESSION`,
`ENABLE_PREUPDATE_HOOK`, 44 exported symbols; `package:sqlite3` exposes `Session`,
`Changeset`, `Session.diff`).

**A hole in what is built today**, found on the way (the distributed-systems
report, finding 2): `cloud-folder-agreed` is a true common ancestor only while the
folder's history is a straight line. If two computers write inside Drive's
propagation window, Drive keeps one, and the loser's base is its own lost write;
for edits to existing rows `_table` then sees was == here != there and takes the
other's, reverting the loser's edits under the "changes arrived" popup. Added
rows are caught by `_checkDescends`, as the whole-ledger question. Rare (both
must write within the same minute or so) and silent. Step 3 below removes it; no
interim guard, to avoid throwaway work.

**Rejected.** A: keep the one shared file, close the hole by keeping the last few
agreed files, turn the five cases into blocks in the row window (about two
weeks); it keeps the whole-ledger question after a restore or whenever no common
base is on hand, and the write race. C: the proposal as written, with a lock
(two to three weeks; still breaks when one computer is offline, which is when
conflicts are made). The smaller step of a change log inside the single shared
file (fixes the base problem, keeps the race and the "(1)" copies) was not
stopped at either.

**The design.** Terms: a *change* is one row's insert, update or delete with its
old and new values by column name; a *batch* is the changes one computer made
between two flushes; a computer's *applied vector* is, for every computer it
knows, the last sequence number it has applied.

- *In the ledger (schema v20; the upgrade adds, never alters, and keeps every
  row, with a test on a v19-shaped file):* a `changes` table (sequence, computer,
  table, key, op, old JSON, new JSON, schema version), filled by AFTER
  INSERT/UPDATE/DELETE triggers on every one of the twelve tables, generated from
  the table list and asserted by a test (a table without its three triggers, or
  missing from `combine.dart`'s `_keys`, fails the suite). Triggers rather than a
  live `Session`, because they are name-keyed (raw changesets are positional, and
  the owner's file and a fresh file don't share a column order,
  `ledger_seal.dart` line 19), they commit inside the same transaction as the
  write, they need no isolate plumbing (drift_flutter opens the ledger in a
  background isolate), and the log lives in the encrypted file so backups and
  the snapshot carry it. Preferences: `sync.applied` (the vector), `sync.applying`
  (set inside the transaction that applies another's batch, so its writes aren't
  logged as this computer's: the echo guard, with a test), `ledger.id` (adopted
  from the folder, never invented twice). `Session.diff` is used where it is
  unbeatable: to log a Restore as one batch, and in tests to prove two files
  identical.
- *In the folder:* `Ledger.betterbudget`, the snapshot as today plus the vector
  and a 30-day tail of `changes`, written only by a computer whose vector is at
  or past the snapshot's, 5 seconds after quiet, through `_put` as now (a
  `Ledger (1).betterbudget` is harmless, derived, and removed once its vector is
  covered). `Computer <id>.betterbudget-changes`, one per computer, encrypted
  like the phone's file, written whole and only by its owner: a header (vector,
  schema, ledger id) and its changes since the lowest point any other known
  computer has reported applying. Phone files as today; phones ignore the new
  file (`isPhoneInboxName`).
- *Locally:* the ledger (its full `changes`) and the computer id in
  `cloud-folder`. `cloud-folder-agreed`, the counters, the seal as a merge
  input, `theirsIsMyOldWrite` and `_writingMark` go. `ledgerDigest` stays as the
  convergence check.
- *The cycle* (same triggers as today's look: launch, before a write, on
  foreground, every 15 s, at quit; one at a time): copy out each other
  computer's file whose size or time moved (torn copy: "arriving", retry); take
  its changes past my vector in order; if its header says it depends on changes I
  lack from a third computer, hold the whole file until they arrive (causal
  order: a change never names a row that hasn't come); apply the batch in one
  transaction in `applyCombined`'s shape (parents first, deferred foreign keys,
  then `foreign_key_check` and `unbalancedSql`; any failure, nothing changes and
  the batch is held, said in red with the computer and day); per row, current ==
  old → apply, current == new → nothing, else a true crossed change → the policy
  below; advance the vector; rewrite my own file if my log has grown; write the
  snapshot if my vector is past it. Drive slow: nothing waits but the causal
  hold. Offline a day: both logs grow, each applies the other's on return. A
  cloned disk (my id in a file I didn't write): take a new id, say so.
- *Deterministic ids* for rows two computers make on their own, in a reserved
  range above `newRowId`'s: a scheduled payday or bill from (schedule id, date);
  a phone entry's transaction from the phone entry id; a bank row from its import
  key; Income and Safety net fixed. Then "both made the same thing" is one id,
  and `_sameScheduled`, `_samePhoneEntries`, `_sameBankRows` stay only as the
  backstop for rows made before. A payee keeps `newRowId` and `_samePayees` (a
  name hash collides across spellings).
- *Converge first, ask second* (my call, from the practitioner's report; the
  owner's rule "warn, don't block" applied to merging). Both computers see each
  other's batches, so a crossed change would be a question on both, and two
  people could answer it two ways, the one thing that must never happen. So every
  computer settles a crossed change the same way by a rule that needs no clock:
  a fact first (a reconciled row keeps its money columns; a bank-matched row
  beats a hand-typed one on amount, date and account), then the batch made with
  more knowledge (the vector that dominates), then the lower computer id. Both
  ledgers are then identical the moment both have read the same files, and the
  phones agree. The person whose change lost gets the row window
  (`rows_dialog.dart`: keep this computer's, keep the other's, neither), now
  reading as a thing already done that they may change; their answer is an
  ordinary change the other computer applies. Nothing is lost: the losing version
  is on the card and in Backups. Rejected: holding the unit unapplied on both
  until one answers (the ledgers differ meanwhile and the phones show whichever
  wrote last).
- *The money rules* (the money expert's, taken; new ways money is counted, put to
  the owner with the choice and not objected to): reconciled wins on money columns
  only, payee, memo and category edits still come in, and a row the other side
  added cleared inside the statement arrives uncleared with a note; bank-matched
  beats hand-typed on money columns and the typed filing stays; deleted on one and
  changed on the other **stays**, with the change, said with Show and "Delete it
  anyway" (a dropped real row is invisible until a balance is off); one payday is
  one row, two confirmations of it are two updates, different amounts settle by
  the rule above and are shown; an account or category renamed on both keeps this
  computer's name and mentions the other, never a question; an amount assigned
  two ways for one period is never summed and never "larger wins" (one shared
  pool); "later edit wins" is never a rule. What still reaches a person as a
  block: the same amount changed two ways with neither matched to the bank; the
  same category assigned two amounts for one period (with what would be left to
  assign under each); a bank row both filed, two ways; a pay or plan changed on
  both in the same column.
- *Restore and erase.* A Restore is logged as one batch (`Session.diff` against
  the attached backup), and the restoring computer is told first what it undoes
  elsewhere ("the laptop's 23 rows since Monday"), warn-don't-block; rows the
  other side changed since become blocks. "Erase everything and start over" gives
  a new `ledger.id`; computers never merge across ids: "The Mac started a new
  ledger: open it / keep this one". That is the one whole-ledger question left,
  after the one whole-ledger act.
- *Guards against silent drift:* each batch carries the writer's `ledgerDigest`
  after it; a reader whose vector equals the writer's at that batch must get the
  same digest, or the line goes red that day with a repair (take the snapshot).
  Property tests shuffle batch order across two ledgers and assert equal digests.
- *Transition:* both computers must be on v20 (the schema gate holds an older
  build as `newerApp` does today). The first meeting after both upgrade uses
  today's path once; from then on, logs. The old path is removed a release later.
  Nothing of the owner's is replaced; the leave in decision 3 is not used.
- *Cost:* about six weeks, give or take two. Survives: `rows_dialog.dart`,
  `Ask`/`Pick`, `_byColumn` and the unit machinery and checks in `combine.dart`,
  `applyCombined`, `unbalancedSql`, `ledger_seal.dart`, `newRowId`, the queue,
  scratch copy, `_put` and `FolderAccess` in `cloud_folder.dart`, all phone code,
  `Backups`. Goes: `cloud-folder-agreed`, counters and seal as merge inputs,
  `decideFolderMove` except as the snapshot rule, `keepMine`/`undoKeepMine`,
  `_decided`, `_askedAbout`, the whole-ledger question except at an erase.

**Built in order, each its own PR:**

1. Schema v20: the `changes` table, the triggers, the echo guard, `sync.applied`,
   `ledger.id`; the upgrade and its test on a v19-shaped file; a test that every
   write path yields a change. No change to the folder yet.
2. Deterministic ids for paydays, bills, phone entries and bank rows, with the
   old dedupe kept as backstop.
3. The folder cycle: the per-computer change file, reading others', causal apply
   with the per-row policy ported from `combine.dart`, the derived snapshot, the
   transition gate. Counters, seal and the agreed file go. This closes the hole
   above.
4. The policy and the blocks: the facts-first rule, the window as "already done,
   change it", the new block kinds (bank row filed two ways, pay or plan), the
   resolution travelling as a change, the money rules above. *Built
   2026-10-17, below; nothing reaches a person as a block any more: each is
   settled by the rule and told after (ADR 0004).*
5. Restore as a batch, erase as a new ledger id, the digest guard, compaction of
   old changes, cleanup of `(1)` copies, and a soak on two Mac accounts through
   Drive, then two machines.

**Built, 2026-10-12: step 1, the change log (schema v20).** What this computer
changes is recorded in the ledger, row by row, from the first launch of this
build; nothing in the folder changes yet.

- **The table** `changes` (`seq`, `tbl`, `pk`, `op`, `before`, `after`, `at_ms`,
  `with_schema`): one row per row changed, the key and the whole row before and
  after as JSON by column name, so an upgraded file's column order and a new
  file's don't matter. `seq` counts 1, 2, 3 on purpose: it is this computer's own
  order, never shared as an id. The upgrade adds the table and touches no row.
- **The triggers** (`changeTriggerSql`) are made from the table list, three per
  ledger table, and are **TEMP**: they live in the connection, made on every open
  and afresh after every upgrade. A trigger in the file could not read the hold
  below (SQLite lets a main-schema trigger name nothing in `temp`) and would stop
  a later upgrade dropping a column it names. Every connection the app opens runs
  `beforeOpen`; a reader that opens the file raw (the folder look, a phone)
  writes nothing. An update that changed nothing is not recorded.
- **The hold** (`_withoutChangeLog`): a TEMP table; a row in it, inside the
  transaction, while another computer's changes are applied (`applyCombined`), a
  whole ledger is put in (`replaceAllFrom`) or everything is erased
  (`startNewLedger`). A restore then leaves one marker row (`op` `restore`) and
  nothing else; the folder's own ledger taken in (`fromFolder`) leaves nothing;
  an erase clears the log and leaves `erase`. Step 5 makes a restore a batch of
  real differences.
- **Each computer's own, never shared:** the `sync.*` settings (not recorded;
  the preferences triggers skip the prefix) and the `changes` table itself
  (`ledgerTables` in `ledger_seal.dart` keeps it out of the digest, the compare
  and so of `combine`; `replaceAllFrom` neither clears nor copies it). Two
  ledgers holding the same rows give the same digest whatever their logs.
- **Ids:** `sync.ledger` is given to a ledger made here (`onCreate`) and anew by
  an erase; a ledger upgraded from v19 gets none, since it may already be shared,
  and takes the folder's in step 3. `sync.applied` is reserved, written by
  nothing yet. Open for step 3: a restore copies the backup's `sync.ledger` and
  `sync.applied` in (right for the id: it is that ledger now; decide for the
  vector).
- **Rules from the code review (2026-10-12), kept:** each trigger names only
  the columns the file really has, so a column an old upgrade left out can't
  make every write fail at the trigger (the chain upgrade tests assert none is
  missing); `recursive_triggers` is on, so an `INSERT OR REPLACE` logs delete
  then insert, the truth; no column may be a blob; the hold nests; an erase
  keeps the log before its marker (its undo puts the rows back, and step 3 may
  still owe the other computer a change made just before). **From v20 on an
  upgrade either changes no row, or is deterministic (no `newRowId`, no clock),
  or runs with the triggers in place**: an upgrade's writes are otherwise never
  logged (the triggers are made at its end), and one like v13's `_oneIncome`,
  run on each computer apart, would leave two ledgers differing on rows neither
  ever sends the other, which the digest guard of step 5 would only report.
- Tests: `changes_test.dart` (every ledger table has its three triggers and is
  one `combine` knows; a purchase is its rows by name; before and after; a no-op
  update and the `sync.*` settings leave nothing; `applyCombined`, a restore, an
  erase; the digest ignores the log; the write paths a person uses each leave a
  record); `migration_test.dart` "upgrades a v19 file".

**Built, 2026-10-12: step 2, one id for the same thing made on both.** A row two
computers would each make on their own from the same fact gets the same id on
each (`sharedRowId(kind, key)`, `domain/sync.dart`: FNV-1a of the kind and key,
in a range of its own, [2^62, 2^63), above anything `newRowId` gives for a
century and above `carriedRuleId`'s). So the two computers hold one row, not two,
and nothing has to be matched by what it says.

- **What gets one:** the payday of a pay on a date (`payday|<pay id>|<date>`),
  the bill of a plan on a date (`bill|<category id>|<date>`), a phone's entry
  (`phone|<device>|<entry id>`), a bank row by its import key (`bank|<key>`), a
  payee by its exact name (`payee|<name>`), a spending category by its name and
  currency, lower-cased (`category|<currency>|<name>`: typed on both, made for a
  phone's new category, or made by an import for Not categorized; a bank
  account isn't, two of one name may be two accounts), Income
  (`category|income`), the Safety net (`category|safety-net|<currency>`). A
  transaction's entries take `<key>|0`, `<key>|1`, so they match too. All through
  `postTransaction(shared:)` and `_freeId`.
- **A row already under the id here** (a payday skipped and scheduled again
  after the pay changed back, an import undone and run again, a category made
  and deleted) makes the new row fall back to `newRowId`, as any other row. The
  old matching by what a row says (`_sameScheduled`, `_samePhoneEntries`,
  `_sameBankRows`, `_samePayees`, `_sameCategories`) stays as the backstop, for
  rows made before this and for those fallbacks.
- **In `combine`:** two rows under one id that neither ledger's base had are no
  longer "made on both, not the same" and the whole-ledger question. The same
  but for when each computer wrote them: one row, the earlier `created_at` and
  the later `updated_at`, and not counted as a change to the person. One side
  still the waiting payday or bill and the other the confirmed paycheck: the
  waiting one is the base the other was made from, and the confirmed one is
  kept, whichever side. Income or the Safety net named or ordered differently
  on each (a label): this computer's stays. Anything else (two confirmations
  of one payday for different amounts, two rows under one id from a build
  that counted from 1): a block in the row window, not the whole ledger. (For
  such a block there was nothing before either computer made the row, so
  "Neither: as it was" and the "As it was" line aren't offered, `Ask.hasBase`;
  step 4, which rewrites the policy, may give a shared-id unit the waiting
  version as its base.) A payee renamed on the other computer counts as a
  change (the popup says so); a new payee comes with its row and doesn't.
- **The digest ignores when a row was written** (`created_at`, `updated_at`;
  `ledgerDigest`). Two computers that each scheduled the same payday wrote it at
  different moments and hold the same ledger; without this each would find the
  other "changed", merge the two times, write, and the first would then take the
  folder's whole ledger in with "Opened the ledger saved on …" for nothing. A
  person's change always changes something else as well.
- **A merge that settled only what the two had made alike** (`CombinedIn.quiet`:
  nothing counted, nothing alike, no block) says nothing on screen and leaves
  the undo stack alone.
- Tests: `two_computers_test.dart` "the same payday, phone entry and bank rows
  get one id on both computers" (two real ledgers: the ids agree, the entries'
  too, and the two are one ledger with nothing to write or say), "a shared id";
  `combine_test.dart` "a payday both scheduled under one id" (merged times;
  confirmed on one; two confirmations, a block), "Income made on both under one
  id"; the digest test "when a row was written is no part of it".

**Built, 2026-10-13: step 3, the folder cycle on change files.** Each computer
writes one file in the folder that only it writes; every computer reads the
others'; `Ledger.betterbudget` is written only by a computer that holds
everything it holds and more. Nothing is ever written over another computer's
file, so there is nothing to lock and nothing for a sync service to make a
copy of.

- **The file** `Computer <id>.betterbudget-changes` (`data/change_file.dart`):
  encrypted like the phone's, a header (the computer's id and name, which
  ledger, the tables' version, its vector, its first and last change) and its
  `changes` rows, name-keyed. Written whole and in place, as `_put` writes the
  ledger, when the log has grown or the vector moved (`_publish`). All of the
  log, for now (compaction is step 5).
- **The look** (`CloudFolder._syncLogs`, taken when both the folder's ledger
  and this one carry a vector; until then the older look, whose write stamps
  the vector, `sealAs`, or whose "identical" adopts it, `adoptSeal`): the
  folder's ledger must be what its seal says (a blind write by an older build
  is still asked about); one ledger id, taken from the folder by a ledger that
  has none, and two that differ are two ledgers, never folded; this computer's
  file is written; then each other computer's file is read from a copy, its
  changes past this computer's vector taken, in order of computer id. One
  whose header says it rests on a third computer's changes that aren't here is
  waited for ("arriving"); one from a build with newer tables holds everything
  (`newerApp`); one holding a `restore` or `erase` marker is the whole-ledger
  question until step 5. The first file with changes to bring in is **folded**
  (`domain/fold.dart`) into the three ledgers `combine` compares: the common
  ground is this ledger with this computer's own changes since the other last
  saw it taken back; the other's is that with its changes made; the base is
  the common ground, except where the other's first change found a row
  otherwise (then what it found, the safer base) and except where one of its
  changes found the row as it is here now (it saw this version and chose over
  it: this row is the base). So **all of `combine` survives**: its units, the
  row window, the money checks, the dedupe backstops, `Ask`/`Pick`; only its
  three inputs are made differently. What the person would call nothing (the
  same rows made on both, settled times, a phone's list) is applied in the
  look itself, and the vector moved; anything else is left for the screen
  (`combine`, `rows`, `apart`) as before, one computer's file per round. Then,
  with nothing pending, the folder's ledger is written when this computer's
  vector covers the folder's and the two differ; a folder ledger ahead on a
  computer whose file hasn't come is waited for, or, when it holds every change
  of this computer's, taken in whole (`newer`), which also covers a file
  compacted past this computer later.
- **An answer travels as a change** (`Resolution`, written into this
  computer's own log by `applyCombined`): for every row of a thing both
  changed, the row as the other computer had it and as it is now, whatever was
  chosen, so the other computer's fold finds a change that saw its version and
  takes the answer instead of asking the same question. **"Keep this
  computer's ledger"** on change files is the same, over everything the others
  changed that isn't here, published at once; its undo can't take a published
  decision back and says so (`FolderMovedOn`).
- **A ledger taken whole from the folder** (`replaceAllFrom(fromFolder:)`: a
  new computer, Open ledger, Restore from… with Share) clears this computer's
  log: what of it was ever written is in the folder's ledger, and the rest was
  replaced. The numbers go on from where they were (AUTOINCREMENT), and the
  file's `first_seq` tells a reader that what came before was dropped on
  purpose. A plain restore here leaves a `restore` marker: the other
  computers' changes still come in on top of the restored ledger (a restore
  takes back nothing another computer did, ADR 0004), and the other computers
  ask the whole-ledger question about this one until step 5.
- **"Looks the same as one already here"** now knows what this computer made
  since the other last saw it from this computer's own log (`combine(madeHere:)`),
  since the fold can't show it.
- **The vector** is `sync.applied` in the ledger: for every computer, the last
  change of its this ledger holds, this computer's own entry its last change
  when it last wrote the folder's ledger; the folder's ledger carries it, so a
  new computer starts from it. `markApplied` and `applyCombined(applied:)`
  move it; it never goes down.
- **Tests:** `change_file_test.dart`, `fold_test.dart`, and the whole of
  `two_computers_test.dart` "two computers and one folder", which now runs on
  change files from each computer's first write (a stale computer brings the
  week in and the other brings its change back; a computer that changed
  nothing brings the other's in and writes nothing; a put-back ledger isn't
  taken for an old one; a folder whose ledger moved on is brought in; a folder
  holding another ledger is left alone; keep-mine travels; an answer travels,
  for mine and for neither; a restore here; the agreed file not needed; round
  after round; alike), and `cloud_folder_test.dart` through the real screen.
- **Rules from the code review (2026-10-13), kept.** *The transition:* a
  write by the older look carries the folder ledger's id and vector on
  (`sealAs(applied:, ledger:)`: the vector merged by the highest of each, the
  id taken when this ledger has none, never a second invented) and marks the
  file as written whole (`sync.whole`, a token); a reader on change files
  whose own ledger doesn't carry that token takes the file whole, as the older
  look would, when it holds every change of this computer's, else asks: so
  the second computer to upgrade, with changes its log never saw, joins the
  first with nothing lost. *The vector's own entry never goes down:*
  `lastChangeSeq` is the table's AUTOINCREMENT counter, which a cleared log
  keeps, so a ledger taken whole from the folder isn't taken again on every
  look. *Merges are symmetric:* deleted or put away on both takes the earlier
  time on both; Income or the Safety net made on both under one id keeps the
  same one of the two on both (the smaller row); so the two ledgers agree to
  the byte, and the folder's ledger is rewritten only when the rows differ,
  never for a vector alone. *Answers that crossed* (both asked before either
  answered, each choosing over the other's version; known by that shape, not
  by timing): the lower computer id's answer stands on both; the other takes
  it and writes down that it did (a `resolve` of its own), so the winner
  doesn't take the loser's earlier answer in turn. *A gap in a change file*
  (its first change past what was applied here): passed over when the folder's
  ledger doesn't hold the dropped changes either, else the folder's ledger is
  taken whole. *An empty change file* still moves the reader's vector to the
  writer's last number; another ledger's change file is passed over (the
  question is the other computer's, whose folder ledger differs); a computer
  never takes whole a file it wrote itself (back on a folder it left). *"Keep this computer's ledger"* on change files has
  no Undo (the choice went out at once), passes over files from a newer build
  or another ledger, and is written whole only on the older look. Answers are
  logged as `resolve`, told apart from this computer's own changes.
- **Rough edges, for step 5:** an erase while the folder's ledger moved on
  falls back to the older look, whose counts aren't kept up on change files,
  so the erasing computer is asked the whole-ledger question first and "keep
  this computer's" writes the new ledger; the other computer then sees
  another ledger id and is asked too. A third computer never gets changes a
  computer took in whole (they are in no change file).
- **Left for steps 4 and 5** (as written at step 3; step 4 below took the
  first): the facts-first provisional winner (today a
  crossed change asks on whichever computer reads it first, and the answer
  travels; both asked before either answered is settled by the lower id);
  a `restore` or `erase` as a batch of its own (today the whole-ledger
  question); compaction and the catch-up take; the red line's words for a file
  waited for (today the "can't be read yet" line); the digest guard at equal
  vectors; `cloud-folder-agreed`, the counters and the seal still written for
  the older look.

**Reversed, 2026-10-20 (0.41.0): asked before, with two computers too.**
The owner chose the asking window over told-after on seeing it (ADR 0004,
"Two computers: asked before, after all"). `many` is always true in
`_look`, so a crossing is asked as with three or more computers. The
settling described below, the popup that stayed and a version picked
afterwards were removed in 0.41.1 (#218); the names below are history.

**Built, 2026-10-17: step 4, settled the same way on both, told after.** A
change crossed with another computer's (the row here is neither what the
other found nor what it made) is no longer held for a question. Every
computer settles it the same way the moment it reads it, with no clock, and
the person whose change was replaced is told in the popup for the other
computer's changes (ADR 0004, "Two computers, step 4: told after, not asked
before"). No schema change: every row already in a ledger file stays as it
is.

- **The rule** (`combine(mineFirst:)`, `_settle` and `_settleRow` in
  `domain/combine.dart`), for a transaction with its entries, an amount
  assigned for one period, or one row of anything else: first a fact, then
  the order. *Deleted on one and changed on the other stays*, with the
  change. *A reconciled row keeps its money* (its date, and its lines in bank,
  cash and credit accounts as reconciled), with the other's payee, memo and
  categories where it changed them; *a row matched to the bank* (an
  `import_key` on one side only) *beats a typed one* the same way (`_merge`).
  The categories come along only when they still add up to the kept money:
  one category line in a currency takes the amount, a split that doesn't
  add up stays as the fact's side has it. Otherwise *the lower computer id's
  version* (`mineFirst` is `me < them`). "The batch with more knowledge"
  needs no rule of its own: a change made after seeing the other's version
  finds that version (`foldChanges`' "saw this"), so it is never a crossed
  change at all; and where the order kept a computer's own version, it writes
  that down (below), so its later edits are found that way too. "Later edit
  wins" is never a rule, and two amounts assigned for one period are never
  added and never "the larger".
- **What each kind does.** An amount, date, payee, memo or category changed
  two ways; a payday confirmed on both for two amounts (one id, one row);
  a bank row both have, filed two ways; an amount assigned two ways: the
  rule above, told. A pay (`pay_schedules`) or a plan (`category_plans`)
  changed on both: the whole row of the one the rule keeps (a pay's days
  make no sense taken from two answers), told. An account, category or payee
  renamed on both: **one name on both, by the rule, told to the computer
  whose name was replaced.** The decision of 2026-10-12 said "keeps this
  computer's name": that can't converge (each would keep its own and the two
  ledgers would never agree), so it is settled like everything else and
  said. A setting changed on both (not one that only changes a view): the
  rule, told. An account or category deleted on one and used on the other:
  it stays, on both, and the computer that deleted it is told. Two rows of
  one bank row or one payday made before step 2 under two ids (the
  backstops `_sameBankRows`, `_sameScheduled`): one of the two, by the rule.
- **Written down, both ways** (`_keptOver`). Whatever this computer settled,
  it writes, as a `resolve` in its own log, every row of the thing as the
  other had it and as it is now, the rows only it had as gone. Two reasons,
  both found by the property tests: the other computer, reading it, takes it
  as an answer instead of settling again from what it had; and this
  computer's own earlier change of the thing, made before it saw the
  other's (a delete, say), is passed over instead of arriving on its own
  afterwards and undoing the settlement (the vector in a change file's
  header is the writer's now, not as it was at each change).
- **Told on the computer whose change was replaced.** Settled on this
  computer, each thing says whether something this computer changed (from
  what it was) isn't in what both keep now (`Ask.replaced`, `_lost`): its
  amount, its categories, its date, payee or memo, whether it is deleted, or
  the amount assigned. Its own filing put beside the other's kept money is
  not a replacement. Settled on the other computer first, the other's
  `resolve` that found this computer's own version and made it something else
  is an *answer over mine* (`foldChanges` gives it back in `answered`, with
  the base taken from this computer's own change, read from its whole log):
  the other's version is taken whole, and this computer is told. A `resolve`
  that only says what was already here, or one whose row the other's own
  change found as it is here (an ordinary edit), is no answer over anything.
  The computer whose change stood is told nothing beyond today's popup.
- **On screen** (ADR 0004): the popup for the other computer's changes, gold,
  with one whole sentence, or a count for more, stays until it is closed or
  Show is clicked; Show opens the row window as a thing already done
  (`_RowsDialog`, `_showSettled` in `ledger_screen.dart`). A button changed
  there and Done is this person's own act: an ordinary change
  (`AppDatabase.applyChangesHere`, logged as any edit, `rowOpsBetween` from
  the rows as they are now to the version picked, `rowsOf`), which the other
  computer takes in and isn't told about, with undo and redo through `_did`.
  For a name only the name is set (`Ask.columns`). What was replaced is in
  Backups (`Backups.keepBefore`, as before every bring-in).
- **Nothing is held back.** `FolderStanding.rows`, `CloudFolder.asks`, the
  person's picks kept for a folder ledger (`_decided`, the `decided` entry of
  `cloud-folder`, no longer read or written) and `bringIn(picks:)` are gone;
  so are "Not now", "Save my choices", and the red "changed on another
  computer too" line in Settings with its Choose… for this case.
  `combine` without `mineFirst` still asks (`Combined.asking`, `Pick`), for
  its tests; the folder never calls it so. The older look (`_combinable`,
  until both computers carry a vector) settles the same way, with the folder
  ledger's writer as the other computer.
- **Still the whole-ledger question:** a `restore` or `erase` marker, a file
  from a newer build or another ledger (step 5), and what `combine` can't put
  together at all: one account reconciled on both, a row added cleared inside
  a statement the other reconciled (the ADR's "arrives uncleared with a
  note" is not built), a folder ledger that lacks a transaction both had (a
  ledger replaced whole), a setting that names a category both made, and a
  phone's entry taken in on both and changed on one before step 2's ids.
- Tests: `two_computers_test.dart` "settled the same on both", for each of
  ten kinds and three orders (the Mac settling first, the laptop first, both
  looking before either brings the other's in), asserting equal digests,
  who was told, and what stands; "nothing is held"; a version picked
  afterwards, for "this computer's" and "neither"; `cloud_folder_test.dart`
  through the real screen (the sentence, the window, Esc, Done, undo and
  redo; goldens `two_rows_told.png`, `two_rows.png`).

**From the reviews, decided (2026-10-18).** The code review's adversarial
tests and the budget review found these; each was decided along the lines the
owner gave, and is tested.

- **What the other had seen, not equal values.** A change of the other's
  "found this version" only when its writer had applied this computer's change
  that made it. Each computer now writes down in its own log, as a row of op
  `applied` (table `sync`, the vector as `after`), what it has applied of the
  others whenever rows came in (`AppDatabase._noteApplied`; not for a batch of
  nothing but such notes, or two computers would note each other's notes for
  ever), and when it takes the folder's ledger whole. The change file carries
  them like any row, says that it does (`notes_applied` in its `computer`
  table), and gives the reader, per change, what its writer had of the reader
  (`ChangeFile.knewOf`, `FoldChange.knew`). An older file without them is read
  as before. **No schema change**: the `changes` table is unchanged, the note
  is a row of it with a new `op`, and the fold and `combine` pass over it.
  Where the other changed a row this computer also changed after what the
  other had of it, the two are compared column by column by which each
  changed (`_apart` in `fold.dart`), not by values: an amount, memo or tick
  both came to apart, or changed and changed back, is no common ground. A
  column both changed with no earlier value that differs from both gets a
  made-up base (`madeUp`), and such a thing is never offered "Neither: as it
  was". An answer of the other's is "the other settled over mine" only when it
  is its last word on the row; a change it made after is crossed as any change.
  The other's answer that only says what this computer already started from
  is nothing new. Answers that changed nothing never count as answers that
  crossed.
- **An amount assigned is one row.** A category's amount for a day gets a
  shared id, `sharedRowId('budget', '<category>|<date>')`, like a payday, so
  two computers assigning it are one row changed two ways, never two rows
  added together. Rows already in a ledger keep their ids; two sets of rows of
  one (category, day) holding the same amount are settled to one set by the
  rule and written down for the other, and nothing is said (the amount is the
  same). The same shape (each computer's own row for the same amount, then a
  later change counted twice) is in the code on main, where step 3 asked
  instead of settling; it was not run there.
- **Three or more computers are asked.** The rule is exact for two. When the
  folder or the vectors show a third computer, a row changed two ways is
  asked about as step 3 did (`FolderStanding.rows`, held, the red line and
  Choose… in Settings, the window with Not now and Save my choices), never
  taken as ok.
- **The locks stay when a version is picked afterwards.** On a row whose kept
  money is reconciled or matched to the bank, every version in the window
  keeps that money, cleared state, `reconciliation_id` and `import_key`; the
  buttons change only the payee, memo and categories, and the card says so.
- **By part.** A transaction is four parts: its money (amount, account,
  date), whether it is cleared (with its reconciliation or bank match), its
  payee and memo, and its filing (the categories; one category is its name,
  a split its categories with their amounts). A part only one computer changed
  is kept; a part both changed goes by a fact (the reconciled or bank-matched
  side's money and tick are a lock, the other's payee, memo and categories
  come in) or else the lower id. When a row was written is never a change. A
  transaction's lines changed apart a line at a time are settled as one thing.
- **From the re-check (2026-10-18).** The lock is worked out again from the
  rows as the ledger holds them when the window is opened and when a pick is
  put in (`lockedVersion`), so a row reconciled after it was settled keeps
  that money; and `applyChangesHere` never changes a reconciled line's money
  or reconciliation, nor its transaction's date (a pick that would take one
  away is refused whole). What the popup says is kept in the encrypted
  ledger as `sync.told` (each computer's own: not in the digest, never
  combined, not logged, removed by a restore, an erase or a ledger taken
  whole, and by stopping the folder), with the ledger's id; a plain file a
  build before kept beside the ledger is deleted at launch. A third computer
  is one whose change file is in the folder now, of this ledger; an id met
  only in a vector is none.
- **Tests:** `two_computers_test.dart` "settled the same on both, under
  stress", run with the Mac's id the lower and then the higher: crossed twice
  in three orders, renamed and put away, changed in different parts in three
  orders, an independent edit to an older amount, one amount assigned on both,
  old rows of one amount, a version picked on a reconciled and a bank-matched
  row for each button, three computers, and a seeded random run of edits,
  looks, bring-ins, renames, amounts assigned and ticks over 40 seeds (1,000
  runs passed once while building it).

**Left for step 5:** a `restore` or `erase` as a batch of its own (today the
whole-ledger question); compaction of old changes and the catch-up take;
cleanup of `(1)` copies; the red line's words for a file waited for (today the
"can't be read yet" line); the digest guard at equal vectors;
`cloud-folder-agreed`, the counters and the seal still written for the older
look; settling by the rule with three or more computers (today asked, as step
3 did); and a soak on two Mac accounts through Drive, then two machines.

### What a phone can and can't do

| Can | Can't |
|---|---|
| Add a transaction, money out or money in: amount, payee, category, account, date | Edit or delete transactions already in the ledger |
| Split one over several categories (owner, 2026-10-17) | |
| Fix or delete its own entries until the Mac takes them in | Fix another phone's entries |
| See what's left in each budget, and account balances | Reconcile |
| Make a new category, by name (owner, 2026-10-08) | Change budgets, accounts, other categories or settings |

Mistakes in older transactions are fixed on the Mac.

**A new category from the phone** (owner, 2026-10-08: "In a pinch, if they're out of
the house, they should be able to create a new category. I know this deviates from
what I said earlier"). It is an inbox item like an entry: a random ID, a name and a
currency, with nothing assigned until that is done on the Mac. The phone's entries can
be filed in it at once. When the Mac takes it in, a category already called that
(whatever its capitals, archived ones included, which the phone can't see) is used
instead of making a second.

**A split from the phone** (owner, 2026-10-17: "It needs to be able to split";
option A of two sketches, the split page). An entry shared over categories is filed
under the word `split` and its lines travel in their own table in the phone's file
(`entry_lines`: entry, category, amount). A computer from before splits finds no
category called `split` and leaves the entry with the phone, as it does a transfer it
can't read, rather than filing it wrong. The computer takes it in as one split row
when its lines are in the account's currency and add up; otherwise it waits on the
phone. A line whose category was deleted on the computer while the entry waited comes
in as Not categorized (owner, 2026-10-17: asked whether it should, "Yes, do that"), so
the account's balance is right and the Not categorized tab asks about it; the phone's
waiting list says so beforehand. "Left" counts each line in its own
category.

From the reviews of the phone split, decided (2026-10-17):

- **A waiting entry is opened and fixed, not only deleted.** Tapped in the waiting
  list, it opens on the entry screen as it was (a split with its split page's lines),
  which says "Changing an entry that's waiting"; Cancel leaves it as it was. Save
  puts the fix in its place under the same id, so the computer never gets both;
  Delete stays. Opening one while something is typed asks first. If the computer
  took it in before Save, what was typed isn't lost: it is saved as a new entry and
  the toast says so ("Fix or delete the first one on your computer"). A fix that
  reaches the folder after the computer has read the first one is a case the phone
  can't see: the computer keeps the first, as it never takes an id twice.
- **A return on the same receipt** (a ₮37,500 shirt back, ₮50,000 of groceries
  bought): a line on the split page is marked **Returned** (on money in, **Spent**),
  offered on the line being typed, and its share counts the other way. It travels as
  a line signed the other way, which the computer already takes in as one split row
  (no change to either file). Returns that come to more than was bought make the
  receipt money in, each line kept going the way it was marked. Income has no such
  mark. A receipt whose returns equal what was bought comes to nothing and isn't
  saved.
- **The toast after a split** is red only on the line whose category is overspent.
- **Money out on the phone is ordinary ink with its minus** (the entry's amount, the
  split page's total, the waiting list), as on the computer; red is for a shortfall
  (overspent, overdrawn).
- **A second tap on the category just picked** only closes the list: for as long as a
  double tap takes after a line of the dropdown is tapped, the phone takes no tap, so
  it doesn't land on the Date row or "+ Another category" under where the list was.

### Numbers on the phone

A budget's "left" = the snapshot's figure − entries not yet taken in, from every phone's
inbox. The phone shows how fresh each source is (for example "From your Mac, Tuesday
21:40" and "Jen's entries as of 14:32"), because the numbers are only as current as the
last sync.

### On the Mac: entries go straight in (owner, 2026-09-24)

Phone entries land in the register as ordinary uncleared rows, with a toast ("3
transactions from your phone") and one ⌘Z that undoes the whole batch. Reconcile
catches mistakes, as it does for any uncleared row.

## Rejected

- **Connectors (Drive or OneDrive APIs in the app).** They break "nothing leaves the
  machine", need a login and code for each service, and Google charges a security
  assessment for full Drive access.
- **Full two-way sync with a KeePass-style merge.** It works, but needs random IDs on
  every table, change timestamps, duplicate detection and reconcile-conflict handling.
  Not worth it for a phone used to record purchases and check budgets.
- **A "From phone" review list on the Mac.** One more place to check. Straight in with
  undo follows "warn, don't block".
- **Live updates between phones.** That needs a server. The owner accepts that sync takes
  seconds to a couple of minutes and waits for signal.

## Consequences

- The database schema doesn't need random IDs. Only inbox items do.
- The phone UI is two screens (entry, budgets), not a phone-sized register. Since
  2026-10-08 it opens on the entry (ADR 0004 "Phone screens: Ledger first").
- Budget views on the phone depend on the budget existing on the Mac first ("ledger
  first, then the budget").
- **Before choosing a service, test** how a shared folder shows up in Files (iOS) and the
  system picker (Android) for Google Drive and for OneDrive, on the owner's and Jen's
  actual phones.
  - **Android with Google Drive, tested 2026-10-07** (Pixel 10a, Android 17, a
    throwaway screen in `app/lib/spike/`): Drive is offered in the system folder
    picker; an account's top level can't be chosen, a folder under My Drive can. The
    permission survived the app being closed. A file the phone wrote was on the Mac 5
    seconds later; a change made on the Mac was not yet on the phone after 17 seconds
    and was there after 60. **Not tested yet:** with no signal, a folder shared from
    another account, OneDrive, and all of iOS.
- Store setup: Apple $99/year, Google Play $25 once plus a 14-day closed test with about
  12 testers for new personal accounts. Both stores need a privacy policy URL. Both
  privacy forms can declare no data collected.
- The Mac App Store is the cheapest first step: the app is already a Mac app, and needs
  sandboxing plus access to files the user picks.

## Where a row came from (2026-10-13, schema v21)

Asked by the owner while watching the first run on two Mac accounts, to know where a
transaction was made ("a small transaction that shows the original source"), as an
optional column that can be turned off, and then to be able to "list a given phone as a
source".

- **Two columns on `transactions`**, `made_how` (`typed`, `imported`, `phone`,
  `scheduled`, `opening`, `adjustment`: `MadeHow` in `domain/sync.dart`, never
  renamed) and `made_on` (the computer's name as it read then, for a typed or imported
  row; the phone's own id for a phone row; null for the rest). Set when the row is made,
  never changed. The upgrade adds both empty and touches no row: a row already in the
  ledger says nothing about where it came from, because nobody knows.
- **By id, with the name beside it.** `made_on` holds the computer's id (the one its
  change file is named by). The name is a setting, `computer.name.<id>`, written once
  after the first look at the folder as what the system calls the computer, and
  renamed by the person in Settings → Register: every row keeps the id, so a rename
  shows on every row (owner, 2026-10-13: "the name should be associated with a primary
  key, so it's fine if they update the name"). A row made on the computer reading it
  says "here". Two accounts of one Mac are two computers with two ids.
- **A phone is named the same way.** The phone only has a random id, the same on
  every computer that takes its entry in. Settings lists each phone that has sent a row
  with a box to name it, kept as the setting `phone.name.<id>`; an unnamed phone reads
  "From your phone" while it is the only one, then "From phone 7b8a". Rows from phones
  before v21 can't be told apart and say nothing.
- **Not part of what two ledgers hold.** The digest ignores both columns, as it does
  `created_at`; one bank row imported on both computers is one row under one id, and
  `combine` keeps the smaller of the two words on both so they agree (`_sameMade`). A
  row from a computer before v21 has the columns empty (`_withMadeBy`). A name set two
  ways on two computers is the smaller on both, and the Source setting is a view that
  nobody is asked about.
- **Optional, on at first.** The register's Source column is shown, and a Register panel
  of Settings turns it off and names the computers and phones. A view choice, kept as
  the setting `register.source` (`0` is off; on is the absence of the setting), like
  the forecast's span, so it is shared with the other computers.
- Rejected: reading the source from the change log (it forgets after a restore or an
  erase and will be compacted), and a mark on the row instead of a column.
- **A rule that came from a bug (2026-10-13):** a computer's id is made, or read, only
  after the saved folder settings are read. `cloud-folder` holds the id, the folder,
  its token and what was published in one file, and writing it before it is read
  writes it without the rest. `CloudFolder.computerId` waits for `load`.
- **The same Mac is "here" (2026-10-13, 0.34.0).** Two accounts of one Mac are two
  computers with two ids, but to the person they are one machine ("since it's the same
  computer, it's local on both accounts"). Each computer writes the setting
  `computer.machine.<id>`: a hash of the Mac's hardware id (`MainFlutterWindow.swift`
  `machineId`, `FolderAccess.machineId`; null where there is none), shared by every
  account on that Mac. A row made on a computer whose machine is this one's reads
  "Entered locally". Two different Macs never share it.
- **A computer's id is worked out, once (2026-10-13, 0.34.0).** A computer with no
  saved id takes a GUID made from the Mac's hardware id and the macOS account
  (`FolderAccess.derivedComputerId`, `guidOf`), so the same computer is the same id
  after a reinstall or a lost `cloud-folder`; a random one only where there is no
  hardware id. One already saved is never replaced (owner chose "A": no churn: its
  change file and what the others applied of it are under it). A disk cloned to
  another computer still gives both the same id.


## The phone's ring (2026-10-26)

The computer's Budget page got a ring before each everyday category's name: how
much of what it had this period is used, green through gold to red (ADR 0004 "How
used up a category is: a ring before the name"). The phone's Budget screen has the
same ring before each category's name, since the phone works the budget out from
the ledger copy itself (`snapshotOf`): the snapshot carries what each category had
this period (`PhoneCategory.hadMinor`, null for a category saving for a bill), and
the share is worked out on the phone against what's left now (`usedShareNow`), so
an entry typed on the phone moves its ring before the computer has seen it. Nothing
in the folder's files changes. A category made on the phone and not yet in the
ledger has no ring (nothing had yet); the categories under Bills have none, as on
the computer.
