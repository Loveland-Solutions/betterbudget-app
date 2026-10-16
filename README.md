# BetterBudget

A private budgeting app for Mac and Windows, with phone apps for recording what you
spend. It's made first for Mongolia, in Mongolian and English, with the tugrik (₮) at
its heart. It's free.

## Your budget is yours

You download BetterBudget onto your own computer, and it's yours. Nothing ever leaves
your machine: no telemetry, no accounts, no subscriptions, no connection to your bank,
no checking for updates. Your ledger is encrypted on your own disk. The developer
doesn't want to know anything about you, and the app gives no way to.

If you keep your ledger in a folder that Google Drive, OneDrive or Dropbox syncs, so
your other computers and phones can use it, that service's own software carries the
encrypted file. BetterBudget itself never connects. The
[privacy policy](https://github.com/Loveland-Solutions/betterbudget/blob/main/PRIVACY.md)
says exactly what is stored and where.

## Download

Releases and bug reports are at
[Loveland-Solutions/betterbudget](https://github.com/Loveland-Solutions/betterbudget).
BetterBudget is still in alpha: the ledger comes first, then the budget.

## Project documentation

**[docs/STATUS.md](docs/STATUS.md) — start here.** What's built, what isn't, open
questions, and local setup. AI sessions also read [CLAUDE.md](CLAUDE.md).

- The app: [app/](app/) ([how to run and test it](app/README.md))
- Ledger feature map, with what's built marked: [docs/ledger-features.md](docs/ledger-features.md)
- Design mockups: [design/ledger/](design/ledger/)

Settled decisions live in [docs/decisions](docs/decisions/). They are recorded once so
they don't get relitigated later.

- [0001 — Local data store: SQLite via Drift, encrypted with SQLCipher](docs/decisions/0001-database.md)
- [0002 — TDB statement import: target the unformatted Excel export](docs/decisions/0002-tdb-import-format.md)
- [0003 — Ledger schema: double-entry storage, categories as accounts](docs/decisions/0003-double-entry-schema.md)
- [0004 — Ledger UI: Midnight, and the rules the register follows](docs/decisions/0004-ledger-ui.md)

## License

BetterBudget is free software: you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software Foundation,
either version 3 of the License, or (at your option) any later version. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See
[LICENSE](LICENSE) for the full text.

Copyright © 2026 Loveland Solutions, LLC.

- **The name and logo are not covered.** The license covers the source code. The name
  BetterBudget and the logos in [assets/logo/](assets/logo/) and
  [app/assets/brand/](app/assets/brand/) belong to Loveland Solutions, LLC. A changed copy
  you share needs its own name and logo.
- **The fonts keep their own license.** The fonts in
  [app/assets/fonts/](app/assets/fonts/) are under the SIL Open Font License; the
  `*-OFL.txt` files beside them are its text.

## Thanks

- **Cynthia G. Loveland** worked through the Budget page's layout with the owner
  (2026-10-05): where things go and what kind of control each one is. The app credits
  her at the bottom of Settings.
