# Personas: what real people need that the app doesn't give them yet

Each persona was walked through the app by agents (a budget-app expert, a persona
sketch, and a code check), and the gaps below are what they found. The owner reads these
and decides what to build; nothing here is decided. Findings that are picked move into
the STATUS "Next step" list and, once designed, into ADR 0004.

## 1. College student, paid every other Wednesday (2026-09-19)

**Who:** a college student living paycheck to paycheck. She works odd hours at Whole
Foods around classes, so every check is different: short during finals, big over breaks.
She has rent on the 1st, a card with a balance, a phone bill, and roommates she
fronts bills for. Semester costs (books, fees) arrive in lumps, sometimes with an aid
refund.

**Her real question:** "How much of this check is already spoken for?" Today the app
answers "will this account stay above zero until the next payday?" That's close, but it
isn't her question.

**Already fits her:** the forecast that ends at payday; "It varies / Expect at least"
with the low side encouraged; late pay not counted ("Runs out 10.15 unless … comes");
the bill list with the balance after each; budget by pay period (26 paydays, two months
with three).

**Gaps, most painful first:**

1. **Seeing past the next payday.** The forecast stops at the first payday
   (`forecast.dart`, the income cutoff), and `ensurePaydays` schedules only one ahead.
   So if rent is due the 1st and payday is the 30th, a short check that won't cover rent
   is never flagged. *Idea:* step the forecast one more pay period, using the next check's
   estimate or the amount she types once she knows her hours. (This isn't the rejected
   "always 30 days".)
2. **Recurring bills** (Next step item 4). Rent, the phone and insurance have to be
   rescheduled by hand every month; if she forgets one, the forecast looks healthy.
   Item 1 above and item 3 below both depend on this.
3. **Card spending missing from checking's forecast.** Gas and books go on the card.
   Checking's forecast doesn't know until she schedules a payment herself. *Idea:* a card
   knows its due day and the account that pays it, and schedules the payment there.
4. **Day-to-day spending not in "lowest point".** "Lowest $X" reads like money she can
   spend, but she still has 12 days of groceries and gas to buy. *Short term:* a "keep at
   least X" floor for the coral warning. *Later:* the budget subtracts what's left in
   day-to-day categories.
5. **Nowhere to divide the check on payday** (open question 4). "Budget by Pay period"
   is stored, but `budget.dart` never reads it. She needs to give each check to rent's
   share, food, gas, including setting rent aside across the two checks before it's due.
6. **Semester and yearly costs** (books, fees, registration) land on a check that's
   already spent. She needs to see them coming and set a little aside each check.
7. **Who owes whom.** She fronts the internet bill and waits on a roommate. There's no
   "owed to me" account, and a scheduled payback stops counting once it's late.
8. **The app assumes Mongolia.** ₮ is hard-coded (`formatMoney` and about 35 strings),
   and "$500" doesn't parse. Dates are YYYY.MM.DD, and "9/24/2026" is refused. The
   demo data uses Mongolian banks. Paydays move off weekends but not bank holidays.
   Import is TDB only.

Also on the roadmap and hurting her: splits (one receipt, three categories); a phone
layout (she decides at the checkout).

**Recommended order:** recurring bills, then the forecast one pay period ahead. Together
they answer "will rent clear?" before the short check lands, and both are ledger work.
Next: card payments in the checking forecast. Then the budget per pay period.

**Owner (2026-09-19): yes, a real user: the owner's daughter.** So dollars and US
dates move up. Neither can wait for a later "multi-currency" decision: she can't enter
"$500" or "9/24/2026" today.

## 2. Salaried wealth builder, 45, works at IBM (2026-09-19)

**Who:** the owner. A steady salary, so getting through the month is handled. They want
their wealth to grow. Other apps help you get through the month; this is where the
**Savings** section (open question 3) comes in.

**The distortion a ledger creates:** about half of gross pay never reaches checking.
401(k) with employer match, HSA, ESPP, insurance and taxes are withheld first, and
mortgage principal hides inside the payment. A checking-only ledger sees about $1k a
month saved (about 8%). The real figure is closer to 35–40% of gross. All figures are
illustrative, not verified plan details.

**Questions they need answered, ranked:**

1. Did last period's surplus get invested, or is it sitting in checking? (monthly)
2. What's my real savings rate, counting paycheck withholding? (monthly, 12-month trend)
3. Is net worth growing, and how much is my saving versus the market? (monthly or quarterly)
4. Is the emergency fund the right size, in months of *my* spending, and how much above
   that is idle? (twice a year)
