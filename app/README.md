# BetterBudget app

Flutter, desktop first. Data is local SQLite via Drift (see `docs/decisions`).

```sh
flutter run -d macos          # run the app (needs Xcode selected and its license accepted)
flutter test                  # unit, database and screen tests
dart run build_runner build   # after changing tables in lib/data/database.dart
flutter test --update-goldens # after an intentional visual change
```

- `lib/domain/` — pure Dart: money, register logic, forecast. No Flutter, no database.
- `lib/data/` — Drift schema and writes; zero-sum is checked inside every write.
- `lib/ui/` — the Midnight ledger.

On first launch the database is empty and gets synthetic demo data. To start over, delete
`betterbudget.sqlite` from the app's Application Support directory.

Release builds declare no network entitlement. The debug entitlement allows a local
server only so Flutter's debugger can attach.
