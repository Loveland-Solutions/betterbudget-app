# Onboarding wizard: the words

Design committee, 2026-10-07. The `ux-writer` agent's report on the settled sequence in
[ADR 0004](../../decisions/0004-ledger-ui.md) ("Onboarding: the first half hour").
Saved as returned. R = reused (arb key), N = new. Example amounts are invented.

## 1. The ten steps

**1–2 Accounts.** Heading N: "Your accounts". Field N: "Balances as of" [date], a label
beside a field, so no date sits inside a sentence.

- Line N: "Add every account you keep money in or owe money on."
- Memory list N: "Easy to miss: other banks, savings, cash in your wallet, every credit
  card, Storepay or лизинг, a dollar account, a home loan, money kept for a business."
- Fields R: Name (`setupName`), Type (`setupKind`), Bank account · Cash · Credit card
  or loan (`setupKindBank/Cash/Owed`), Currency (`setupCurrency`), Balance
  (`setupBalance`), You owe (`setupYouOwe`), with hints `setupStartBankHint` and
  `setupStartOwedHint`.
- Owing account N: "How do you pay it?" Answers: "Paid in full every month" (R
  `planRolePaidMonthly`) · "A set amount each month" (N).
- Loan type: Mortgage · Student loan (R `planRoleMortgage`, `planRoleStudentLoan`) ·
  "Another loan" (N).
- Beside a credit card N: "A charge from today that the bank hasn't shown yet isn't in
  this figure."
- Cash question N: "How do you pay for everyday things?" (answers: see question 1 in
  section 6).
- Warning if Cash or Both and no cash account, N: "You have no Cash account. Cash you
  spend won't be recorded, and the budget will show more money than you hold." Button
  N: "Add a Cash account".
- Buttons: "Add account" (R `setupAddAccount`), "Continue" (R `startContinue`), "Back"
  (N).

**3 Import.** Heading N: "Import from your bank?"

- Line N: "A bank file fills in rows you'd otherwise type. The budget works without it."
- Buttons: "Skip" (N, the default), "Import…" (R `importButton`) beside each bank
  account.

**4 Start.** Heading N: "Which period does the budget start in?"

- Choices N: "This month · 10.01–10.31" and "Next month · 11.01–11.30".
- Late in the period, N: "22 days of this month are gone. Spent will count only from
  today."
