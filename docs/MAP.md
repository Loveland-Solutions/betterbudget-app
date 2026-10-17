# Map of the app (`app/lib`, `app/test`)

Where things are and what calls what. For what a file does, read its header comment.
Paths are relative to `app/`. Checked against imports and class names on 2026-10-07
(schema v21 since 2026-10-13). **Update this file when a file is added, moved or renamed.**

Never open or list: `test/goldens/`, `test/failures/` (PNGs), `.dart_tool/`, `build/`,
`android/`, `ios/`, `macos/`, `windows/`.

## Layers

`lib/main.dart` → `lib/ui/` → `lib/data/` → `lib/domain/`. Imports only go that way.

- `lib/domain/` imports nothing outside itself. `lib/import/` is pure Dart too (it
  imports only `domain/money.dart`); `data/database.dart` and the UI use it.
- `lib/data/` reports problems as enums and exceptions; `ui/data_words.dart` words them.

## Launch, then the one screen

1. `main.dart` loads `AppearanceController` and `LanguageController` (small files beside
   the ledger) and hands `BetterBudgetStartup` a `KeyStore`, the ledger file and an
   `open` callback (`AppDatabase.openEncrypted`, `Backups`, the daily-copy timer).
2. `ui/startup.dart` calls `resolveDataKey` and `keyOpens` (`data/encryption.dart`), then
   shows `StartChoiceScreen` (`ui/start_choice.dart`: no ledger and no key here, three
   ways to start), `RecoveryKeyEntryScreen` or `RecoveryKeySetupScreen`
   (`ui/recovery_key_screen.dart`) or `LedgerScreen`, inside `FitWindow`.
