# Roadmap: alpha to beta and beyond

**Started 2026-09-30** from the owner's list. [STATUS.md](STATUS.md) says what's built
today. This file lists what's left before the owner calls it beta, and what comes after.
Tick items off here as PRs merge. Record design choices in ADR 0004 (or a new ADR), not here.

Each feature still gets the usual steps: two or three options with sketches, the owner
picks one, build it, run both reviews, merge.

## Decided (owner, 2026-09-30)

- **Beta means other people download it** from the public repo's releases. So the bug
  link and signed downloads (B) block beta, along with the budget, Savings and USD.
- **Totals across currencies are shown separately**: net worth shows ₮X and $Y on
  their own lines. No rate is stored. Rejected: one MNT total at a rate typed by hand
  (it drifts).
- **Budget model: envelopes.** Each category keeps its own balance from period to
  period (STATUS open question 4, closed). Rejected: targets that start fresh every month.
- **Public repo: [`Loveland-Solutions/betterbudget`](https://github.com/Loveland-Solutions/betterbudget)**
  (created 2026-09-30, public, README only), holding issues, releases and the privacy
  policy. The code is in this repo, public too since 2026-10-16. The earlier private Tauri project that had the
  name is now `Loveland-Solutions/betterbudget-tauri-archive`. Its local clone
  (`~/Repositories/BetterBudget`) was repointed, so a push from it can't reach the public repo.

## Decided (owner, 2026-10-16): open source

- **The code is open source, under GPL-3.0 or later**, and `betterbudget-app` is public
  with its whole history. Rejected: MIT or Apache-2.0 (a closed fork could add tracking
  and sell it); a fresh repo with one first commit (the owner is fine with the process
  being seen). The license covers the code, not the BetterBudget name and logos; the
  fonts keep the OFL.
- **A masked card number stays in the history** (owner: "Leave it"). An early ADR 0002
  quoted a TDB card number the way the bank masks it (first six, last four) and a
  teller code; later commits removed both. Rewriting history was rejected.

## Before beta

### A. Alpha leftovers (from STATUS "Next step")
- [x] The owner erases the test data and enters real accounts (erased 2026-09-30)
- [ ] Recurring bills (rent, СӨХ, utilities, phone) on the pay schedule model. The
      annual and quarterly budget items in C build on this.
- [ ] CI running `flutter analyze && flutter test` on pull requests. Windows and Linux
      builds need it anyway (F, H).

### A2. Mongolian interface (owner, 2026-09-30)
Decided in ADR 0004 ("Language"): Settings → Language, follows the Mac; drafted here,
checked by a native speaker; dates in sentences read "9-р сарын 30".
- [x] Settings → Language, every screen translated, Mongolian screenshots in the tests
- [ ] A native speaker goes through [the review sheet](mongolian-review.csv) (fill the
      "corrected" column); corrections go into `app/lib/l10n/app_mn.arb`
- [ ] The official Mongolian title of the course in Savings

### B. Report a bug → public repo (owner item 1)
- [x] Create the public repo (2026-09-30). It holds issues, releases and download assets; the code
      is in `betterbudget-app`, public since 2026-10-16.
- [ ] Help → Report a bug… opens the browser at a new issue with the app version, OS
      and platform filled in. **No ledger data, ever.** The app makes no network call
      itself: the browser opens the link, and only when the user clicks it (unbreakable rule).
- [ ] Issue templates in the public repo (bug, idea)
- [x] Version numbers in the app (0.1.0, shown in Settings; ADR 0006), 2026-09-30.
- [ ] Releases: notarized macOS download attached to a GitHub release (tag-driven; see
      ADR 0006 before setting up CI). Downloads outside
      the App Store come first because they're faster to ship. Built (2026-10-16):
      `tool/release_mac.sh` and the Windows workflow. Waiting on the paid Apple
      team in Xcode (only the free Personal Team is signed in), and on a first run
      of the Windows build on the owner's PC before it's attached. Moving the Mac
      app to the paid team changes its Keychain group, so the first build signed by
      it asks for the recovery key once; try it on the testuser account first.
- [ ] Find updates by hand: Help → "Check for a newer version" opens the releases page
      in the browser. The app never checks on its own.

### B2. Free and open source (owner, 2026-10-16)
"I've decided that I'm going release this as open source." And: "I'm going to just
have it for free." Free on every platform and in every store; the code public.
- [x] `PRIVACY.md` section 4 says BetterBudget is free, with nothing to buy inside it.
- [ ] Copy `PRIVACY.md` to the website word for word (lovelandsolutions-website
      `src/legal/betterbudget-privacy/en.md`).
- [x] Licence: GPL-3.0 or later, `LICENSE` (PR #82; "Decided (owner, 2026-10-16): open
      source" above). Outside contributions under GPL need a contributor agreement if
      the owner may ever relicense.
- [x] Checked before going public: no value from the bank statements is in the files
      or the history but a masked card number in an early ADR 0002 (kept, owner's
      call). Ledger figures in the docs are the demo ledger's or test amounts (owner,
      on the overflow note's balance: "it was a test amount"). Secrets: recovery-key files, the bank statement folders and
      `key.properties` are git-ignored and were never committed.
- [x] This repo went public on 2026-10-16, with its whole history.
- [ ] Everything that says the code is private: the public `betterbudget` repo's README
      ("The app's source code is private"). This file and CLAUDE.md are done.
- [ ] Store listings set to free.

### C. Budget page, polished (owner item 2)
Budget types (owner, 2026-10-03, two instead of four; ADR 0004 rule 27):
- **Any time** (groceries, car repairs): a set amount each period. What's left carries
  over or goes back; carrying over, an optional cap ("up to ₮X") stops the asking.
- **On a date** (water, annual insurance, quarterly СӨХ, a certificate every three
  years, a birthday): an amount by a date, once or repeating, split over the periods
  left; a missed part spreads over the rest. Paid from an account, the bill is kept
  scheduled there so the forecast counts it. Goals in Savings (D) are these.

Work:
- [x] Sketch the Budget page (envelopes, decided): Put in · Spent · Left a line,
      overspending carries as minus, card debt reduces the money (ADR 0004 rule 26)
- [x] Budget amounts per category per period (month or pay period; since 0.8.0 each
      category's own, and the Budget page's view, ADR 0004 "Two earners")
- [x] Rollover, including what happens after overspending: sketched as options
      (carries as minus, rule 26)
- [x] Plans: a plan per category, a note under its name, and "Assign what's planned"
      (ADR 0004 rule 27, schema v11); the four types became the two above, with the
      cap, the spread of a missed part, repeats up to every three years, and Paid from
      scheduling the bill in its account (2026-10-03, schema v14)
- [x] Bills due less often than monthly, or oftener: How often is Once, the presets,
      Every payday, Every N days/weeks/months/years, or On these dates each year,
      with a weekend rule (rule 27, schema v15)
- [x] A category's rows, opened from Budget, show that period (STATUS open question 4)
- [x] Money not yet budgeted, shown plainly
- [ ] Move money between categories ("Money can be moved in from another
      category any time", rule 26); today it's two typed amounts
- [ ] The forecast's "Nothing has been budgeted" sentence switches on the budget
- [x] Both reviews for plans (PR #30) and for currency and accounts (PR #31); each new
      piece gets its own
- [ ] More controls on a line (owner, 2026-10-02): order or groups, a one-period
      change or pause for a plan, a note, a cap, clearing a period (STATUS "Next step")

### D. Savings, the differentiator (owner item 3)
"Other budgets help you make it through the month. This budget helps you make it
through life." Today Savings shows the owner's four steps, each with its picture
(ADR 0004 "Four Savings steps", 2026-10-09): a safety net, no debt but the house,
three to six months, saving for the future.
- [ ] Sketch what Savings becomes beyond the steps: goals with dates, and life events
      (missions, weddings, school, a house, a car, retirement), showing whether each
      is on track
- [ ] Goals are set up in Savings and paid for through budget lines (C)
- [ ] How far each step has come, not just done or not done: "1 month set aside: ₮X of ₮Y"
- [ ] Both reviews, plus a committee of agents if the owner wants one

### E. MNT and USD (owner item 4)
Today: one MNT account and two USD accounts. The schema already stores `currency` and
`rate` on entries (ADR 0003); the UI assumes MNT only.
- [x] Each account has a currency. Its register, balance and reconcile all use that currency.
      (Chosen at creation, PR #24, ADR 0004 "Tugrik and dollars".)
- [x] **Transfers between currencies**: the user enters both sides, what left the MNT
      account and what arrived in the USD account. Double entry stays balanced
      within each currency through a hidden exchange account, so the books still
      balance with no rate stored. The rate is shown after the fact ("₮3,450 per $1").
- [x] Money formatting for each currency ($ and ₮, where the symbol goes, 2 decimals)
- [x] Totals shown in each currency separately (decided): net worth, All accounts, the forecast
- [x] **Every currency** (owner, 2026-10-02, PR #32): the 155 ISO currencies a person
      can hold, each with its own decimals and symbol ([currencies.md](currencies.md))
- [ ] Whether the currency list also lives in the ledger file (owner asked; not
      decided)
- [ ] Savings with two currencies (counts the main one for now; owner to decide)
- [ ] Changing an account's currency after it has rows
- [x] Budget categories: each spending category is in one currency, with a pool per
      currency and a checklist of the accounts it uses (ADR 0004 rule 28, schema v12)
      Sketch this with C.
- [ ] US date format as an option (the student persona). STATUS mentions it.
- [ ] Schema upgrade and tests. The copy made before the upgrade still applies.

## After beta ("eventually")

### F. Mac App Store (owner item 5)
- [ ] App Store Connect record, bundle ID `com.lovelandsolutions.betterbudget`
- [ ] Sandbox check: release entitlements have no network. Debug has
      `network.server` for Flutter tooling only; confirm it isn't in Release.
- [x] Privacy policy (2026-10-14): `PRIVACY.md` in the public repo,
      https://github.com/Loveland-Solutions/betterbudget/blob/main/PRIVACY.md, the address
      for every store's listing
- [ ] Privacy label ("Data not collected"), screenshots, description
- [ ] Keychain and recovery key work as expected in an App Store build (ADR 0001)
- [ ] TestFlight for Mac, then submit for review

### G. Windows (owner item 6)
- [ ] A Windows machine or CI runner (`app/windows/` is built on GitHub since 2026-10-16, never run; the owner has a Windows PC to try it)
- [ ] Encryption on Windows verified (Credential Manager, ADR 0001)
- [ ] Shortcuts already have Ctrl versions; check fonts, title bar, file dialogs
- [ ] The window stops at 1360 × 760 as on the Mac (ADR 0004 "The smallest
      window"); until then a smaller window shows the app shrunk
- [ ] Installer (MSIX, and later the Microsoft Store), signed; attach it to public releases

### H. Linux, RPM and deb (owner item 8)
- [ ] Scaffold `app/linux/` (it doesn't exist yet) and build in CI
- [ ] Encryption verified with Secret Service. Without it, the app asks for the
      recovery key at launch (ADR 0001).
- [ ] Packages: `.rpm` (Fedora, RHEL) and `.deb`. Maybe a Flatpak later.
- [ ] Attach them to public releases

### I. Phone entry apps, iOS and Android (owner item 7)
Designed in [ADR 0005](decisions/0005-mobile-companion.md): record transactions and see
what's left in each budget, synced through a cloud folder the user picks. Comes after C,
since phones show budget amounts.
- [x] The ledger stored in a cloud folder, written by the Mac (2026-10-07,
      `Ledger.betterbudget`)
- [ ] **More than one computer on the same ledger** (owner, 2026-10-07; the way
      chosen 2026-10-09: combine, ask only on a conflict, both open at once; three
      steps in ADR 0005, none built)
- [ ] One file of entries per phone, taken in by the Mac
- [x] Entry screen and budget-left screen, on Android, reading the folder (2026-10-07)
- [ ] The iPhone build: folder access, icon
- [ ] Encryption on Android verified
- [x] Android's Play name and upload key (2026-10-14): the package is
      `mn.lls.betterbudget`, registered in Play Console's developer verification
      with the upload key's SHA-256 fingerprint. The key is `~/betterbudget-upload.jks`
      (alias `upload`), backed up by the owner; `app/android/key.properties`
      (git-ignored) holds its password, and release builds sign with it. The Mac
      keeps `com.lovelandsolutions.betterbudget`, where its ledger and key live.
- [ ] TestFlight / Play internal testing, then the stores

## Still on the list from STATUS (not beta blockers unless the owner says so)
Search, sorting, cash accounts, app lock; splits are below, in the owner's words. (The better "not cleared" note,
the duplicate check on Confirm, the count of overdue bills and the backup reminder
were built on 2026-10-09: ADR 0004 rule 20 and "Backups".)

**A search field at the top of the categories** (owner, 2026-10-12: "there will be a
lot of categories. Let's put a search field at the top for them."). Where categories
are picked from a list: the Category dropdown on a ledger row (Categorize, and the
chip on the row), the Category dropdown in a payee's Edit on the Payees page, and
the Budget page's list of categories. The entry row's Category field already
narrows as you type; the dropdowns and the Budget page don't. Design it and show
it to the owner first.

**Splitting one transaction over categories** (owner, 2026-10-12: "we need to make
sure there is a way to split categories on a transaction: I go to Walmart and buy
clothing and groceries under one receipt. I'll need to be able to handle that. Put
that in our list of things to do."). Today a split row can be shown (demo data has
one) but can't be made or edited (`splitNotEditable`). To build: from a row, and
while adding one, the amount divided over two or more categories, each with its own
amount, the parts adding up to the receipt; then Edit for a split. Design it and
show it to the owner first.

**Payees: the real feature** (owner, 2026-10-12: "Let's make this a real feature…
Like 'contains' this text, etc."). The list, Delete, retyping the words and changing
the category were built on 2026-10-12 as the Payees section (ADR 0004 "Payees: its
own section"). The budget-app expert's brief the same day, from the redacted
fixtures' row shapes (ADR 0002: most TDB rows have no counterparty, so the payee is
the bank's text, "POS 12345678: НОМИН"; Khan and Golomt put the shop or person in
the middle; the same shop comes in three spellings a month), ranked what's missing.
**Built the same day (version 0.28.0, schema v19; layout B, the owner's pick; a
payee on several accounts, the owner's ask):** (1) the words may be anywhere, and the app also reads the
bank's description (a rule made from the popup stays "starts with"; the page
switches it); (2) the count, live, before saving: "14 rows in TDB Checking · 9 still
in Not categorized · 2 in another category", so a short word like "QPay" shows
itself as a large count (said, not prevented); (3) adding a payee on the page for
one that has none; (4) after any change, the same button to file the rows still in
Not categorized, never the filed ones (owner: moving filed rows "would be really
bad"); (5) what Delete means: today an import with no rule files an exact payee
where it went last, so Delete looks broken; recommended: Delete really forgets and
the next import leaves that payee in Not categorized; (6) one line for every account,
offered only with more than one; (7) when two fit, the longer words win, then the
later one, said only when it happens. **Soon, each a question for the owner:**
(8) a payee that is money moved to another account (a transfer), same currency only;
(9) "Shown as": a clean name on import, the bank's text kept in the memo. **Later:**
only money in or out, an amount floor; a second spelling on one line; keeping the
counterparty's account number in the memo. Storage: a table from the start
(`payee_rules`, `payee_rule_accounts`), since a payee holds on several accounts;
the upgrade carries the owner's rules over and leaves the old setting in place.
The two layouts drawn (<https://claude.ai/artifact/7RXhhAREPqtfxLMDrU12ac>) and
the choice, B, are in ADR 0004 "Payees: the real feature".
Also still to do: the offer from a row's Edit, and the offer at the foot of a row's
category dropdown (asked 2026-10-07 and 2026-10-12; the owner said the question
wasn't clear: ask it with a picture of the row).

**No overflow stripe, ever** (owner, 2026-10-14: "that yellow and black overflow
appears in both the phone app and the computer app. We need to constrain things so
the user doesn't see that."). Flutter draws a yellow-and-black stripe where
something is wider than its space. Seen on the computer in an account's header: a
working balance of more than a hundred million tugrik, with cents, runs past its box. To build: find every place a
number or name can grow (balances, amounts, payees, account and category names,
Mongolian words), on the computer and the phone, and make each fit its space at any
size: shrink the number, wrap or cut the words with "…". A test that lays out each
screen with very large amounts and long names and fails on any overflow, so it
can't come back.

**A plain popup for a failure** (owner, 2026-10-10: "let's put this on a
list of things to do"). "Couldn't
save: …" arrives in the gold popup that says a change was saved, and carries the
error's whole text (the owner's was a screen of library paths). To build: a
failure has its own plain popup, saying what didn't happen in one line, with the
detail put away behind a click. About 35 places show one (STATUS, "From the
reviews of the new look").

Moved from STATUS on 2026-10-07, as written there. Each must follow
[ADR 0004](decisions/0004-ledger-ui.md); design each before building it and show it to
the owner.

### Search

**Today:** one box that does a plain substring match on payee, memo, category and amount
digits, in the current account only.

**To build:**
- **Search in All accounts** (the view exists, rule 23): the search box and filter chips there should search every account.
- **Amount search that understands money:** `8000` matches ₮8,000.00, not every amount
  containing those digits; ranges like `>100000` or `50000-120000`.
- **Dates:** a single day (`2026.09.14`), a month (`2026.09`) or a range.
- **Cyrillic-aware matching:** case-insensitive, and a Latin query should find the
  Cyrillic payee and vice versa ("nomin" finds "Номин"). Real bank data will contain both
  spellings (§F).
- **Structured filters** (category, status, amount range, date range) that combine with
  the text, plus **saved filters** for searches people repeat (§G).
- **Results show a total** for what matched. "How much did I spend at E-Mart since
  July?" is usually the reason for searching.

**Questions to settle:** one smart box with a syntax, or a box plus filter chips? What
does the header's forecast show while results span several accounts?

### Cash accounts (owner, 2026-09-17: "not yet")

From budget-app finding F: cash entries saved as cleared, and "Count" instead of
Reconcile, with the difference posted to a category the user picks. **The account Type
now exists** (2026-10-06, schema v18): Cash is one of the three on Add account, it has
its own sidebar group, and a cash account is offered neither Reconcile nor Import.
**Still not built:** the Count flow itself. Until then the difference is typed as an
ordinary row.

### Sorting

**Today:** newest first, fixed.

**To build:**
- Click a column header to sort by **date, payee, category or amount**; click again to
  reverse. The active column shows its direction.
- The sort is remembered for each account.
- It works together with search, filters and multi-select (Shift-click ranges follow the
  visible order, which the code already does).

**Questions to settle:** a running balance only makes sense in date order, so what does
the Balance column show when sorted by amount or payee? Hide it, dim it, or keep each
row's date-order balance? Where do scheduled rows go when not sorted by date?
