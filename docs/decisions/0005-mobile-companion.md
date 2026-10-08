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
  twice. The phone reads that from the ledger's next copy and drops those entries;
  the computer forgets an id once the phone's file no longer holds it. Undone rows
  stay marked as in, so they don't come back by themselves.
- **The phone reads the folder again every 30 seconds** while it is open, as well as
  when it comes to the front, so the waiting line goes without the app being left.
- An entry whose account or category was deleted on the computer is left with the
  phone.

No table was added: the ledger's schema is unchanged. Not built: other phones'
entries shown on a phone, money in and transfers, and the iPhone's folder access. With
two computers on one ledger each would take the same entries in (the next section).

### More than one computer on one ledger (owner, 2026-10-07): wanted, not designed

"I definitely want to be able to support multiple machines on the same ledger. Let's
figure that out in a new conversation." Said when told that a second or out-of-date
computer writes its own ledger over the one in the folder. This record assumed one
computer and some phones: the computer is the folder file's only writer, and the full
two-way merge under Rejected was turned down as too much for a phone that records
purchases. Two computers that both edit the ledger change that, so the choice has to be
made again for them. Nothing is decided; [STATUS](../STATUS.md) "Next step" says where
the code stands.

### What a phone can and can't do

| Can | Can't |
|---|---|
| Add a transaction: amount, payee, category, account, date | Edit or delete transactions already in the ledger |
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
