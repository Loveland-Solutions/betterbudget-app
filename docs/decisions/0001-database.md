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
  > tugrik is effectively a zero-decimal currency since the möngö is obsolete. Real TDB
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

## Encryption design (owner, 2026-09-24: "build it right the first time")

Targets: macOS, Windows, Linux, iOS, Android. The phone apps
([ADR 0005](0005-mobile-companion.md)) share files through a cloud folder, so a key
that lives on only one device isn't enough.

### Library

**SQLite3 Multiple Ciphers**, writing the **SQLCipher v4 file format**, selected in
`pubspec.yaml` (`hooks: user_defines: sqlite3: source: sqlite3mc`). `package:sqlite3`
builds it for every platform from one setting. It was chosen over the SQLCipher community
build, which links OpenSSL on Windows, Linux and Android and ships an older SQLite. The
files are standard SQLCipher v4, so other SQLCipher tools (DB Browser for SQLite's
SQLCipher build) open them with the key, which keeps "open your own file without us".
Each connection sets `PRAGMA cipher = 'sqlcipher'`, `PRAGMA legacy = 4`, then the
key as a raw 256-bit value (`x'…'`), so no slow key stretching on every open.

### Keys

- **One data key**, 256 random bits. It encrypts the database, every backup, and the
  phone snapshot and inbox files.
- **A recovery key** the user keeps (about 25 characters in groups, plus a check
  character against typos). The data key is derived from it (HKDF), so it alone opens the
  ledger and any backup on any device. Changing it means re-encrypting (`PRAGMA rekey`),
  which is rare.
- **Each device stores the data key in its own secure store** (`flutter_secure_storage`),
  never synced: Keychain "this device only" on macOS and iOS, Android Keystore, Windows
  DPAPI, and the Secret Service (GNOME Keyring or KWallet) on Linux. **Linux without a
  Secret Service asks for the recovery key at launch**, the only case where the user types
  anything (owner, 2026-09-24).
- **Adding a device:** type the recovery key. Nothing goes over a network.
- **The recovery key is shown once and never stored** (owner, 2026-09-28: "Treat it
  like any other key. Save it, copy it whatever, but you can only view it once, and the
  app doesn't store it"). The setup screen shows it on one line with **Save…** (a text
  file) and **Copy**, and says it won't be shown again. It's skippable (warn, don't
  block): a coral line says continuing without saving or copying means it's gone. Only
  the derived data key is kept, in the secure store, and it's never displayed. HKDF is
  one-way, so it can't be turned back into the recovery key. **Settings → Security**
  says the ledger is encrypted and that BetterBudget keeps no copy, in coral if the key
  wasn't saved or copied. It has no button. A build that stored the key (for "Show
  recovery key…") deletes that copy at the next launch.
- **Rejected (owner, 2026-09-28):** "Show recovery key…" in Settings. The owner:
  "that encryption doesn't seem that great if I'm able to view the master key at will".
  Anyone at an unlocked computer could copy the key and open every future backup. Also
  rejected: showing it behind Touch ID or the Mac password, and a QR code on the Mac for
  adding a device (it would re-show the key). Also rejected (owner, 2026-09-29): **making a new
  recovery key** (re-encrypting the ledger and backups). "No. One key or all the data
  is lost." A ledger has one recovery key for its whole life. Lose it, and the
  ledger and every backup can't be opened on another device. The setup screen's
  warning says so.

### Converting what's there

The live file is never changed until an encrypted copy has checked out: the `-wal`
is folded in (`wal_checkpoint(TRUNCATE)`), a copy is encrypted (`rekey`) and checked
(`quick_check`, same table count), and the copy is renamed over the file. A crash
before the rename leaves the plain file as it was. A `.before-encryption` copy left
by an older build's cut-short conversion is put back, or removed if the file is fine.
Every plain copy in the app's folder is converted too: the daily copies, the copies
made before each schema upgrade, and older folders. A copy that can't be converted is
reported by name ("still readable"), never allowed to stop the app from starting. The
app says how many were converted. A plain backup picked in Restore from… still
restores, and the result is encrypted.

### At launch (review, 2026-09-29)

- **A key is checked against the ledger before it's stored or used.** A key that
  doesn't open the ledger is never kept. If a stored key stops fitting (a new Mac by
  Migration Assistant, where "this device only" keys don't move), the entry screen
  comes back instead of a blank window.
