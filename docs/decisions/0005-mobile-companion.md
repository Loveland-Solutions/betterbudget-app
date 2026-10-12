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

Not built: a question about the one row in conflict, with the real values (decision
1). A conflict still asks which whole ledger to keep, and still shows only counts.
Two people who each choose "Keep this computer's ledger" replace each other's in
turn; nothing is deleted. A purchase both computers typed by hand is two rows, as
it would be typed twice on one. Not yet run on two real computers.

### What a phone can and can't do

| Can | Can't |
|---|---|
| Add a transaction, money out or money in: amount, payee, category, account, date | Edit or delete transactions already in the ledger |
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
