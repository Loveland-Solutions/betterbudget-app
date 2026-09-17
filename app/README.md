# BetterBudget app

Flutter, desktop first (macOS verified; Windows, iOS and Android scaffolded but not built).
Data is local SQLite via Drift ([ADR 0001](../docs/decisions/0001-database.md),
[ADR 0003](../docs/decisions/0003-double-entry-schema.md)). The look and the register's
rules are in [ADR 0004](../docs/decisions/0004-ledger-ui.md).

```sh
flutter run -d macos          # run the app (Xcode must be selected, license accepted)
flutter analyze && flutter test
dart run build_runner build   # after changing tables in lib/data/database.dart
flutter test --update-goldens # after an intentional visual change; then look at the PNGs
```

## Layout

| Path | What |
| --- | --- |
| `lib/domain/money.dart` | Integer minor units (MNT exponent 2), formatting, `parseAmount` with arithmetic |
| `lib/domain/ledger.dart` | Plain data classes; register rows with running balance; working/cleared/reconciled summary |
| `lib/domain/forecast.dart` | Today → next scheduled income: steps, lowest point, first day below zero, causes |
| `lib/data/database.dart` | Drift tables (accounts, payees, transactions, entries, reconciliations); every write checks zero-sum in the same SQL transaction; bulk ops return previous state for undo |
| `lib/data/demo_seed.dart` | Synthetic demo data, dated relative to today, seeded into an empty database |
| `lib/ui/theme.dart` | Midnight tokens (`Mid`), `onest()` text style, `Money`, `StatusGlyph` |
| `lib/ui/ledger_screen.dart` | Screen state: section, account, filter, selection, editing, bulk actions, toasts, key handling; also the sectioned sidebar and Budget/Savings placeholder pages |
| `lib/ui/balance_header.dart` | Balance and symbol key, forecast panel and chart |
| `lib/ui/register.dart` | Tabs or bulk bar, rows, scheduled rows, category menu |
| `lib/ui/entry_row.dart` | The any-order entry row, used both for new transactions and for editing an existing one in place |

`lib/domain/` has no Flutter or Drift imports; keep it that way, since it's where the
logic is tested directly. The UI reads one `LedgerData` snapshot, re-emitted whenever a
ledger table changes (`AppDatabase.watchLedger`). That's simple and fine at demo scale;
it will need narrower queries for tens of thousands of transactions.

## Tests

- `test/money_test.dart`: formatting and the amount calculator.
- `test/ledger_test.dart`: in-memory database. Covers zero-sum, balances, register, bulk
  ops, early confirm and the forecast.
- `test/ledger_screen_test.dart`: the real screen at 1440×900, including golden
  screenshots in `test/goldens/`.

Gotchas:

- Database work in widget tests must run inside `tester.runAsync`, because the fake
  clock never completes real SQLite I/O.
- Goldens load Onest and Manrope from `assets/fonts/` and Material Icons from the
  Flutter SDK. Border animations need an extra `pump()` before capture.
- Goldens render as a non-Mac platform, so shortcut hints read "Ctrl".
- **Single-key shortcuts** (Delete, C, Esc on selected rows) live in
  `_LedgerScreenState._onKey` and return `ignored` while a text field has focus. Never
  bind a plain key with `CallbackShortcuts`: it claims the key before the text field sees
  it, which once made Delete and the letter c impossible to type. Test real keys with
  `sendKeyEvent`, since `enterText` bypasses shortcuts.

## Fonts

Onest (UI) plus Manrope as `fontFamilyFallback`, both bundled variable fonts with their OFL
licenses. **Onest has no ₮ glyph**; Manrope supplies it. Check ₮ (U+20AE), Ө and Ү in any
replacement font. Weight goes through the variable axis, which is why `onest()` sets
`fontVariations`.

## macOS

- Window: 1440×900 default, 1200×760 minimum, title bar transparent over the ground
  color (`macos/Runner/MainFlutterWindow.swift`).
- Product name `BetterBudget`, bundle id `com.lovelandsolutions.betterbudget`.
- Release entitlements have no network access. Debug allows a local server only, so
  Flutter's debugger can attach.
- Data file:
  `~/Library/Containers/com.lovelandsolutions.betterbudget/Data/Library/Application Support/com.lovelandsolutions.betterbudget/betterbudget.sqlite`
  (plus `-wal` and `-shm`). Quit the app and delete all three to reseed.
- Build error `tapi error … MacOSX27.0.sdk` means `xcode-select` points at the Command
  Line Tools. Fix: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.

## Deliberately not yet

- SQLCipher: switch via `hooks: user_defines: sqlite3: source: sqlcipher` after the
  Windows spike.
- Everything else is listed in [docs/STATUS.md](../docs/STATUS.md).
