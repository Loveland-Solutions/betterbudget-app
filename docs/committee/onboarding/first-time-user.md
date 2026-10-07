# Onboarding wizard: the first-time reader's report

Design committee, 2026-10-07. The `first-time-user` agent read the settled sequence in
[ADR 0004](../../decisions/0004-ledger-ui.md) ("Onboarding: the first half hour") and
the words of the screens it reuses. Nothing was run; the wizard isn't built. Saved as
returned.

My household (invented): pay into Khan Bank on the 1st and 15th, ₮1,400,000 each time
after a salary loan takes ₮350,000; Khan account ₮1,850,000; wallet ₮120,000; Khan
savings ₮3,000,000 (for Tsagaan Sar and a fridge); Storepay ₮480,000 left, ₮120,000 a
time; salary loan about ₮6,000,000; СӨХ ₮90,000; kindergarten ₮150,000; electricity and
heating ₮180,000; phone and internet ₮80,000.

**Before step 1: the recovery key.** First thing I see is "BetterBudget encrypts your
ledger" and red text "it's gone". I don't know "ledger" or "encrypts". I'd think I'd
already done something dangerous before typing one number. I'd click Save, not know
where the file went, and continue uneasy.

**Step 1–2: accounts and what's in each today.**

- I understand: list where my money is. I'd type Khan ₮1,850,000 from the bank app,
  count the wallet (₮120,000), savings ₮3,000,000 from the app.
- "Type: Bank account · Cash · Credit card or loan". Storepay is none of these to me;
  it's a shop instalment. The hint does say "a loan or Storepay", so I'd get there if I
  read the hint.
- "What do you owe on it today?" for Storepay: I'd go to the Storepay app. For the
  salary loan I'd have to find the bank's loan screen; I know the monthly cut, not the
  remainder. First real stop.
- "not the 'available' balance": my bank app shows one number. I don't know which it
  is. Stop.
- "How it gets paid: in full each month, or a set amount": Storepay is four set
  payments, fine. The salary loan is taken before pay arrives; neither answer fits.
- "A home or student loan is marked here": marked as what, and why?
- "How do you pay for everyday things? Card and bank · Cash · Both": easy, Both. But
  I'd wonder what it changes.
- "One date for every opening balance": I don't say "opening balance". "What's in it
  today" I understand.
- Mongolian: the Bank account hint still says "Харилцах данс, хадгаламж эсвэл бэлэн
  мөнгө" (includes cash) though Cash is now its own Type; the Cash hint says "түнэ",
  which I don't recognise (түрийвч?). (`app_mn.arb` lines 500, 503.)
- After: I expect a list of my accounts and one total I can check against the bank app.

**Step 3: import.** "Import a file from your bank": I don't know what file. I'd skip,
and worry I'd skipped something that matters.

**Step 4: "Which period the budget starts in".** I don't know what a "period" is or
what "starts" changes. Today is the 7th; pay was the 1st. Is my 1st-to-7th spending
lost? I'd pick whatever is pre-chosen.

**Step 5: pay.** Clear questions. "Twice a month", "Which two days of the month?" 1 and
15. Amount: I'd type ₮1,750,000, my salary, unless told plainly "what arrives in the
bank". "Expect at least", "the forecast counts on this": I don't know "forecast". "On a
weekend: Friday before / Monday after / Keep the day": I'd have to remember; guess
Friday.

**Step 6: bills with dates.** I know these. СӨХ ₮90,000 by the 10th, kindergarten
₮150,000 by the 5th, phone ₮80,000 on the 20th, Storepay ₮120,000 on the 15th.
Electricity and heating change monthly: I'd stop for the paper bill or the app and not
know which figure to type. "Is there a due date?" is fine. "Paid from": fine. Is the
salary loan a bill here? It never leaves my account; I'd add it and count it twice.

**Step 7: food, transport, everything else.** Food ₮900,000 a month. But is it per
month or per pay? If by pay period I'd type the monthly figure in a half-month box.

**Step 8: "Money already saved: what is it for?"** Two things (Tsagaan Sar, fridge);
one answer box? "Nothing yet" is a relief.

**Step 9: "Assign what you have now".** Stop. See question 1.

**Step 10:** see question 5.

## The direct questions

1. **What does assigning do?** "Assign" sounds like sending money somewhere, like a
   bank transfer into a sub-account. I'd half expect ₮90,000 to leave Khan for СӨХ, and
   I'd hesitate to click "Assign ₮90,000". What settles it: the Khan balance sitting
   visibly unchanged next to the click, and one sentence saying nothing leaves the
   bank; this is only me writing down what the money is for, as in my notebook.
2. **The three rows.** "Cash & bank ₮4,970,000": my money, checkable. "In categories
   ₮1,340,000": money I've set aside on paper; but "in" sounds like it moved. "Not
   assigned ₮3,630,000": reads like a job left undone, or money I'm free to spend. I'd
   not see at once that the second and third add to the first. "Assigned too much" I'd
   read as a scolding without knowing what breaks.
3. **Where I'd close the app.** Step 2, at the loan and Storepay balances, or step 6 at
   the electricity bill: figures I have to fetch. Coming back, I'd need what I'd
   entered still there, where I'd stopped, and what's left ("3 of 6"), not a start from
   the beginning and not the recovery key again.
4. **Opened the next day with no account.** I'd expect the same setup at the question
   I'd left. An empty page with a sidebar and "Budget", "Savings" and zeros would make
   me think it lost my work or that I'm meant to know what to do. Being asked for the
   recovery key would frighten me.
5. **Step 10's four things.** "Record everything including cash": understood, I'd lapse
   on small cash. "A transfer, never a category": I don't understand. Moving ₮500,000
   to savings feels like spending on "Savings"; drawing ₮200,000 at an ATM feels like
   spending. Nothing tells me how to make "a transfer". "Confirm a scheduled bill
   instead of typing it fresh": I don't know what scheduled looks like or where to
   confirm. "Come back on payday and assign the rest": the rest of what? Will the app
   know pay came?
6. **Prying, and what's missing.** The salary loan balance and employer ("From") feel
   like a bank form; savings "what is it for?" less so. Missing: I expected a bank
   login. Nothing I read says the app never connects; "encrypts", "phone that records
   spending" and "import from your bank" made me assume the opposite. I'd want it said
   once, at the start, before I type a balance.

## Three worst stops

1. Step 9, "Assign": I think money moves, so I stop.
2. Step 2, owed accounts: "What do you owe on it today?", "in full each month, or a set
   amount", "not the 'available' balance"; figures I don't have, answers that don't fit
   a salary loan.
3. Step 4, "Which period the budget starts in": I can't tell what I'm choosing or what
   happens to money already spent this month.
