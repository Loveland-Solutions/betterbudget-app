# Money-side answers: which conflict answers are safe, which need a rule, which need a person

Read: the brief, ADR 0005 lines 182–492, `app/lib/domain/combine.dart`
(`_sameScheduled`, `_sameBankRows`, `Ask`/`Pick`), schema columns
`entries.cleared`, `entries.reconciliation_id`, `entries.import_key`.

## The household's week (design for this)

Two earners in Ulaanbaatar, a laptop each, one Drive folder. In an ordinary week:
each is paid into their own account (Khan, TDB) and confirms their own payday on
their own laptop; one types most daily spending (groceries, cash, kids), the
other their own card and the big bills (rent, loan, utilities); both have the app
open the same evening, one typing while the other checks whether rent will clear;
both download the same TDB export; one hands the other cash and both type it;
monthly each tops up envelopes, sometimes the same one; each reconciles their own
account. Laptops are shut most of the day, so the usual gap is hours to a day.
Two people editing the same row two ways is rare. Design for additive, disjoint
changes; the duplicates to catch are the same bank row, payday, phone entry and
cash purchase.

## What a wrong automatic answer costs

- A bank balance, silently, found at reconcile or never: a row counted twice
  (payday, bank row, phone entry), a real row dropped (a delete or restore
  winning), an amount, account or date changed, a cleared flag changed inside a
  reconciled statement.
- A budget total (envelope left, to-assign, the forecast): category filing,
  assigned amounts, pay or plan amounts.
- A label: payee, memo, account or category name.

Rules may settle labels freely, and the first two tiers only where one side holds
a fact (the bank file, a reconcile). Otherwise ask. "Later edit wins" is never a
rule: no clock decides (ADR 0005), and later isn't more right; the one holding the
receipt may have typed first.

## Each class

1. **Same transaction edited both sides.** Different columns: both stand (built).
   Same column two ways on amount, account, date or cleared: ask, showing each
   version's full lines (account, amount, category), its cleared state, "as it
   was", and which version, if either, carries a bank import key. One
   bank-matched, the other hand-typed: don't ask; the bank's amount, date and
   account win, said in a toast, and the typed row's filing stays. Payee or memo:
   keep this computer's and say so. Category: ask; a budget total.

2. **Deleted one side, edited the other.** Keep it. A kept row that should be
   gone sits in the register where it can be deleted again; a dropped real row is
   invisible until a balance is off. In words: "If one of you deleted it and the
   other changed it, it stays, with the change, and you're told." Popup with Show
   and "Delete it anyway". A delete that was a dedupe against a bank row is
   class 3.

3. **Same bank row imported on both, filed two ways.** The bank line (date,
   amount, account) is identical on both, so this is never a balance question;
   the only balance error is keeping two. One row, always. One side filed it, the
   other left it unfiled: the filed one wins silently. Both filed differently:
   ask, showing the bank line once and the two filings. A card, not the whole
   ledger. The same purchase typed by hand on one side and imported on the other
   (today's "looks the same") should settle the same way: one row, the bank's
   figures, the typed filing; ask only when the amounts differ.

4. **Pay or plan edited on both.** No posted money moves, but the forecast does,
   and "will rent bounce" rests on it. Different columns stand; the same column
   two ways is asked, with as it was. Rare.

5. **Account renamed on both.** A label. Keep this computer's, mention the other,
   never ask.

6. **Same category assigned on both for one period.** "Larger wins" is unsafe:
   assigned is drawn from one shared pool, so the larger figure can over-assign
   without anyone choosing it. Ask (built), and show under each choice what would
   be left to assign; that is the number they need to answer well.

7. **Reconciled on one side, the other edits a row inside the statement.** A
   reconcile is a fact: the cleared balance on that date matched the bank. Rule,
   no ask: the locked row's amount, account, date and cleared state stay; payee,
   memo and category edits come in. Say it: "Jen changed this to ₮54,000; it's in
   a statement Tom reconciled, so it stays ₮45,000." If the bank really says
   54,000 the reconcile was wrong and the fix is undoing it, a lock the owner
   keeps. A row the other side added cleared inside the period comes in
   uncleared, said aloud; cleared, it would silently move the number reconcile
   vouched for.

8. **Both confirmed the same payday.** One row, always: two paychecks double a
   month's income, the checking balance and to-assign, the worst silent error
   there is. Same amount: counted once (built). Different amounts: the cleared or
   bank-matched one wins without asking; neither is, ask with both amounts. In
   words: "One payday is one paycheck. If you both confirmed it we keep one; if
   the amounts differ we ask."

9. **Restore or erase on one side.** No agreed base, so "deleted there" and
   "added here" can't be told apart; the safe direction is union, never dropping
   a row by itself. Ask with counts and sums: "Tom restored Tuesday's backup on
   the Mac. This laptop has 14 transactions since then, ₮1,240,000, that it
   doesn't. Keep them (recommended) / Let them go." Erase-and-start-over is the
   one whole-ledger question that is right: the other computer is told plainly
   and chooses to follow (its own to Backups) or keep its own.

## The six weighings, summed up

Reconciled beats an unreconciled edit on money columns only; bank-matched beats
hand-typed on money columns, typed filing kept; later-edit is never a rule;
larger-assigned is never a rule (ask with left-to-assign); one payday is one row,
always; a restore never drops rows by itself.
