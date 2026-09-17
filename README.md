# BetterBudget

## Overview

This is a budgeting app that will eventually run on iPhone, Android Phone, Windows PC or Mac OS machine.

## Unbreakable rules

This is theirs. They download the tool onto their machine. Nothing ever leaves their machine. No telemetry, no subscriptions, no syncing with banks, no checking for updates. Their privacy is paramount. I (the developer/app owner) do not want to know any of their information. I need to see its development as we're building it so I can make sure it's going the right direction.

## Features. 

This is launching in Mongolia, so it will need to support MNT. 

## Assets

The logos are in the assets/logo directory. The colors in the logo should govern the colors of the app. The application should be developed on Flutter so that it can run on all the different platforms

## Ledger

This is where the transactions are imported/entered. It should be polished and professional. Let's talk through all the features that are needed before any code is written. We'll start here first, polish it, then move on to the budget. 

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
