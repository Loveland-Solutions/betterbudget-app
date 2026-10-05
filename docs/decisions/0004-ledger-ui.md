# 0004 — Ledger UI: Midnight, and the rules the register follows

**Status:** Accepted
**Date:** 2026-09-16

## Context

The README asks for a ledger that is polished and professional. The owner added a sharper
brief while reviewing designs: *sexy, professional, beautiful*, and **"Everything has a
purpose. I don't want to just copy other budget apps."**

Three desktop register directions were mocked up from the same synthetic data:
*Private Banking* (light, serif figures), *Midnight* (dark), and *Precision* (dense
Swiss grid). The mockups and their generator are in [`design/ledger/`](../../design/ledger/),
and the published canvas is at https://claude.ai/artifact/PVysW4N9RyarWTr4zZMgV5.
Midnight was chosen. The decisions below came out of reviewing the mockups and then
using the working app. Each one was a correction the owner made, so none of them should
be quietly undone.

## Decision

### Visual direction: Steppe night (dark mode)

- **Chosen by the owner 2026-09-29** (canvas board "Z2 · Night, gray denim sidebar"),
  replacing Midnight (`#060D1E` ground, `#0B1630` panel: "too dark"). It is the dark
  pair of Steppe, the light mode under consideration. Tokens live in
  `app/lib/ui/theme.dart` (`Mid`).

  | Token | Hex | Role |
  | --- | --- | --- |
  | ground | `#0D1522` | page and title bar, blue-black |
  | side | `#243550` | sidebar, gray denim; chosen account `sideSel` (white 10%) |
  | panel | `#141D2D` | register, dialogs |
  | card | `#1A2436` | balance header |
  | raised | `#222E44` | hover, menus, active tabs |
  | ink / ink2 / ink3 | `#ECEFF4` / `#AAB3C2` / `#8D97AA` | text, three levels (ink3 lifted to read on the sidebar) |
  | blue | `#6FA8F0` | interactive, chart line, "Budget" in the wordmark (steppe sky), the Add button (dark text) |
  | sun | `#F5C518` | sidebar marks: open section, chosen account's edge |
  | gold | `#E8C15A` | reconciled, scheduled |
  | green | `#5CCB8E` | money in |
  | coral | `#F08A8A` | below zero, errors |
- Rejected on the way: Steppe's bright blue `#1B5BA8` as the dark sidebar ("awful"),
  deep steppe blue `#163B6E`, an ink sidebar darker than the page, and Steppe "felt"
  (warm near-black). The title bar stays the ground color, so a strip of it shows above
  the sidebar.

### Light mode and the Appearance setting (owner, 2026-09-29)

- **Settings → Appearance: "Same as this Mac" (default), Light, Dark.** Under the
  first, a line says which one shows now. Kept per computer in a small `appearance`
  file beside the ledger, not in it, so a phone on the same ledger keeps its own. ⌘Z
  switches back; no toast (the whole window changing says it happened).
- **Light is Steppe with the same gray denim sidebar** (owner chose this over Steppe's
  bright blue sidebar), so only the page changes between modes. Light tokens: ground
  `#F6F1E7` (felt cream), panel and card `#FFFFFF`, raised `#EEE8DC`, ink / ink2 / ink3
  `#1A2230` / `#4E5666` / `#6C7382`, blue `#1B5BA8`, gold `#9A721A`, green `#2E7D4F`,
  coral `#C0392F`; text on filled buttons is white (`onAccent`).
- **Add buttons are blue, not red (owner, 2026-09-29):** red reads as a warning. Blue
  already means "what you click". Rejected: sun yellow (too close to gold, which means
  reconciled or scheduled) and green (it means money in). There is no red token now.
- The sidebar has its own constants (`Mid.side*`, `Mid.sun`) because it is dark in
  both modes; the wordmark uses them too. The macOS title bar follows the page color
  over a `betterbudget/window` channel.

- Brand colors were measured from the pixels of `assets/logo/logo-english.png`: navy
  `#03173E`, royal `#0342B2`, gold `#C9A96B`, slate `#707784`. The logo is now a bee
  (`assets/logo/Better Budget Logo - *.svg`, 2026-09-29): wings are two B's in navy
  `#031A42` and royal `#0342B2`, the body gold `#C9A96B` between black stripes. The
  SVGs' leftover green fills (hidden under each shape's style) were removed.
- **App icon (owner, 2026-09-29):** the bee on a white macOS tile, **tilted 45°** so it
  flies up and to the right, drawn 27% larger than upright with room kept to the edge.
  Rejected: the bee upright (smaller), and the largest tilt that fits (stinger and
  wing crowd the edge). Made by `design/icon/app_icon.swift`; the phone apps still
  have Flutter's icon.
- **Logo in the app (owner, 2026-09-29):** the top left of the sidebar shows the
  logo's wordmark alone (was a gold diamond and "BetterBudget" in Onest):
  `lib/ui/brand.dart`, cropped SVG in `app/assets/brand/`. On the dark ground its navy
  "Better" becomes ink and royal "Budget" the lifted blue. Rejected: the bee on a small
  white tile beside it, and the logo on the recovery-key screens. *(Superseded
  2026-09-30: the sidebar shows a dark-mode logo; see "Color schemes".)*
- **The bee is back, left of the wordmark, with no tile (owner, 2026-09-29).**
  `app/assets/brand/bee.svg` is the logo's bee cropped. It is recolored like the
  wordmark (navy wing ink, royal wing lifted blue), and its antennae become `sideInk2`
  so they show on the denim. It is 40 px tall beside the 22 px wordmark. The body keeps
  the logo's black and gold stripes: with the black stripes turned light gray, the gold
  one couldn't be seen (owner).

### Color schemes, and the logo in its own colors (owner, 2026-09-30)

- **The owner couldn't pick one palette, so the user picks** (owner: "let the user
  choose. Use every color scheme from this page",
  figma.com/resource-library/color-combinations). Settings → Appearance, under
  Same as this Mac / Light / Dark, has **Colors**: BetterBudget (the app's own
  Steppe pair) and then Figma's 100 combinations in its seven groups and
  order (Monochromatic, Romantic, Playful, Vibrant, Neutral, Tranquil, Seasonal),
  each tile its four colors over its name. A click switches the whole window; no
  toast; ⌘Z goes back. Kept per computer on the `appearance` file's second line.
  The colors are in `lib/ui/schemes.dart`; nothing is fetched.
- The hex codes are the ones printed on Figma's images. Two printed codes don't
  match their swatch ("#CC550" in Golden hour, "#00F0FF" under Bubblegum pop's pale
  cyan), so those two are the swatch's color.
- **A scheme sets the colors; Light / Dark still applies** (owner chose this over
  "the scheme decides light or dark"). `Palette.of` turns four colors into a light
  and a dark palette: the darkest color becomes the sidebar (made dark enough for its
  light text), the most colorful one what you click (the Add button, links, the
  chart), the next most colorful the sidebar's marks, and the page takes the darkest's
  hue in dark mode and the lightest's in light mode. Surfaces and text sit at the
  same brightness as the Steppe pair, and every color is moved lighter or darker
  until it reads (text 4.5:1 or more, tested for every scheme in both modes).
- **Money's colors never change with the scheme:** green money in, coral below
  zero, gold reconciled or scheduled, so a scheme can't make a shortfall look fine.
- **From both reviews (2026-09-30):** what you click (and so the forecast line, a
  card's owed line, a selected bill's edge) never takes a red, orange, gold, green or
  gray from a scheme: the next most colorful swatch is used, or the steppe sky blue
  when none is left (37 of the 100, the warm, green and gray ones). It gets some
  saturation so it never looks like text. The sidebar's marks may be gold, never red
  or green (a red edge on the chosen account read as a problem). Tested for all 200 palettes.
- **The picker is folded** (review): Colors shows the scheme in use and "See all 101
  colors"; unfolded, every tile and "Hide the colors". Otherwise 100 tiles pushed
  Language and the recovery-key warning far down Settings. Not done: tiles drawn as
  the app would look rather than Figma's four swatches (they are what the owner
  asked to choose from).
- The `appearance` file is written beside itself and renamed, so a crash mid-write
  can't reset it. An older build reading a file with a scheme falls back to "Same as
  this Mac" (downgrades only).
