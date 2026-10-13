# Brief: how two or more computers should share one BetterBudget ledger

Repo: /Users/thomasloveland/Repositories/betterbudget-app (Flutter desktop app, Dart; `app/`).
Read these before anything else:
- docs/decisions/0005-mobile-companion.md, lines 182–460: "More than one computer on one ledger" — what was decided, what was built in steps 1–3, and what was rejected.
- app/lib/domain/combine.dart — the three-way row compare (base = file both last agreed on, mine, theirs). Top of file lists tables, keys, references.
- app/lib/data/cloud_folder.dart — the folder look/write cycle (`_sync`, `decideFolderMove` in app/lib/domain/sync.dart, `_combinable`, `bringIn`, `_put`).
- app/lib/domain/sync.dart — per-computer counters and the seal.
- app/lib/data/database.dart around `applyCombined` and `replaceAllFrom`; the schema is Drift/SQLite, encrypted with SQLCipher (sqlite3 package, "SQLite3 Multiple Ciphers" build), WAL mode. Double-entry: every write must leave each transaction summing to zero (ADR 0003, docs/decisions/0003-double-entry-schema.md).
- docs/decisions/0001-database.md if you need the encryption/key model.

## Hard constraints (owner's rules, not negotiable)
- Nothing leaves the user's machine: no server, no network calls, no account. The only channel between devices is a folder that the OS's own sync client (Google Drive today; OneDrive, Dropbox, Box possible) copies around. The app never talks to Drive's API.
- The owner's ledger is real, in-use data. A schema change needs an upgrade that keeps every row, with a test. For THIS work only, the owner has said the ledger file's form may change or the file may be replaced, if that is what a bulletproof design needs, asked first.
- Phones (Android built, iPhone planned) write their own small files into the same folder (one file per device, entries only); the computer ingests them. Phones read the computer's ledger file for balances. See ADR 0005 "All of the data lives in the cloud folder".
- "Warn, don't block": the person is never prevented from acting; they're told what will happen.

## What is built today (step 1–3 plus today's work)
Each computer has its own SQLite file. The shared file `Ledger.betterbudget` in the folder is written whole by whichever computer writes. Before every write, at launch, on foreground, and every 15 s, the computer copies the folder file out, reads per-computer counters + a content seal, and decides: same → nothing; folder is my last write or older → write; folder ahead and I changed nothing → take it in whole; both changed → three-way compare against the file both last agreed on (kept locally as `cloud-folder-agreed`), apply the other's non-conflicting changes row by row (`combine`), then write the union. Rows have ids that are unique across computers (`newRowId`: ms timestamp + random bits) so no renumbering. Today's uncommitted work: when both changed the same transaction (or one deleted it and the other changed it), or the same category's assigned amount for a period, the person gets a window listing each with both versions and "as it was", three buttons each (keep mine / keep theirs / neither). Nothing is written until answered, so only one computer is asked.

Still falls back to "choose which WHOLE ledger to keep" (which the owner does not want anyone to face): a bank row both imported and filed two ways; a pay or a category's plan changed on both; an account renamed on both; a setting changed on both; a reconciled row changed on the other side; and anything after a restore/erase on one side (no agreed base).

## The owner's position (2026-10-12, verbatim where quoted)
- "I don't want them to have to make this decision" (choosing a whole ledger). "We need to make a way where entries are ingested without replacing the entire database."
- "Databases are made for this type of thing, though. I feel like we should be able to leverage that." Their proposal: 1. app opens; 2. loads master DB into a local child DB; 3. session happens locally; 4. every X minutes and on proper close: a. check whether master changed since open; b. place a lock file telling other machines not to write; i. if nothing wrote, write; ii. if something wrote, check for conflicts.
- They are fine with a per-item question when two people truly changed the same thing two ways. They are fine with no Undo on that answer.

## Concerns raised so far (test these; don't just accept them)
- A lock file through Drive isn't atomic: Drive propagation is seconds to minutes, so two machines can each create a lock believing they hold it. Drive may also keep both versions as "Ledger (1).betterbudget" when two write in the same minute.
- A live SQLite database opened by two machines through a sync folder corrupts (partial copies of -wal/-shm, torn writes). That's why each machine keeps its own file and the folder file is written whole.
- SQLite's session extension (sqlite3session, changesets/patchsets with conflict handlers) is "databases made for this" — but is it compiled into the sqlite3 / sqlite3_flutter_libs / multiple-ciphers build this app uses (SQLITE_ENABLE_SESSION)? Check ~/.pub-cache for the package sources / build flags before recommending it. Also consider: a changeset log per computer in the folder (append-only, one file per device, like the phones already do) applied by every computer, with the "ledger file" becoming a derived snapshot.
- A permanent id + version/vector clock per row was weighed on 2026-10-09 and set aside for upgrade cost; the ids were later taken (`newRowId`), versions were not.

## What to deliver (no edits to the repo; report only)
1. The design you'd recommend, concretely enough to build: what lives in the folder, what each computer keeps locally, the exact read/write/merge cycle, and how it behaves when Drive is slow, offline for a day, or keeps two copies of a file.
2. For each conflict class below, what your design does, automatically or by asking, and why that's safe for money: same transaction edited both sides; deleted one side / edited other; same bank row imported both sides and filed differently; pay schedule or category plan edited both sides; account renamed both sides; same category assigned both sides same period; reconciled on one side while the other edits a row inside the statement; both confirm the same scheduled payday; one side restored a backup / erased and started over.
3. Failure modes of your design that a careful engineer would still worry about, ranked.
4. Cost: schema changes, upgrade of the owner's existing file, phones affected?, rough size of work in weeks for one developer, and what of today's code survives.
5. A frank verdict on the owner's master/child + lock-file proposal: what's right in it, what breaks, and what would make it work.
Keep it under ~1,500 words. Plain English; the owner reads these. Name files and functions when you refer to code.
