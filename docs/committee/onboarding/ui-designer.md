# Onboarding wizard: the layout

Design committee, 2026-10-07. The `ui-designer` agent's report on the settled sequence
in [ADR 0004](../../decisions/0004-ledger-ui.md) ("Onboarding: the first half hour").
Saved as returned. Widths are estimates from the existing screens (sidebar 240, page
1120 at the minimum window); Mongolian strings were not measured in the app.

## 1. The frame

**Recommended: A, the real app shell. Left is where the money is, right is what it's
for.** The sidebar is the real one, empty at first, and fills under Bank / Cash / Credit
as each account row is completed. The page holds one step. This answers finding (a)
spatially: the account balances on the left never move during steps 6 to 9, while
everything about categories happens on the right.

```
+--------------+------------------------------------------------------------------+
| BetterBudget | Accounts  Import  Pay  Bills  Everyday  Saved  Assign  Finish later|
|              | ========-------------------------------------------------------- |
| Bank         | <step heading>                                                   |
|  TDB Checking|                                                                  |
|  ₮4,182,450  |  <the step's work: a table that fills the width,                 |
| Cash         |   or a 560 form at top-left like New account>                    |
|  Wallet      |                                                                  |
|  ₮86,500     |                                                                  |
| Credit       |                                                                  |
|  Golomt Visa |                                                                  |
|  ₮640,200 owed------------------------------------------------------------------|
| Net worth    | Back      <one running fact for this step>       Skip   Continue |
+--------------+------------------------------------------------------------------+
```

- Progress is the step names in words, not dots or "3 of 7". Done names are clickable.
  A step that doesn't apply (Saved, with nothing saved) is absent, not greyed.
- The footer is pinned: Back on the left, Continue (blue) bottom-right, Skip as a text
  button only on skippable steps. Pay has "I don't have regular pay" where Skip would
  be.
- Ledger / Budget / Savings are not in the sidebar until setup ends, because there is
  nothing behind them yet.

**Alternative, different in kind: B, one page, no wizard.** A "Set up" page of seven
rows, each opening in place like a register row and closing to a one-line summary.

```
+--------------+------------------------------------------------------------------+
| (sidebar)    | Set up                                                           |
|              |  ✓ Accounts    4 accounts · ₮6,790,000 in cash and bank     Edit |
|              |  ✓ Pay         ₮2,100,000 on the 25th                       Edit |
|              |  ▾ Bills  ........ open: the bills table, Save / Cancel ........ |
|              |    Everyday                                                      |
|              |    Saved                                                         |
|              |    Assign                                                        |
+--------------+------------------------------------------------------------------+
```

It gives no chrome, every answer stays visible, and it doubles as the empty-ledger
screen. The costs: the order (import before assign, pay before bills) is only suggested,
the open row pushes the list around, and it sits close to "everything on one page". I'd
pick A and keep B's list only as the resume screen (section 3).

## 2. Step layouts (frame A)

**Accounts (steps 1–2).** One table edited in place, not the Add account form nine
times.

```
Balances as of [2026.10.07]

Add:  [The bank your pay goes into] [Another bank] [Savings] [Cash in the wallet]
      [A credit card] [Storepay or лизинг] [A dollar account] [A home loan] [A business]

Name              Type                    Currency   In it today
TDB Checking      Bank account ▾          ₮ ▾          4,182,450.00     ×
Wallet            Cash ▾                  ₮ ▾             86,500.00     ×
Golomt Visa       Credit card or loan ▾   ₮ ▾   owed     640,200.00     ×
   Payment  [ 120,000 ] on the [15th]   [ ] A home or student loan
+ Another account
                               Cash & bank ₮4,268,950.00 · Owed ₮640,200.00
How do you pay for everyday things?   [Card and bank] [Cash] [Both]
```

- The memory list is buttons that add a row with Type and a starting name filled in, so
  the list does work instead of being read.
- Type is a dropdown here, although Add account uses three buttons: nine rows would
  mean 27 buttons, and the Add buttons already set it. In Mongolian three buttons run
  about 420 px per row; the dropdown column is 220.