- Quiet line N (the ADR's own): "This period counts from 10.10".

**5 Pay.** Heading R: "Your pay" (`setupYourPay`). Everything on the form is reused:
`setupPaidInto`, `setupFrom`, `setupPayIs`, `setupPaySame`, `setupPayVaries`,
`setupEachPayday`, `setupWhen`, `setupMonthly`, `setupTwiceMonthly`,
`setupEveryFewWeeks`, `setupNoRegularPay`, `setupNextPayday`, and the error
`setupAmountMissing`.

- One new hint under the amount: "What arrives in the bank, after tax and any loan
  taken from your salary."

**6 Bills.** Heading N: "Which bills have a due date?" It echoes `planDueDateQ`.

- Line N: "Leave empty any you don't pay."
- Row names N: Rent or home loan · СӨХ · Electricity and heating · Water · Phone and
  internet · Kindergarten or school · Insurance · Instalment.
- Columns R: Amount due (`planAmountDue`), Due (`planLabelDueDate`), How often
  (`planHowOften`), Paid from (`planLabelPaidFrom`).
- Button N: "Add a bill". Error R: `planEnterAmountDate`.

**7 Everyday.** Heading N: "Everyday spending".

- Rows N: Food · Transport · Everything else.
- Column R: "Set aside each month" (`planSetAsideMonth`). Hint R: `planEmptyHint`.

**8 Saved.** Heading N, one message: "₮6,200,000 is in Khan Savings. What is it for?"

- Field R: `planCategoryName`, with hint N: "Renovation, a car, emergencies".
- Choice N: "Nothing yet". Under it, N: "₮6,200,000 stays in Not assigned. Assigned too
  much won't show until you assign more than everything you hold."

**9 Assign.** Heading N: "What is the money you have now for?"

- Top key R: `planKeyCashBank`, `planKeyAssigned`, `planKeyNotAssigned`, `planKeyOver`.
  Column R: `planAssigned`.
- Group labels: "Until your 10.25 paycheck" (R `planUntilPaycheck`) and "After that"
  (N).
- Buttons R: `planAssignThis`, `planFill`.
- Warnings: `planFillOver` (R), and N: "₮3,400,000 doesn't cover the ₮3,650,000 due
  before 10.25. Rent is ₮250,000 short."

**10 Tomorrow.** Heading N: "From tomorrow". Four new lines:

- "Record everything you spend, cash too."
- "When you move money between your own accounts, record a transfer, never a category."
- "When a scheduled bill is paid, confirm its row. Don't type it again."
- "On payday, come back and assign your pay."
- Button N: "Open the ledger".

## 2. Name and progress

The wizard needs no name on screen. If a menu item reopens it, call it "Set up a
ledger", from `startNewToApp`.

Name the steps rather than "Step 3 of 9"; a named step tells them what's coming, and
each is a noun the app already uses: Accounts · Import · Start · Pay · Bills · Everyday
· Saved · Assign · Tomorrow. Steps 1–2 share "Accounts".

No new word is needed for "envelope". The app says category, and every sentence above
works with it.

## 3. The assigning sentence

- **A, a definition:** "Assigning is deciding what the money you already have is for.
  Nothing moves at the bank; your balances stay as they are."
- **B, shown with their own number**, a live line under the top key:
  - Before anything is assigned: "Cash & bank holds ₮3,400,000. None of it is for
    anything yet."
  - After: "Cash & bank still holds ₮3,400,000, the same as your bank app. ₮1,150,000
    of it is now for 4 categories."

I recommend B, under the question heading. The reader who would open TDB to check is
handed the figure they would check, and it visibly doesn't change. A is a lecture about
a word; with the heading in place it isn't needed. Step 9 is the first place assigning
appears; steps 6–7 type plans, in the plan's own words.

## 4. Main window with no accounts

- Heading N: "No accounts yet".
- Line N: "Add an account and what's in it today. Everything else starts from there."
- Buttons: "Add account" (R `setupAddAccount`), "Set up step by step" (N, reopens the
  wizard).
- Budget page: "Add a bank account first" (R `ledgerAddBankAccountFirst`).

## 5. Mongolian drafts

All of these need a native check.

1–2. Таны данснууд · Үлдэгдлийн огноо
3. Банкны файлаас оруулах уу?
4. Төсөв аль үеэс эхлэх вэ?
5. Таны цалин
6. Аль төлбөр төлөх өдөртэй вэ?
7. Өдөр тутмын зарлага
8. Khan Savings дансанд ₮6,200,000 байна. Юунд зориулсан бэ?
9. Одоо байгаа мөнгөө юунд зориулах вэ?
10. Маргаашнаас

- **B:** "Бэлэн мөнгө ба банкинд ₮3,400,000 хэвээр байна, банкны апптай адил. Үүнээс 4
  ангилалд хуваарилсан нь: ₮1,150,000." This runs about a third longer. The second
  sentence is reshaped so no case ending is glued to the amount.
- **A:** "Хуваарилах гэдэг нь байгаа мөнгөө юунд зориулахаа шийдэх юм. Банкнаас мөнгө
  гарахгүй." I'm unsure of this one: "хуваарилах" itself can read as handing money out,
  which is the very misreading. That is another reason for B.

In `app_mn.arb`, on the Add account screen the wizard reuses:

- `setupKindOwed` says "Зээлийн карт" where the glossary says "кредит карт".
- `setupKindBankHint` still says "or cash", though Cash is now its own Type.
- "түнэ" in `setupKindCashHint` looks like a typo for wallet.

## 6. Questions

1. The cash question's first answer, "Card and bank", uses bare "card", which the owner
   rejected ("Are they gift cards?"). Should it read "From the bank (card, QR or
   transfer) · Cash · Both"?
2. The ADR says the answer to "how does it get paid" decides whether the balance comes
   off "You have". The later decision the same day took what's owed off the Budget page
   and removed the "Paid off" question. If the answer now only leads to a bill, is the
   plain question "Do you pay a set amount on it each month?", with the amount and date
   beside it?
3. Step 4 asks which period before step 5 asks about pay, so the choices can only say
   "This month". Someone paid on the 15th may budget by pay period. Should step 4
   always speak in months, or should its choices be re-dated after pay is answered?
