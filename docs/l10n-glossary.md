# Mongolian glossary

The words the Mongolian interface uses for BetterBudget's ideas, so every screen says
the same thing the same way. Chosen to match what Mongolian banks (TDB, Khan, Golomt)
show in their apps and statements. A native speaker checks these first; when one
changes here, change it everywhere in `app/lib/l10n/app_mn.arb`.

## Tone

- Buttons and menu items: the verbal noun (`Хадгалах`, `Устгах`, `Нэмэх`), the way
  bank apps label buttons.
- Confirmations of something done (toasts): past tense, short (`Хадгаллаа`,
  `Устгалаа`).
- Talking to the user: polite `та`, only where English says "you". No `уу/үү`
  pleading on every line. Keep it as plain and specific as the English.
- Numbers, ₮ amounts, dates in rows (`09.30`, `2026.09.30`) and shortcuts (⌘Z) stay
  as they are.
- Dates inside sentences: `9-р сарын 30`, with year `2026 оны 9-р сарын 30`
  (`sayDate` / `sayFullDate` in `lib/ui/language.dart`).
- Mongolian nouns don't take a plural after a number: `3 гүйлгээ`, `1 гүйлгээ`.

## Words

| English | Монгол | Notes |
|---|---|---|
| ledger | дэвтэр | the whole file of accounts; "new ledger" = шинэ дэвтэр |
| account | данс | |
| all accounts | бүх данс | |
| transaction | гүйлгээ | |
| payee | харилцагч | who the money went to or came from |
| category | ангилал | |
| memo | тэмдэглэл | |
| amount | дүн | |
| balance | үлдэгдэл | |
| balance after / owed after | үлдэх дүн / үлдэх өр | "дараах" reads as "the one below" |
| cleared | баталгаажсан | the bank has it |
| uncleared / pending | хүлээгдэж буй | banks show pending this way |
| reconcile | тулгах | reconciled = тулгасан; "Never reconciled" = Тулгаж байгаагүй |
| statement date | хуулгын огноо | |
| bank balance | банкны үлдэгдэл | |
| off by | зөрүү | |
| budget | төсөв | |
| spending | зарлага | |
| income | орлого | |
| transfer | шилжүүлэг in sentences; the category reads "Данс хооронд" | banks call any payment to a person шилжүүлэг |
| opening balance | эхний үлдэгдэл | |
| scheduled | товлосон | a future bill or income |
| bill | төлбөр | |
| forecast | төсөөлөл | таамаг sounds like a guess |
| until next income | дараагийн орлого хүртэл | |
| pay, paycheck | цалин | |
| payday | цалингийн өдөр | |
| pay period | цалингийн үе | |
| twice a month | сард хоёр удаа | |
| savings | хуримтлал | the Savings section and savings goals |
| savings account | хадгаламж | |
| checking account | харилцах данс | |
| credit card | кредит карт | |
| loan | зээл | student loan = оюутны зээл |
| owed / you owe | өр / таны өр | |
| paid off | төлж дууссан | |
| paid in full | бүрэн төлсөн | |
| cash | бэлэн мөнгө | |
| net worth | цэвэр хөрөнгө | |
| split | хуваасан | a split transaction = хуваасан гүйлгээ |
| backup (a copy) | нөөц хуулбар | "back up" = нөөцлөх |
| the daily copy | өдөр бүрийн хуулбар | |
| restore | сэргээх | |
| recovery key | сэргээх түлхүүр | |
| encrypted | шифрлэсэн | |
| security | аюулгүй байдал | |
| settings | тохиргоо | |
| appearance | харагдах байдал | light = цайвар, dark = бараан |
| language | хэл | |
| undo / redo | буцаах / дахин хийх | "Nothing to undo" = Буцаах зүйл алга |
| save | хадгалах | |
| cancel | болих | |
| confirm | батлах, except a scheduled row: бүртгэх | батлах sounds like баталгаажсан (cleared) |
| continue | үргэлжлүүлэх | |
| delete | устгах | |
| edit | засах | |
| rename | нэр солих | |
| add | нэмэх | |
| show / hide | харуулах / нуух | |
| archive | архивлах | archived = архивласан |
| today / yesterday | өнөөдөр / өчигдөр | |
| month | сар | months are numbered: 9-р сар |
| date | огноо | |
| from / to | -аас / руу | build whole sentences; don't glue pieces |
| row | мөр | |
| sidebar | хажуугийн цэс | |
| back up to… / restore from… | нөөцлөх… / нөөцөөс сэргээх… | |
| daily copy | өдрийн хуулбар | |
| working (balance) | үлдэгдэл | never "боломжит": that's the bank's available balance, which the app tells people not to type |
| adjustment | залруулга | from a reconcile |
| lock / locked | түгжих / түгжээтэй | |
| move to (another account) | өөр данс руу | not шилжүүлэг, which is a transfer |
| categorize | ангилах | |
| off by / matches | зөрүү / таарч байна | reconcile |
| runs out | мөнгө дуусна | |
| below zero | хасахад орсон | |
| in credit (card) | илүү төлөлт | |
| card charge / card payment | зарлага / төлөлт | |
| expenses | зардал | "a month of expenses" = нэг сарын зардал |
| emergency fund | яаралтай үеийн нөөц | |
| consumer debt | хэрэглээний өр | |
| mortgage | орон сууцны зээл | |
| set aside (a step) | хойшлуулах | |
| estimate | тооцоолсон дүн | |
| at least | багадаа | |
| lowest balance | доод үлдэгдэл | "хамгийн бага ₮X" reads as "at least ₮X" |
| cards and loans (sidebar group) | карт, зээл | |
| weekend | амралтын өдөр | |
| employer | ажил олгогч | |
| (deleted) | (устгасан) | after an account name |
| Budget by | төсвийн үе: сараар / цалингийн үеэр | |

## Word forms

- A case ending is never glued to a placeholder: the ending depends on the word or
  number (`2-т`, `16-нд`). A fixed word carries it instead: `{account} дансанд`,
  `{name} ангилалд`, `Мөнгө дуусах өдөр: {date}`.
- Days of the month take `-нд`/`-т` through the `startDayOn` message (`25-нд`, `2-т`).

## To check first

- The course title «Өөртөө найдах чадварын төлөө хувийн санхүү» is a guess; use the
  official Mongolian title of "Personal Finances for Self-Reliance".
- «{amount} хэтэрсэн байна» and «Илүү төлөлт {amount}» (cards).
- The transfer rows: `Khan Savings данс руу` / `данснаас`.
- Reconcile labels, which sit in a narrow column.
- Pay days typed into a box: «Сар бүрийн [__]-нд» attaches an ending to whatever number is
  typed (2-т, 16-нд).
- «Харилцагч» for payee: banks mostly use it for "customer"; «Хэнд, хэнээс» is the
  alternative for the column header.
