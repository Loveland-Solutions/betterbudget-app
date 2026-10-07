# Onboarding wizard: the flow

Design committee, 2026-10-07. The `interaction-designer` agent's report on the settled
sequence in [ADR 0004](../../decisions/0004-ledger-ui.md) ("Onboarding: the first half
hour"). Saved as returned. Nothing here was run in the app; it comes from reading the
code and ADR 0004.

## How the reused pieces save today

- Recovery key (`app/lib/ui/startup.dart`): a Continue button; the key is stored and
  the ledger opened only then.
- Add account (`app/lib/ui/accounts.dart`): two saves. Name/Type/Currency, by Enter in
  Name or the button; an empty name gets a default. Then the account's own page asks
  balance and date; Enter from either, and empty means ₮0. No toast for either, and a
  separate ⌘Z for each. Cancel/Esc exist only when another account exists.
- Pay (`app/lib/ui/pay_setup.dart`): a modal; Enter anywhere saves; Cancel; "No regular
  pay" is offered only while it has never been answered. One undo, with a toast.
- Add category, then Edit (`app/lib/ui/budget.dart`): the name row creates it (toast),
  then Edit opens. Enter saves, Esc/Cancel closes; all changes are one undo, quiet
  unless money moves.
- Assigned field: each field saves on its own, quiet. The first one writes
  `budget.began` as a side effect. "Assign what's planned" is one click, one undo, one
  toast.
- Import (`app/lib/ui/import_dialog.dart`): a modal; Enter imports; one undo for the
  whole file.
- Undo (`_did` in `app/lib/ui/ledger_screen.dart`): the history is in memory, for this
  session only.

## Recommended

Separate full-window screens with a step rail, drawn inside `LedgerScreen` so `_did`,
⌘Z and the database are the app's own.

```
key -> [A: accounts]                 [B: budget]                               [C]
       2 accounts+date -> 3 import -> 4 period* -> 5 pay -> 6 bills -> 7 everyday -> 8 saved* -> 9 assign -> 10 tomorrow
                              |  "Stop here for now"                                     (* = shown only when there is something to ask)
                              v
                      real app, ledger works; the Budget page's empty state holds "Set up the budget" -> 4
```

| Step | Written when | Forward button | Empty is |
|---|---|---|---|
| 2 | each account as added (account + balance, one undo) | Continue | not offered until one account exists |
| 3 | on Import in the existing modal | Continue (primary); "Import a file…" (secondary) | the default |
| 4 | on Continue (default preselected) | Continue | n/a |
| 5 | on answer | "Save pay" / "I don't have regular pay" | no bare Continue |
| 6 | each bill as added | Continue | fine |
| 7 | each field, as the Assigned field does | Continue | fine |
| 8 | on answer | "Save" / "Nothing yet" | fine |
| 9 | on click | "Assign these" / Continue | fine |
| 10 | sets `setup.done` | "Open my budget" | n/a |

1. **Writing.** Each thing is written when it is added, because every reused piece
   already saves on its own Enter or Save. A step holds nothing unsaved, so Continue
   and Back only move. Back shows the list as it stands and never takes anything away.
   An item is changed by double-clicking it (the same fields open in place) and removed
   by its own Remove. ⌘Z undoes the last write through the same history, and acts on
   typing while in a field. No toasts for adds: the row appearing is the confirmation,
   as with accounts today. One difference from today: an account and its balance are
   one row and one undo, because here they are typed as one line under the one date.
2. **Leaving and coming back.** Store one preference, the furthest step reached. While
   `setup.done` is unset, the next launch opens the wizard at that step with the lists
   as they were. A half-typed row is lost, as in the register. ⌘Z is gone after a quit,
   which is why Back, edit and Remove must not depend on it. After the end, the wizard
   never returns; finished steps are changed on the normal screens.
3. **Skipping.** No Skip buttons: Continue with nothing entered is the skip. The rail
   is clickable in any order once one account exists. Step 5 has two forward buttons of
   equal weight and no bare Continue. Leaving it by the rail is allowed, and then the
   Income tab keeps the gold dot it has today. After a skipped step: no import means
   nothing; no bills or everyday amounts means an empty Budget page with Add category;
   step 9 skipped leaves Not assigned holding everything.
4. **Adding several.** The memory-jog lists are tappable starters. Clicking "Savings",
   "Cash in the wallet", "Home loan" or "Rent", "СӨХ" opens one row in the list with
   the Type or name prefilled and focus in the first empty field. Enter from any field
   adds; what's missing is named. After an add the row closes and focus lands on "Add
   another", so Enter opens the next one and Tab reaches Continue. No standing blank
   row. Esc closes the open row and never leaves the wizard. A starter stays after use,
   since people have two banks. A bill row holds name, amount, day and Paid from
   (defaulting to the pay account), not the whole Edit panel.
5. **Branches.**
   - Step 4 is shown only when the period is more than half gone; otherwise `began` is
     written as this period, with no screen.
   - If "next period" is chosen: steps 6–7 are unchanged, step 9 assigns into the next
     period, and the landing is that period.
   - Step 8 is shown only when a non-spending account holds money, and it assigns that
     balance there, so step 9's Not assigned is only spendable money.
   - No regular pay: step 9's first group is "due before the period ends".
   - No bills and no amounts: step 9 is dropped.
6. **The end.** "Open my budget" sets `setup.done` and lands on Budget, Spending tab,
   in the chosen period, with nothing open and no toast. ⌘Z still works.
7. **No accounts.** One designed screen serves both cases: step 2's body (the date, the
   starters, the list) inside the normal shell. While setup is unfinished, it is the
   wizard at step 2.