5. Dated goals: retirement at 60 or 62, college, mortgage payoff. On track? (yearly)
6. Am I getting the full match and on pace for the contribution limits? (quarterly)
7. Where does an extra $X do the most good? Concentration in employer stock?

**Today the app answers:** 1 and 4 partly (balances and transfers exist, but no account
is marked as savings or investment); the rest not at all.

**Leave out:** holdings, allocation, per-fund performance. The broker already shows
them, they'd need price feeds, and they don't change what they do with next month's
surplus.

**Concepts for the section** (budget-app expert):

- **A. Growth page (recommended).** Each pay period, what came in, what was spent, what
  was kept, and where the kept money went, including "stayed in checking" flagged when
  idle for several periods. A 12-month savings rate. Net worth as a step line, split into
  "saved" and "market change". This is the one place a factual nudge is allowed (ADR 0004
  held savings nudges back until now).
- **B. Balance sheet.** Groups: Ready cash / Invested / Retirement / Home / Debts, each
  with its value, an "as of" date and an Update value button. Ready cash in months of
  spending. Recommended as the way values get into A, not as the page itself.
- **C. Goals.** Cards with a target, a date, linked accounts and an on-track line. Only as
  good as A and B beneath it; later, as lines on A.
- **Name:** "Savings" suggests one deposit account. "Growth" or "Wealth" fits better.

Sketches (illustrative dollar figures):

```
A. Growth                       Pay period 09.15–10.14
Income        $9,000
Spent        −$5,600
Kept          $3,400   38%   (12-mo 31%)
 → HYSA          $1,000
 → 401(k)        $1,500  incl. match
 → stayed in checking $900  ◆ 3rd period idle
Net worth ──╱──  +$180k this yr: $140k saved, $40k markets
```

```
B. Balance sheet
Ready cash   $24,800   = 4.1 months of spending
Invested     $96,000   as of 09.30
Retirement  $612,000   as of 06.30 ◆ 81 days old
Home        $520,000   as of 01.2026
Mortgage   −$280,000   payoff 2038
```

```
C. Goals
College 2034   $160k   funded 34%   $1,300/mo needed · putting in $1,000
```

**Recommendation put to the owner (2026-09-19), not yet decided:** A, with B's Update
value as the way values get in; goals later as lines on A; rename the section "Growth".
Owner: "document this, and we'll follow up."

**Owner's direction (2026-09-19):** Savings "will take some work". It should get users
onto the first few steps of the Church of Jesus Christ of Latter-day Saints course
*Personal Finances for Self-Reliance*, starting with "a safety net of one month's pay".
So the section is a guided path through the course's milestones, not A/B/C as
sketched above. Those concepts become later steps or supporting views (the course's
later chapters cover investing). The course's exact steps and wording are being
researched from the Church's manual before anything is designed.

**What has to change first** (data-model check, file references in the session notes):

1. **Account kind** (schema v6, a new column; today "Bank account" and "Card or loan"
   are only labels for asset and liability): Bank, Investment, Retirement, Property,
   Loan. This decides what counts as kept money, as emergency fund, and what gets valued
   instead of reconciled.
2. **Update value.** Type the statement's value; the difference posts against a new
   equity account, "Market change". This is the same pattern as reconcile's "Balance
   adjustments", so it stays out of spending and the savings rate. It must not lock
   rows the way a reconcile does. It needs undo and redo.
3. **Net worth on any date** is already derivable (sum entries up to that date); no
   history table is needed. Draw it as steps, since values change only on update dates.
4. **Currency is a live bug risk now.** Net worth adds up raw balances, so a USD
   401(k) would add cents to tögrög. Decide open question 5 first: a typed rate with a
   date, and always show which rate was used.
5. **Splits and recurring come first.** A paystub split (gross, net, 401(k), match,
   taxes) and a mortgage split (principal, interest) are what make the savings rate
   true. Pay today is one net amount into one account.
6. **A spending category called "Savings" breaks the math** (money moved there counts as
   spent). Steer to a transfer instead.

**Unbreakable rules:** no price or rate feeds: values are typed from statements, each
shows its age ("valued 81 days ago"), never estimated from an index. Projections use
the owner's own return assumption, labeled as such. **Encryption should come before or
with this section:** a full balance sheet in plain SQLite, with plain backups, is a
bigger exposure than a spending log.

**Typing cost:** about 30 minutes of setup (paystub template, loan terms, assumptions),
then about 5 minutes a month typing 6–8 statement values.
