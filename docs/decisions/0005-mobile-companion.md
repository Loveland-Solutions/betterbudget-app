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

### What a phone can and can't do

| Can | Can't |
|---|---|
| Add a transaction: amount, payee, category, account, date | Edit or delete transactions already in the ledger |
| Fix or delete its own entries until the Mac takes them in | Fix another phone's entries |
| See what's left in each budget, and account balances | Reconcile |
| | Change budgets, accounts, categories or settings |

Mistakes in older transactions are fixed on the Mac.

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
- The phone UI is two screens (entry, budgets), not a phone-sized register.
- Budget views on the phone depend on the budget existing on the Mac first ("ledger
  first, then the budget").
- **Before choosing a service, test** how a shared folder shows up in Files (iOS) and the
  system picker (Android) for Google Drive and for OneDrive, on the owner's and Jen's
  actual phones.
- Store setup: Apple $99/year, Google Play $25 once plus a 14-day closed test with about
  12 testers for new personal accounts. Both stores need a privacy policy URL. Both
  privacy forms can declare no data collected.
- The Mac App Store is the cheapest first step: the app is already a Mac app, and needs
  sandboxing plus access to files the user picks.
