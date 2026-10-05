# BetterBudget — working notes for Claude

Read **[docs/STATUS.md](docs/STATUS.md)** first: what's built, what isn't, known bugs,
uncommitted work, **the next step the owner asked for**, and setup. The road from alpha to
beta (and the platforms after it) is tracked in **[docs/ROADMAP.md](docs/ROADMAP.md)**. UI decisions are in **[docs/decisions/0004-ledger-ui.md](docs/decisions/0004-ledger-ui.md)**.
The phone apps' design (record and check only, synced through a cloud folder the OS
handles) is in **[docs/decisions/0005-mobile-companion.md](docs/decisions/0005-mobile-companion.md)**.

## Unbreakable rules (from the README)

- Nothing leaves the user's machine: no network calls, telemetry, sync, update checks,
  or runtime font or asset fetching. Release builds declare no network entitlement.
- Real bank statements in `tdb-bank-transaction-exports/` never get committed, and no
  values from them go into code, tests or docs.
- Ledger first, polished, then the budget.

## How the owner works

- They run the app, react to it, and expect fixes right away. Show the change working in
  the real app, not just in tests.
- **Every element needs a purpose.** Don't copy other budget apps' conventions.
- They correct UX assumptions, so write each correction into ADR 0004 so it isn't lost.
  Past corrections: no In/Out columns, no month subheadings, symbols that look like
  checkboxes, entry that only works left to right, no savings suggestions yet, shortcuts
  that swallowed typing, no way to edit a transaction, "not posted" wording for
  uncleared (banks show pending), a dash symbol that read as a minus sign, a separate big
  balance above the header sum, "latest cleared" date (noise), a reconciled amount (only
  the date matters), a sidebar layout (option A chosen), Delete removing reconciled
  rows, a chevron on sidebar sections (it promised a toggle), an always-visible blank
  entry row, a "+ for money in" hint, multi-select (not wanted yet), a toast on
  every cleared-symbol click (toasts are for saved changes; ⌘Z undoes anything), and
  an income name under the forecast's end date (both ends show plain dates), a bank
  balance prefilled with the cleared total, reconciled rows whose payee couldn't be
  fixed, a row hover as faint as the row stripe, a separate cash-account counting
  flow (not wanted yet; on the roadmap), "a different amount each day" for split pay
  (it's each paycheck), a dark theme built from one color in lighter and darker
  shades (surfaces should differ), "tögrög" in English (spell it "tugrik"), and sidebar
  balances rounded to whole units (show the cents), a toast when an account is made,
  "settled" (the app's word is cleared), "Put in how much comes" for pay, and a
  forecast a new user couldn't read (unlabeled chart, "Never below today's",
  "Pay"/"Next pay", a hint and link that read as AI-speak), and search at the top
  of the page (it belongs in the register's tab row), "Put in" for budget amounts
  (the word is **Assigned**), and questions worded in the app's internals instead
  of a plain example, and a logo recolored by the scheme, a light band behind it, and a white glow around it (the sidebar shows a dark-mode logo), and a Budget page
  that stopped two-thirds of the way across the window (pages fill it), and a window that
  shrank until an account page ran out of room (it stops at 1360 × 760), and credit
  cards left out of a category's list of accounts (a card is an account; if they plan
  to pay with it, let them), and too many menus on a budget category (its menu is
  Edit and Delete, a double-click opens Edit, and everything about it is in Edit), and
  an Edit that Esc or a second double-click didn't close, and a button for each
  currency (a Currency dropdown: every currency is to be supported), and a category's
  accounts laid out as a list in the panel (a dropdown of checkboxes), and a currency's
  code at the start of some rows and the end of others (always at the end), and
  made-up currency symbols (`CA$` where Canadians write `$`: show the real one, and
  tell two apart only when a ledger holds both), and income categories (there's one
  built-in Income; "not assigned" is where money needing a category shows), and
  treating their ledger as production data (it isn't yet: don't weigh a change by
  what it does to old rows), and "Came in" for a period's income (the word is
  **Income**; use the plain word people say), and "Everything has cleared" beside a
  zero Uncleared line (don't tell them what they already know), and ⌘K shown as the
  search key (it's ⌘F; ⌘K was copied from other apps), and "Say how much arrives in…"
  squeezed beside Add (why a row can't be saved goes in the popup at the bottom, worded
  like "Enter an amount", not like a child talking), and an Edit only Esc could close
  (everything must work with just the mouse: a Cancel button, and a click away), and
  "Kind" for an account's type (the word is **Type**), and five plan types of which two
  came to the same number (two now, behind one question: "Is there a due date?"), and
  "Any time" as an answer to when money is spent (a non-answer: "it's going to be
  spent some time"), and a category's Edit laid out as a row of fields ("all the
  features shoved on a page": it's designed as one thing, the name as heading, a short
  labelled form, the row drawn as it will read), and a wizard for making a category
  (the one question is the panel's first line), and two account dropdowns in a
  category's Edit (one row, **Paid from**), and a new category left closed after Add
  (its Edit opens), and "Every…" for the repeat you set up yourself (the word is
  **Custom…**), and Budget by as a setting (it's a view on the Budget page, and each
  category has its own period: month or a named pay; a set amount seen by another
  period is prorated by days), and a minus beside "Not assigned" (it stops at zero and a
  red row, **Assigned too much**, holds the amount), defended because "the sum adds
  up" (arithmetic that's right can still confuse; don't think like a computer).
- **Warn, don't block** (owner, 2026-09-18: "I really hate it when a developer tries to
  save me from myself"). Don't forbid an action to protect the user. Say exactly what
  will happen, big and specific with real numbers, then let them go ahead, with undo.
  Use a default rather than a required choice. Locks the owner chose themselves (such as
  reconciled rows) stay.
- They often choose between options, so offer two or three with a recommendation and
  sketches, then build the one they pick. Record the choice, and what was rejected, in
  ADR 0004.
- Once they've made a call, don't re-ask it. Review findings that refine it (wording,
  defaults, edge cases) are yours to decide along the lines they gave; report them
  briefly. Ask only about new features or new ways money is counted or shown, two or
  three at a time. Run the review passes once per feature, not again on their own
  follow-ups (owner, 2026-09-17: "you keep asking me the same five questions").
- If they must run something themselves (for example `sudo`), give them one copy-paste
  line and say why.

## Code map (`app/`)

- `lib/domain/`: pure Dart, no Flutter and no database. `money.dart` (integer minor
  units in each currency's own decimals, `Currency` and its table of every ISO currency in
  `currencies.dart`, made by `app/tool/gen_currencies.py`; amount calculator), `ledger.dart` (register rows, balances),
  `forecast.dart`, `budget.dart` (envelopes, and each category's plan worked out for a
  period: rules 26 and 27).
- `lib/data/`: Drift schema and writes (`database.dart`; regenerate with
  `dart run build_runner build`), `backup.dart` (daily copies, back up, restore, the copy before a new ledger,
  converting plain copies), `keys.dart` (recovery key, data key, secure store),
  `encryption.dart` (cipher pragmas, converting a plain file), plus `demo_seed.dart`.
- `lib/import/`: pure Dart, reading bank files into a grid (`xls.dart` BIFF8,
  `xlsx.dart`, `csv.dart`, `sheet.dart`) and `mapping.dart` (which column is which,
  guessing, reading rows, the balance check, import keys). The dialog is
  `ui/import_dialog.dart`; writes are the import section of `database.dart`. Tests build
  `.xls` files with `test/xls_fixture.dart`; never commit a real statement.
- `lib/l10n/`: every word on screen, `app_en.arb` and `app_mn.arb` (each English entry
  says where it shows); `flutter gen-l10n` builds the `Words` class. Terms and tone:
  [docs/l10n-glossary.md](docs/l10n-glossary.md). New text goes in both files; English
  must not be glued from pieces (Mongolian word order differs).
- `lib/ui/`: `language.dart` (Settings → Language, `context.t`, `sayDate`),
  `data_words.dart` (words for the data layer's codes: restore, key and database
  problems, row labels, pay), `theme.dart` (`Palette` dark and light, read as `Mid.ink` etc.; the
  sidebar's own `Mid.side*`; `Money`, `StatusGlyph`), `appearance.dart` (Settings →
  Appearance, switching and redrawing), `schemes.dart` (the color schemes: the app's own and
  Figma's 100, Blue eclipse the default; `Palette.of` in `theme.dart` turns one into light and dark), `brand.dart` (the bee and the wordmark, the dark-mode logo files), `fit_window.dart` (the smallest size the app is laid out for; smaller windows show it shrunk; keep it the same as `MainFlutterWindow.swift`), `ledger_screen.dart`
  (state, selection, row actions, toasts, sidebar, Settings page), `balance_header.dart`
  (key, forecast chart and bill list),
  `register.dart` (rows, row action bar, category menu), `budget.dart` (the Budget
  page: envelopes, the plan note under a name, Edit under a category's row), `entry_row.dart`
  (entry row, `DateField` and calendar), `reconcile.dart` (reconcile panel), `recovery_key_screen.dart` (the key shown
  once at setup, the entry screen when a device has no key, the key-check dialogs),
  `startup.dart` (what happens at launch: check the key, show a new key before storing
  it, convert, open; tested in `test/startup_test.dart`).
- Widget tests stand in for the macOS open and save dialogs with a fake
  `FileSelectorPlatform` (see the "backups" group); taps that start file work go
  inside `tester.runAsync`.
  `ledger_screen.dart` also holds the session undo/redo history (`_did`, `_undo`,
  `_redoLast`): every new action must record both an undo and a redo.

## Two review passes before wrapping a feature or page

Run both before calling a feature or page done (owner's rule), and bring the findings to
the owner rather than fixing everything silently:

1. **Code review** by the `code-reviewer` agent (`.claude/agents/code-reviewer.md`):
   correctness, data integrity, the unbreakable rules, tests.
2. **Budget app review** by the `budget-app-expert` agent
   (`.claude/agents/budget-app-expert.md`): does it hold up for someone actually
   managing money in Mongolia? It flags gaps without copying other apps' conventions.

## Design committee, for how a screen is presented

When the owner says a screen has the right features but the wrong presentation, run
the four agents in `.claude/agents/` in parallel and fold their reports into two or
three mockups with a recommendation (the Design artifact type draws them):
`ui-designer` (layout), `ux-writer` (words), `interaction-designer` (flow, clicks,
focus), `first-time-user` (someone in Ulaanbaatar who has never used a budget app,
reading it literally). `budget-expert` is for how money is counted, not presentation.
Don't bring back the same row of controls with better words (owner, 2026-10-04).

## Checks before handing work back

```sh
cd app && flutter analyze && flutter test
```

- Bump `version:` in `app/pubspec.yaml` in each feature PR (minor) or fix PR (patch);
  the build number comes from git ([ADR 0006](docs/decisions/0006-version-numbers.md)).
- Visual changes: `flutter test --update-goldens`, then look at the PNGs in
  `test/goldens/`, then rebuild and relaunch the macOS app.
- Widget tests that touch the database must do the I/O inside `tester.runAsync` (see
  `test/ledger_screen_test.dart`). The fake clock never completes real SQLite work.
- Goldens load Onest and Manrope explicitly. Border and fade animations need an extra
  `pump()` before capture.
- Any font change: confirm the font has ₮ (U+20AE), Ө and Ү. Currency signs neither
  Onest nor Manrope has come from `BetterBudgetSymbols.ttf` (`tool/gen_symbol_font.py`);
  `tool/gen_currencies.py` stops if a currency's symbol can't be drawn.
- The app is signed with the owner's Apple team (see STATUS "Local setup notes"). An
  unsigned build can't use the Keychain the encryption key lives in (ADR 0001).
