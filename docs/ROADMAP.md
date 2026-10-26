# Roadmap: alpha to beta and beyond

**Started 2026-09-30** from the owner's list. [STATUS.md](STATUS.md) says what's built
today. This file keeps the owner's decisions about the road to beta and after, and
what is done in each part. **What's left is on the [BetterBudget board](https://github.com/orgs/Loveland-Solutions/projects/1)**, one
issue each; the milestone says Beta or After beta. Record design choices in ADR 0004
(or a new ADR), not here.

Each feature still gets the usual steps: two or three options with sketches, the owner
picks one, build it, run both reviews, merge.

## Decided (owner, 2026-09-30)

- ~~**Beta means other people download it** from the public repo's releases.~~
  Superseded 2026-10-20; see below.
- **Totals across currencies are shown separately**: net worth shows ₮X and $Y on
  their own lines. No rate is stored. Rejected: one MNT total at a rate typed by hand
  (it drifts).
- **Budget model: envelopes.** Each category keeps its own balance from period to
  period (STATUS open question 4, closed). Rejected: targets that start fresh every month.
- **Public repo: [`Loveland-Solutions/betterbudget`](https://github.com/Loveland-Solutions/betterbudget)**
  (created 2026-09-30, public, README only), holding the privacy policy (Issues off
  since 2026-10-27)
  (no releases since 2026-10-20). The code is in this repo, public too since 2026-10-16. The earlier private Tauri project that had the
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

## Decided (owner, 2026-10-20): stores only

- **Beta is a fully functioning, fully featured app.** It is a measure of the app,
  not of how people get it.
- **No downloads from GitHub.** BetterBudget is distributed only through the Apple
  App Store, Google Play and the Microsoft Store, which also handle updates. Owner:
  "I would be constantly fighting signatures." So no Developer ID signing, no
  notarized downloads (#94, #152 closed as not planned) and no update check.
- **Done the same day:** the public repo's `PRIVACY.md` lost its "download from our
  GitHub page" paragraph (last updated October 20, 2026; `0f501a8`), and its README
  no longer links to Releases; lls.mn's copy of the policy matches and is live. This
  repo's README says the same (PR #220).
- **Owner to decide:** 0.35.1, 0.36.0 and 0.38.0 are still published on the public
  repo's releases page.

## Before beta

### A. Alpha leftovers (from STATUS "Next step")
- [x] The owner erases the test data and enters real accounts (erased 2026-09-30)

Open: #88, #89.

### A1. A fine-tooth comb before release (owner, 2026-10-16)
"Go over the ledger, budget, savings, and payees sections with a fine tooth comb."
Every screen, control, word and figure in each section, against CLAUDE.md's rules,
before release.

Open: #161 (Ledger #162, Budget #163, Savings #164, Payees #165).

### A2. Mongolian interface (owner, 2026-09-30)
Decided in ADR 0004 ("Language"): Settings → Language, follows the Mac; drafted here,
checked by a native speaker; dates in sentences read "9-р сарын 30".
- [x] Settings → Language, every screen translated, Mongolian screenshots in the tests

Open: #90.

### B. Report a bug → lls.mn (owner item 1)
**Moved to the website** (owner, 2026-10-15: "Yeah, let's move them"). Bug reports
and requests (a bank whose file doesn't import right, an idea) come through the
contact form on lls.mn, which needs no account, instead of GitHub issues. The
public repo keeps the privacy policy.
- [x] Create the public repo (2026-09-30). It holds the privacy policy; the code
      is in `betterbudget-app`, public since 2026-10-16.
- [x] The public repo's README points to Report a problem… and lls.mn's form, and its
      Issues are off (#93, 2026-10-27).
- [x] Version numbers in the app (0.1.0, shown in Settings; ADR 0006), 2026-09-30.

Open: #95.

### B2. Free and open source (owner, 2026-10-16)
"I've decided that I'm going release this as open source." And: "I'm going to just
have it for free." Free on every platform and in every store; the code public.
- [x] `PRIVACY.md` section 4 says BetterBudget is free, with nothing to buy inside it.
- [x] Licence: GPL-3.0 or later, `LICENSE` (PR #82; "Decided (owner, 2026-10-16): open
      source" above). Outside contributions under GPL need a contributor agreement if
      the owner may ever relicense.
- [x] Checked before going public: no value from the bank statements is in the files
      or the history but a masked card number in an early ADR 0002 (kept, owner's
      call). Ledger figures in the docs are the demo ledger's or test amounts (owner,
      on the overflow note's balance: "it was a test amount"). Secrets: recovery-key files, the bank statement folders and
      `key.properties` are git-ignored and were never committed.
- [x] This repo went public on 2026-10-16, with its whole history.

Open: #96, #97, #98.

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
- [x] Both reviews for plans (PR #30) and for currency and accounts (PR #31); each new
      piece gets its own

Open: #99, #100, #129.

### D. Savings, the differentiator (owner item 3)
"Other budgets help you make it through the month. This budget helps you make it
through life." Today Savings shows the owner's four steps, each with its picture
(ADR 0004 "Four Savings steps", 2026-10-09): a safety net, no debt but the house,
three to six months, saving for the future.
- [x] A debt's interest rate on step 2, typed there or on Add account, a month's or
      a year's; debts listed by what each costs a month (2026-10-14, 0.35.0; ADR 0004
      "A debt's interest rate on step 2")

Open: #101, #102, #103, #174, #191.

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
- [x] Budget categories: each spending category is in one currency, with a pool per
      currency and a checklist of the accounts it uses (ADR 0004 rule 28, schema v12)
      Sketch this with C.

Open: #104, #105, #106, #107.

## After beta ("eventually")

### F. Mac App Store (owner item 5)
- [x] Privacy policy (2026-10-14): `PRIVACY.md` in the public repo,
      https://github.com/Loveland-Solutions/betterbudget/blob/main/PRIVACY.md, and its
      copy on the website, https://lls.mn/en/betterbudget/privacy/, the address for every
      store's listing (owner, 2026-10-23, for the Microsoft Store)

Open: #108, #169.

### G. Windows (owner item 6)
- [x] Built on GitHub (`.github/workflows/windows.yml`, PR #86, 2026-10-16); not yet run
      on a Windows PC

Open: #109, #171.

### H. Linux, RPM and deb (owner item 8)

Open: #110.

### I. Phone entry apps, iOS and Android (owner item 7)
Designed in [ADR 0005](decisions/0005-mobile-companion.md): record transactions and see
what's left in each budget, synced through a cloud folder the user picks. Comes after C,
since phones show budget amounts.
- [x] The ledger stored in a cloud folder, written by the Mac (2026-10-07,
      `Ledger.betterbudget`)
- [x] Entry screen and budget-left screen, on Android, reading the folder (2026-10-07)
- [x] Android's Play name and upload key (2026-10-14): the package is
      `mn.lls.betterbudget`, registered in Play Console's developer verification
      with the upload key's SHA-256 fingerprint. The key is `~/betterbudget-upload.jks`
      (alias `upload`), backed up by the owner; `app/android/key.properties`
      (git-ignored) holds its password, and release builds sign with it. The Mac
      keeps `com.lovelandsolutions.betterbudget`, where its ledger and key live.
- [x] Play Console set up, and the app on the owner's phone through Internal testing
      (2026-10-16)

Open: #111, #112, #113, #114, #189, #190.

## Not tied to a release

Search, sorting, counting a cash account, splits, the rest of Payees, the overflow
stripe and the failure popup are on the [board](https://github.com/orgs/Loveland-Solutions/projects/1) with no milestone. Their notes
moved into those issues on 2026-10-16.