- **A launch that can't finish says so, with Try again** (agreed with the owner,
  2026-10-09; built 2026-10-14). A Keychain that refuses the key (a locked Mac,
  -25308), a file that can't be read, a new key that can't be stored, or a ledger
  that fails to open, each puts up one line in ordinary ink ("Couldn't read the key
  kept on this computer"), what it means for the ledger where that is known ("Your
  ledger hasn't been touched."), a Try again button that does the failed step again
  without a relaunch, and the error itself behind Show details. No "unlock your Mac"
  line: the cause isn't always known.
- **A new key is shown before anything is stored or encrypted.** A quit or crash on
  the key screen leaves everything as it was, and the next launch shows a new key. A
  ledger from before encryption gets its key without being asked for one.
- **The entry screen says whether a ledger is here.** With an encrypted ledger here,
  "Start a new ledger instead…" warns in coral and moves it aside
  (`betterbudget.set-aside-<time>.sqlite`), never deletes it or opens it with a new key.
- **On a new computer**, after the key is typed, the app offers to open the newest
  backup (from Back up to…), with Start empty beside it, and no demo data (owner, 2026-09-29).
- **Check my recovery key…** in Settings → Security (owner, 2026-09-29): type the key
  and learn whether it opens this ledger. Nothing is ever shown.
- **A backup under another ledger's key** asks for that key and restores its rows under
  this ledger's key, so this ledger's key never changes (owner, 2026-09-29).
- **"Saved" is kept beside the data key, not in the ledger,** so a new ledger or a
  restore doesn't turn Settings coral. Copy doesn't clear the warning, it changes it to
  "paste it somewhere off this computer". The clipboard is cleared after a minute.
- The check character uses weights coprime to 34, so every single mistyped character
  is caught. Typing in Cyrillic says to switch to ABC. SQLite errors never carry the
  key into logs.

### Rejected

- **A key shown before that change is still taken** (2026-10-07). The weights were
  changed at 11:50 on 2026-09-29, after the owner's ledger had been given its key the
  night before, and from then on the app called that key mistyped: only the Keychain's
  copy of the data key opened the ledger, and the recovery key could not have brought
  it back on a new computer. It was found when the phone asked for the key. `parse`
  now takes a check character by either rule (the data key comes from all 25
  characters either way). The cost: about one single-character typo in 34 passes the
  shape check as some other key, which opens nothing, since a key is kept only after
  it has opened the ledger. **A change to how a key is read needs a test with a key
  made before the change.**
- **Key only in the device's secure store.** Backups in a cloud folder become unreadable
  the day the computer dies, and an Android phone can't read a Mac's Keychain.
- **A passphrase typed at every launch.** Forget it and every copy is lost, and typing it
  at a till to check a budget is too much. An app lock (Touch ID, Face ID, Windows Hello,
  phone PIN) can come later on top of the encryption, not instead of it.
- **The SQLCipher community build.** OpenSSL on three platforms and an older SQLite.

### Test build results (2026-09-24, this Mac)

- SQLite3 Multiple Ciphers 2.5.0 on SQLite 3.53.4 builds and runs on macOS. An **iOS
  build** (unsigned) bundles `sqlite3mc.framework`. All 179 app tests pass on it.
- A file with the key is unreadable without it. **`VACUUM INTO` copies stay encrypted**
  with the same key, so backups need no extra step. **A plain WAL file converts in place**
  with `rekey`. **Speed:** 40,000 rows written and read back in about the same time
  encrypted as plain (20–30 ms).
- **macOS Keychain (2026-09-28):** the app is now signed with the owner's Apple
  developer team (`5FJUXAJX9P`, "Apple Development", automatic signing) and has
  `keychain-access-groups` = `$(AppIdentifierPrefix)com.lovelandsolutions.betterbudget`
  in both entitlements files. The **data-protection keychain** works
  (`usesDataProtectionKeychain: true`, the default), with `unlocked_this_device` and
  not synchronizable, and a key written by one build is read by the next. Unsigned
  (ad hoc) builds fail there with −34018. The login keychain worked unsigned, but it
  isn't used, so there's nothing to migrate. The iOS project carries the same team.
- **Signing setup notes:** this Mac lacked Apple's "WWDR G3" intermediate certificate
  (only the one that expired in 2023 was installed), so the new certificate showed as
  not valid. Installing `AppleWWDRCAG3.cer` from apple.com/certificateauthority fixed
  it. The first development provisioning profile needed one `xcodebuild …
  -allowProvisioningUpdates` run. `flutter build macos` works after that.
- **Not yet verified:** Windows, Linux and Android. There's no Windows or Linux machine
  here, no Android SDK on this Mac, and no `linux/` runner in the app yet. The same
  prebuilt libraries exist for all three. Verify each when its build is first made, or
  in CI (a GitHub Actions matrix build) once CI exists.

## Where the ledger lives on Windows (owner, 2026-10-23, #246)

The zip download keeps the ledger, its daily copies, the saved key
(`flutter_secure_storage.dat`, DPAPI) and its small settings files in
`%APPDATA%\Loveland Solutions\BetterBudget`. The Microsoft Store app keeps them in
its package's own folder, `%LOCALAPPDATA%\Packages\<family>\LocalState`, which Windows
deletes on uninstall (owner: what's left behind on uninstall is garbage; the person
keeps their recovery key, and uninstall removes the saved one from the machine).
`data/store_folder.dart` asks Windows whether the app runs from a package and, if so,
hands path_provider that folder, so the key store follows too.

The Store app never looks in the zip download's folder. Left to Windows, a packaged
app reaching into AppData edits a file that's already there in place but sends every
new file beside it (the ledger's `-wal`, the daily copies, the files of two computers)
to the package: one ledger in two places, which the two builds see differently.
Someone moving from the zip download brings their ledger over with Open ledger, from
their folder or a backup, as a second computer does.

Rejected: the restricted capability `unvirtualizedResources`, so the Store app used
the zip download's folder for real (built and tried in 0.46.1, then dropped the same
day: it leaves the ledger behind on uninstall); a `BetterBudget` folder in the user's
home folder (left behind too); Windows' default with a line in Settings (the split
above).

The zip download has no uninstall, and macOS doesn't tell an app it's been dragged to
the Trash, so both still leave their folder behind.

## Open items

- **Verify the cipher library on Windows, Linux and Android** (see the test build
  results above). macOS and iOS are verified.
- **Attachment storage** (receipt photos as BLOB vs. on disk) is a separate decision.
  It affects whether the single-file backup story holds.
- **Double-entry vs. transaction + splits** is a separate decision. It does not change
  this one.
