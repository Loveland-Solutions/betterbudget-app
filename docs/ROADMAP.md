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
  policy. The code stays private here. The earlier private Tauri project that had the
  name is now `Loveland-Solutions/betterbudget-tauri-archive`. Its local clone
  (`~/Repositories/BetterBudget`) was repointed, so a push from it can't reach the public repo.

## Before beta

### A. Alpha leftovers (from STATUS "Next step")
- [x] The owner erases the test data and enters real accounts (erased 2026-09-30)
- [ ] Recurring bills (rent, СӨХ, utilities, phone) on the pay schedule model. The
      annual and quarterly budget items in C build on this.
- [ ] CI running `flutter analyze && flutter test` on pull requests. Windows and Linux
      builds need it anyway (F, H).

### B. Report a bug → public repo (owner item 1)
- [x] Create the public repo (2026-09-30). It holds issues, releases and download assets; the code
      stays private here.
- [ ] Help → Report a bug… opens the browser at a new issue with the app version, OS
      and platform filled in. **No ledger data, ever.** The app makes no network call
      itself: the browser opens the link, and only when the user clicks it (unbreakable rule).
- [ ] Issue templates in the public repo (bug, idea)
- [ ] Releases: notarized macOS download attached to a GitHub release. Downloads outside
      the App Store come first because they're faster to ship.
- [ ] Find updates by hand: Help → "Check for a newer version" opens the releases page
      in the browser. The app never checks on its own.

### C. Budget page, polished (owner item 2)
Budget types, as understood (owner, correct me):
- **Spend through the month** (groceries): money goes in each period and is spent down.
  Choose whether what's left rolls over.
- **Save up, spend any time** (Christmas, car repairs): a set amount goes in each
  period, and the balance builds and can be spent whenever needed.
- **Due on a date** (annual insurance, quarterly СӨХ or taxes): the bill amount divided
  into equal parts up to the due date, with "on track / ₮X short" shown.
- **Goal** (₮X by a date): the amount needed each period is worked out from what's left
  and the time left. Linked to Savings (D).

Work:
- [ ] Sketch the Budget page (envelopes, decided)
- [ ] Budget amounts per category per period (month or pay period, set in Settings)
- [ ] Rollover, including what happens after overspending: sketched as options
- [ ] The four budget types above
- [ ] Bills due less often than monthly (annual, quarterly, every N months)
- [ ] A category's rows, opened from Budget, show that period (STATUS open question 4)
- [ ] Money not yet budgeted, shown plainly
- [ ] Both reviews

### D. Savings, the differentiator (owner item 3)
"Other budgets help you make it through the month. This budget helps you make it
through life." Today Savings shows the self-reliance course steps (rule 25).
- [ ] Sketch what Savings becomes beyond the steps: goals with dates, and life events
      (missions, weddings, school, a house, a car, retirement), showing whether each
      is on track
- [ ] Goals are set up in Savings and paid for through budget lines (C)
- [ ] How far each step has come, not just done or not done: "1 month set aside: ₮X of ₮Y"
- [ ] Both reviews, plus a committee of agents if the owner wants one

### E. MNT and USD (owner item 4)
Today: one MNT account and two USD accounts. The schema already stores `currency` and
`rate` on entries (ADR 0003); the UI assumes MNT only.
- [ ] Each account has a currency. Its register, balance and reconcile all use that currency.
- [ ] **Transfers between currencies**: the user enters both sides, what left the MNT
      account and what arrived in the USD account. Double entry stays balanced
      within each currency through a hidden exchange account, so the books still
      balance with no rate stored. The rate is shown after the fact ("₮3,450 per $1").
- [ ] Money formatting for each currency ($ and ₮, where the symbol goes, 2 decimals)
- [ ] Totals shown in each currency separately (decided): net worth, All accounts, the forecast
- [ ] Budget categories: choose a currency for each category, or keep categories in MNT only.
      Sketch this with C.
- [ ] US date format as an option (the student persona). STATUS mentions it.
- [ ] Schema upgrade and tests. The copy made before the upgrade still applies.

## After beta ("eventually")

### F. Mac App Store (owner item 5)
- [ ] App Store Connect record, bundle ID `com.lovelandsolutions.betterbudget`
- [ ] Sandbox check: release entitlements have no network. Debug has
      `network.server` for Flutter tooling only; confirm it isn't in Release.
- [ ] Privacy label ("Data not collected"), screenshots, description, privacy policy
      page (it can live in the public repo)
- [ ] Keychain and recovery key work as expected in an App Store build (ADR 0001)
- [ ] TestFlight for Mac, then submit for review

### G. Windows (owner item 6)
- [ ] A Windows machine or CI runner (`app/windows/` is scaffolded, never built)
- [ ] Encryption on Windows verified (Credential Manager, ADR 0001)
- [ ] Shortcuts already have Ctrl versions; check fonts, title bar, file dialogs
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
- [ ] Sync format (Mac snapshot, one inbox per phone)
- [ ] Entry screen and budget-left screen
- [ ] Encryption on Android verified
- [ ] TestFlight / Play internal testing, then the stores

## Still on the list from STATUS (not beta blockers unless the owner says so)
Splits, TDB import, search, sorting, cash accounts, better "not cleared" note, duplicate
check on Confirm, several overdue bills, backup reminders, Mongolian UI strings, app lock.