3. `ui/ledger_screen.dart` (`_LedgerScreenState`) listens to `AppDatabase.watchLedger()`,
   which re-runs `loadLedger()` into one `LedgerData` (`domain/ledger.dart`) on any table
   change. Pages draw from that snapshot; writes are methods on `AppDatabase`. By
   `AppSection`:
   - ledger: `BalanceHeader` (holds `ForecastPanel`) or `ReconcilePanel`, then
     `RegisterPanel`, which holds `EntryRow` for a new row and for an edit
   - budget: `_BudgetPage`; savings: `_SavingsPage`; payees: `_PayeesPage`;
     settings: `_SettingsPage`
   - dialogs: `_ImportDialog`, `_PaySetupDialog` (a frame around `_PayForm`, which
     setup's Pay step also holds), `_RestoreDialog`, `_NewLedgerDialog`

**`part of ledger_screen.dart`:** `ui/accounts.dart`, `ui/budget.dart`,
`ui/import_dialog.dart`, `ui/pay_setup.dart`, `ui/payees.dart`, `ui/savings.dart`, `ui/setup.dart`. Their classes are
private, their imports go in `ledger_screen.dart`, and they are tested only by pumping
`LedgerScreen`.

## Feature areas

"Both ledger tests" means `ledger_test.dart` (database and domain) and
`ledger_screen_test.dart` (the real screen). `database.dart` sections are in quotes.

| Area | Domain / data | UI | Tests |
| --- | --- | --- | --- |
| Register, entry, edit | `domain/ledger.dart` (`RegisterRow`); `database.dart` "reads", "writes" | `register.dart`, `entry_row.dart` | both ledger tests |
| Balances, forecast | `domain/ledger.dart` (`AccountSummary`), `domain/forecast.dart` | `balance_header.dart` | both ledger tests |
| Reconcile | `domain/ledger.dart` (`Reconciliation`, `ReconcileHint`) | `reconcile.dart` | both ledger tests |
| Accounts | `database.dart` "accounts" | `accounts.dart`; sidebar in `ledger_screen.dart` | both ledger tests ("accounts") |
| Pay | `domain/pay.dart`; `database.dart` "pay" | `pay_setup.dart` (`_PayForm`); `_applyPay` in `ledger_screen.dart` writes its answer | `pay_test.dart`; both ledger tests ("pay"); `setup_test.dart` (the Pay step) |
| Budget, categories | `domain/budget.dart`; `domain/ledger.dart` (`CategoryPlan`, `BudgetAmount`); `database.dart` "categories" | `budget.dart` | `budget_test.dart`; both ledger tests ("categories") |
| Savings steps | `domain/readiness.dart` (`ReadyStep`: four; its names are stored, don't rename; `isSafetyNet`, the built-in category; a debt's rate `DebtRate`, kept as `ready.rate.<id>`) and `database.dart` `safetyNetCategory`; `_ensureSafetyNet` in `ledger_screen.dart` makes it at launch | `savings.dart`; `SavingsPicture` in `brand.dart` draws a step's picture from `assets/brand/savings-*.svg` | `readiness_test.dart`, `ledger_screen_test.dart` ("savings:") |
| Import | `import/sheet.dart` (`readSheet` picks `xls`, `xlsx`, `csv` or `ofx`); `import/mapping.dart` (`guessMapping`, `readRows`, `importKeys`); `database.dart` "import" (`planImport`, `applyImport`, `undoImport`) | `import_dialog.dart`; file picking in `ledger_screen.dart` | `import_test.dart`, `xls_fixture.dart` |
| Payees (the remembered categories) | `domain/payee_rules.dart` (`PayeeRuleInfo`: words, anywhere or at the start, accounts, category or pay, deleted; `pick`, `deletedBlocks`, `payeeWords`, `carriedRuleId`); tables `PayeeRules` and `PayeeRuleAccounts` in `database.dart`, section "payee rules" (`allPayeeRules`, `putPayeeRule`, `addPayeeRule`, `removePayeeRule`); `applyImport` follows them; `_carryPayeeRules` is the v19 upgrade from the setting `import.rules.<account>` (`PayeeRule` in `import/mapping.dart` still decodes it) | `payees.dart` (`_PayeesPage`, `_PayeeLine`, `_PayeeEditor`, `_fitting`); "payees" in `ledger_screen.dart` (`_savePayeeRule`, `_deletePayeeRule`, `_fileWaiting`); made from a row by `_alwaysOffer` and `_alwaysFile` there | `ledger_screen_test.dart` ("payees", 2 goldens); `import_test.dart`; `migration_test.dart` (v18) |
| Currencies | `domain/money.dart` + `domain/currencies.dart`; `l10n/currency_names.dart` | `theme.dart` (`Money`, `CurrencyScope`); `language.dart` (`currencyName`) | `money_test.dart`, `currency_test.dart` |
| Keys, encryption | `data/keys.dart`, `data/encryption.dart` | `startup.dart`, `start_choice.dart`, `recovery_key_screen.dart` | `keys_test.dart`, `encryption_test.dart`, `cipher_test.dart`, `startup_test.dart`, `recovery_key_screen_test.dart` |
| Backups, restore, new ledger | `data/backup.dart` (`Backups`; `CopiedElsewhere` and the file `copied-elsewhere` beside the ledger hold when "Back up to…" last worked, for the line under Net worth) | `_SettingsPage` in `ledger_screen.dart` | `backup_test.dart`, `encrypted_backup_test.dart`, `ledger_screen_test.dart` ("backups") |
| Ledger kept in a folder (ADR 0005) | `data/cloud_folder.dart` (`CloudFolder`: every look and write goes through `_sync`, which never writes `Ledger.betterbudget` without reading the one there; `FolderStanding` says how the two stand; `FolderAccess` keeps the Mac's bookmark and asks the computer's name, both in `macos/Runner/MainFlutterWindow.swift`); the setting, and this computer's id, are the file `cloud-folder` beside the ledger | `_keepInFolder`, `_stopFolder` and the "Stored in" line of `_SettingsPage` in `ledger_screen.dart` | `cloud_folder_test.dart` (3 goldens) |
| Two computers on one ledger (ADR 0005, "Never write blind") | `domain/sync.dart` (`SyncKeys`, the computers' counts, `decideFolderMove`); `data/ledger_seal.dart` (`ledgerDigest`, `lookAtLedger` for a ledger file that isn't the live one); `database.dart` (`sealState`, `sealAs`, `restoreSync`, `replaceAllFrom(fromFolder:)`); `Backups.restore(fromFolder:)`, `Backups.keepFromFolder` | `_firstLookInFolder`, `_lookInFolder`, `_openFolderLedger`, `_takeFolderLedger`, `_chooseLedger` and `_TwoLedgersDialog` in `ledger_screen.dart`; a second computer set up by `_restoreFrom` and `_RestoreDialog`'s checkbox (`CloudFolder.folderOfLedger`), or by Open ledger on the first screen (`_offerRestore`, `_openLedgerInFolder`, `_finishRestore`) | `two_computers_test.dart`; `cloud_folder_test.dart` ("two computers", through the real screen) |
| The folder cycle on change files (ADR 0005, "the way chosen 2026-10-12", step 3) | `data/change_file.dart` (`changeFileName`, `writeChangeFile` whole and in place, `readChangeFile`, `readChangeFiles` from a scratch copy, `ChangeFileHeader` with the vector and `firstSeq`, `ChangeRecord`); `domain/fold.dart` (`foldChanges`: this ledger, the other's changes and this computer's own since, into `combine`'s three); `domain/combine.dart` (`Resolution`, `Combined.resolutions`, `combine(madeHere:)`); `database.dart` (`syncState`, `markApplied`, `applyCombined(resolutions:, applied:)`, `sealAs` and `adoptSeal` stamp and adopt the vector, `replaceAllFrom(fromFolder:)` clears the log); `cloud_folder.dart` (`_syncLogs`, `_publish`, `_planFor`, `_Plan`, `keepMine` as a published decision, `undoKeepMine` refused on change files; the older `_sync` until both carry a vector) | `_bringInFolderChanges`, `_chooseRows`, `_chooseLedger` in `ledger_screen.dart`, unchanged | `change_file_test.dart`; `fold_test.dart`; `two_computers_test.dart` ("two computers and one folder", on change files throughout); `cloud_folder_test.dart` |
| One id for the same thing made on both (ADR 0005, "the way chosen 2026-10-12", step 2) | `sharedRowId`, `isSharedRowId` in `domain/sync.dart`; `SharedKey` and `_freeId` in `database.dart`, used by `postTransaction(shared:)`, `postSimple`, `ensurePaydays`, `ensurePlanBills`, `takePhoneEntries`, `applyImport`, `_payeeId`, `createCategory`, `incomeCategory`, `safetyNetCategory`; `_sameMade` and `_waitingOf` in `domain/combine.dart` (one id made on both); `ledgerDigest` ignores `created_at` and `updated_at` | `CombinedIn.quiet` in `cloud_folder.dart`: `_bringInFolderChanges` says nothing | `two_computers_test.dart` ("the same payday, phone entry and bank rows get one id", "a shared id", the digest); `combine_test.dart` ("under one id") |
| Where a row came from (ADR 0005, "Where a row came from") | `Transactions.madeHow` and `.madeOn` in `database.dart`, set by `postTransaction(how:, on:)`, `postSimple`, `postExchange` and read into `TxnData` and `RegisterRow`; `thisComputer` (the computer's id) is set by `LedgerScreen._nameThisComputer`, which also writes `computer.machine.<id>` (`FolderAccess.machineId`, so another account of the same Mac reads as here), and `_nameThisComputer` gives it `computer.name.<id>`; `MadeHow` in `domain/sync.dart`; `phoneNamePrefix`, `showSourceKey` in `domain/phone.dart`; the digest ignores the columns (`_whenWritten` in `data/ledger_seal.dart`) and `combine._sameMade` keeps one word on both computers | `SourceColumn`, `_SourceCell` and the header cell in `register.dart`; the entry row's blank cell in `entry_row.dart`; `register_settings.dart` (`_RegisterSettings`, `_PhoneName`: part of `ledger_screen.dart`) | `source_test.dart`; `combine_test.dart` ("a bank row imported on both"); `ledger_screen_test.dart` ("Source:"); `migration_test.dart` |
| The change log (ADR 0005, "the way chosen 2026-10-12", step 1) | `database.dart` "the change log": the `changes` table (`Changes`, one row per row changed, before and after as JSON by column name, `seq` counts 1, 2, 3 on purpose), `changeTriggerSql` (TEMP triggers on every ledger table, made on every open in `beforeOpen` and afresh after every upgrade), `_withoutChangeLog` (the hold: a TEMP table a row in which keeps the triggers from recording another computer's changes, a restore or an erase), `_logMarker`, `changesSince`, `lastChangeSeq`; `SyncKeys.applied`, `.ledger`, `changeLogTable`, `newLedgerId` in `domain/sync.dart`; `ledgerTables` in `data/ledger_seal.dart` keeps the log out of the digest and the compare | nothing yet | `changes_test.dart`; `migration_test.dart` ("upgrades a v19 file") |
| Two computers combined (ADR 0005, "Combine") | `domain/combine.dart` (`combine`: three ledgers as row maps in, `RowOp`s or a conflict out; the tables' keys, references and order are listed at its top, and a new table has to be added there); `newRowId` in `domain/sync.dart` (every id column's `clientDefault`); `data/ledger_seal.dart` (`ledgerRows`, `readLedgerRows`); `database.dart` (`allRows`, `applyCombined`); `cloud_folder.dart` (`_keepAgreed` and the file `cloud-folder-agreed`, `_combinable`, `bringIn` with `picks`, `asks`, `_decided`, `FolderStanding.combine` and `.rows`); `Backups.keepBefore`, `keepRestored` | `_bringInFolderChanges`, `_chooseRows` in `ledger_screen.dart`; `_RowsDialog`, `_AskCard` in `ui/rows_dialog.dart` (the question for a row both changed) | `combine_test.dart` (the rules, on row maps); `two_computers_test.dart` ("combine", two real ledgers); `cloud_folder_test.dart` (the popup, the row question; 2 goldens) |
| File names | `data/ledger_file.dart` (`ledgerExtension`, `ledgerFileName`; `ledgerFileIn` renames a ledger still called `betterbudget.sqlite`, called from `main.dart` and `AppDatabase.openEncrypted`) | none | `ledger_file_test.dart` |
| Schema, upgrades | tables at the top of `database.dart`; `schemaVersion`, `migration` | none | `migration_test.dart` |
| Words | `l10n/app_en.arb`, `l10n/app_mn.arb` | `language.dart` (`context.t`, `sayDate`), `data_words.dart` | `language_test.dart` |
| Look | none | `theme.dart` (`Palette`, `Mid`, `onest`), `schemes.dart`, `appearance.dart`, `brand.dart`, `fit_window.dart` | `schemes_test.dart`, `ledger_screen_test.dart` ("appearance") |
| Undo, redo, toasts, keys | none | `ledger_screen.dart` (`_did`, `_undo`, `_redoLast`, `_onKey`, `_Toast`) | `ledger_screen_test.dart` ("undo and redo, action by action") |
| Setup (first run) | `domain/setup.dart` (`SetupKeys`, `inSetup`); `database.dart` (`redateOpeningBalances`) | `setup.dart` (`_SetupPage`: the Accounts and Pay steps); "setup" in `ledger_screen.dart`; `_Sidebar(setup:)` | `setup_test.dart` |
| Phone app (ADR 0005) | `domain/phone.dart` (`PhoneSnapshot`, `PhoneEntry`, `leftNow`, `categoriesMatching`, `categoryNamed`, `phoneIncomeId` for money in filed as income, the amount pad's keys, `snapshotOf` a ledger); `data/phone_ledger.dart` (`PhoneFolder`, the folder channel answered by `android/.../MainActivity.kt`; `readPhoneLedger` opens a private copy); `data/phone_inbox.dart` (the phone's own file in the folder: `writePhoneInbox`, `readPhoneInboxes`, `PhoneOutbox` keeps it on the phone); `database.dart` "phones" (`takePhoneEntries`, `undoPhoneTake`) | `ui/phone/phone_start.dart` (`PhoneStart`: recovery key, folder, problems), `ui/phone/phone_app.dart` (`PhoneFrame`, `PhoneStore` with the entries and categories made here, `PhoneHome` holding `_EntryScreen` (Ledger) and `_BudgetScreen`, `_CategoryMenu` (the Category dropdown), `_SplitPage`, `_WaitingScreen` (a waiting entry opens on the entry screen to be fixed), `_TapHold`); `_takePhones` in `ledger_screen.dart` takes the phones' entries in on the computer; `main.dart` runs `PhoneStart` on Android and iOS; `phone_preview.dart` runs the screens on invented figures (`-t lib/phone_preview.dart`) | `phone_test.dart` (10 goldens, 390 × 844); `cloud_folder_test.dart` (an entry taken in through the real screen) |
| Demo data | `data/demo_seed.dart` (`seedDemoIfEmpty`, called by `LedgerScreen` only with `demo: true`) | none | most tests seed with it |

`database.dart` is 4,600 lines marked off by `// ---------- name ----------` comments;
search for the marker. Keys for the `Preferences` table are defined in the domain
(`BudgetKeys`, `ReadyKeys`, `SetupKeys`, `SyncKeys`, `ForecastSpan.prefKey`,
`noRegularPayKey`).

## Gotchas

- **Generated files, all committed. Change the source, then regenerate.**
  `data/database.g.dart` from the tables, by `dart run build_runner build`.
  `l10n/app_localizations*.dart` (the `Words` class) from the `.arb` files, by
  `flutter gen-l10n` or any build. `domain/currencies.dart` and
  `l10n/currency_names.dart` by `tool/gen_currencies.py`; `BetterBudgetSymbols.ttf` by
  `tool/gen_symbol_font.py` ([currencies.md](currencies.md)).
- **Logo and pictures.** `assets/brand/mark-dark.svg`, the two wordmarks and the eight
  `savings-*.svg` (four steps, day and night) are written
  by `assets/logo/prepared/prepare.py` (repo root) from the owner's vectors in
  `assets/logo/Images/`; change those and run it again, don't edit the copies. The
  Mac and Windows icons are drawn by `design/icon/app_icon.py`, Android's by
  `tool/gen_android_icons.sh`.
- **Downloads.** `tool/release_mac.sh` makes the Mac disk image signed with Developer
  ID and notarized (packed by `tool/make_dmg.sh`), tags the commit and puts a draft
  release on `Loveland-Solutions/betterbudget`. The Windows app is built on GitHub by
  `.github/workflows/windows.yml` (repo root) on a `v*` tag or a pull request that
  touches Windows, and downloads from the run's Artifacts. Microsoft's C++ runtime DLLs
  are copied in beside `BetterBudget.exe`.
- **Words.** New text goes in both `.arb` files with the same key and placeholders, or
  `language_test.dart` fails. Terms and tone: [l10n-glossary.md](l10n-glossary.md).
- **Ids.** A new row's id is `newRowId()`, large and not sequential: never write
  a test or a query that expects 1, 2, 3 from rows it makes. Rows still sort by id
  in the order one computer made them. A row two computers would each make from
  the same fact (a payday, a bill, a phone's entry, a bank row, a payee, a
  category, Income, the Safety net) gets `sharedRowId(kind, key)` through
  `postTransaction(shared:)` or `_freeId`, the same on every computer; a new kind
  of app-made row should too, or two computers hold it twice.
- **Schema.** A new table also goes in `_keys`, `combineOrder` and `_references` at
  the top of `domain/combine.dart`, or two ledgers holding it are never combined,
  and in `replaceAllFrom`'s list, or a restore drops it (`changes_test.dart`
  checks the first). A table change needs a new `schemaVersion`, a step in
  `onUpgrade` (which copies the file first and runs in one transaction), a
  regenerated `database.g.dart` and a case in `migration_test.dart`. The change
  triggers name every column and are made afresh after every upgrade by
  themselves; a test that takes a file back to an older shape calls
  `dropAddedInV20` first, since a trigger that names a column stops `DROP
  COLUMN`; each trigger names only the columns the file really has
  (`expectAllColumns` in that test pins that an upgraded file has them all).
  `recursive_triggers` is on, so an `INSERT OR REPLACE` logs delete then insert;
  `insertOnConflictUpdate` logs an update. No column may be a blob
  (`json_object` can't hold one; `changes_test.dart` checks). The `sync.*`
  settings and the `changes` table are each computer's own: never in the
  digest, never combined, never restored over. From v20 on an upgrade either
  changes no row, or is deterministic (no `newRowId`, no clock), or runs with
  the triggers in place: its writes are otherwise never logged, and two
  computers would differ on rows neither sends the other.
- **Encryption** ([ADR 0001](decisions/0001-database.md)). The app opens the ledger with
  `AppDatabase.openEncrypted`; tests use `AppDatabase(NativeDatabase.memory())`, which
  is plain. Raw SQLite calls go inside `withoutKeyInErrors` (`encryption.dart`) so a key
  never reaches a log. The order of steps in `startup.dart` is deliberate (see its
  header). Tests swap the Keychain for a fake secure-storage platform (`keys_test.dart`,
  `startup_test.dart`, `language_test.dart`).
- **Real secrets in the repo folder, ignored by git: never open.**
  `BetterBudget recovery key*.txt` and the two `*-bank-transaction-exports/` folders.
- **Two computers in a test.** Give each its own folder, database file, `Backups`
  and `CloudFolder`, and one shared folder for the ledger (`_Computer` in
  `two_computers_test.dart`). A change the folder code should notice has to be a real
  one in the database: `ledgerChanged` alone writes nothing now. On change files a
  stale computer's look says `combine` (bring the other's changes in), not
  `newer` (take the whole file): `settle(on)` there does what the screen does.
- **Widget tests.** Database work goes inside `tester.runAsync`; reuse `pumpLedger`,
  `settle` and `tidy` from the top of `ledger_screen_test.dart`. Open and save dialogs
  are faked by `_FakeDialogs` there. A click that saves and is followed by a read
  of the database goes through `press` in `setup_test.dart` (the tap inside
  `runAsync`): tapped outside it, the write waits on pumps and the read hangs behind it.
- **Goldens** come from `ledger_screen_test.dart` (71), `setup_test.dart` (6),
  `language_test.dart` (4, Mongolian), `cloud_folder_test.dart` (6),
  `startup_test.dart` (2) and `recovery_key_screen_test.dart` (1). A dialog isn't inside `LedgerScreen`: to draw
  one, capture `find.byType(MaterialApp)`. `test/goldens/` is committed;
  `test/failures/` is ignored output. They load Onest and Manrope explicitly; border and
  fade animations need an extra `pump()` before capture.
- **A Mac draws buttons 8 shorter** (Flutter's compact density on desktop), and goldens
  are drawn as the tests' platform draws. A button beside text can look right in every
  golden and sit wrong in the app: give it `visualDensity: VisualDensity.standard`, or
  test it with `variant: TargetPlatformVariant.only(TargetPlatform.macOS)`. The same
  variant, with a mouse tap, is needed to test a click away from a text field.
- **Fonts.** After any font change, confirm the font has ₮ (U+20AE), Ө and Ү. Signs
  neither Onest nor Manrope has come from `BetterBudgetSymbols.ttf`;
  `tool/gen_currencies.py` stops if a currency's symbol can't be drawn.
- **Signing.** An unsigned build can't use the Keychain the key lives in. The app signs
  with the owner's Apple team: [STATUS.md](STATUS.md) "Local setup notes".
- **Keyboard.** Single-key shortcuts live in `_LedgerScreenState._onKey` and return
  `ignored` while a text field has focus. A plain key bound with `CallbackShortcuts`
  takes the key from the field. Test with `sendKeyEvent`.
- **Money.** `Money` reads its currency from the `CurrencyScope` above it and falls back
  to tugrik without complaint, so a new page for an account needs the scope.
- **Not verified.** `fit_window.dart` says its smallest size must match
  `macos/Runner/MainFlutterWindow.swift`; that folder was not opened for this map.
  `app/README.md` has an older layout table that leaves out about half of these files.

## Other docs

[STATUS.md](STATUS.md) (built, next step, setup), [ROADMAP.md](ROADMAP.md) (decisions), the
[board](https://github.com/orgs/Loveland-Solutions/projects/1) (everything left to do), and
[decisions/](decisions/): 0001 database and encryption, 0002 import format, 0003
double-entry schema, 0004 UI rules and owner corrections, 0005 phones, 0006 versions.