- **A dark-mode logo in the sidebar** (owner, 2026-09-30). The sidebar is dark in
  every scheme, so it shows the logo drawn for dark backgrounds: "Better" near-white
  `#F2F5FA` where the logo is navy, "Budget" a lighter royal `#6FA3FF` (the royal's
  hue), antennae `#D9DEE7`/`#C4CAD5`, and the body's gold and black as drawn. It is
  the same in every scheme (brand colors, not the scheme's). Files: `assets/logo/*
  (dark).svg` beside the originals, and `app/assets/brand/{bee,wordmark}-dark.svg`;
  a test checks it reads on all 202 sidebars. Rejected on the way the same day: the
  original colors on a light band across the sidebar's top ("I don't like the white
  stripe"), the original colors with a soft white glow around them ("That logo isn't
  working"), and the original colors straight on the sidebar ("Better" vanishes).
  Earlier (2026-09-29) the logo took the scheme's sidebar ink and blue; the owner
  asked to go back to the logo's colors, which is what the dark-mode logo keeps.
- **Blue eclipse is the default** (owner, 2026-09-30: "I like blue eclipse. Let's
  make it default"): shown until someone picks, and for a file from before schemes.
  BetterBudget's Steppe pair stays first in the picker.

### Color: how the dark and light modes were reached (owner, 2026-09-29)

The owner: Midnight is "a bit too dark. We need some color." Sketched on one canvas,
https://claude.ai/artifact/DuV7bmBYHEiCpG4qBY2Wdb (the ledger screen with demo data).
What's known so far:

- **Categories get their own color** in their chip ("Lovely"). Violet Housing, orange
  Groceries, sky Phone & internet, slate Bank fees, pink Dining out, teal Transport,
  green income. Transfers and splits stay plain text.
- **Dark mode must not be one color in lighter and darker shades** (owner: "I don't
  need to stick to a dark color with a slightly less dark version of the same color").
  Surfaces should differ from each other. This is what was wrong with Midnight, and
  with the Dusk, Graphite and all-green sketches.
- **A light mode is wanted** alongside dark (this reverses "a light theme is not
  planned" below). **Charcoal & paper** was liked for it: a charcoal sidebar and
  balance header over a light register.
- **Dark: Forest & brass is the favorite** (deep green-black, brass for what you click,
  bone balance card). The bone card is too bright for dark mode; offered instead: a
  bronze card `#2B2517` (recommended) or charcoal `#1C1F1D`. Not chosen yet.
- The owner also proposed a green palette (light `#F8FAF7`/`#35A66F`, dark
  `#101613`/`#4CC98A`, teal secondary); sketched. Open points raised: its brand green
  and income green are the same color, and no color in it comes from the bee logo.
- Rejected: Dusk (lifted navy), Daylight, navy two-tone, Graphite, Espresso, Plum,
  charcoal with a royal, teal or warm block ("all look kind of gross together"), navy
  with copper, apricot or cream, and three uses of sage `#7FB069`. Oxblood & bone,
  Steppe and Ink & tangerine are still on the canvas, not picked. Also rejected
  ("the worst", 2026-09-29): the three Midnight navies with a pine teal `#355344`
  sidebar and a dark coffee `#39281E` balance card.
- **Steppe for light mode is being considered (2026-09-29).** Its dark pair keeps the
  sun yellow and red and turns the cream to a blue-black ("night", `#0D1522`) or warm
  near-black ("felt"). Rejected ("awful"): Steppe's bright blue `#1B5BA8` as the dark
  sidebar. Offered instead: deep steppe blue `#163B6E` (recommended), gray denim
  `#243550`, or an ink sidebar `#070B13` darker than the page. **Gray denim chosen**
  (see "Visual direction" above).
- **Type: Onest, with Manrope as fallback.** Both are bundled; no font is fetched at
  runtime. **Onest has no ₮ (U+20AE) glyph.** Without the fallback every tugrik sign
  renders as a box. Browsers hide this by substituting a system font, which is why the
  HTML mockups looked fine. Any future font change must be checked for ₮, Ө and Ү.
- The macOS title bar is transparent over the ground color. The native title bar is kept
  so window dragging works.

### Rules the register follows

1. **Every element earns its place.** Before adding a chart, column, badge or avatar,
   name the decision it helps the user make. Removed on these grounds: a decorative
   running-balance chart, letter avatars, and a breadcrumb that repeated the sidebar.
   (Nav for unbuilt screens was removed at first, then brought back deliberately as
   placeholders by the owner; see rule 14.)
2. **The header's chart is a forecast, not history.** It runs from today to the next
   scheduled income, steps down on each scheduled bill, and names the lowest point. It
   turns coral only when the balance will go below zero. **The line under the headline
   never names payees** (owner's correction: names can be any length, and several bills
   won't fit). It reads "3 bills · ₮2,790,200 before 10.10". Clicking it opens a list of
   every bill before that date, then the income that ends it, each with date, payee,
   amount and the balance after it (coral below zero). Clicking a bill opens it, like
   a dot; Esc or clicking outside closes the list. Rejected: naming the two biggest bills
   plus "and N more" (A), and naming the bill that tips it under (C).
   With no bank sync, "will I make it to payday?" is the question only the user's own
   ledger can answer. **It makes no suggestions about savings or moving money.** The
   owner said savings come later. **Each dot is a way into its bill** (owner's request):
   hovering shows a card with date, payee, memo or category, amount and the balance
   after (bills on the same day share a dot and a card); clicking the dot, or the payday
   label, switches the register to Scheduled and selects that transaction. No link
   inside the card, since the dot itself is the click. **The chart's ends are labeled
   with plain dates** ("09.17" … "10.10"), so it's clear what span it covers. They
   replaced "Today" and "10.10 Salary" (owner's correction: the end label was unclear,
   and the income's name added nothing the headline doesn't already say). Short dates
   are month.day, as in YYYY.MM.DD, so "10.10" is 10 October; the owner, still getting
   used to that format, first read it as an amount.
   Hovering the end date still shows the income, and clicking it opens it. When the account is already
   under zero the headline says "Below zero now", not a future "runs out" date.
   **Scheduled money coming in lifts the line** (owner's call, from the budget-app
   review): a transfer from another account, or a refund, is a step up, and the line
   under the headline adds it ("2 bills · ₮990,200 before 10.10 · +₮1,000,000 in").
   **Late money in isn't counted until it arrives** (owner's call, option A of three,
   from review finding 1 on PR #6). A salary or refund due today or earlier and not
   confirmed is left out; the forecast runs to the next salary not yet due, or 30 days.
   The small label above the headline says so in gold, with the amount and how late:
   "Next 30 days · +₮2,500,000 in, 2 days late · not counted" ("in, due today"; several:
   "+₮2,650,000 in, 2 not arrived · not counted"). The amount, not a name or a date: it
   says whether the warning would clear if the money came, and "10.10" beside amounts
   read as money (owner's call, from its review); "+… in" because late bills use the
   same gold (owner's call). Only the amount part shrinks, so "not counted" always
   shows. **On payday the warning is conditional** (owner's call): "Runs out 10.15
   unless ₮2,500,000 due today comes". The bill list marks bills and transfers past due
   and counted as today ("· due 3 days ago"), so money the user forgot to move doesn't
   look covered (owner's call). Clicking the note opens that row (the first, when
   several), like a dot, so it can be confirmed. **Salary due today waits too** (owner's
   call): on payday morning it may still be late, and ending the forecast there hid
   rent due in two days. **A late transfer between the user's own accounts counts** on
   both sides, as due today (owner's call): leaving it out of the receiving account
   while the sending one still took it off put the money in neither. Before, a late
   salary counted as arriving today and ended the forecast there, so next week's rent
   vanished from it just when pay was late. Late bills still count, as due today.
   Confirming the money when it lands brings it back. A card is unchanged, since owing
   never warns. Rejected: counting it as today but running on past it (B), which says
   you're fine while rent bounces if pay is later still, and a second dashed line for
   "if it arrives today" (C), one more thing to explain.
   **Only a row in a payday income category (Salary; see rule 24) ends the forecast.** It used to ignore
   transfers in, so moving money from savings before rent still showed "Runs out", and any
   scheduled money in, even a ₮5,000 refund, ended it as if it were payday.
   **A credit card forecasts what will be owed** (owner's call): "Next 30 days",
   "₮0 owed after 09.25", "1 payment · ₮640,200 before 10.16", a blue line, never coral
   and never "runs out". Owing on a card is normal.
   **How far it looks is a dropdown on its small title** (2026-10-05; see "From the
   2026-10-05 call" below): the pay period as before, or 30, 60 or 90 days, six
   months or a year, with the paydays and plan bills after the scheduled ones
   projected that far.
3. **One signed amount column, not In/Out.** A transaction moves money one way in one
   account. The two-column layout is a paper-checkbook and bank-statement habit. Money
   out is plain; money in is green with a `+`.
4. **Every row shows its full date (`YYYY.MM.DD`). No month subheadings or month
   subtotals.** The owner asked for these to be removed; don't reintroduce them.
   **Every other posted row is tinted a faint royal blue** (`Mid.stripe`, blue at 4.5%;
   owner's request, so transactions are easy to tell apart across the wide row). The
   first row is plain. **Hovering a row lifts it clearly above the stripe**
   (`Mid.rowHover`, a pale tint at 8%, laid over the stripe on tinted rows). The old
   hover was as faint as the stripe, so a hovered plain row looked like its striped
   neighbour (owner's correction). A selected row keeps its blue wash and outline. The dashed scheduled rows aren't striped; their
   dashed border already sets each one apart.
5. **Cleared-state symbols must not look like checkboxes or like math.** An empty circle
   beside a row reads as "select me", and a dash reads as a minus sign in the header's
   sum. The owner caught both. The symbols are: a small clock for uncleared (waiting to
   clear), ✓ cleared, ◆ reconciled (gold, from the logo's diamond).
6. **The header is the key to those symbols, written as a sum.** It reads like a
   receipt: *Cleared* (settled at the bank), then *Uncleared* as a signed amount (not
   settled yet), a rule, and *Working* as the total. **The total is the header's one
   big number**; there's no separate large balance above the sum (owner's call). It teaches why working and cleared differ. Below that,
   *Reconciled* shows **only when**: "Last reconciled on 09.10". The amount was dropped
   as unimportant (owner's call). Each line
   shows symbol, name, amount and meaning. Hovering
   a line fades non-matching rows; hovering a row's symbol lights up its line; clicking a
   line filters. Discoverable meaning beats a legend or a help screen. **Uncleared
   doesn't mean the bank hasn't seen it.** Banks often show a transaction as *pending*
   before it clears, so copy must say "not cleared yet", never "not posted" (an owner
   correction). Nor "settled" (owner, 2026-09-30: it reads as AI-written): the app's
   word is **cleared**.
   **With nothing uncleared the line carries no note** (owner, 2026-10-03: "Everything
   has cleared" told them what they already know); "3 not cleared yet" still shows.
   **Search sits in the register's tab row**, between the tabs and Add (owner,
   2026-09-30), not at the top of the page: the page starts higher and gives the
   header more room. **Its hint shows ⌘F** (owner, 2026-10-03), the Mac's own key
   for finding in a list; ⌘K, copied from other apps' command palettes, still works
   but isn't shown.
   **On a credit card every amount is what's owed, positive**, as the bank shows it
   (owner's call, from the budget-app review): the total reads "Owed ₮640,200" in
   normal ink, the register's last column is "Owed", and the sidebar says "₮640,200
   owed". Coral on a card read as an emergency, which teaches people to ignore coral
   where it matters. Rejected: keeping the minus signs and only dropping the coral.
7. **Data entry works in any field order.** Enter in any field adds the transaction if
   complete, otherwise it moves to the first missing field. Started rows outline the
   required fields still empty and say "needs N more". There is a visible Add button.
   Autocomplete gets the first Enter only while a half-typed name has suggestions
   showing. **The new-transaction row is hidden until the blue Add button (or ⌘N)
   opens it**. Add sits at the right end of the register's tab row, just above where the
   row opens (owner's call; it started in the page header beside search) (owner's call: the always-there blank row was clutter). It opens with the
   cursor in Payee, stays open after each add so a batch goes quickly, and closes on
   Esc or when you click away from it empty; with anything typed it stays. **A memo
   line sits under Payee while the row is in use** (option A; rejected: a memo field
   beside Add, too narrow). **No "+ for money in" hint** (owner: it only made sense in
   retrospect); `+` before an amount still means money in.
8. **One row at a time; its actions attach under it.** Clicking a row selects it and
   opens a bar inside its highlight with only what applies: Edit, Categorize (not on
   splits or transfers), Mark cleared *or* Mark uncleared, Delete, and ✕. Buttons are
   outlined (owner's call) so they read as buttons; Delete's outline is coral.
   **A reconciled row keeps Edit and Categorize, but its date and amount are locked**
   (owner's call: "sometimes I maybe want to change the payee; changing the amount would
   be a problem"). A statement confirms date, amount and account, not payee, memo or
   category. The bar reads "Reconciled on 09.10 · date and amount locked"; the editor
   shows the date and amount as plain text. A reconciled transfer can't move to another
   account, and a category can't turn into a transfer. Delete and clearing stay off.
   Rejected: locking everything, category chip included. Clicking the row again, ✕ or Esc closes it;
   the filter tabs stay put. Tab counts are in parentheses, "Uncleared (2)" (owner's call). No hint text: it should be obvious. **Multi-select was
   removed** (owner: not wanted now; ⌘-click, Shift-click and the bulk bar that
   replaced the tabs). It may come back with bank import, where categorizing or
   clearing a batch could be real work. Delete never removes a reconciled row (owner's
   correction: it once did), enforced in the database. **A transfer reconciled on one
   side is locked on both.** From the other account the row keeps its own ✓ or clock and
   can still be cleared there, and its payee and memo edited, but its bar reads
   "Reconciled in TDB Checking · date and amount locked" and there's no Delete. Editing it from that side once changed the locked side's
   amount; the database now refuses.
9. **Every action can be undone; only real changes get a toast.** **⌘Z (Ctrl+Z on
   Windows) undoes the last action**, then the one before, back through the session:
   add, edit, categorize, clear or unclear, delete, confirm, reconcile (owner's call).
   In a text field it undoes typing instead (rule 13). An undo says what it undid
   ("Undone · Unitel marked cleared"), because it may change a row that isn't in view.
   **Toasts appear only when a record was changed and saved or removed** (edit,
   categorize, delete, confirm, reconcile), with an Undo button for that one action.
   **A toast's Undo works only while its action is still the newest.** Otherwise it says
   "Undo the newer changes first · ⌘Z": undoing an older action out of order once wiped
   a later clear without saying so (code review, 2026-09-17). An undo the database
   refuses says "Couldn't undo … it changed since" instead of pretending it worked.
   **Clearing a row is quiet** (owner's correction: a toast on every symbol click was
   noise, especially while reconciling). The symbol changing is the confirmation.
   Adding stays quiet too, because the row appears. **Toasts are gold with dark
   text** (owner's call) so they get noticed; the dark toast they replaced was easy to
   miss. **A row that can't be saved says why in the same popup** (owner, 2026-10-03):
   beside Add there was room for "Say how muc…" and no more. It goes away once the row
   is edited. The wording is an instruction in plain office English ("Enter the amount
   arriving in Chase", "Enter the date as 2026.09.16"), never "Say how much…", which
   the owner read as written by a child. The short notes that show while typing
   ("needs amount", "= ₮150.00", "new category") stay beside Add. Undo is bold and
   underlined. **One row is open for typing at a time** (owner, 2026-10-03: Edit and a
   new transaction were open together). Add closes an untouched Edit, and Edit closes
   an empty new row; if the open one holds changes it stays and the popup says "Save
   with Enter, or press Esc to discard your changes". **An Edit closes with the mouse
   too** (owner, 2026-10-03: Esc was the only way out): a **Cancel** button sits beside
   Save where "Esc to cancel" was written, and a click away closes an Edit nothing was
   changed in. One with changes stays through a click away, so nothing typed is lost;
   Cancel or Esc drops it. **⌘⇧Z redoes** (Ctrl+Y or Ctrl+Shift+Z on
   Windows), and any new action clears what could be redone. The history lasts for the
   session and isn't saved.
10. **Confirming a scheduled item means it happened now.** Confirming before its due
    date posts it today, never on a future date, and the toast says so ("Zaisan
    Residence confirmed early · ₮1,800,000 · posted today, 09.16").
    **Confirm opens the bill to check its amount** (owner's call, option A of three,
    from review finding L: "some bills are hard to predict"). It turns the row into
    the editor with the amount selected (after its `+`, so typing the figure can't
    turn money in into money out). **A bill not due yet is dated today; an overdue bill
    or transfer keeps its due date**, since a standing order or auto-pay left then, and
    a statement will show it then (both review passes: dating it today moved it
    silently and broke the next reconcile). **Overdue money in is dated today** (owner's
    call): late means it didn't come on its date, and dating a late salary back put
    money in the balance before it arrived; Enter (or the row's Confirm
    button) confirms whatever it says, so a bill that matched costs one keystroke. The
    date can be changed to the day it really went out, but not to a future day (the
    calendar greys them). When the amount changed, the toast names the plan:
    "Electricity confirmed · ₮64,210, planned ₮60,000", and when the date isn't the
    planned one it says so ("· posted 09.12"). Esc leaves it scheduled.
    Rejected: posting at once with "Change amount" in the toast (B), easy to miss for
    bills that usually vary, and marking some scheduled items "amount varies" (C), a
    setting to maintain.
    **Money in confirmed short can stay owed** (owner's call, after a committee of three:
    household money, design, ledger integrity). When a salary or refund is
    confirmed below plan, a line under the amount reads "₮1,250,000 less than planned:
    (•) Still owed, due 10.10 ( ) Paid in full". **Still owed is chosen when more than a tenth is
    missing** (owner's call; otherwise Paid in full, since take-home pay and refunds
    after an exchange rate move vary a little), so Enter keeps
    the rest scheduled on the planned date (payee, memo and category as confirmed) in
    the same write. Past that date it's late, so rule 2 leaves it out of the forecast and names
    it. A remainder nobody wanted is visible and one Delete away; a forgotten one would
    vanish. The toast says "· ₮1,250,000 still owed, due 10.10", and one Undo puts back
    the single planned row. Bills never see the line: one that came in lower owes
    nothing more. Nor do transfers between the user's own accounts: moving less is
    their own decision, and a kept remainder would count in the forecast (late
    transfers count) as money that was never going to move (both review passes). Wording was the owner's pick ("Rest still coming" was disliked;
    rejected: "Expect the rest / That's all", "Keep ₮X scheduled / Drop it"). Rejected
    designs: a toast action (toasts are missed), keeping the rest automatically (varying
    income would leave a remainder every month), "Paid in full" as the default (a
    forgotten remainder disappears), and waiting for recurring schedules (they make next
    month's salary, not this month's shortfall).
11. **A future-dated manual entry is scheduled**, not posted. It shows in the forecast
    and in Scheduled but in no balance until confirmed. The same applies when an edit
    moves a posted transaction into the future.
12. **Editing happens in place, in the same row as adding.** Double-click a row (or
    select it and press Enter, or click Edit in its action bar) and it becomes the
    entry row, filled in, with a memo line and the cursor in the cell that was clicked.
    A single click only selects, with no delay, because double-click is detected from
    two single clicks. **A row opening into the editor, or its action bar, grows smoothly** and
    shrinks back when it closes (owner's request): 180 ms, ease out, from whatever
    height it has at that moment, so a double-click (bar, then editor) eases the whole
    way instead of jumping. The new-transaction row opens the same way (160 ms). A
    window resize doesn't animate. Instant with the OS reduced-motion setting. Enter or Save keeps the changes, Esc cancels, and Undo restores
    the whole transaction. Clicking another row with unsaved changes doesn't discard
    them; it says how to save or cancel. Reconciled rows don't open, and a message says
    why.
13. **Plain-key shortcuts never steal typing.** Delete, C, Enter and Esc act on the
    selected row only while no text field has focus. Clicking a row takes focus out
    of any field.
14. **The sidebar is organized by section (option A of three considered).** Ledger,
    Budget and Savings are section headers in one sidebar. The section you're in
    expands; the others collapse to one line. Under Ledger are the accounts, grouped.
    Net worth stays pinned at the bottom. Budget and Savings are placeholders marked
    "Later" that open a "Not built yet" page. **"Savings" is a working name** until the
    section is defined. Rejected: an icon rail plus a per-section panel (B), and
    accounts-only sidebar with sections as a top switch (C). "All accounts" was first held back
    for cross-account search; the owner asked for it with categories (rule 23).
    **Opening a section spills its contents down** (owner's request): the space opens
    and the items fade and drop into place one after another, top to bottom, while
    the sections below slide down. Opening takes 360 ms and
    closing plays back in 200 ms. With the OS reduced-motion setting on, it opens
    instantly. Any section's contents can use it (`_Spill`); only Ledger has
    contents today. The timing is a first version and can be tuned.
    **No chevron on section headers** (owner's correction): a chevron promises a
    toggle, where clicking an open section closes it again. Here clicking a section
    switches to it, and it stays open until you pick another. The blue icon and bold
    label already mark the current section. Accounts line up with the section label.
    **A coral dot after an account's name says its forecast runs out** (2026-10-05;
    see "From the 2026-10-05 call" below).
15. **The date field opens a calendar under it (option A of three considered).** It
    shows while the date field has focus, styled in Midnight, Monday first. Typing
    still works and the calendar follows it to the typed month. Clicking a day fills
    the date and moves to Payee; Esc closes the calendar first, and a second Esc
    reaches the row. The selected day is filled blue and today is underlined. **Days
    after today are gold**, because picking one schedules the transaction (rule 11);
    hovering or selecting one says "After today · it will be scheduled". It marks
    nothing else. The same calendar opens when editing a transaction's date. Rejected:
    Today/Yesterday buttons under the calendar (B), since the field already starts on
    today, and Flutter's modal date picker dialog (C), which looks stock, blocks
    typing and pulls you out of the row.
16. **Reconcile happens in the header (option A of three considered).** An outlined
    Reconcile button sits beside "Last reconciled on…". The reconciled line itself
    still filters, like the other key lines. The balance sum is replaced by
    Statement date (today by default; the calendar can't pick future days), Bank
    balance ("Bank says you owe" on credit accounts, entered as a positive number),
    Cleared here, and **Off by**. The forecast stays beside it. Bank balance starts
    filled with the cleared total, so if it already matches, reconciling takes one
    click. The register narrows to rows not yet reconciled up to the statement date,
    labeled "Not reconciled, through …", where rows are marked cleared the usual way
    (symbol click or C). "Off by" updates live and reads "Matches" in green at zero.
    **Bank balance starts empty, with the cursor in it** (owner: "that's bad" about the
    old prefill). It used to start at the cleared total, so Reconcile then Enter locked
    everything without anyone reading the bank's number. Next to the empty field: "Not
    the “available” balance" (bank apps show one that takes off pending holds and won't
    match). **Lock stays disabled until the numbers match.** When they don't, the panel
    helps find why: "Bank is lower" or "Bank is higher" (opposite causes), and a line
    naming the one row whose amount is exactly the difference, if exactly one is ("Unitel
    on 09.16 is ₮30,000 and isn't cleared", "… cleared here · not at the bank yet?",
    "… dated 09.18, after the statement"); otherwise "Clear the rows your bank shows".
    While reconciling, the last column is **Cleared balance**, a running total of cleared
    rows only, to compare line by line with the statement; uncleared rows show none.
    **A difference nobody can find goes in as a named adjustment** (owner's call). In
    place of the disabled Lock, an outlined (not gold) "Add ₮30,000 adjustment and lock"
    posts one cleared "Reconcile adjustment" row on the statement date against a
    "Balance adjustments" account (equity, like opening balances, so never spending), and
    locks it with the rest. Its toast says "· ₮30,000 adjustment added", and Undo removes
    the adjustment with the locks. Rejected: staying strict with only the finding aids
    (people would make up a spending row to force a match). The button
    names how many rows it locks. Locking marks this account's cleared entries up to
    the date reconciled, records the statement, and offers Undo. The other side of a
    transfer isn't locked. Esc cancels (after closing the calendar). A date before the
    last reconciliation or after today is refused with a reason. Rejected: a yes/no
    "does your bank show X?" first step (B), which invites clicking Yes without
    checking, and waiting for bank import (C). Import can reuse the "Off by" line.
    **A reconcile can be taken back at any time, not just this session** (owner's
    call). A locked row's bar says "Reconciled on 09.10 · locked because it matches
    that statement". Rows locked by the account's newest reconcile also get **Undo this
    reconcile**, which puts that reconcile's rows back to cleared. Reconciles come
    undone newest first, so every lock left in place still matches its statement.
    Later reconciles that locked nothing go with it. The toast has Undo, and ⌘Z / ⌘⇧Z
    work too. Each entry stores the reconcile that locked it (schema version 2);
    older data was linked to the first statement dated on or after each row. **Only
    an account's own side is ever reconciled**, and always by a statement. Older data
    also locked category, opening-balance and statement-less sides, which made rows
    look unlocked but refuse edits, or stay locked forever. Schema version 3 puts those
    back to cleared. The database also refuses statement dates out of order, and
    forecast dots do nothing while a reconcile is open (the register hides scheduled
    rows then).

17. **A transfer says which way it goes before it's added** (owner's call, from
    budget-app review finding H). While the category is "→ Account", a line under
    category and amount, level with the memo line, reads "₮640,200.00 from TDB
    Checking to Golomt Visa", and "Swap" turns it around (it adds or removes the
    `+`). The category reads "→ Golomt Visa" whichever way the money goes, so a
    transfer entered from the receiving account used to go the wrong way unnoticed.
    Editing a transfer shows the same line; on a reconciled one there's no Swap.
18. **"Move to" fixes a transaction entered in the wrong account** (owner's call,
    finding I). It sits in the row's action bar, after clearing, and lists the other
    accounts. Only this account's side moves; date, amount, payee and category stay.
    **The moved side starts uncleared**, because the other bank hasn't been checked,
    and the toast says so ("· uncleared there until it clears"). Not offered on
    reconciled rows (either side), opening balances, or onto a transfer's own other
    side. ⌘Z puts it back as it was, cleared state included.
19. **Backups stay on this machine** (owner's call, finding K). Once a day, when the
    app opens (and hourly while it stays open), a copy goes to `Backups/` beside the
    database. **Kept: the newest 14, plus the first copy of each of the last 12
    months** (owner's call, from the review: a mistake found a month later still has
    a copy from before it). **Backups live in Settings** (owner's call: "where we'll
    have other settings"). A gear labelled "Settings" sits at the bottom of the sidebar, just above the Net
    worth section, lined up under the section icons (owner's corrections: it started
    right of Net worth, then left of it, and got its label), and opens a Settings page in the main area (option A; rejected: a menu
    from the gear, too small for status or later settings, and a gear beside search
    in every account's header). The page's first section, Backups, shows the daily
    copy ("Today 09:30 · on this computer"), what's kept, and two buttons. They first
    sat as links under Net worth. **"Back up to…"** saves a copy wherever the user
    picks (another drive, a USB stick); the toast names the file. The automatic copies
    share a disk with the data, which is why it exists. **"Restore from…"** sits beside
    it (owner's call). The picker opens on the daily
    copies. Nothing is replaced until a dialog shows the backup's date and time, what
    it holds and what's here now ("19 transactions · 4 accounts"); Enter or Restore
    confirms. What's here is saved first, the toast says so, and Undo (or ⌘Z) brings it
    back. A restore clears the earlier undo history, since those actions point at rows
    it replaced. A backup from an older version is upgraded on the way in; one from a
    newer version, a damaged file, or a file that isn't a BetterBudget backup is
    refused with a reason. Rejected: copying a file over the data by hand, which can
    corrupt it (SQLite's `-wal` file stays behind). **A failing daily copy says so**
    (owner's call), once the newest copy is over two days old; a single failed hour
    stays quiet. The gear gets a coral dot, and Settings says "Failing · the last one
    is from …" in coral.
    Backups are unencrypted until SQLCipher; that work must encrypt or remove them.
    **Start over** (owner, 2026-09-24, for the alpha: "a clean start with no demo
    accounts") is the last section of Settings: "Start a new ledger…" opens a coral
    warning with what goes ("19 transactions · 4 accounts · 1 reconcile", then pay,
    payees, and the Budget and Savings settings) and a box, ticked by default, to
    keep the open categories with no rows (a default, not a required choice). What's
    here is saved first as `before-new-ledger-….sqlite` in `Backups/`; Undo or ⌘Z
    puts it back, and Restore from… can later. It clears the undo history like a
    restore. A ledger emptied this way stays empty: the demo data only fills a file
    that has never had a ledger started in it.
    **Made plain that everything goes** (owner, 2026-09-29: "it needs to be more clear
    that all their old stuff will go away"; option A of three). "Start a new ledger"
    read like adding a second ledger, so it's **"Erase everything and start over…"**,
    and the card says it erases every account and transaction (no "Done trying
    things out?" in front: owner removed it, 2026-09-29). The dialog, titled
    "Erase everything and start over?", lists under "All of this is erased:" each
    account by name with its balance as the sidebar shows it ("₮640,200 owed"), the
    transactions with their first and last dates, then pay, reconciles, payees and
    settings, and says "You start with no accounts and no money in the app." **The
    categories are a visible choice** (owner: "the option to leave the categories or
    delete them should be clearly visible"): "Your 15 categories" with "Keep them,
    empty" (default) or "Erase them too", and a line saying what each means. The
    button reads "Erase everything"; the toast "Everything erased · what you had is
    saved in Backups". Still one click, saved first, undoable (warn, don't block).
    Rejected: stronger words with counts only (B), and a before/after comparison
    (C). The recovery-key screen's "Start a new ledger instead…" keeps its name: it
    moves the old ledger aside, not erasing it.

20. **Old items say on the row why Working may be off** (owner's call, option A of
    three, from review finding G). Working leaves out scheduled rows and keeps
    uncleared ones, so two kinds of old row skew it without a word. **A scheduled row
    past its date** says "· due 7 days ago" in gold after the payee, in place of "next
    of N scheduled" (the Scheduled tab counts them). It isn't in Working until
    confirmed, though it probably happened; the forecast already counts it as due today.
    **An uncleared row 14 days old or more** says "· not cleared for 34 days" after its
    memo, a shade brighter than the memo. Card holds usually drop within that, so it
    may never have happened (cancelled, or entered twice) yet still lowers Working.
    Nothing changes Working by age on its own. Rejected: a header line that filters to
    these rows (B), and both (C).

21. **Accounts are added and managed where they're used** (owner's call, option A of
    three). A quiet "+ Add account" sits under the accounts in the sidebar and opens a
    form in the main area: a name ("New account" if left empty) and a kind, Bank account
    (already chosen) or Credit card. A bank field was left out because nothing shows it.
    **A new account's first screen asks what's in it** ("What do you owe on it
    today?" on a card), with a date. The answer becomes a cleared opening balance, so
    the first reconcile starts from it. Left empty, the account starts at ₮0 with the
    entry row open. **The name renames in place** when clicked (Enter or leaving the
    field saves, Esc cancels). A ⋯ beside it holds Rename, Change to credit card / bank
    account, Archive… and Delete…. **Right-clicking an account in the sidebar opens the
    same menu** (owner's request, after trying it). The account stays lit while the
    menu is open, and Rename there opens the account with its name ready to edit.
    Every action undoes with ⌘Z. Rejected: an Accounts
    page in Settings (B, managing accounts away from the ledger) and typing a new
    account straight into the sidebar (C, no place to ask the kind).
    **Warn, don't block** (owner, 2026-09-18: "I really hate it when a developer tries
    to save me from myself"). The first design allowed archiving only at a zero
    balance and deleting only an account with no rows. Now both are always allowed,
    and a dialog says exactly what will happen first. **Archive** takes the account
    out of the sidebar, transfers and Move to, but keeps it in net worth. It asks
    only when something is left behind ("₮4,182,450 is still in it…", "4 scheduled
    rows … won't show in any forecast"). Settings lists archived accounts with "Show in
    sidebar". **Delete is stark and final** (owner's correction: don't promise it
    can be brought back). The title is coral, and the dialog gives the rows that go and
    how many were reconciled, how far net worth moves, and where transfers stay. The
    button names the account, and Enter doesn't press it. The toast has no Undo,
    though ⌘Z still works as it does for everything in the session (the dialog doesn't
    say it can't be undone, since that wouldn't be true). **Deleting an account never
    changes another account** (owner's call). Its transfers stay on the other account
    as "TDB Checking (deleted)", so balances, cleared totals and reconciles there are
    untouched, and a lock that came from the deleted account's statements lifts.
    Rejected: turning those transfers into ordinary rows with no category, which hides
    where the money came from.
    **From the reviews** (decided along the lines above):
    - The second kind is **"Card or loan"**, with a hint naming loans and Storepay.
      Salary loans, mortgages and buy-now-pay-later all show as owed. The form says
      accounts are in tugrik for now.
    - The start hint shows before anything is typed. On a card it says "what you've
      used, not the available limit". The question follows the date ("What was in it
      on 08.31?").
    - After a balance, the entry row opens, because the bank's number already
      includes everything cleared. **No toast** (owner's correction, 2026-09-30: the
      account was just made on purpose; it used to say "Started at … · add only what
      hasn't settled yet"). ⌘Z still takes the balance back, and Esc on the entry row
      leaves ⌘Z working without a click. The opening row's category reads **"Opening
      balance"**, singular like its payee (owner, 2026-09-30; was "Opening balances").
    - **Changing the kind flips an unreconciled opening balance**, since it was typed
      in the kind's own sign. Changing back flips it back.
    - The archive warning separates bills (dropped from every forecast) from scheduled
      transfers (still on the other account's forecast). The delete warning names
      scheduled transfers that stay.
    - Balances in the warnings read "₮3,000 overdrawn" or "₮5,000 in credit: the bank
      owes you", and show the fraction when there is one.
    - Net worth adds "incl. ₮X in archived" when archived accounts hold anything.
    - Deleting an account with no rows and no transfers skips the dialog.
    - Undo of adding an account only works while it is still empty.
    - The database refuses new rows in a deleted account.

22. **Categories are managed on the Budget screen** (owner's call). Categories belong
    to both the ledger and the budget, and one place should own them. The Budget
    screen is where every category will be a line, so its first version is just the
    list. It is grouped Spending and Income, and each category shows "42 rows · last
    09.12 · 1 scheduled", which is what decides whether to keep, merge or archive it.
    There are **no ₮ amounts yet**; the budget model (envelopes or targets, still open)
    adds its columns to these rows. Budget no longer says "Later". Rejected, and
    first recommended: a Categories page under Ledger, which would have become a second
    place once the budget came; and a top-level Categories section, for the same
    reason. **Add category** opens an inline row (name, Spending or Income; income ends
    a forecast, like payday). **Click a name to rename it**; ⋯ or a right-click gives
    Rename, Change to income / spending, Archive and Delete…, like accounts (rule 21).
    (Replaced 2026-10-02 by rule 29: the menu is Edit and Delete, and the rest is in
    Edit.)
    **Archive** needs no dialog, since nothing is lost: the category leaves the menus
    and the entry row, and its rows keep its name. "Show archived (n)" lists archived
    categories with "Show in menus". **Delete with rows asks where they go** ("1 row is
    filed under it. It moves to: [Groceries]"), then merges. The rows are moved, not
    lost, so this isn't a block. Deleted rows move too, so undoing their delete
    later finds a live category. An empty category just goes, with ⌘Z.
    **A new category can be made while typing a transaction.** In the entry row, a
    name that isn't a category shows "+ New category 'Coffee'" in the list and a gold
    "new category" note, so a typo is visible before saving. Saving makes it (income
    if the amount had `+`), and the toast says "Nomin Coffee added · new category
    'Coffee'". One ⌘Z takes both back. "Gro" plus Enter still picks Groceries: the
    "+ New" line never counts as a match.
    **From the reviews** (decided along the lines above):
    - An archived category's name is still known. Editing or confirming one of its
      rows keeps it; only the lists leave it out. The first build treated it as new
      and quietly made a second one.
    - A typed name becomes a category only when that's clearly meant: "+ New" was
      picked, or the name looks like nothing else. If it's part of another name,
      saving from another field says "'Gro' isn't a category · pick Groceries, or +
      New category". If it's an account's name, it says "Did you mean '→ Golomt
      Visa'?". This protects against slips; it doesn't refuse anything, since "+ New"
      is always there.
    - The note says "new income category" when the amount has `+`, and it stays
      beside a calculator sum.
    - The category and its row are one write, and one undo takes both.
    - No duplicates: adding a name that exists (any case) says so. If it's archived,
      it comes back instead. Renaming onto another category's name offers "Merge
      Gifts into Entertainment?", the same operation as delete-with-move.
    - Delete counts deleted rows too, so undoing their delete later finds a category.
      The dialog says how many are scheduled, and when moving between spending and
      income it says what changes.
    - A split merged into its own other line shows the category twice. Balances are
      right; accepted until splits can be edited.
    - The Add category row stays open for the next one. Dates from another year show
      in full. Names sort ignoring case.
    - The database refuses category actions on anything that isn't a live category.

23. **All accounts is a view under Ledger** (owner's request, from clicking a
    category's usage). "All accounts" sits above the account groups in the sidebar
    and shows every account's rows in one register. **The last column is Account**,
    in place of Balance: a running total mixing checking, a card and cash means
    nothing. **A transfer shows once**, from the account the money leaves ("To Khan
    Savings" in TDB Checking's row). Scheduled rows name their account where one
    account's register says "next of 4 scheduled". **Adding a row asks for the
    account** (owner's call: the dropdown is for adding, not filtering). It's a
    dropdown in the Account column that starts on the account last open and stays
    on the last one picked, so a batch from one account is picked once. The note and
    Add move to a line under it. A row's own actions (edit, clear, categorize, Move
    to, delete, confirm) work on its own account. **Nothing sits above the register
    but filters** (owner's call, option A): net worth is in the sidebar, and the
    forecast and reconcile stay per account, since "will I make it to payday?" and a
    statement are about one account. Rejected: a slim summary line (B) and a
    combined forecast (C). **Clicking a category's usage on the Budget screen**
    ("2 rows · last 09.16") opens All accounts with a chip, "Category: Groceries ✕",
    and what matched: "2 rows · ₮276,650.50 spent". A split counts only its line in
    that category. ✕ or Esc takes the filter off. This is the first slice of Search
    (roadmap item 10): chips for account, date and amount can join it.
    **From the reviews** (decided along the lines above):
    - **The picker starts on the account last open each time All accounts is
      opened, then stays on the last pick for the batch.** A pick from days ago
      doesn't carry on. (The first build reset after every save, so the second row
      of a batch went to the wrong account.) It comes after Amount in Tab order.
      With an account chosen, Enter adds; Space or ↓ opens the list. Keys pressed
      on it never reach the row shortcuts, and hovering its list doesn't close an
      empty row.
    - Nothing moves money to its own account (enforced in the database). "→ Cash
      wallet" from Cash wallet says "Can't transfer to the same account".
    - **A transfer's symbol shows the less settled side**, with a tooltip naming
      it ("In Golomt Visa: Uncleared…"). Clicking clears that side, and
      Uncleared counts it. "Has my card payment landed?" can be answered here.
    - A transfer is shown from an open account's side before an archived one's.
    - Scheduled rows name their account even when overdue ("· due 3 days ago ·
      TDB Checking"). Search matches account names too.
    - **A new row that won't show under the filter or search says where it
      went** ("Nomin added to Cash wallet · not in this view"), so it isn't typed
      twice.
    - The filter line counts the posted rows its total covers, gives the span,
      and counts scheduled rows apart: "2 rows · ₮276,650.50 spent since
      2026.09.12 · 1 scheduled". More back than spent reads "refunded".
    - Rename, Add account and "Show in sidebar" from All accounts open that
      account. Switching views with an unsaved edit stops, as clicking another
      row does.

24. **Pay: paydays end the forecast, and the app asks for pay** (owner's calls,
    2026-09-19). **Only a payday income ends a forecast** (option A of three).
    Income categories carry a payday mark: on for Salary and Pension (every existing
    income category kept it when upgraded), off for the rest. Child allowance on the
    12th no longer ends the forecast before rent on the 20th. Toggle it with "Mark as
    payday" / "Not a payday" in the category's ⋯ (in Edit since rule 29). Rejected: ending the forecast at
    the first income big enough to cover the bills (B), and always forecasting 30
    days (C). **Putting in pay** (option A): a pay setup names the category, the
    account it's paid into, who from (optional), whether it's about the same each
    time or varies, the amount, and when it comes (monthly on a day, twice a month,
    or every N weeks from a payday), with a weekend payday moved to the Friday
    before or the Monday after, or **kept on its day** (owner, 2026-09-30: "some
    people are paid on a Saturday"; "Keep the day", schema v9). It opens from the forecast, from a payday category
    on the Budget screen ("payday · pay not set up", gold, until it is; or
    "payday · ₮2,100,000 or more on the 10th and 25th · next 09.25"), and from
    Settings. **The next payday is always scheduled from the plan**: saving
    schedules one, and confirming it schedules the one after at the planned
    amount, whatever came. Rejected: a Pay section only in Settings (B), and
    prompting after each payday with nothing scheduled (C). **The app keeps asking
    until there's pay:** an account's forecast with no payday to run to says
    "Next 30 days · no payday ahead · Add your pay →" in gold.
    **The forecast runs through the next pay period** (owner's call, 2026-09-30,
    option A of three; before, it stopped at the next payday, so with payday
    tomorrow it showed one day). From today, the next paycheck is a step up (its
    date labelled under a green line), and the forecast ends as the paycheck after
    it lands, a date from the pay plan (only the next payday is ever scheduled).
    The label reads "Until your 10.15 paycheck" (first tried "Through the next pay
    period"; owner, 2026-09-30: a new user can't tell what it means). Bills on that last payday count;
    money in on it doesn't, except a transfer. Without a plan (pay scheduled by
    hand, or a bonus while the plan's own payday is scheduled) it ends at payday as
    before. Rejected: at least 30 days, ending on a payday (B), and the next payday
    unless it's within a week (C). **It has to read for someone new** (owner's
    correction, 2026-09-30, on a flat line with a jump under "Never below today's
    ₮4,289,291": "What does it mean?"; option A of three). With pay but no bills,
    there's no chart: a list under a bold, centered **"Forecast"** title: "Today's
    balance ₮X", then each payday as "10.01 Expected income +₮Y" and "10.15 Expected
    income +₮Y" (the app doesn't know what kind of income it is; "Pay" and "Next
    pay" were wrong, since the first one is the next pay), then "Nothing has been
    budgeted. Once you fill out your budget, this area will show you a forecast."
    (owner's wording, 2026-09-30; it replaced a hint and an "Add a bill" link they
    called AI-speak). Every state has the "Forecast" title. With bills, the chart names its amounts beside their points:
    where it starts, the lowest point, and "+₮Y pay" on the paycheck's step (one
    that would cover another is left off). Rejected: a labeled chart even with no
    bills (B), and always a list, no chart (C). **From the reviews:** the headline
    says "Lowest ₮X, today" when nothing goes under today's balance, and "Lowest ₮X
    on 10.01, after payday" when the low leans on the paycheck; the lines under it
    say "through 10.10" (that day's bills count), not "before"; a moved split
    paycheck is matched to its payday by amount. Left for later: a "scheduled bills
    only" note, following the budget's own pay schedule when two earners share an
    account, cents in the forecast for dollar accounts, and a late paycheck making
    the span swing (30 days on payday morning, two periods the day after).
    **Pay that varies is an estimate on the low side** (owner: "better to have too
    much money than too little"). The setup's amount reads "Expect at least", with
    the advice that the forecast counts on it. Your last paychecks' lowest and highest
    show beside it. Typing more than some of them says so in gold ("Higher than 2 of
    your last 6 paychecks: the forecast may look better than it'll be"), and it
    still saves. Confirming under the estimate isn't "still owed". The toast says
    "₮180,000 under the estimate", and the payday card says "at least, an
    estimate". When the last three came in over 5% above it, the Budget screen line
    says "Last 3 came in above ₮X · raise the estimate?". Nothing changes the
    estimate but the user.
    **Budget by month or pay period, the user's choice** (owner's call: people
    paid every two weeks). It's in the pay setup and in Settings ("Budget by: Month
    / Pay period"), and it starts on Month. A pay period needs a pay schedule; with
    two earners, whose pay it follows is the choice. Every-two-weeks pay notes "26
    paydays a year: two months a year have three". For now it decides the span of a
    category's rows opened from Budget: a "This month · 09.01–09.30" (or "This pay
    period") chip, removed with ✕ or Esc for all time. The budget's periods will use
    the same setting.
    **From the reviews** (decided along the lines above):
    - **Early or late pay belongs to its planned payday.** Pay confirmed on the
      23rd for the 25th schedules next month's, not the 25th again. A payday the
      user deletes (unpaid leave) stays skipped. Paydays the app takes away itself
      (a changed plan, an undo) are unlinked, so they don't count as skipped.
    - **A salary the user had scheduled by hand** within a week of the first
      payday is taken over by the new schedule, and undo brings it back.
    - While a payday is overdue, the next one is scheduled too, so the forecast
      still has a payday to run to.
    - Confirming a bill never touches pay; confirming a payday schedules only its
      own schedule's next one.
    - An every-N-weeks start date later than today is the first payday.
    - **"Add your pay" asks only while there's no pay set up anywhere.** Once
      there is, accounts that pay doesn't go into say plainly "Next 30 days". A
      click can't start a second Salary by mistake.
    - The amount is labelled "Each payday". For twice a month and every N weeks,
      the summary adds "about ₮X a month", so a monthly figure typed by mistake
      shows as double before saving. "It varies" says to leave bonuses out.
      Estimates and history come from the schedule's own paychecks, not
      everything filed under Salary.
    - **Nudges point the safe way.** Pay that varies suggests raising the
      estimate only when the *lowest* of the last six beat it by 5%. Pay that's
      the same notices when the last two came in alike and off the plan ("Last 2
      came in at ₮X, less than planned · update it?").
    - Undo puts back exactly which schedule the budget ran by, and a category's
      payday mark. Editing a schedule no longer re-marks a category the user set
      to "Not a payday".
    - Paydays skip archived or deleted accounts and categories. Settings says
      so ("(archived · no paydays until it's back)"), names two earners by
      employer, and the dialog says which pay the budget follows when it's
      another's.
    - Date arithmetic is in calendar days, safe across daylight saving. A
      restore schedules paydays as a launch does.
    **Two amounts, and no regular pay** (owner said yes to both, 2026-09-29):
    - **Twice a month can have a different amount each paycheck** (an advance on
      the 10th, the rest on the 25th). The default stays one amount: "The same each
      paycheck" / "A different amount each paycheck" shows under the amount once
      "Twice a month" is picked, and the second choice turns the amount into
      "On the 10th" and "On the 25th", earlier day first. (Owner's correction,
      2026-09-29: "a different amount each day" was misleading; it's each
      paycheck.) Each payday is
      scheduled at its own day's amount, a weekend move included; the summary
      shows the next payday's amount and "about" the two added together. The
      Budget screen and Settings say "₮500,000 on the 10th and ₮1,600,000 on
      the 25th". Estimates and nudges compare each paycheck with its own day's
      plan, so an advance never reads as a short paycheck. The "higher than
      your last paychecks" warning is off for split pay (its history mixes
      advances and the rest). The same amount typed twice saves as one.
      Stored as a second amount on the schedule (schema v7).
    - **"I don't have regular pay"** sits bottom left in "Add your pay" while
      there's no pay anywhere (self-employed, between jobs). It turns off the
      forecast's "Add your pay →" and the Budget screen's gold "pay not set
      up" (it reads "payday · no regular pay"). Settings says "You said you
      don't have regular pay, so the forecast doesn't ask for it" with **Ask me
      again**; "Add your pay" stays in Settings the whole time. ⌘Z undoes
      either.
    - From the code review (decided along those lines): going back to one
      amount (same both days, or another rule) keeps the larger of the two,
      since the advance alone would undercount pay. Split pay confirmed late
      belongs to the payday whose amount it matches (an advance on the 18th is
      still the 10th's, and the rest on the 25th stays scheduled). Both days on
      the 28th or later warn in gold that shorter months have one payday, not
      two. Adding pay after "I don't have regular pay" clears the saying, and
      undo brings it back; the button isn't offered again once it's set.
25. **Savings is the steps to getting financially prepared** (owner's calls,
    2026-09-19). It follows the order of the Church's *Personal Finances for
    Self-Reliance* course ("What Is My Current Financial Priority?", chapter 5;
    see [self-reliance-course.md](../self-reliance-course.md)), **for everyone**.
    Tithing is left out: "I'm not going to push tithing. I want to push getting
    financially prepared." Six steps: one month of expenses set aside; health
    coverage; no consumer debt; 3 to 6 months set aside; saving for retirement;
    paying off the mortgage and student loans. **Option A of three** (a ladder).
    Rejected: B, the payday split (tithing, then the fund, then the rest) as the
    section itself (it may come with the budget), and C, a course companion with
    weekly lessons (courses may be added later). Also set aside for now: the
    earlier Growth page, balance sheet and goals concepts
    ([personas.md](../personas.md) §2).
    **How it works** (decided along those lines):
    - Every step shows. **The current step is the first not done** ("Now",
      outlined in blue); done steps have a green check. Nothing is locked: any
      step can be **set aside** from its ⋯ and brought back (warn, don't block).
    - **A month is a month of expenses, not pay** (the course's own wording):
      the average of spending categories over the last 3 months (or since the
      ledger began, from 4 weeks), rounded up. Refunds count against it; transfers,
      card payments and opening balances don't. The user can type their own
      ("as you typed it"); emptying it goes back to the average. With under 4
      weeks of rows it asks for one.
    - **The fund lives in accounts the user picks** ("Kept in Khan Savings",
      a menu of bank accounts). Until one is picked, step 1 isn't done whatever
      is saved.
    - **Consumer debt** is every card or loan owing, unless marked a mortgage, a
      student loan, or "paid in full every month" (a card used for convenience).
      Each shows its balance, smallest first, with the course's advice: extra
      on one at a time, smallest balance or highest interest first, then roll
      its payment into the next. While step 1 is current, it names the debts to
      pay only minimums on.
    - **Health coverage and retirement are the user's answers** (the money
      usually never passes through the ledger). "Not yet" is the default.
    - The bigger fund aims for 3 months unless the user picks 4, 5 or 6.
    - Answers are quiet clicks (like clearing a row); marking an account, a
      typed month and setting a step aside toast. All of them undo and redo.
    - Stored as an account role and a small preferences table (schema v6).
    **From the reviews** (decided along the lines above):
    - The month's average starts at the first spending row, so an opening
      balance dated months back doesn't shrink it and tick step 1 early.
      Payments into a marked mortgage or student loan count as a month's
      expenses ("loan payments included"); card payments don't, since the
      card's own spending already counts. Worked out in whole integers.
    - **A check means paid off or yes, never "not marked".** With no loan
      marked, step 6 asks: "I have none", "Paying extra on them" or "Not yet".
    - A card marked "paid in full every month" that has owed something every
      day for over five weeks says so in gold ("Owed every day since …"). It
      stays the user's call.
    - Step 3 marks one debt **"Pay extra here"**: the smallest, or one picked
      from its menu ("Pay extra on this one").
    - One word for the figure: "a month of expenses", the course's word.
    - The fund and the month are set on step 1 only; step 4 adds the months.
      Archived accounts count nowhere in Savings (they can't be seen or
      changed there).
    - Row keys (Delete, C) act only on the ledger, so they can't reach a
      hidden row from Savings; answers read the newest ledger, so quick
      clicks both count.
    - **Later:** showing the three monthly totals under the average (a
      student's swings); keeping the "a separate account works best" hint
      when the fund's account is also spent from; the rate and minimum payment
      per debt (with card due dates, personas §1).
26. **The budget: envelopes with three numbers a line** (owner's calls,
    2026-09-30; envelopes were decided the same day, ROADMAP "Decided").
    - **Each category reads Assigned · Spent · Left** for the period on screen
      (month or pay period, the Settings choice), option A of three. Left is
      what the envelope holds now, so it includes what carried over ("₮500,000
      from before" under it when it differs). A line at the top gives the money
      not assigned to a category yet. Click Assigned to type an amount.
      (Owner's correction, 2026-09-30: "What does 'put in' even mean?? Change
      it to 'Assigned'"; "not given out" went with it.) Rejected:
      Left only, with a bar and the other two numbers in an action bar (B); a
      list plus a give-out panel for payday (C).
    - **Overspending carries as minus** (option A of three). A category keeps
      its own balance below zero: October's −₮32,000 in Dining out starts
      November's ₮150,000 at ₮118,000. Money can be moved in from another
      category any time. Rejected: the next period's money not given out
      absorbs it and the category restarts at zero (B); covered at once from
      the money not given out, so nothing goes below zero (C).
    - **Card debt reduces the money** (option A of two). Not given out = cash
      and bank, minus what cards owe, minus what's in categories. Groceries
      bought on the card come out of Groceries and nothing else; paying the
      card moves nothing on the Budget page; card debt from before the budget
      shows as less to give out on day one. Rejected: a card-payment category
      per card that fills as the card is used (B), the common convention.
    **How the first build works** (decided along those lines, 2026-09-30):
    - ‹ › beside the title step through periods ("This month · 09.01–09.30",
      "October · 10.01–10.31", "Pay period · …"); "Back to today" returns.
      Switching Settings between month and pay period starts over at
      today's period. Amounts are stored by the day their period starts,
      and a category's balance is every amount less its spending, so
      switching loses nothing.
    - Spent shows no sign ("₮276,650.50"); more back than spent shows as
      "+₮X". A minus there read as a double negative.
    - **Typing an amount is quiet**, like clearing a row: on payday it's
      typed a dozen times. ⌘Z takes any back. Enter or clicking away saves,
      **Tab saves and opens the next category**, Esc cancels; sums work
      (`100000+50000`); something that isn't an amount stays in the field,
      outlined, and nothing is saved. Emptying it assigns nothing. Clicking
      an arrow mid-typing saves it in the period it was typed in. Typing
      replaces everything the category has anywhere in the period (after
      a switch between months and pay periods, amounts can sit mid-period),
      and ⌘Z puts each back on its own day.
    - **The budget begins in the period the first amount is assigned to**,
      and that day (and the budget's currency) is saved then, so neither
      moves on its own later: assigning to an earlier period adds money,
      it doesn't pull in that period's spending. Spending before the start
      counts against no category. From then on a category that spends with
      nothing assigned goes below zero (the money is gone either way), and
      "₮X from before" shows under Left when the period began with a
      balance.
    - **Starting partway through a period offers the next one** (owner's
      call, 2026-09-30, option A of three; first asked in words the owner
      called confusing). When the first period is already under way and
      categories with nothing assigned have spent, a gold note says "You're
      starting partway through this period: ₮295,090.50 was already spent
      in 7 categories with nothing assigned, and it counts against them."
      with **Start the budget on 10.01 instead** (moves what was assigned
      to the next period, one ⌘Z) and **Keep it as it is**. Rejected:
      counting all of the period with no note (B), and counting only from
      the day the first amount was typed (C), which overstates what's left.
    - The top line reads "₮X not assigned to a category yet", "₮X more
      assigned than you have" (coral), "Cards owe ₮X more than you have in
      cash and bank" (coral, when nothing is assigned and cards alone put
      it below zero), or "Everything is assigned to a category". Its
      tooltip shows the sum with real numbers. Amounts assigned for a later
      period count against it now: that money is spoken for.
    - **"Not categorized" holds no money** (owner's call, option A of two):
      imported rows waiting there count straight in the top line, and a
      gold line under it says "12 rows not categorized (−₮84,300), counted
      in the line above · show them". Rejected: its own line pinned first.
    - **Mortgages and student loans** (their Savings marks) are left out of
      the money: they're paid over years. **Their payments come out of a
      category** (owner's call, option A of three): the loan's menu has
      "Payments come out of ▸ Housing", and a transfer into the loan from
      cash, bank or a card is that category's spending. With "No category"
      the payment just lowers the money not assigned. Rejected: only
      saying on the page what was paid (B), and counting the loans like
      cards (C). Other loans count like cards. Each currency is
      counted on its own (rule 28).
    - Spent opens the category's rows for that period in All accounts (the
      chip names the period). The usage ("42 rows · last 09.12") moved to
      the top of the category's ⋯ menu, where keep, merge and archive are,
      and opens every row (the bottom of Edit since rule 29). Income lines show what came in that period.
    - A merge moves the amounts with the rows; deleting a category, merging
      it into an income one, or changing it to income gives its money back,
      and the toast says so with the amount ("₮150,000 assigned to Dining
      out goes back to not assigned"). An archived category keeps its
      balance, shown in the archived list. A pay period that no longer is
      one (the schedule changed) resets to today's.
    - **The page is as wide as the window** (owner's correction,
      2026-10-01: "It only takes up 2/3's of the page"), like an account's
      register, with every other row tinted so the eye can follow a name
      across to its amounts. Rejected: a column capped at 820 px.
    - **Left for later** (from the reviews): "same as last period" for one
      category or all (every payday otherwise means typing each again); a
      line summing what's overspent ("₮X over in 3 categories comes out of
      next period"); pay that lands a day or two early counted in the
      period it's for; a Spent click showing loan payments (they aren't
      filed under the category); moving money out of an archived category.

27. **Plans: what a category is for** (owner's types, 2026-09-30; built
    2026-10-01; two types instead of four, owner 2026-10-03). A spending
    category can have a plan, which decides how much it should be assigned
    each period. A category with no plan works exactly as before.
    - **One question: "Is there a due date?"** (owner, 2026-10-04). The
      panel asked "When will the money be spent?" with No plan · Any time
      · On a date, and the owner put a finger on it: "Any time: what is
      that? It's going to be spent some time." The question only existed
      to name two code paths. Asked the way a person would, it's one
      yes-or-no: **No** means a set amount each month or pay period
      (groceries, car repairs); **Yes** means an amount by a date (rent,
      СӨХ, insurance, a birthday). "No plan" is no longer a button: an
      empty amount is no plan, a default rather than a choice. The two
      types below stay as the code's names for the two answers. (The
      2026-10-03 wordings, "Money goes out" and then "When will the money
      be spent?" with tooltips on each choice, are superseded.) After a
      budget expert walked their own scenarios through: groceries, car
      repairs, a birthday, the water bill, an annual subscription, a VPN
      bought every two or three years, quarterly garbage). The four kinds
      of 2026-10-01 were Spend through the month, Save up spend any time,
      Due on a date and Goal; Spend and Save up came to the same number
      every period, and Due on a date (once) and Goal asked the same two
      things and differed only in what a missed part did. *Rejected:*
      keeping Save up with the cap as its one difference; a step-by-step
      wizard when a category is made (groceries is one number, and
      everything about a category is in Edit; the panel's first line is
      the wizard's one question).
    - **The panel is designed as one thing, not a row of fields** (owner,
      2026-10-04: "it looks like we just have all the features shoved on
      a page"; a design committee of four agents, `ui-designer`,
      `ux-writer`, `interaction-designer` and `first-time-user`, walked
      it, and five mockups were drawn). The name is the panel's heading,
      big and editable; Currency and Accounts sit quiet beside it with no
      labels (their values say what they are; the label is the tooltip),
      since they're set once. Then a short labelled form, label column
      on the left, one note beside the field that needs it: "Is there a
      due date? No | Yes"; No: "Set aside each month ₮[nothing set]"
      ("Leave it empty and you decide each month."), "What's left at
      month's end: Stays here | Goes back to not assigned", "Stop at
      ₮[no limit]" ("Once it holds this much, it stops asking."); Yes:
      "Amount due", "Due [date] [How often: Once · Every month … Every 3
      years]", "Paid from [No account]" ("Shows in TDB Checking's
      forecast on 01.10; you confirm it when it's paid."), and "Set aside
      each month: ₮67,500 · worked out from the date", which the app
      works out rather than asks for. Under the form, **"The row will
      read"** and the category's row drawn as it will look after Save,
      with its note and Assign link, in place of a loose line of text a
      first-time reader took for a fact. Content stops at 820 px so the
      form doesn't sprawl across the window. Clicking a dropdown takes
      the keys from the date field, so its calendar doesn't sit over the
      rows below. *Rejected:* the same row of controls with better words
      and alignment (mockups A and B), the three answers as a list with
      their help beside the fields (C), and three answer cards under
      "When will the money be spent?" (D), all of which still read as
      features laid out on a page. The words that went: "Up to" (now
      "Stop at", which says what it does), "optional" (now "no limit"),
      "Not scheduled" (now "No account"), "Repeats: Doesn't repeat" (now
      "How often: Once"), and the help lines and tooltips, replaced by
      one note beside the field that needs it.
      - **Any time** (groceries, car repairs): a set amount each period.
        Asks: the amount; **What's left carries over** (default) or
        **goes back to not assigned**; and, carrying over, an optional
        **Up to ₮X**. Once the category holds that much the line stops
        asking and reads "₮1,500,000 set aside"; after a repair it asks
        again. The cap counts from what the category held when the period
        began, so a repair this period is asked for from the next one.
        What's overspent carries either way (rule 26).
      - **On a date** (water on the 1st, annual insurance, quarterly СӨХ,
        a certificate every three years, a birthday in August): an amount
        by a date. Asks: the amount, **How often**, the date, and **Paid
        from**, optional (below). The note reads "₮270,000 due 01.10 ·
        ₮90,000 a month" for one that repeats and "$100 by 08.20 · $12.50
        a month" for one that doesn't.
    - **How often handles every situation, not a fixed list** (owner,
      2026-10-04; option A of two, with "tie it to a paycheck" added).
      One dropdown: Once · Every week · Every 2 weeks · Every month ·
      Every 3 months · Every year · **Every payday** (one entry per pay
      schedule, named by who pays when there are several; absent when pay
      isn't set up) · **Every…** (opens a number and a unit: days, weeks,
      months, years, so every 6 weeks, every 10 days, every 3 years all
      read the same way) · **On these dates…** (a list typed as "04.15,
      06.15, 09.15, 01.15", repeating each year, for gaps that aren't
      even: taxes, school terms; the button then says "4 dates a year").
      Every payday takes its dates from the pay schedule, with an
      optional "[2] days after payday" ("on payday" while it's 0); the
      pay schedule's weekend rule already applies, and if the schedule
      is stopped the plan keeps the one date it was made on. Every other
      repeating pattern gets a weekend rule beside its date, **On the
      day** by default, or **Before a weekend** / **After a weekend**,
      the same rule pay has. Twice a month is "On these dates: 01, 15".
      Tuition and Tsagaan Sar (amounts or dates that change each time)
      stay a once-plan that will offer "set the next" when its date
      passes (left for later). *Rejected:* the pay schedule's radio rows
      reused as they are (B): six rows for a question most answer
      "monthly", and no uneven dates. Schema v15 adds `every_days`,
      `on_dates`, `pay_schedule_id`, `days_after_pay` and `weekend` to
      `category_plans`.
    - **How a dated plan's parts are counted** (owner, 2026-10-03: "spread
      it out"). What's still missing is split over the periods left
      through the date, each part rounded up to a whole ₮ or $, the last
      part whatever is left. A thin period raises the parts after it
      instead of being asked for all at once; a period that put in more
      lowers them. With one period left the part is the rest, so a
      monthly bill still catches up at once. **It counts what was
      assigned, not what's left** (the owner's birthday: $100 by August,
      and a $20 gift bought in April is part of the $100, so $80 is there
      in August): spending the money on the thing itself isn't falling
      behind, and an amount set aside and then spent stays "set aside".
      Each repeat is counted on its own, from the plan's first period or
      from the period after the one before it was due, so a bill skipped
      and never owed isn't asked for again. What the category held when
      the plan began counts toward the first; anything beyond a whole
      bill toward the next; a minus (the last one cost more than was
      saved) is added to the next. The plan counts from the period it was
      made in, or the budget's first period if that's later; and if
      nothing was assigned in that first period (the month's money was
      already given out), from the next, so a new plan isn't "short" in
      its first weeks. Two bills due inside one period (a monthly bill
      just before a payday a weekend moved) are both asked for. Changing
      the amount, the date or how often it comes starts the count again
      from today; a cap or Paid from doesn't. *Replaced:* equal parts
      with the whole gap asked for at once (a bill), beside a goal that
      spread it: the same miss got two answers only because of the
      type's name.
    - **"₮X short" (gold) means behind: what last period asked for and
      didn't get.** A part that rose and was then kept up with isn't
      "short" again. On payday, before anything is assigned, a plan that's
      up to date says nothing after its part; once this period's part is
      in it says **"on track"** (one that repeats) or **"set aside"** (a
      one-time amount, all of it in). A one-time amount whose date has
      passed drops "a month" and asks for all that's missing, as "₮X was
      due 11.20". *Replaced:* "short" against the original equal parts
      (it stayed "short" for the rest of the plan after one thin month),
      and "on track" needing the money to still be there (the count is by
      what was assigned now).
    - **Paid from: the plan keeps its bill scheduled** (owner's pick,
      2026-10-03, A of two). The Budget page and the forecast didn't talk
      to each other: a plan's date never reached an account's forecast,
      which reads the register's scheduled rows, so garbage was set up
      twice. Choosing an account under Paid from schedules the bill there
      on its date, named by its category the way a payday with no "who
      from" is, so that account's forecast steps down on it, and it
      confirms like any scheduled row (rule 10), early or late (the water
      bill that clears on the 30th instead of the 1st). Confirming one
      schedules the next; the same ⌘Z undoes both. A scheduled bill the
      user deletes is skipped and doesn't come back, like a payday. A
      changed amount, date, repeat or account takes the still-scheduled
      bill away and schedules the new one; confirmed ones stay. One that
      doesn't repeat is scheduled once. Rows link to the category
      (`transactions.plan_category_id`), as paydays link to their
      schedule; launch, restore, a save and an undo keep the next bill
      scheduled. **A bill the plan scheduled counts on the date it was
      for** (budget review): December's water taken 11.30 is December's
      bill, not an extra one in November that would double December's
      ask; a row typed by hand on 11.30 is November's. Only rows from the
      day the plan was made are its (code review): tuition re-dated from
      01.15 to 08.20 after January's was confirmed reaches the forecast
      again. Undo of a plan change brings back the very bill it took
      away, memo and all, not a fresh one (code review). An account put
      away schedules nothing, and Edit says so in gold (budget review).
      *Rejected:* the forecast reading dated plans directly
      (B): two kinds of entry in the bill list, and a plan would still
      have had to say which account's forecast it belonged in.
      **Since 2026-10-05 Paid from is the one accounts row** of Edit (see
      "From the 2026-10-05 call" below): the bill is scheduled in the one
      account left checked there.
    - **A note under the category's name** says the plan (owner's pick,
      option A of three, 2026-10-01): "₮900,000 a month", "₮100,000 a
      month · up to ₮1,500,000", "₮1,500,000 set aside", "₮270,000 due
      01.10 · ₮90,000 a month · on track", "$100 by 08.20 · $12.50 a
      month"; in the last period before the date the part is the rest,
      "₮202,500 this month" (budget review: "a month" wasn't one). The
      three columns stay as they are. Rejected: a fourth Planned column
      before Assigned (B), empty for most categories; and the list split
      into a section per kind with its own columns (C), which breaks the
      one alphabetical list the entry row's menu also shows.
    - **Getting the amounts into Assigned** (owner's pick, option A of
      three): a button under the top line, **"Assign what's planned ·
      ₮1,462,500 in 4 categories"**, assigns every plan's amount that isn't
      assigned yet this period, with one toast and one ⌘Z; and each line's
      note ends with its own **"Assign ₮200,000"**, quiet like typing.
      Both top a line up to what its plan wants and never lower one, and
      both name what gets added (a line with ₮500,000 of ₮900,000 says
      "Assign ₮400,000"). When
      the plans want more than there is, the button still works: a coral
      "₮262,500 more than you have left to assign" says so beside it first, and
      the top line turns coral after (warn, don't block). Rejected: filled
      in on their own when a period begins (B), since "not assigned" would
      drop with nobody having done anything; and per line only (C).
      This replaces the "same as last period" idea from rule 26's reviews.
    - **A dated plan that's behind asks for its raised part**, not the
      whole gap (above). A period where more than the part went in lowers
      the next one's.
    - **Clicking the note opens the plan**; so does **Plan…** in the
      category's ⋯ menu, the only way in for a category without one
      (since rule 29 the plan is part of Edit, as its Type). The
      plan opens under the row, which grows like a register row (rule 12):
      the one question, "Is there a due date?",
      one line saying what the chosen one does, then its fields, and a line showing what the note will say
      before it's saved ("₮2,000,000 due 2027.01.15 · ₮400,000 a month").
      Enter or Save keeps it, Esc cancels, a missing amount or date is
      outlined. Saving is quiet (the note is the
      confirmation); **Remove plan** toasts with Undo. A plan opened low
      in the list scrolls into view.
    - **A date typed without a year** is the next such day ("03.15" in
      October is next March); for a bill that repeats, its next time
      round ("10.10" typed on 10.15 for a monthly bill is 11.10). A year
      more than a hundred ahead isn't taken as a date.
    - **Changing or removing a plan that didn't carry over** brings back
      what earlier periods returned (nothing is stored; the emptying is
      worked out from the plan). The panel says so in gold before Save,
      and the toast after: "₮440,000 that went back returns to Groceries,
      so not assigned goes down by that much" (warn, don't block).
    - Parts are rounded up to a whole ₮ or $; the last part is whatever is
      left. With the budget by pay period the note reads "each pay period"
      and a dated plan is split into pay periods.
    - A category that doesn't carry over is emptied by the periods as
      Settings has them now: switching between month and pay period
      re-cuts past periods, so what went back can shift a little.
    - Schema v11 (`category_plans`, one row per category); v14 adds the
      cap (`up_to_minor`), the account (`paid_from_id`) and the link from
      a scheduled row to its category (`transactions.plan_category_id`),
      and maps the four kinds to two: spend and save up become "each"
      (save up carrying over), due on a date and goal become "by date". A
      deleted category keeps its plan for undo; a merge doesn't move it.
      Starting over erases plans.
    - **Left for later** (from the reviews and the owner's scenarios):
      switching Settings between month and pay period leaves a "₮900,000
      a month" plan reading "₮900,000 each pay period", twice as much
      (dated plans re-split correctly); rows added later to a past period
      change what went back from it; tuition each semester (uneven dates
      and amounts) and Tsagaan Sar (a date that moves) want "when it's
      passed, ask for the next date" (a one-time amount keeps "was due
      11.20" under the name once its date passes); the first amount and
      the budget's start aren't one write; Paid from offers only accounts
      in the category's currency; "short" names last period's miss, not
      two in a row; a bill paid from the register or an import without
      confirming the scheduled row leaves that row to delete (it hits the
      TDB import hardest: every Paid-from bill becomes a stale overdue
      row until it's deleted; the import matching a scheduled row is a
      feature for the owner to call); a scheduled bill left unconfirmed
      past its date gets the next one scheduled beside it, as a payday
      does; late in a period a repeating bill's note still names the date
      this period saved for ("due 11.01" on 11.25) while the forecast
      shows the next; a monthly bill set up mid-month splits into two
      halves, which the preview shows.
28. **A category is in one currency and uses the accounts you leave
    checked** (owner's call, 2026-10-02). The owner's case: car insurance
    paid from a dollar account. Until here the whole budget was in one
    currency, so that plan could only be typed in tugrik and the dollar
    payment didn't count against it at all.
    - **The owner's design, in their words:** "They have to choose a
      single currency the budget category is tied to. Once they choose,
      the category has a list of accounts with that currency with all the
      boxes checked. If the user wants a specific account dedicated to
      that category, they can uncheck the accounts they don't want."
      Considered and not chosen: tying a category to a currency only (my
      recommendation; it can't dedicate an account), tying it to one
      account (breaks whenever the money leaves by another route), and a
      category holding both currencies at once.
    - **A pool per currency.** The top of the page has one "not assigned"
      line for each currency there are accounts or categories in (the
      budget's first currency first), each with its own "Assign what's
      planned" and its own not-categorized rows. Tugrik and dollars are
      never added together and no rate is used. Moving money between the
      pools is a real transfer between accounts.
    - **Choosing the currency.** With accounts in both, a new spending
      category takes ₮ or $ beside Spending / Income (the budget's first
      currency to begin with), and one made from the entry row takes the
      currency of the account the row is in. With accounts in one
      currency there's nothing to choose. Income categories aren't tied.
    - **Currency and accounts…** in the category's ⋯ menu ("Accounts…"
      with one currency) opens a panel under the row (part of Edit since
      rule 29): the currency, then
      "Accounts this category uses" over every open account in it that
      counts as money (cash, bank and cards; not mortgages or student
      loans), each with a checkbox and its balance (a card's as a minus),
      all checked to begin with. **Cards are in the list** (owner's
      correction, 2026-10-02: "If they plan to pay with the visa, you
      should let them. It's a separate account."). I had taken them out
      after the budget review, because a category limited to a card always
      read as short; instead a category that uses only cards gets no
      "its accounts hold less" warning, since a card isn't where money is
      kept, and with a card and bank accounts checked only the bank
      accounts are compared.
      Only the unchecked ones are stored, so a new account is used by
      every category that uses them all; a category already narrowed
      doesn't take a new account on its own (it starts unchecked there).
      Enter or Save keeps it, Esc cancels; unchecking is quiet, ⌘Z undoes.
    - **What unchecking does** (decided along "warn, don't block"):
      - The line says where its money is kept, under its name: "only from
        Khan Savings", "only from 2 of 3 accounts".
      - It still draws on its currency's one pool, so there's one "not
        assigned" number per currency, not one per account. But it can't
        have more left than its accounts hold: then the line says so in
        coral, with the page's own word and the account's name, "₮800,000
        left here, but Khan Savings holds ₮500,000" (or "₮1,100,000 left
        in 2 categories kept in the same accounts, which hold
        ₮1,000,000"). Today's balances, so only in today's period.
      - **What it doesn't do, said in the panel with the real amounts:**
        "₮10,000,000 of what's in Khan Savings is for Emergency fund. The
        other ₮2,600,000 there can still be assigned to any category."
        The account isn't walled off: only what the category has left has
        to be there. Whether the whole account should be reserved is the
        owner's to decide.
      - A payment from an unchecked account still counts against the
        category, and the line names it in gold: "₮276,650.50 paid from
        TDB Checking, which this category doesn't use". It goes once that
        much has been moved into the paying account this period from one
        the category does use (cash taken out, checking paid back, the
        card paid), so it means "the money hasn't been moved yet". A
        purchase on an unchecked card is named the same way; a refund
        never is. Clicking opens the rows.
    - **A row in the other currency** filed under the category can't be
      counted, so the line says it's there, in gold, until it's fixed:
      "₮300,000 in 1 row isn't counted here (this category is in $); it
      came out of ₮ not assigned". Clicking opens the category's rows.
    - **Changing a category's currency later** is allowed. Its amounts
      and its plan were in the old currency, so they go: the panel says
      so in gold before Save ("Changing the currency takes back $120.00
      assigned to it"), the toast says it after, and one ⌘Z brings all
      of it back. **Merging into a category in the other currency** moves
      the rows but not the amounts, which go back to not assigned, and
      the toast says so (the budget review: ₮900,000 became $900,000).
    - **Income shows what came in in each currency**, one line each, so
      pay in dollars doesn't read as ₮0.00.
    - **In its new currency a category counts from the period the change
      was made in** (code review): the dollar payments filed under it
      before were never counted against it, and counting them all at once
      would start it off far below zero.
    - **Existing ledgers:** with amounts assigned, every category takes
      the currency the budget began in. With none yet, each takes the
      currency most of its own rows are in, or the one most open accounts
      are in. Schema
      v12 (`category_accounts_off`; a category's currency is its row's
      existing `currency` column).
    - **Left for later:** the entry row's category menu doesn't mark or
      sort categories by currency (the Budget page names the row after);
      a loan's "payments come out of" category must be in the loan's
      currency to count; two categories narrowed to overlapping but
      different accounts aren't checked against each other; clicking the
      "paid from" note opens all the category's rows for the period, not
      only that account's.

29. **A category has one Edit, and its menu is Edit and Delete** (owner's
    correction, 2026-10-02: "I like the information on the budget
    categories, but I don't like how it's executed. First, there are too
    many menus"). Before, a category had a click-to-rename name, a menu of
    up to nine items, a plan panel and a currency-and-accounts panel.
    - **Right-click a row (or ⋯): Edit, Delete…** and nothing else.
    - **Double-click a row: Edit**, as a register row opens (rule 12). A
      single click on the name does nothing now; Assigned, Spent and the
      notes under the name keep their own clicks.
    - **Edit opens under the row and holds everything**: Name (selected,
      so typing renames); Spending or Income; for spending, **Type** (No
      plan, or one of rule 27's four, with its fields and the line saying
      what it comes to), Currency (with accounts in both) and "Accounts
      this category uses" (rule 28); for income, Payday or not, and Pay…
      (rule 24). At the bottom: how much it's used ("42 rows · last 09.12
      · show them"), Archive, Cancel, Save. Enter saves, Esc cancels.
    - **Esc closes Edit, and so does a second double-click on its row**
      (owner's correction, same day). Esc works wherever the last click
      was: on a choice in the panel, or on the page outside it. What was
      typed and not saved is dropped, as Cancel does.
    - **Currency is a dropdown** (owner's correction, same day: "I want
      to support all the currencies, so the way you're laying out the
      currencies won't work"), labelled Currency, in Edit and in Add
      category. It lists the currencies there are accounts in. Rejected:
      a button for each currency (it only fits two). Add account still
      has the two buttons; it changes when more currencies come.
    - **"Accounts this category uses" is a dropdown of checkboxes**
      (owner's correction, same day), beside Currency. Its button says
      "All accounts", the one account's name, "2 of 4 accounts" or "No
      accounts"; the list shows each account with its checkbox and
      balance and stays open while they're checked and unchecked. Esc or
      Enter closes an open dropdown first, then acts on Edit. Rejected:
      the checklist laid out in the panel (it grew with every account).
    - **One Save, one ⌘Z.** A single change is said and undone as it was
      before (a rename's toast, a plan saved quietly). Several at once are
      written together and undone together, with one toast ("Changes to
      Groceries").
    - **"No plan" is a Type**, replacing the Remove plan button.
    - **The plan's note and the lines about its accounts open the same
      Edit**; from the note the cursor starts in the plan's amount.
    - **What a change will take is said before Save**, in gold (rule 21's
      "warn, don't block"): a change of currency takes back what's
      assigned and removes the plan (the Type goes back to No plan, and a
      new one can be picked in the same Save); made income, what it has
      left goes back to not assigned.
    - **Archive is in Edit**, since the menu is only Edit and Delete.
    - **From the reviews** (2026-10-02): Currency comes before Type,
      whose amount is in it, and a change of currency keeps the type,
      date and repeat and empties only the amount; No plan picked over a
      plan that didn't carry over says in gold what returns to the
      category; the sentence under Payday follows the choice; Archive
      sits by the usage line, apart from Cancel and Save; the cursor is
      put in Edit when it opens (the screen held the keys, so Esc and
      Enter did nothing until a field was clicked); pay set up from Pay…
      while Edit is open isn't undone by Save.
    - **Left for later:** ~~Add category opening this same Edit~~ (done
      2026-10-05, see "From the 2026-10-05 call" below); a rename
      that becomes a merge closes Edit first, so cancelling the merge
      drops the other changes typed with it; opening another row's Edit,
      or Archive, drops what was typed without a word; a plan typed in a
      new currency shows no line saying what it comes to until it's
      saved; archiving a category that still holds money doesn't name the
      amount.
    - Rejected: keeping the click-to-rename name beside Edit (two ways to
      do one thing, and a double-click would have started a rename).

30. **There is one Income, and it's the app's own** (owner's call,
    2026-10-03). Asked what an income category was for, the answer was
    that it isn't a budget category at all: it's a label for money
    arriving, and "not assigned to a category yet" is already the place
    that says there's money needing a category. The owner: "do we even
    need a category or just a place that says we have money that needs a
    category?" This replaces the income categories of rules 22 and 24 and
    the Spending or Income and payday choices of rule 29.
    - **One built-in category, Income** ("Орлого"), made by the app. Money
      coming in that isn't a refund is filed under it. It can't be deleted
      or merged away.
    - **It's in the ledger's category dropdown** (owner: "There should
      still be an option in the ledger dropdown for income"). Picking it
      makes the amount money in, as an income category did.
    - **It's per currency** (owner: "we have to track where the money is
      and if the budget category has that account selected and is for
      that currency"). A row under Income is in the currency of the
      account it came into, and it raises that currency's "not assigned".
      Which categories can use that money is still rule 28's accounts.
    - **The Budget page has no Income list.** Under the "not assigned"
      lines, one line says the period's income, each currency on its own
      ("Income: ₮2,500,000.00 · $120.00"; a click shows the rows). It
      first read "Came in: …" (owner's correction, the same day: "Why
      are you talking like a cave man. It's income"),
      and beside it what pay is set up ("Pay: ₮2,100,000 on the 25th ·
      next 10.25"), or "Pay not set up" (gold), or that the estimate wants
      updating (rule 24's nudges). A click opens that pay. With more than
      one pay, the note is about the one that wants updating, else the one
      the budget's period follows, else the one that comes next.
    - **Edit and Add category have no Spending or Income choice** and no
      payday choice. Every category the user makes is a spending one. A
      new name typed in the entry row with a `+` amount makes a spending
      category holding a refund, and the gold note says so: "new category ·
      money in counts as a refund to it; for pay, pick Income". No
      category of the user's can be called Income or Орлого; typing either
      as a new name means Income.
    - **Pay is filed under Income.** The pay setup no longer asks which
      category. Settings names a pay by its payee, or "Income".
    - **What ends a forecast** (owner: "The forecast can still track
      hand-typed income if needed"): a payday from pay that was set up.
      Income typed by hand ends it only when no pay is set up anywhere;
      once any is, it's money in that lifts the line, in every account.
      There is no payday mark any more. First built as "when no set-up
      payday is ahead in this account"; both reviews found that an
      allowance then ended the forecast before the rent after it, in an
      account pay doesn't come into and on the morning a paycheck is late
      (the case rule 24 fixed).
    - **From the reviews** (2026-10-03): saving pay takes over income
      scheduled by hand only when it's the same pay (the same payer, or
      with none named the same amount) and the toast says it did; before,
      it would have taken an allowance near the first payday. The pay
      setup's "your last paychecks" counts only income from the payer
      typed, and shows nothing with none. A payday with no payer is
      named by its category in the user's language, not stored as
      "Income". Merging into Income sends the category's assigned money
      back to not assigned and says so. Income can't be renamed, archived
      or given a budget amount or plan. The New ledger dialog doesn't
      count Income among "your categories".
    - **A category can still be merged into Income** (Delete…, or a rename
      onto its name): the fix for one made for income by mistake. The
      dialog says in gold that its rows will count as money in.
    - **The upgrade (schema v13)** turns every income category into
      Income: their rows and pay move to it and the old names go (owner:
      "I'm not using this in production. Stop worrying about the data").
    - Rejected: keeping income categories off the Budget page, managed
      somewhere smaller (an element without much purpose); and, earlier
      the same day, moving the Spending or Income choice to a small line
      at the bottom of Edit.
    - Left as it was: imported money in still lands in "Not categorized",
      so the Income line doesn't count it until it's filed under Income (asked
      of the owner: should the line name it?). Telling salary from other
      income is by payee only.

### From the 2026-10-05 call with Cynthia G. Loveland (owner's notes)

The owner went through the Budget page with Cynthia (see "Credits") and
brought back six notes. Four are built on the `budget-page-layout` branch;
the rest are open, below.

- **Add category opens Edit under the new row** (her question: "Why don't I
  see the budget wizard when I first create the budget category?"). Typing a
  name and pressing Enter makes the category and opens its Edit at once, the
  cursor in the amount, so the panel's one question is asked when it
  matters. The add box closes (one thing open at a time, rule 6); a name
  that's taken keeps the box with the name selected; a name that's an
  archived category's brings that one back and opens it. This closes rule
  29's "Add category opening this same Edit". There is still no wizard
  (rule 27): Edit is the whole of it.
- **One account control, "Paid from"** (her question: "Why are there two
  account selectors in the budget creation wizard? Just have one."). The
  quiet "All accounts" dropdown beside the name (rule 28's "Accounts this
  category uses") and the dated plan's "Paid from" dropdown (rule 27) were
  one idea twice: where the category's money is. Now there's one row,
  **Paid from**, under both answers to "Is there a due date?": the same
  dropdown of checkboxes over the accounts in the category's currency, all
  checked to begin with (rule 28's meaning and warnings stand). For a dated
  plan **the bill is scheduled in the one account left checked**; with
  several checked, or none, the note beside it reads "Leave one account
  checked and the bill shows in its forecast" and nothing is scheduled.
  Opening a plan saved with a Paid from account shows that account alone
  checked. Rejected: two controls with clearer labels (the labels weren't
  the problem), and a single-pick dropdown in the dated form only (an
  emergency fund kept in one savings account has no date and still needs
  the row).
- **The forecast looks as far as you say** (her note: "We should be able to
  change the date range that it covers"). The small title above the
  forecast's headline ("Until your 10.10 paycheck", "Next 30 days") is a
  dropdown: the pay period as before (named by the paycheck's date, and
  offered when a payday ends this account's forecast), Next 30 days, Next
  60 days, Next 90 days, Next 6 months, Next year. One choice for every
  account, kept in the ledger (`forecast.span`), changed quietly like the
  Budget page's period (no toast, no undo). Only the next payday of a pay
  schedule and the next bill of a plan are ever scheduled, so a longer
  forecast **projects the ones after**: paydays from the pay schedule (its
  dates and amounts, weekend rule included), bills from the plan's How
  often, each drawn as a copy of the scheduled row, so a click opens that
  row. Rows scheduled by hand are what they are. To a chosen date,
  everything through it counts, the paycheck is a step like any other, and
  the end is just where it stops looking (no closing paycheck line). Through
  the pay period nothing changes.
- **A coral dot beside an account that will run out** (her note: an alert
  when "the account balance drops to zero or below", as "a red badge for
  that account under the ledger heading, and/or red clickable text above the
  forecast pane"). The sidebar's account tile gets a 7 px coral dot after
  its name whenever that account's forecast goes below zero, with the
  header's own warning as its tooltip ("Runs out on 10.15 · up to ₮X
  short"); clicking the tile opens the account, whose headline is already
  coral. An account already below zero shows its balance in coral there
  instead, as before. Cards never (owing isn't a warning, rule 2).
  **The owner's call on her "red clickable text above the forecast pane"
  (2026-10-05):** it's the account's own forecast pane, and "if at any
  point in the paychecks tracked for that account, the balance drops to or
  below zero, we need to let the user know." So the app looks **a year of
  paychecks ahead** for every account, whatever span is on screen (the same
  projection the spans use). When the balance goes to zero or below past
  what the forecast shows, a coral line sits above the "Forecast" title:
  "Past 10.10: runs out on 11.20 · up to ₮1,107,750 short"; clicking it
  picks the shortest span that reaches that day, where the headline then
  says it. Within the view the headline already says it, so the line isn't
  repeated. The sidebar's dot uses the same year's look-ahead. **To zero or
  below:** landing exactly on zero now counts as short ("Runs out on
  11.20", with no "short" amount), where before only below zero did.

**Open, for the owner to call:**

- **A Spending / Income tab on the Budget page, with the paychecks on
  Income** (her first note: pay tracked "in a highly visible place like the
  budget income tab, not the settings menu"; several sources, in several
  currencies if need be). The app already keeps several pay schedules, each
  in its account's currency (rule 24), listed in Settings → Budget; rule 30
  put one Income line on the Budget page in their place.
- **How often as a recurrence picker like Outlook's** (her note). Rule 27's
  dropdown covers every interval and fixed dates; what Outlook adds is
  weekday patterns ("the last Friday of every month", "every Monday") and
  an end ("until 2029.03", "after 36 times").

### The smallest window (owner, 2026-10-01)

The owner's correction: "We seem to be letting the app collapse farther than
it should." An account page ran out of room at the old 1200-wide minimum
(the header's key, the Import button, the payee column).

- **The window stops at 1360 × 760**, where the header's key sits whole
  beside the forecast and the payee column can be read. On a screen smaller
  than that the window gets what the screen has.
- **Where a window can still be smaller** (such a screen, or Windows and
  Linux until their windows stop too), the whole app is drawn at 1360 × 760
  and shrunk to fit (`FitWindow`). Nothing is cut off or striped.
- **The register's Category, Amount and Balance columns are narrower** (190,
  156, 156; were 220, 170, 170), so the payee has the room.
- **The sidebar's sections scroll** when the accounts outgrow the window;
  Settings and Net worth stay at the bottom.
- Rejected: laying each page out again for narrow windows (the phone apps
  are their own design, ADR 0005).

### Language: English and Mongolian (owner, 2026-09-30)

Before beta the owner asked for a Mongolian option. The choices:

- **Where it's picked: Settings → Language**, under Appearance and working the
  same way: "Same as this Mac" (or Windows), English, Монгол. "Same as this Mac"
  opens in Mongolian when Mongolian comes before English in the Mac's languages;
  any other language gets English. Kept per computer in a small file beside the
  ledger, like the appearance. No toast; ⌘Z switches back. *Rejected:* always
  opening in Mongolian whatever the Mac says; asking at first launch.
- **Who writes it: drafted here, checked by a native speaker before beta.** The
  words follow what Mongolian banks show (pending is "Хүлээгдэж буй"); the shared
  terms are in [the glossary](../l10n-glossary.md), and a review sheet lists every
  phrase with where it appears. *Rejected:* shipping the draft unchecked; waiting
  for an outside translation.
- **Dates: "9-р сарын 30"** inside sentences and lists ("2026 оны 9-р сарын 30"
  with the year); the calendar's title reads "2026 оны 9-р сар". Rows and the
  chart keep 09.30 and 2026.09.30 in both languages. *Rejected:* 2026.09.30
  everywhere; leaving dates as they are.
- Amounts, ₮ and shortcuts are the same in both languages. Payee and category
  names are the user's own and are never translated.
- From the budget review: the working balance is **"Үлдэгдэл"**, never "Боломжит"
  (that's the bank's available balance, the figure the app tells people not to
  type); confirming a scheduled row is **"Бүртгэх"**, so it can't be mistaken for
  cleared ("Баталгаажсан"); the transfer category is **"Данс хооронд"**, since
  banks call any payment to a person шилжүүлэг; the lowest point reads **"Доод
  үлдэгдэл"**; cards and loans group as **"Карт, зээл"**.
- The app's own names (opening balances, adjustments) follow the language; a
  new account left unnamed is saved as "New account" or "Шинэ данс", whichever
  is showing, and stays that way until renamed.

### Import: the bank file's own columns (owner, 2026-09-30)

Mongolian banks don't export OFX or QFX, so import reads whatever file the bank gives
(TDB's `.xls`, `.xlsx`, CSV) and the person says what each column holds. The owner's
two assumptions: files are tables, and a person keeps using the same export for an
account. Design in [ADR 0002](0002-tdb-import-format.md), "Any bank's file".

- **Option A, file first (chosen).** The window shows the file's own columns and its
  first rows, with a choice over each column: Date, Amount (+ in, − out), Money in,
  Money out, Payee, Memo, Bank's balance, Not used. The file's name for a column sits
  under the choice. Rows that won't come in (headings, totals, blank lines) show
  dimmed. *Rejected, option B:* the app's fields listed, each with a menu of the
  file's columns. It hides the data behind menus, so you can't see what you're matching.
- **The app guesses first.** Each column's choice starts at the app's best guess, and
  the bank's running balance proves the amounts are read right. A date like 03.04
  that reads both ways gets two choices, each showing the date it would make. One amount column
  gets a choice of which sign is money out.
- **Remembered per account.** Confirming saves the columns for that account. A later
  file of the same layout opens straight on the rows with "Read with the columns you
  set for this account last time" and Change columns. The open dialog offers the
  file type used last on that account first.
- **One window: columns above, rows below.** The summary reads "63 new rows · 12 match
  rows you typed, which become cleared · 4 already in the ledger · 3 rows with no
  date or amount left out". Each row is tagged New, Matches (the typed row's payee
  and date) or Already in. Enter or **Import 63 rows** writes it; a file with nothing
  new says so in place of the button.
- **Warn, don't block.** If the bank's balance doesn't add up, a big coral line says
  which row and both numbers, and the import still goes ahead on a click. A second line
  compares the cleared balance after the import with the file's last balance.
- **Where it starts:** Import… beside Reconcile in the account header (both are about
  matching the bank). ⌘Z undoes the whole import as one action. The toast names the
  rows, the typed rows now cleared, and "Not categorized" when it was used.
- **From the reviews (2026-09-30):** each row's tag can be clicked. A match becomes
  its own row, then Left out; a new row is Left out and back. When the new rows fall on
  days this account already has imported rows, a big coral line names the dates and the
  count, with **Leave the new rows out**. Typed rows in the file's dates that nothing
  matched are listed in gold ("…aren't in this file: Номин ₮12,000.00 on 09.14"),
  since the bank never had them or has them at another amount. The cleared-balance line
  gives the gap. Lines without a date (headings, totals) are counted quietly; a row with a
  date but no readable amount is named in coral. The button says what happens: "Import
  63 rows · clear 12". Columns saved from a file whose balance didn't add up are shown
  again next time, not skipped.
- **Rows before the opening balance (owner, 2026-09-30, option a):** a big coral
  line with the numbers ("3 rows are dated before this account's opening balance
  (₮1,023,000.00 on 2026.09.16), which already counts them"), and by default **Move
  the opening balance to 2026.09.09 at ₮1,000,000.00**: the day before the file, less
  what its rows add, so today's balance doesn't change. "Leave it (those rows count
  twice)" is the other choice; ⌘Z undoes either. A reconciled opening balance stays,
  with Leave those rows out. *Rejected (b):* importing only rows after it by default.
- **A match's date (owner, 2026-09-30, option a):** the typed date stays unless the
  bank's is in another month; then it takes the bank's, so the month's reconcile
  matches the statement. The preview says so ("dated 10.02, the bank's"). *Rejected:*
  always the bank's date (b); always the typed one (c).
- **Categories:** each new row gets the income or spending category last used with its
  payee on that account (never another account, so an own-name payee can't turn rows
  into transfers); otherwise **Not categorized** (Ангилаагүй), an ordinary category the app
  makes in the language showing, which the person can rename or delete. It isn't
  called "Unassigned": in an envelope budget that means money waiting for a job.

### Every currency (owner, 2026-10-02)

"I want to support all the currencies." The list, where it comes from and how
each is shown is in [currencies.md](../currencies.md): 155 ISO currencies, each
with its own decimals (yen has none, a Kuwaiti dinar three), and the symbol its
own people write (`$` for a Canadian dollar too, `¥` for the yuan, `kr`, `zł`;
and **every currency has one** (owner: "every currency should have a symbol"):
where the usual source has none it's the sign or abbreviation in common use,
`฿`, `₸`, `KD`, and a small bundled font draws the 13 signs the app's fonts
lacked). Two that share a symbol are told
apart only while a ledger holds both: then the Canadian reads `CA$`. Add account picks from a dropdown of all
of them with a search; a category's dropdown lists the currencies there are
accounts in. **Every row of the list reads the same way** (owner's correction:
"you have the three digit abbreviation in the wrong place on some of these"):
the symbol in a column at the start, empty for a currency with none of its own,
then the name, then the code at the end. The code never stands in the symbol's
place there. **The symbol in that column is the currency's real one** (owner's
correction: "I think the symbols aren't right now on the left side", of `CA$`
and `CN¥` standing where `$` and `¥` belong, and of most rows having none).
Tried and rejected on the way: a made-up symbol no other currency shares
(`CA$` always), and dropping symbols made of letters (`R`, `zł`). The list is
tugrik and dollars, then by name. The owner was asked how two `$` currencies should read and whether
yen shows no decimals, and said to go ahead; both are as above until they say
otherwise. What follows about tugrik and dollars holds for any pair.

### Tugrik and dollars (owner, 2026-09-30)

The owner asked that accounts can be made in MNT (₮) or USD ($). ROADMAP E had
already decided the rest: totals shown per currency and never converted, and both
sides of a transfer between currencies. Built on that:

- **The sidebar shows whole amounts, cents included** (owner, 2026-09-30: "I'd prefer
  to have the whole amount here"): each account's balance and net worth read
  ₮4,289,291.00 and $9.00. *Rejected:* rounding to whole units there.
- **Spelled "tugrik" in English** (owner, 2026-09-30: plain English
  letters). *Rejected:* "tögrög".
- **Chosen when the account is made:** Currency, "₮ Tugrik" or "$ Dollar", under
  Type (owner, 2026-10-03: the label read "Kind"; the word is "Type"). It defaults to the currency most accounts are in (₮ for a first account, not
  whichever account is on screen), a default rather than a required choice. The hint
  says it can't be changed later yet; whether to add that is with the owner.
- **An account's money is in its symbol everywhere:** register, header, forecast,
  reconcile, pay, import, the sidebar, toasts. In All accounts each row shows its own.
- **Never added across currencies:** net worth is a line per currency ("₮16,228,750"
  then "$250"); a category's total reads "₮X · $Y". *Rejected (ROADMAP E):* one
  total at a typed rate.
- **A transfer between currencies takes both amounts.** Under the transfer line the
  entry row asks "Arrives in Chase:" (or "Left Chase:" for money in), and shows the
  rate once both are in ("₮3,450.00 per $1"). The row then reads "$1,000.00 there ·
  ₮3,450.00 per $1". Each currency's entries pass through a hidden "Currency
  exchange" account, so each still adds up to zero and no rate is stored.
- **Move to** offers only accounts in the same currency; a transfer between
  currencies stays where it is.
- **From the reviews:** the amount field's hint carries the symbol (₮0.00, $0.00), so
  a receipt can't slip into the wrong currency in All accounts; "Sent from Chase:"
  (not "Left", which read as a balance); the row reads "Chase: $1,000.00 · ₮3,450.00
  per $1"; an import file that names the other currency gets a big warning with a
  real row ("₮86,400 would become $86,400"); a category total words each currency
  ("₮120,000 spent · $20 refunded").
- **Savings counts one currency** for now: the one most open accounts are in (₮ on
  a tie). It names what it leaves out ("Not counted here yet: Khan USD $3,000."), the
  fund picker shows those accounts but can't pick them, and a typed month of spending
  is kept with its currency. The owner decides how Savings treats two currencies.

## Credits

- **Settings ends with a credit line** under the version (owner, 2026-10-05): "The
  Budget page was laid out with help from Cynthia G. Loveland." One line where someone
  already looks to learn about the app. Rejected: a separate About page (a page holding
  one name has nothing else to do) and the macOS About panel's credits file (macOS only,
  outside the l10n files, gone on the phones).

## Consequences

- Desktop and mobile get separate layouts over one data layer
  ([ledger-features.md §J](../ledger-features.md)). These rules are written for desktop;
  mobile must honor 1–7 and 9–16 in its own form.
- ~~A light theme is not planned.~~ The owner wants a light mode (2026-09-29); see
  "Color: being redone" above.
- The 1440×900 window shows about five transactions under the header. Collapsing the
  header on scroll is an open idea, not a decision.
- Golden screenshot tests (`app/test/goldens/`) pin these rules visually. Update them
  only for intentional changes.