8. **Useful early.** After step 3 the ledger is complete and honest. That boundary gets
   one line and two buttons: "Go on to the budget" and "Stop here for now". The only
   reminder afterwards is the Budget page's own empty state, the page where it's fixed.
   No dot, no checklist.

**Step 9 and the bank.** Keep the accounts and their balances on screen, fixed, beside
the list. As each Assign is clicked, Not assigned counts down and the category goes up,
while "TDB Checking ₮2,400,000" never moves. Bills come first, as one button with its
real total; everyday amounts second. The closing line restates the unchanged bank
figure.

## Alternative, different in kind

No wizard screens. First launch lands in the real shell on the empty-ledger screen, and
a "Setup" page lists the nine jobs with their state read from the ledger. Each job
opens the real screen (Add account, the pay dialog, the Budget page with starters,
"Assign what's planned").

- Gains: nothing is learned twice, saving and undo are exactly today's, no resume
  logic, and re-entry is free.
- Loses: the order, which is the accounting (import before the first assignment,
  `began` chosen on purpose, saved money before assigning). The checklist is a standing
  nag. The full Edit panel stands where two fields would do. A first-timer meets an
  empty five-section shell. The one date has no home.

## Questions for the owner

1. Step 2 asks how an account that owes money gets paid, "in full or a set amount",
   because that once decided whether its balance came off "You have". Since 2026-10-05
   nothing owed comes off Cash & bank, and the "Paid off" question was removed as a
   control that changes nothing. Should the wizard ask only "Is there a set payment
   each month?" and make it a bill (for example "Golomt Visa payment ₮150,000 on the
   15th")? The ADR also rejects "a category per card" on day one.
2. Step 4 asks which period the budget starts in before step 5 says when pay arrives.
   Someone paid on the 15th would be asked about October and may then budget by pay
   period. May the period question come straight after pay, or should it name a plain
   date ("Start counting from 10.07, or from 11.01")?
3. If they choose the next period, step 9 assigns today's ₮2,400,000 to a budget
   starting 11.01, but they will spend some of it before then. Should step 9 wait until
   that period starts, with step 10 saying "come back on 11.01"?
