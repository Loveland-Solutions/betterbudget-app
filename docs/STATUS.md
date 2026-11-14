# Where things stand

**Last updated: 2026-11-13** · version 0.88.1 · schema v26 · 1091 tests pass

**This file holds the current state, nothing else.** What's left to do (features, bugs,
questions for the owner) is on the [BetterBudget board](https://github.com/orgs/Loveland-Solutions/projects/1), one issue each. No log of PRs:
git, the PRs and [ADR 0004](decisions/0004-ledger-ui.md) hold the history. When a PR
merges, rewrite "Next step", "In the stores" and the table; don't add a block about the
feature. Keep it under about 20,000 characters. What this file said before is in
`docs/archive/STATUS-2026-10-07.md` and `docs/archive/STATUS-2026-11-13.md`, which are
not for reading unless the owner asks.

## Next step

The New category type cards are in (#429, 0.89.0), on the computer and the phone. Next
Beta features offered: bills on
the Budget page one line each (#365); the Budget page's tabs reading as tabs, with Add
other regular income beside the incomes (#435 with #436). The Mongolian of everything
since #90's last pass is a draft until Tanan checks it (#90).

## In the stores

| Store | Has | Waiting |
| --- | --- | --- |
| Google Play (`mn.lls.betterbudget`) | 0.88.1 (679) on Internal testing; alpha and production sent to Google's review 2026-11-13 | — |
| Microsoft Store (`9NH3HJNFJN4G`) | 0.88.1, published at the owner's Publish now (2026-11-14) | — |
| Mac App Store, "The BetterBudget" | 0.72.1 (598), live; free in 174 countries | 0.88.1 (679) in Apple's review, submitted 2026-11-14. The EU's 27 until the owner gives the Digital Services Act trader details (#375), which the EU shows publicly |
| iPhone App Store, same record | Nothing yet; TestFlight has 0.73.1 (604) | 0.73.1 in Apple's review, resubmitted 2026-11-12 with a screen recording and answers in its Review Notes, after a Guideline 2.1 "information needed" rejection. A check with Google Drive on a real iPhone is on #114 |

Listings lead with building wealth (ADR 0004); Play's and the Microsoft Store's follow
when next changed (#377). Every store lists it free. No downloads from GitHub (owner, 2026-10-20,
ROADMAP); old Windows ones are still on the public repo's releases page (#452).

## How a release goes out

A release is the owner's say each time, in every store. Run each script from a clean,
pushed commit on main; `--check` does everything but the last step.

- **Play:** `app/tool/release_play.sh "What changed."` builds the signed `.aab` (build
  number = commit count, ADR 0006), checks it asks for no network, and makes it the only
  build in Internal testing; alpha and production go by Play's edits API. Before offering
  one, compare the table above with `git log` on `app/lib/ui/phone/`. Play's review gets
  past the recovery key with the demo key `DEMO-DEMO-DEMO-DEMO-DEMO`, kept in App access →
  Sign in details (#303; ADR 0005 "A demo key for Play's review"). **A schema bump means a
  phone needs a build at or after it before it can read the folder's ledger again.**
- **Microsoft Store:** `app/tool/release_store.sh` tags main `vX.Y.Z`, which starts
  `.github/workflows/windows.yml` on GitHub (its download kept 14 days), waits for the
  build, checks the `.msix`, deletes any submission still waiting (owner, 2026-10-30), and
  sends the new one to certification, set to publish only on the owner's Publish now.
- **Apple:** `app/tool/release_mac.sh` and `app/tool/release_ios.sh` build, check and
  upload, signing with the team's App Store Connect API key in `~/.config/betterbudget/`
  (#380; Xcode 27.2's command line can't use Xcode's sign-in). Both apps' Info.plist
  answers the encryption question as exempt (`ITSAppUsesNonExemptEncryption` false, #456),
  so App Store Connect no longer asks it per build. France also waits on the French
  encryption declaration.

## Phase

**A working ledger and budget are built**, on the computer (macOS, Windows) and the
phone (Android, iPhone), from [`app/`](../app/). The owner uses it with real money and
refines it by what they hit; their wife enters receipts on her Android phone. The road
to beta and after is in [ROADMAP.md](ROADMAP.md). The repo is public under GPL-3.0 or
later (owner, 2026-10-16); anything pushed is published. Two computers on one ledger
are built through step 4; step 5 is after beta (#451).

**The owner's ledger is production data** (since 2026-10-06; rules in
[CLAUDE.md](../CLAUDE.md)). It holds one tugrik account and lives in their Google Drive
folder. A wordless screenshot from the owner, after being told something couldn't be
checked in the real app, is the result being shown, not a complaint.

## Questions for the owner

On the [board](https://github.com/orgs/Loveland-Solutions/projects/1) as issues titled "Question: …". Asked and not answered: don't
re-ask; bring one up when its screen comes up again.

## What exists (each line checked against the code on 2026-11-13)

| Area | What works |
| --- | --- |
| Storage | SQLite (Drift) at schema v26, encrypted (SQLCipher v4), WAL mode. Double-entry ([ADR 0003](decisions/0003-double-entry-schema.md)): a write that doesn't sum to zero is refused. Deletes are soft. Before an upgrade the file is copied beside itself (`Ledger.before-v26-from-v25-<time>.betterbudget`) and the upgrade runs in one transaction. A ledger saved by a newer build is refused, nothing changed |
| Sidebar | Ledger, Budget, Savings, Payees. Under Ledger: All accounts, then accounts grouped Bank, Cash, Credit, each with its balance and a coral dot when its forecast goes below zero, then **Add account**. Below: the Settings gear (a dot when the folder or daily copy needs attention), **Net worth** per currency, "Last backup 41 days ago" after a month, and **Send feedback…** |
| Accounts | **Add account**: Name, **Type** (Bank account, Cash, Credit card or loan), Currency (can't change later), **Interest rate** for a card or loan. It starts from a balance on a date, or from a bank file. Its menu: Rename, Change to…, **Payments come out of** (card or loan), Archive…, Delete…. Cash gets neither Reconcile nor Import |
| Register | One signed amount column (money in green with a plus, money out ordinary ink with a minus) and a running **Balance** (**Owed** on a card). Filter buttons, each in its color: All, Uncleared, Scheduled, and **Not categorized** while this period's rows wait; Cleared and Reconciled come from the header. Then **Import transactions…**, **Manually add a transaction** and search (⌘F: payee, memo, category, account or amount). All accounts opened from Budget is narrowed to a category and period, with its total |
| Entry | ⌘N or **Manually add a transaction** opens the row. Enter from any field; until it can save, it says what's missing ("2 more to fill in"). An amount takes a sum, and `+` (or Swap) for money in. `→ Account` makes a transfer; to another currency it asks what arrived. **Split** at the top of Category, **New category** beside it. A date after today schedules it. A remembered payee fills its category; otherwise **Remember this category for this payee** sits under the row |
| Editing | Double-click a row (or Enter) to edit in place, with **Save** and **Cancel** (Esc). A reconciled row's date and amount are locked; its category, payee and memo can change. A split's lines are edited in its card. A memo wraps under the payee, whole |
| Source | An optional column, on until Settings → Register unticks "Show where each transaction came from": Entered or Imported locally or on a named computer, From a phone, Scheduled. Blank for opening balances, adjustments and rows from before v21 |
| Row actions | Edit, Categorize, Mark cleared / uncleared, Move to (same currency), Delete; the category pill opens the same menu. **Confirm** on a scheduled row; **No bill this time** in place of Delete on a category's bill. A bill a row may have paid asks "Paid on 10.13? … Yes / No"; a row taken as the bill has **Not this bill**. The newest reconcile's rows have **Undo this reconcile**. Keys ↑ ↓, Enter, C, Delete, Esc |
| Undo | ⌘Z and ⌘⇧Z (Ctrl+Z, Ctrl+Y on Windows) through this session's actions; in a text field they act on typing. A popup's Undo works only while its action is the newest. Changes brought in from another computer clear the list |
| Popup | Gold, 440 wide, bottom right, with Undo, for a saved change; it stays while the pointer is on it. After a category is picked it offers "Remember this for next time". A failure is a plain card with a coral edge, **Show details** and Copy |
| Header | **Working** is the large number (coral below zero; Owed on a card), Cleared and Uncleared under it, each a click that picks out its rows. "Last reconciled on" and Reconcile (not on cash). The forecast chart fills the rest of the card |
| Forecast | Range buttons To income (with a payday ahead) · 30 days · 90 days · 1 year · Custom…. The line steps at each dated row and slopes with the budget's day-to-day spending, drawn as a band; coral below ₮0, its dip marked Lowest. The key, Money out · Day-to-day · Transfer · Money in, lights its marks and opens every bill with the balance after each. Hover reads any day; a click on an event opens its row. Words only where the chart can't speak: nothing scheduled, a wallet to fill, what a card is owed, running out past the range |
| Reconcile | Takes the balances' place: Statement date, Bank balance, Cleared here and Off by, with a hint at the likely row. When they differ, "Add ₮… to the balance and lock"; when they match, Lock N transactions. The database refuses changes to locked rows |
| Budget | Spending and Income tabs; period arrows and Back to today; the title picks Month or an income's pay periods. The key: Cash & bank, In categories, Overspent, Not assigned (green), "Assigned too much", Assign what's planned, Clear September's Assigned. The income card sets the period's plans against its income. Each category reads Assigned · Spent · Left; Left is green, gray at zero, coral when short, and **Move money** moves it. A ring before the name shows how used up it is. Everyday categories, then the person's groups, then **Bills** ("paid 10.20", or Skip this bill), then **Saved**; a **Total** row; each currency on its own |
| Budget: Saved | The built-in Safety net, listed last under "Saved"; its money builds up. Renamed and edited, not deleted or archived. Made the first time a ledger past setup opens without one |
| Categories | Add category and "New category" in the entry row open the same window, with Add, then start another. It and Edit open on four type cards with pictures (#429): **Day-to-day** (an amount each month or pay period, Just for September, what's left at month's end), **Fund** (an amount each period, Most it holds), **Bill** (Amount due, How often: Twice a month with Starts, Every payday, Custom…, On these dates…; Ends), **Goal** (Amount to have ready, Ready by, once or repeating, shown on Savings by what was put toward its next date, never marked paid). The phone's New category has the same cards, two to a row. Also one **Paid from**, Currency; in Edit, Group, Note, In a month of expenses?, Archive, Delete…. The type isn't stored: it comes from the plan. One built-in Income |
| Regular income | On the Income tab: a name, who it's from, Paid into, the amount (About the same each time, or It varies), How often as a category's or No set day, the first payday, a weekend rule, Ends, each with an ⓘ. "I don't have regular income". "Stop counting on this income" asks what its categories go by from then |
| Savings | The owner's four steps with their pictures: Build a safety net (a month of expenses from the budget; what's Left in the Safety net), Eliminate debt (each card and loan's rate, interest and payment; Smallest first or Highest rate first, with when each pays it all off), Build three to six months of savings, Save for the future. Each is done, current, later or skipped for now. Goals under the steps: what for, how much, by when; on track or behind, and what each asks a month. One currency |
| Payees | Every payee the app remembers a category for, a line each that reads as a sentence ("starts with «Unitel»"), its accounts, its category, Delete. A click or Add a payee opens its Edit in place: the words, where to look, Accounts, Category, how many rows it fits, one drawn as it will read. Save offers to file this period's rows in Not categorized; rows in a category are never moved. On import the longest words win, then the later-made |
| Import | `.xls`, `.xlsx`, CSV and OFX, told apart by contents; the column choice is saved per account. Two counts, to import and skipped. A typed row the file has is cleared, not added; one at another amount is offered ("Same purchase: take the bank’s ₮…"). A check of the bank's running balance; a warning when rows overlap an earlier import. Remembered payees file the rows; one in a bill's category pays it. One undo |
| Currencies | 155, each with its own decimals and symbol ([currencies.md](currencies.md)). A transfer between two takes both amounts and shows the rate, through a hidden exchange account. Net worth has a line per currency |
| Two computers | The folder holds the whole ledger and one change file per computer, written only by it. Each looks at launch, on coming to the front and every 15 seconds, and brings in the others' changes ("4 transactions from Tom’s MacBook Air", no Undo; what was here is in Backups). A row or Assigned amount changed two ways is asked first, one window: Keep this computer's, Keep the other's, Neither: as it was; answered on one, the others aren't asked. Only a ledger that can't be put together asks which whole ledger to keep. A second computer joins by Open ledger, or Restore from… with "Share the ledger in My Drive/BetterBudget". Open the app from Applications, never from inside the Drive folder |
| Backups | A copy a day, keeping the newest 14 and the first of each of 12 months. Back up to… ("Last backup 41 days ago" after 30 days, unless in a folder). Restore from… and "Erase everything and start over…" save what was there first, and undo. "Move my ledger to a folder…" keeps it, encrypted, as `Ledger.betterbudget` in a Drive, OneDrive, Box or Dropbox folder, written 5 seconds after a change; "Stored in" says where |
| Security | A recovery key shown once at setup (the clipboard cleared a minute after a copy); a key from before 11:50 on 2026-09-29 ends in an older check character, and the app takes both (the owner's is one). A screen asks for it when this device has none. Settings → Security, "Check my recovery key…" ([ADR 0001](decisions/0001-database.md)) |
| Appearance | Same as this Mac, Light or Dark; 101 color schemes, the app's own first: the logo's navy sidebar, a cool white page by day and blue-black at night, green main buttons, blue for what you click, the coins' gold for what was saved. In every scheme money in is green, money out ordinary ink, coral a shortfall or failure, gold reconciled |
| Language | Same as this Mac, English or Монгол; 1,662 messages, the same keys in both files |
| Setup | "Your accounts": one date for every balance, a line per account, "How do you pay for everyday things?", Continue. "Your regular income": the form, with a card beside it of what it does to the forecast and budget, then "Open my ledger". It resumes where it was left and never returns once done. A computer with no ledger and no key opens on "How do you want to start?": Start fresh, Restore from backup, Open ledger; cancelled, "Where is your ledger?" asks |
| Settings | Appearance, Colors, Language, Backups, Security, Register (the Source column; a name for each computer and phone), Archived accounts, Start over, the version. **Recent problems** while there are any: the newest five, on this computer only, no amounts, with Copy all. **Send feedback…** under Net worth opens lls.mn's contact form with the version, platform and system |
| Phone | Android and iPhone, to record and check ([ADR 0005](decisions/0005-mobile-companion.md)). Set up once with the recovery key and the folder; reads `Ledger.betterbudget` there every half minute and says how fresh it is. **Ledger**: an amount pad, payee, account, a Category dropdown (Split at the top, each regular income by name, transfers, + New category), Save; "1 entry isn't on your computer yet". **Budget**: what's left in each category with its ring, Accounts, Send feedback…, Recent problems. Entries go to the phone's own file in the folder and come in on the computer as uncleared rows. `DEMO-DEMO-DEMO-DEMO-DEMO` as the key opens made-up figures |
| Windows | The Store app keeps the ledger, its copies, the saved key and settings in its package folder, so uninstalling leaves nothing; the old zip download's ledger comes over with Open ledger |
| Demo data | Tests only (`LedgerScreen.demo`): TDB Checking, Khan Savings, Cash wallet, Golomt Visa, the Safety net. The app never seeds it |

Rules behind each: ADR 0004 and ADR 0005. Where the code is: [MAP.md](MAP.md).

## Known limits, accepted

**Dropped:** putting `+` in the amount when a payee's last row was
money in. It is a guess filled into a field (owner, 2026-10-08: "Don't autofill").

A scheduled split confirms at its planned total only;
"Back up to…" overwriting a file isn't atomic in the sandbox; the newest 5
`before-restore` copies are kept, not the oldest; undoing a reconcile in a later
session loses the statement balance.

## Local setup notes

- **Toolchain:** Flutter via Homebrew (`brew install --cask flutter`). Xcode is selected
  (`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`). If the macOS build
  fails with `tapi error … MacOSX27.0.sdk`, `xcode-select` is pointing at the Command Line
  Tools again.
- **Signing:** the Mac and iPhone apps sign with the paid team "Loveland Solutions, LLC"
  `44H5SLX8KR`, needed for the Keychain entitlement and the App Store; a build signed by
  another team can't read the ledger's key (ADR 0001). No iPhone is registered, so an
  iPhone build reaches a phone only through TestFlight. If Xcode asks for a new
  provisioning profile, run once from `app/macos`: `xcodebuild -workspace
  Runner.xcworkspace -scheme Runner -configuration Debug -allowProvisioningUpdates build`.
  Android's package is `mn.lls.betterbudget` (the Apple one,
  `com.lovelandsolutions.betterbudget`). Release builds sign with the upload key
  `~/betterbudget-upload.jks` (alias `upload`) when the git-ignored
  `app/android/key.properties` holds its password, otherwise with the debug key; the owner
  keeps them in KeePass. `keytool` is Android Studio's,
  `/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool`.
- **Goldens** are drawn on macOS 27; another macOS version differs by about 0.1%.
- **If tests stall** (widget tests time out with the CPU idle), look for leftover
  `flutter_tester` or `dart pub get` processes (`ps -ax | grep -E "flutter|dart"`), then
  restart the Mac.
- **Checks on GitHub:** `.github/workflows/check.yml` runs analyze and test on each pull
  request touching `app/`, about 17 minutes, not required for merging (MAP.md "Checks on
  GitHub").
- **The logo** and the Savings pictures are made by `assets/logo/prepared/prepare.py` from
  the owner's five vectors in `assets/logo/Images/`; the rest of that folder is on the
  owner's Mac only, not in git.
- **Run:** `cd app && flutter run -d macos`, or build with `flutter build macos --debug`
  and open `app/build/macos/Build/Products/Debug/BetterBudget.app`.
- **Rebuild and relaunch** (from `app/`): the owner runs a Release build signed by the
  company team (44H5SLX8KR), so build that, then quit and open it: `xcodebuild -workspace
  macos/Runner.xcworkspace -scheme Runner -configuration Release -derivedDataPath
  build/macos-company -allowProvisioningUpdates build && pkill -f
  "BetterBudget.app/Contents/MacOS"; open
  build/macos-company/Build/Products/Release/BetterBudget.app`.
- **App data:** `~/Library/Containers/com.lovelandsolutions.betterbudget/Data/Library/Application Support/com.lovelandsolutions.betterbudget/Ledger.betterbudget`
  (plus `-wal`, `-shm`). **This file is production data.** Never delete, reseed, erase or
  hand-edit it; tests use demo data, and anything tried by hand goes on a copy.
- **Screenshots of the running app:** `screencapture -l<window id>` works once the
  terminal has screen-recording permission; get the window id from
  `CGWindowListCopyWindowInfo` for owner `BetterBudget`.
- `tdb-bank-transaction-exports/` and `afcu-bank-transaction-exports/` hold **real,
  unredacted** statements. Both are gitignored and must stay that way. Committed
  fixtures must be redacted: real headers, real date format, real Cyrillic payee
  strings, scrubbed account numbers, synthetic amounts.
- Reading legacy `.xls` during analysis needs `xlrd` in a throwaway venv.