- The owing question is a second line under that row only, so the row grows and nothing
  else moves.
- The foot total uses the sidebar's words, so it can be checked against the left.
- The cash question is three buttons (three short exclusive answers), last on the page.
  If "Cash" or "Both" is picked with no Cash row, show a gold line with an "Add a cash
  account" button, and don't block.

**Import (3):** one line per bank account with "Choose a file…". Skip sits beside
Continue.

**Period (4):** two large buttons with the dates in them, shown only when the period is
more than half gone.

**Pay (5):** the existing form, on the page instead of in a dialog, 560 wide at
top-left.

**Bills (6).** The suggestions are rows already there. A row exists once it has an
amount, so there are no checkboxes.

```
Bill                      Amount        Due        Repeats         Paid from
Rent or home loan       [ 900,000 ]   [10.10]   Every month ▾   TDB Checking ▾
СӨХ                     [  45,000 ]   [10.15]   Every month ▾   TDB Checking ▾
Electricity and heating [         ]   [     ]
Phone and internet      [         ]   [     ]
...                                    + Another bill
footer fact:  3 bills · ₮1,065,000 a month · pay ₮2,100,000
```

Repeats and Paid from appear on a row once it has an amount. The Paid from column is
shown only with more than one account to pay from.

**Everyday (7):** the same table with three rows (name, amount, "a month / each
paycheck" dropdown).

**Saved (8).** One row per such account: where it is on the left of the row, what it's
for on the right.

```
Khan Savings   ₮12,600,000.00      What is it for?  [ Renovation          ]
                                   Leave it empty and it stays in Not assigned.
```

A text field: the answer is a name, and empty is "Nothing yet".

**Assign (9).** The Budget page's own pane on top, the rows in two groups.

```
Cash & bank       ₮4,268,950.00    <- same figure as the sidebar; never changes here
In categories     ₮  945,000.00
Not assigned      ₮3,323,950.00

Due before payday 10.25              Due      Plan         Assigned
Rent                                 10.10    900,000    [ 900,000 ]
СӨХ                                  10.15     45,000    [  45,000 ]
After payday, and everyday
Food                                          400,000    [         ]
Phone and internet                   10.28     30,000    [         ]
```

Bills due before payday come prefilled (a default, editable). Clicking a Plan figure
copies it into Assigned. "Assigned too much" is the app's red row. The fix for (a) is
that the top row and the sidebar stand still while the two rows under them trade.

**Tomorrow (10).** Four full-width rows: a sentence on the left, the real control drawn
(disabled) on the right: the entry row, Type: Transfer, a scheduled row's confirm, Not
assigned. One button: "Open my ledger". No footer fact, no Skip.

## 3. Empty ledger

```
+--------------+------------------------------------------------------------------+
| BetterBudget | Set up your budget                                               |
| Ledger       |  ✓ Accounts   none yet                                           |
|  + Add account   Pay                                                            |
| Budget       |    Bills ...                                   [Continue setup]  |
| Savings      |  or  [+ Add account]  on its own                                 |
| Settings     |                                                                  |
+--------------+------------------------------------------------------------------+
```

No group headings and no Net worth at ₮0.00 (noise). Once setup has been finished and
every account is later removed, the page is only "No accounts" and the Add account
button.

## 4. Questions

1. **Is the owing account still asked how it gets paid?** Step 2 says the answer
   decides whether the balance comes off "You have", but the same day's later decision
   made Cash & bank never subtract debt and removed the "Paid off" question. I've laid
   it out as an optional payment amount and day that becomes a bill at step 6. That
   also meets "no category per credit card or instalment on day one". Which holds?
2. **Step 8 depends on "an account they don't spend from", and nothing asks that.**
   Should step 8 list every bank account except the one pay goes into, or does step 2
   need a mark per account?
3. **Step 4 has two answers and applies only late in a period.** May it be absent
   otherwise, or must it always be a screen?
