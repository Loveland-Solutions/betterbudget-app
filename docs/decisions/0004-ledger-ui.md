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
  wing crowd the edge). Made by `design/icon/app_icon.swift`. Android has the same
  tilted bee on white since 2026-10-07 (`app/tool/gen_android_icons.sh`), and its name
  under the icon is "BetterBudget"; the iPhone app still has Flutter's icon.
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

### The logo's colors (owner, 2026-10-08; built 2026-10-09 for the owner to see)

The owner: "The app is dark and drab, the coloring in the logo doesn't look right, and
neither does the icon," then drew a new logo (a navy B over a green B with a stack of
gold coins) and four Savings pictures, and said "I'm going to change the theme, logo,
and some assets to what's here." A committee (colour expert, layout, interaction,
words, a first-time reader) worked the colors out; five options were drawn on the real
screens at https://claude.ai/artifact/45WadFF4LmDnbYxTTNeT8S.

- **The app's own colors ("BetterBudget" in Settings → Appearance) are the logo's.**
  Tokens in `app/lib/ui/theme.dart` (`Palette.light`, `Palette.dark`):

  | Token | Day | Night | Role |
  | --- | --- | --- | --- |
  | ground | `#EEF2F7` | `#0D1522` | page and title bar |
  | panel, card | `#FFFFFF` | `#141D2D`, `#1A2436` | register, balance header |
  | raised | `#E4E9F1` | `#222E44` | hover, menus |
  | ink / ink2 / ink3 | `#14213A` / `#434F68` / `#5C6780` | `#ECEFF4` / `#AAB3C2` / `#96A0B3` | text |
  | side | `#13305A` | `#15335F` | sidebar: the logo's navy, a little lighter at night so its edge shows |
  | blue | `#1B5BA8` | `#6FA8F0` | what you click: links, the chosen row and tab, the forecast line (the navy's own hue, lifted) |
  | fill / onFill | `#4DB594` / `#0F2045` | `#5FC9A3` / `#0F2045` | the main filled buttons: the logo's green, navy letters |
  | green | `#0E7560` | `#7EDDBB` | money in |
  | coral | `#9E3320` | `#EE807B` | money out, below zero, errors |
  | gold | `#866100` | `#F2BD4B` | reconciled, scheduled |
  | sun, toast | `#FEBD35` | `#FEBD35` | sidebar marks and the saved popup: the coins' gold, navy text |

- **Green buttons (owner, 2026-10-08: "Why no green in the color scheme?").** The
  committee had kept green for money in alone, and the first three options came out
  navy and blue under a navy and green logo. Option 4 was built: Add, Save, Continue
  and the other main filled buttons are the logo's green with navy letters
  (`Palette.fill`, `onFill`). The row and tab you've chosen, links and the forecast
  line stay blue, so clicking a grocery row never tints it the color of pay. Money in
  is a deeper green than the button by day. At night the two are close mints, and only
  the button's shape and navy letters tell them apart (its label is "+ Add", so the
  plus doesn't): the budget review's weakest spot, with a deeper night button
  suggested. In every other color scheme the filled
  buttons keep the scheme's own click color (a scheme's green can't be told from money
  in). **This undoes "Add buttons are blue … Rejected: green (it means money in)"
  (2026-09-29)** for the app's own colors: the logo had no green then.
- **Also undone, each by this change:** the gray denim sidebar (2026-09-29) is the
  logo's navy; the felt-cream page (2026-09-29) is a cool white, because cream is the
  coins' hue and dulled the green beside it; sun yellow `#F5C518` and the toast's
  `#E8C15A` are both the coins' gold; "Budget" in the wordmark is green, not blue.
  Blue eclipse is still what a new install shows (2026-09-30): the owner was asked
  whether the new colors should take its place and had not answered when this was
  built. The owner's own Mac was set to BetterBudget, so it shows the new colors.
- **Money's colors moved for people who can't tell red from green** (expert,
  computed): the night pair before (`#5CCB8E`, `#F08A8A`) came out as one color to a
  deuteranope; the new night pair stays apart. By day the two differ in hue and
  hardly in lightness, so the plus and the minus still do real work. Coral stays warm
  ("so a shortfall doesn't read as a stop sign") and goes deeper.
- **The tab you're on is tinted like the row you've chosen** (`blueWash`, the label
  in blue), in the register's and the Budget page's tab rows; before, it was a gray
  chip.
- **Rejected:** blue for every button (options 1 and 3: no green anywhere but the
  logo); the logo's navy for Add and Save (option 2: the button is the sidebar's color,
  so only its shape says "click", and at night it must be another color anyway); green
  for everything you click (option 5: a chosen spending row turns the color of pay);
  the logo's navy as the night page (one color in shades: Midnight again); a pale
  sidebar; a green-white page (the page would carry money in's hue).
- **Asked with the canvas and not answered when this was built:** whether a scheduled
  row stops being gold (gray dashes and a blue Confirm, keeping gold for reconciled
  rows and the saved popup: with coins in the logo a first-time reader took gold on a
  row to mean "money I have"); whether the new colors replace Blue eclipse as the
  default, with the phone following its own day and night setting.
- **Logo.** The sidebar shows the logo drawn for dark backgrounds, as before
  (2026-09-30): the first B and "Better" near-white `#F7F9FC`, the second B and
  "Budget" the lighter green `#5FC9A3`, the coins as drawn; 40 px beside the 22 px
  word. The owner kept the existing "BetterBudget" word, recolored. The bee is gone.
- **Art.** The owner converted the logo and the four Savings pictures to vectors
  (`assets/logo/Images/*_Light_Mode.svg`). `assets/logo/prepared/prepare.py` makes the
  app's files from them: cropped, one navy and one green, a night copy of each, and
  what the app shows written into `app/assets/brand/`. The owner took "3-6 MONTHS" and
  the "$" out of pictures 3 and 4 themselves, so the "$" came off the Safety net coin
  and "DEBT" off the ball as well (words in a picture can't be translated, and "$"
  says dollars in a tugrik ledger). The Savings pictures are on the Savings page since
  2026-10-09, one to a step ("Four Savings steps" below).
- **App icon.** The logo upright on a white tile, on Android
  (`app/tool/gen_android_icons.sh`), and until 2026-10-09 on the Mac. This
  replaces the bee tilted 45° (2026-09-29). The iPhone and Windows builds still have
  Flutter's icon. **On the Mac it is the logo's night form on a navy tile** (owner,
  2026-10-09: "Let's redo the main app icon… Make a nice one with the new icon"):
  the sidebar's navy, lit a little from above, with the white B, the green B and
  the coins, so the subject stays light when macOS's dark style turns tiles
  charcoal (`design/icon/app_icon.py`). Drawn beside it and not chosen: the same
  logo on a soft white tile. Android still has the white tile.

### Gold is an accent, and the new colors come first (owner, 2026-10-09)

Shown the real screens side by side (https://claude.ai/artifact/1xJW37g537PUgA5BRLkzvq),
the owner settled what was left of the first color scheme on the computer.

- **A new install shows the app's own colors**, not Blue eclipse (which had been the
  default since 2026-09-30). Blue eclipse and the other 99 schemes stay in Settings →
  Appearance ("let's leave them there for now"). A computer whose
  appearance was never touched changes with this; one that picked a scheme keeps it,
  and so does one where only Light or Dark was chosen (that wrote Blue eclipse down). The test screenshots are drawn
  in the app's own night colors.
- **"Gold is an accent color. Don't overuse it."** Gold is for what is done and safe:
  the reconciled diamond and the button that locks a reconcile, the saved popup, the
  sidebar's marks (and the recovery key's letters). It had also meant "not yet" and
  "heads-up", about forty places, and by day those came out brown-olive, nothing like
  the coins. Now:
  - A scheduled row is gray dashes with a gray date and a **blue Confirm**; the
    calendar's days after today are plain, and "After today · it will be scheduled"
    says the rest. **This undoes "gold: reconciled, scheduled"** (2026-09-29).
  - A heads-up with nothing wrong is quiet ink (`Mid.note`): "new category" beside
    Add, the notes on Budget, Import, Pay and setup. Where a quiet line sat beside it
    already ("on track" against "₮200,000 short"), the one to notice is in full ink.
  - A heads-up about money that could be missed and regretted is full ink, and
    heavier where it shares a line (budget review, 2026-10-09: with the gold gone
    "due 22 days ago" read the same as "next of 4 scheduled"): a late bill on its row
    and in the forecast's list, late income "not counted", a card carrying a balance
    on Savings, an import with no balance to check against. Not coral: nothing is
    short.
  - What was gold to say "click here" is blue: "Add pay", the dot on the Income tab,
    the Savings buttons still waiting for an answer. The go-ahead button of a warning
    that isn't a deletion is the green filled button.
- **Money out is ordinary ink, with its minus** (owner, 2026-10-09: "I said I wanted
  the outflow to be normal color instead of red"), in the register and the import
  preview. **This undoes "money out is red with a minus in front"** (2026-10-06); the
  minus and money in's green and plus still tell the two apart. Red (coral) is left
  for what is wrong: a balance below zero, a forecast that runs out, a category
  overspent, an error. The phone still shows it red until its own turn.
- **At night the Add button is the day's green** (`#4DB594`, was `#5FC9A3`), so it
  can't be read as money in's mint; an amount's cents in the register are at 80%, was
  60%.
- **The phone is left on dark Blue eclipse** until its own turn (owner: "Let's start
  with just the computer"); `main.dart` sets it.
- **The Savings steps are going to change** (owner, when asked where the four Savings
  pictures go: "We're going to change the steps. We'll get to that when we get to the
  budget page"). Changed on 2026-10-09: "Four Savings steps" below.

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
   account. The two-column layout is a paper-checkbook and bank-statement habit.
   **Money out is red with a minus in front; money in is green with a `+`** (owner,
   2026-10-06: "it's hard to tell if the values are negative or positive. Outflow
   should be red and have a negative symbol in front of them"). Until then money out
   was plain ink with no sign, and in a column of mostly outflows a row of money in
   was the only one marked. The red is `Mid.coral`, the same red a balance below zero
   has, so red means "below zero" in both columns; zero stays plain. It holds in every
   register (All accounts, a card, scheduled rows) and in the import's preview. (On a
   credit card the preview still showed the opposite of its register until 0.13.1: a
   purchase green with a plus, then red with a minus once imported. The budget review
   of 2026-10-07 caught it; the preview is where someone checks money in and money out
   are the right way round.) The search box takes the sign as typed: "-30000" finds
   the row. On a
   card a purchase is money out like anywhere else and a payment is money in; the
   total and the Owed column stay positive in normal ink (rule 6).
   **A credit card's own page signs its rows the same way** (owner, 2026-10-07, option
   A of three, asked because the budget review found a minus beside an Owed that goes
   up). On Golomt Visa, "Owed ₮640,200": a ₮50,000 purchase is red `−₮50,000` and Owed
   rises to ₮690,200; a ₮350,000 payment is green `+₮350,000` and Owed falls. A card
   purchase reads as a checking purchase does beside it in All accounts, and a row
   never changes sign between its own page and All accounts. *Accepted with it:* the
   Amount column is the one place on a card's page that isn't written as what's owed
   (rule 6 covers the total, the Owed column and the sidebar), so the header's
   Uncleared line counts that same purchase as ₮50,000 more owed; and red is on a
   card's page again, as the sign of money out, not as a warning. *Rejected:* **B**,
   signs that follow Owed (green `+₮50,000` for a purchase, red `−₮350,000` for a
   payment: every row adds up to Owed, but spending turns green, paying a card down
   turns red, and a row changes sign between pages); **C**, signs that follow Owed
   with colors by meaning (red `+₮50,000`, green `−₮350,000`: it adds up, but a red
   plus breaks "red has a minus"). *Not decided:* an opening balance still takes its
   sign like any row (green plus on Cash wallet, red minus on the Visa); plain ink
   with no sign was suggested and not picked up.
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
   **On a credit card every amount is what's owed, positive** (the header, the Owed
   column and the sidebar; a row's own Amount is signed as money out or in since
   2026-10-07, rule 3), as the bank shows it
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
   miss. **The popup is a card in the page's bottom-right corner** (owner, 2026-10-06,
   "Not loving the way this looks", option A of two; see "The popup is a card" below).
   **A failure has its own plain popup** (owner, 2026-10-10; #128): "Couldn't
   save: …" came in the gold popup with the error's whole text, a screen of library
   paths. Gold now means only that something was saved. Anything that didn't happen
   (a failure, a refusal, a row that can't be saved yet, a nudge such as "Save or
   discard the open row first" or "Nothing to undo") is the page's own card with
   ordinary ink, a coral edge and a coral mark before the sentence (owner,
   2026-10-21: "the color should stand out in some way"; option A of three, since
   coral's job is errors. *Rejected:* a coral card, as loud as an alarm for a
   nudge, and a light card, which stands out without saying anything is wrong). It says what
   didn't happen in one line. The technical reason waits behind **Show details**,
   which reveals it, selectable, and holds the popup until it's closed. It stays 12
   seconds instead of 6. "Couldn't undo … it changed since" has no Details, since
   the line already says all of it.
   **A row that can't be saved says why in the same popup** (owner, 2026-10-03):
   beside Add there was room for "Say how muc…" and no more. It goes away once the row
   is edited. The wording is an instruction in plain office English ("Enter the amount
   arriving in Chase", "Enter the date as 2026.09.16"), never "Say how much…", which
   the owner read as written by a child. The short notes that show while typing
   ("needs amount", "= ₮150.00", "new category") stay beside Add. Undo is bold
   (underlined until 2026-10-06; the offer is now the only bordered thing in the
   popup, so Undo no longer needs telling apart from it). **One row is open for typing at a time** (owner, 2026-10-03: Edit and a
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
    **A month without a copy off this computer is said under Net worth** (owner's
    call, 2026-10-09, of two: there, seen on every page, or only in Settings beside
    "Back up to…"). The daily copies share a disk with the ledger. Once "Back up
    to…" hasn't been used for more than 30 days, a small line in plain ink under
    the Net worth figure reads "Last backup 41 days ago", or "No backup yet" when it
    never has been (first "Last copied elsewhere 41 days ago", which the owner read
    as another machine having backed it up: "Did it actually detect that someone on
    another machine backed it up somewhere else?" It says only what this computer
    did, in the button's word) (counted from the day this
    computer first looked, so a new ledger isn't told on its first day). It opens
    Settings, where a "Backed up" line above the button says when, or "Not yet ·
    Back up to… saves a copy to another drive". Never while the ledger is stored
    in a folder, nor in setup. It is a heads-up, so no dot and no coral. The date
    is this computer's own, in a small file beside the ledger (`copied-elsewhere`),
    not in the ledger, where a restore would turn it back.
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

    **Changed 2026-10-09** (the owner said to work the open items; each was built as
    it had been recommended in STATUS, then refined by the two reviews). **The
    uncleared note goes by the statement, not by age, once an account has been
    reconciled**: a row the last statement should have had says "· not on the 09.10
    statement", since a statement that didn't have it is the reason to doubt it. By
    age it was noise for someone who reconciles monthly. "Should have had" leaves
    out a row from the statement's last 3 days (30 on a card or loan): that is a
    hold the statement was too early for. An account never reconciled still counts
    days ("not cleared for 34 days") from 14, and from 30 on a card or loan, where a
    hold from abroad sits 20 to 30 days; a row newer than the last statement says
    its age only from 45 days, for the account reconciled once and then left. A cash
    account never says it: nothing clears cash. **A late bill counts the other late
    ones**: All shows only the first scheduled row, so it reads "· due 7 days ago ·
    1 more overdue", and the count opens the Scheduled tab as "next of N scheduled"
    does ("2 overdue" read as two others). **Confirm names a row already in**
    (since 2026-10-21 the bill's row says it without Confirm: see "A bill paid
    another way" under rule 27). Confirming a late bill that was typed from the bank
    app, or imported, put it in twice. A row for it is one the
    same way, dated from 6 days before the bill to 6 days after (a week would find
    last week's weekly bill), or up to today when the bill is late, with the same
    payee; failing that, for a category's bill, a row in that category for between
    half and twice the amount. **The payee may be the bank's spelling of it** (owner,
    2026-10-09, "Fix these"): "МОБИКОМ КОРПОРАЦИ ХХК" is a bill called Mobicom, told
    by putting both in lower-case Latin letters, with c and k, kh and h, w and v, y
    and i made one, and seeing whether one holds the other (a name under four
    letters has to be the whole of it). Last, a row still in Not categorized, as
    an import leaves it, counts when it is for exactly the bill's amount. The
    surest kind wins, then one in the bill's own account, then the nearest date.
    **The line leads to its row**: clicked,
    the row it names is outlined and the list scrolls just far enough to show it;
    in the Scheduled tab, which lists no such rows, the row is drawn under the
    line. Confirm is still there (warn, don't block). A payday is not looked
    for: money in is made a pay's paycheck from its own row's Category. **The Move
    popup has Show**, which opens the account the row went to with the row chosen
    (a scheduled one in the Scheduled tab). **Not built: a `+` put in the amount
    when a payee's last row was money in.** It was on the same list, and it is a
    guess filled into a field, which the owner sent back on 2026-10-08 ("Don't
    autofill").

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
    called AI-speak). That sentence shows only while no category in use has a
    plan or an amount assigned; with a budget but no bills in this account, the
    line above already says there are none, and nothing is added (#129). Every state has the "Forecast" title. With bills, the chart names its amounts beside their points:
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
    paid every two weeks). ~~It's in the pay setup and in Settings ("Budget by: Month
    / Pay period")~~ Since 2026-10-05 it's a view on the Budget page, and each
    category has its own period (see "Two earners" below); it starts on Month. A
    pay period needs a pay schedule; with two earners, whose pay it follows is the
    choice. Every-two-weeks pay notes "26
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
    2026-09-19). **The six steps below became four on 2026-10-09** ("Four Savings
    steps"); how a step works is as written here unless that section says
    otherwise. It follows the order of the Church's *Personal Finances for
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
    - **Two dotted lines part the three columns** (owner, 2026-10-07: "It's
      hard to differentiate between the Assigned, Spent, and Left columns",
      then, shown three rebuilt rows, "I don't really like any of those.
      Can't you just put two vertical dotted lines between the columns?").
      One runs between Assigned and Spent and one between Spent and Left,
      from the headings down every row, stopping at an open Edit. The
      three headings are centred in their columns (owner, the same day:
      "Assigned, Spent, Left should be centered"); the amounts stay
      against the right so their digits line up. Nothing else about the
      row changed. Rejected: Assigned in a filled box with
      Spent underlined and Left larger (A); Assigned moved beside the name
      (B); two-line rows with the words on the row and no headings (C);
      and, with them, leaving a zero amount empty. The committee's mockups:
      <https://claude.ai/artifact/TdSp3spEoNhwLg6NxACkvb>.
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
    - **A bill paid another way** (#88, 2026-10-21). The bill confirms
      like a payday, but a payment that came in another way (typed, entered
      on the phone by someone else in the household, or imported) left the
      bill overdue until someone opened Confirm, and the forecast counted
      it twice: in the balance, and as due today. **The rule is the
      owner's:** "Electricity bills only come once per time period. Really
      any bills. So if any transaction in that category takes place, it
      should be assumed to be paying that bill. We can pop up a
      confirmation window if needed." So a money-out row in a category's
      bill (or with a line in it), in any account in its currency, pays the
      bill of its date: the nearest of the plan's dates (the rule a
      confirmed bill is counted by), or, the bill being late, any day from
      its date up to the next bill's. The first such row pays it; a later
      small one is spending. Soonest bill first, each row once. A bill
      typed by hand, with no plan, keeps the match by payee or amount.
      **Mark it paid, ask if unsure** (owner's pick, A of two; rejected:
      always asking once, a question every month for every bill). Near the
      bill (from nine tenths of it to half again over, a winter
      electricity bill), the bill is paid with no question: a row typed,
      edited or filed under the category here pays it as its own action,
      with "Mobicom bill paid. Next due 11.15." and one ⌘Z; a phone's rows
      or a bank file's pay theirs with the rows, and their popup says "1
      bill paid." and takes the ties away with its Undo. Otherwise a window
      asks, in the UX writer's words (the owner sent back "Looks paid",
      "That's this bill", "Not it", "It didn't come" and "Skip it": "I
      really hate the language you're using"): "Did this pay the Mobicom
      bill? / You paid Mobicom ₮5,000 from Golomt on 10.13. / The bill is
      ₮41,500, due 10.15." with **No, something else** (the default under
      half the bill) and **Yes, it's paid**; "Is ₮21,500 still to pay?"
      for part of it, with **Not this bill**, **No, the bill is paid** and
      **Yes, pay the rest by 10.15** (the default; the rest stays scheduled
      on the bill's date with its payee and memo); "Did this pay 2
      Цахилгаан bills?" when it is two or three bills' worth, with **Only
      one bill** and **Yes, both bills**, which skips the bills after it
      and schedules the one past them. Enter takes the default, Esc closes
      it with nothing decided. A typed row that isn't near opens the window
      at once; from the phone or a file the popup says "1 bill to check."
      with Show. Until it's answered the bill's row asks: "Paid on 10.13?
      Mobicom, −₮40,000.00, from Golomt" with **Yes** and **No**, and the
      forecast says "A bill may already be paid. It's counted until you
      say yes." with a click to it (owner: "yeah, idea"). No is kept as a
      setting (`bill.notIt.<bill>`), merged when both computers say it.
      **Not this bill** on a row taken as a bill brings that bill back to
      pay and doesn't ask about the row again. **No bill this time**
      takes Delete's place on a category's scheduled bill, which already
      skipped it: "No Mobicom bill on 10.15. Its ₮41,500 stays for the one
      due 11.15." On the Budget page **a bill there won't be asks
      nothing** and what was put aside for it counts toward the next
      (owner: "By default it's set for December, but of course, it's free
      to move if needed"): a deleted bill still tied to the plan, with no
      row that paid it, is one there won't be, and the period saves for
      the next; paid ahead, the minus is made up by the periods up to the
      next bill, a bill's worth each. Rent isn't paid in parts (owner:
      "You pay it all at once"), so part payment is for a bill shared, not
      rent. **Not in #88:** a repeat on a scheduled transfer. The owner:
      "Anything scheduled as a payment should have a category. If it
      doesn't have a category, we're not budgeting it."
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
    - **The ledger's lists offer only the row's currency** (owner's
      correction, 2026-10-06: "I don't love that USD category options are
      showing up in the dropdown on my mnt ledger"). A row's category chip,
      Categorize in its action bar and the list under Category while typing
      a row hold the spending categories in that row's currency, plus Income
      and Not categorized, which take any. A card's "payments come out of"
      list is narrowed the same way, since a payment is only counted against
      a category in the card's currency. Nothing is forbidden: a row already
      filed under a category in the other currency keeps it and its tick,
      and a name typed in full still finds it (the gold note on the Budget
      page says the row isn't counted). In All accounts the list follows
      the row's account.
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
brought back six notes; all six are built on the `budget-page-layout`
branch, the last three after the owner's calls the same day.

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
  several checked, or none, the note beside it says so with the count
  (below) and nothing is scheduled. A plan saved with a Paid from account
  (before this row, or one since archived) keeps that account while the
  checks aren't touched, and the note names it; changing the checks is
  what moves the bill. Rejected: two controls with clearer labels (the
  labels weren't
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

- **Spending and Income are tabs on the Budget page, and pay lives on
  Income** (her first note: pay tracked "in a highly visible place like the
  budget income tab, not the settings menu"; several sources, in several
  currencies if need be; owner's call, 2026-10-05, option A of three). The
  panel's top row holds two tabs drawn like the register's, Spending and
  Income; over the categories the column heads stay on that row. **Income**
  shows this period's income, each currency on its own ("Income:
  ₮2,500,000.00 · $120.00", a click shows the rows) and beside it, once
  some pay has come, how much was pay ("₮2,100,000 from pay · ₮400,000
  other"); then one striped line per pay, as Settings listed them: who from
  (or "Income"), "₮2,100,000 or more · every 2 weeks · into Cash wallet ·
  next 10.15", an estimate nudge in gold under it, and Edit; with no pay,
  "Pay not set up" in gold, or the "You said you don't have regular pay"
  line with **Ask me again**. The page's top-right button is **Add
  category** on Spending and **Add your pay** / **Add other pay** on
  Income: one button for the tab that's on. A gold dot on the Income tab
  says pay wants attention (not set up, or an estimate to update), since
  rule 30's gold note left the Spending tab with the Income line. Settings
  → Budget keeps only Budget by; its Pay list, Add pay and Ask me again
  moved here, and the no-regular-pay toast now points at the Income tab.
  Rejected: an Income section above the Spending list on one page (B), and
  the one Income line opening the pay list on a click (C), the least
  visible. Several pay schedules in several currencies were already there
  (rule 24): each is in its account's currency.

- **How often's "Every…" is "Custom…", an Outlook-like block** (her note:
  "a better recurrence selector like what Outlook uses"; owner's call,
  2026-10-05, option A of three, with the name changed from "Every…" to
  "Custom…"). The dropdown keeps its quick choices (Once, Every week, Every
  2 weeks, Every month, Every 3 months, Every year, Every payday, On these
  dates…) and reads "Custom" while the block is open. **Custom…** opens a
  block of rows in place, under the Due date it starts from: **Repeat
  every** [N] [days | weeks | months | years]; every so many weeks, **On** a
  row of weekday chips (Mo … Su; none picked means the date's own weekday);
  every so many months or years, **On** "Day of the month" or "A weekday"
  with two dropdowns, first · second · third · fourth · last and Monday …
  Sunday (picking A weekday starts from the date typed: 10.15 is the third
  Thursday); and **Ends**: Never · On a date [YYYY.MM.DD] · After [N]
  times. The first bill of a weekday pattern is the first match on or
  after the Due date (October's second Tuesday being before 10.15, the
  first is November's). Past its last bill a plan asks for nothing,
  schedules nothing, is projected no further, and its note reads
  "₮300,000 · ended 2027.01.12". Schema v16 adds `weekdays`, `nth`,
  `nth_weekday`, `end_date` and `end_count` to `category_plans`. Rejected:
  Outlook's full dialog as a popup (B), and only an Ends field added to
  the row (C). Not taken from Outlook: "every weekday", and a separate
  start date (the Due date is the start).

**From the reviews (2026-10-05, decided along the lines above):**

- **The year's look-ahead is only for accounts pay goes into** (the
  owner's "paychecks tracked for that account"). Any other account, fed by
  transfers the app can't project, gets the dot only when its forecast on
  screen goes under; before, a cash wallet with kindergarten paid from it
  wore the dot from day one, for a year of bills and no money in.
- **The dot and the coral line name the first dip, not the year's low:**
  "After 10.10: runs out on 11.20 · ₮120,000 short" is what has to be moved
  in before 11.20; the headline keeps "up to ₮X short" once the span is
  widened. "Past 10.10" became "After 10.10" (it read as the past).
- **Expected rows say so.** A payday or bill the forecast projects past the
  scheduled one reads "· expected" in the bill list, and the line under the
  headline adds "· 3 of them expected", so the count no longer disagrees
  with the Scheduled tab without saying why.
- **Paid from with several accounts checked says what that does**, in the
  warn-don't-block voice with the count: "Checked in 3 accounts, so this
  bill isn't in any forecast. Uncheck down to one to see it there." (The
  old note read as if done.)
- **Ends shows under every repeat typed as every so many**, not only in
  Custom…: "Every month, 12 times" is an installment plan (лизинг), the
  common ending plan. A pattern (weekdays, a weekday of the month) is what
  makes a plan Custom…
- **Two pays with no payer are told apart by their account** on the Income
  tab ("Income into Khan Savings").
- Left as decided: zero counting as short (the owner's words), the one-word
  "Paid from" for an emergency fund with no date, projected pay at the
  "or more" floor.
- **From the code review:** an ended plan no longer asks for bills past
  its end when several fall in one period (every week, twice, in a month);
  the Spending list stays mounted under the Income tab, so an Edit open
  there keeps what was typed through a tab switch; chosen weekdays turn
  the weekend rule off (a Saturday moved to Friday doubled Friday's bill);
  the sidebar's look-ahead is worked out once per ledger snapshot; "other"
  income never reads below zero; a v15 file's upgrade is tested.
- **The Income tab says "₮2,100,000 received of ₮4,200,000 expected this
  period"** (the owner's wording, 2026-10-05), one per currency pay is set
  up in: what the schedules expect in the period (each payday's amount, the
  "or more" floor for pay that varies) against the paydays confirmed in it.
  It replaced "from pay · other" from the first build.
- **The question says what each answer means** (owner, 2026-10-05, on the
  panel's first line: "What happens if there isn't a due date? We can spend
  throughout the month like groceries?"). Beside "Is there a due date?", No
  reads "A set amount you spend through each month, like groceries." (or
  "each pay period") and Yes "An amount to have ready by a date, like rent
  or insurance." One note beside the field that needs it, as the panel's
  rule has it. And **"What's left at month's end: Stays here | Goes back to
  not assigned" shows under No whether or not an amount is typed** (owner:
  "We never zero it out again?"): the answer is on the panel the moment No
  is picked, Stays here the default. Stop at still needs an amount.
- **Asked of the owner, in plain examples** (new ways of counting): whether
  a 6-month forecast should also take out what's budgeted for groceries,
  transport and the rest each month (today it shows pay in and rent and
  water out, nothing else, so it climbs richer than the household will
  be); and whether a new Rent plan should start with TDB Checking checked
  on its own (where the rent rows were paid from) so the bill shows in the
  forecast at once, instead of "All accounts" and no forecast until one is
  left checked.

### Two earners: each category's own period, and a view (owner, 2026-10-05)

"Jeff and Jenny are married. They both get paychecks. Can they use this
budget?" Mostly, since pay was already a list; what didn't hold was Budget by
pay period, which followed one pay for the whole budget (rule 24: "with two
earners, whose pay it follows is the choice"), and the words that assumed one
person. The owner's design, built (version 0.8.0, schema v17):

- **Budget by leaves Settings and the pay setup. It's a view on the Budget
  page:** a dropdown beside the period, "Month ▾" or a pay's name, shown once
  there's pay. The owner: "The budget screen is the only place we need to see
  it." A view, not a change to the money: no toast (⌘Z still puts the last
  view back), and switching never re-buckets anything. The choice is kept in
  the ledger as before (one pay at most). Rejected: the budget's grain as one
  global setting flipped from the page with a warning (the first draft here;
  the owner: "Not necessarily").
- **Each category says how it's budgeted** (owner: "When you create a budget
  category, you would need to tell how you want it. Once a month, or by pay
  period, and if so, for which paycheck."). A set amount (No due date) has a
  **How often** row: "Every month" (the default, so a new category isn't
  asked; rule: a default over a required choice) or "Every pay period" (·
  name, with more than one pay). It's the plan's own period: its amount is
  per it, "What's left at the period's end" happens at its ends, and its
  wording ("Set aside each pay period") follows it, not the view. A bill
  (Yes) has a due date and How often already, and divides over whatever
  periods are on screen. Stored in the plan's existing pay column; v17 sets it
  on every set amount of a ledger that budgeted by pay period, so those keep
  meaning "each pay period".
- **Seen by another period than its own, a set amount is prorated** (owner:
  "if you make a view that is from a different paycheck and they don't fall
  on the same day, you would just prorate it"). Assigned, Spent and Left need
  none of it: they're sums over the dates on screen, exact for any span.
  Only the plan's "what should be here" is: each of its own periods the span
  touches still wants its amount less what was put in before the span began,
  spread by days over the rest of that period, and the span takes its days'
  share. Shares add up to the whole over time, a period already filled asks
  for nothing more, and a span that holds all of a period's rest asks for the
  whole, exactly. A cut share reads "about": "₮600,000 each pay period · Jeff
  · about ₮280,000 this pay period"; "Assign ₮280,000" at the note's end
  assigns the share. Rejected: prorating a bill (a bill due on the 1st seen
  by fortnights is "₮300,000 this paycheck, ₮300,000 next", which the dated
  plan's parts already do; a day-share would leave them short).
- **A pay has a name** (owner: "the user should be able to name the
  paycheck"). The setup's first line, "Name", hint "Jenny, or Jeff’s job
  (optional)"; the employer stays as "From" (history is matched by it). The
  name is what the view dropdown, How often, the plan note and the Income tab
  call the pay by; unnamed, the payer, then "Income" or "Income into TDB
  Checking" with two. Still one person's words elsewhere ("Until your 10.15
  paycheck", "your last 6 paychecks"): left for a later pass.
- **One purse.** "Not assigned" is one pool per currency across every
  account, so Jenny's view counts Jeff's balance too: for a couple who pool
  money that's right, and a bill they split needs nothing (the envelope wants
  the whole; a transfer between their accounts is a move, not spending). A
  couple who truly keep separate money are two ledgers. No person entity.
- **From the budget review (2026-10-05):** money assigned from a view that
  isn't the category's own is dated into each of its own periods the span
  touches (by the plan's shares, else by days; the rows already there stay),
  so a no-carry-over category isn't handed a month's worth in one fortnight
  and the rest given back at the next payday. Inside a span, only period
  ends up to today empty anything ("₮150,000 went back to not assigned on
  10.09"). A new category's How often starts as the period on screen. A cut
  share rounds to ₮100. A stopped pay reads "Jeff (stopped)" where a
  category is still per it.
- **A share bigger than the amount says why** (owner, 2026-10-05: "fix it").
  When the category's period before was never filled and the rest of it is
  in view, the note reads "₮600,000 each pay period · Jeff · ₮600,000 still
  to put in for 10.23–11.24 · plus about ₮180,000 toward the next" instead
  of "about ₮780,000 this pay period", which read as a contradiction.
- **Stopping a pay warns and moves what was per it** (owner, 2026-10-05:
  "warn them and give them a chance to move the abandoned categories to a
  new income source"). With categories budgeted per the pay (a set amount
  each of its periods, or a bill every payday of it), Stop first shows a
  coral dialog: "2 categories are budgeted per this pay: Groceries, Housing",
  then "From now, budget them": Every month, or "Every pay period · Jenny"
  for each other pay. With exactly one other pay that's the offered answer;
  otherwise the month. A bill every payday moved to the month comes every
  month from the stopped pay's next payday (plus its days after), and the
  dialog says so. Stop goes ahead either way (warn, don't block); the toast
  reads "Pay no longer scheduled · 2 categories now Every pay period ·
  Jenny" and one ⌘Z puts the pay and every plan back. Rejected: leaving them
  on the stopped pay's rhythm, shown "(stopped)" (the first build).
- Left for later: the forecast on a shared account still runs to the first
  payday it sees and through that pay's period (rule 24's note); a bill paid
  "Every payday" is pinned to one pay.

### The top pane: the key (owner, 2026-10-05)

"Let's make this top pane prettier. It looks like a mess up there." The
Budget page's top pane was three sentences in three colours and three sizes
("$4,963,768.91 more assigned than you have" in coral, "₮4,289,291.14 not
assigned to a category yet", "2 rows not categorized (₮0.00), counted in the
line above · show them" in gold), stacked at one edge, the number a person
needs inside one of them and the sum behind a hover tooltip. The design
committee (ui-designer, ux-writer, interaction-designer, first-time-user) ran;
three mockups were drawn (`docs/mockups/budget-top-pane.html`); **the owner
picked B, "the key"**.

- **A card like an account page's header**: "You have" (cash and bank, less
  what cards owe; the old tooltip's words are its tooltip), "In categories"
  (what they hold now: assigned less spent, below zero when overspent), a
  rule, then **"Not assigned"** big: the result. The payday question ("I got
  paid ₮2,100,000, why is only ₮1,400,000 free?") answers itself. One column
  per currency, the budget's first, so two currencies are two of the same
  thing. Then the rows card. Rejected: A, the figure with a label and the
  sentences under it (the sum still a tooltip, the height jumping with each
  state); C, one block per currency with the sum as a sentence under the
  figure (prose again, two blocks fighting for width).
- **Each note sits on the row it is about**, so colour means state, not
  position: the gold "2 rows not categorized · show them" (or "−₮84,300 in 2
  rows not categorized · show them"; "(₮0.00)" and "counted in the line
  above" are gone) on You have, since they are money in accounts; the "Assign
  what's planned" chip on In categories, with "That's ₮X more than you have"
  in coral beside it when it would overdraw; the one real warning on Not
  assigned, the figure coral and a sentence that says what will happen:
  "Spend what the categories hold and the accounts go $4,963,768.91 below
  zero." (Replaced 2026-10-06 by a row of its own: see "Assigned too much".) Cards owing more than there is colours You have and says "Cards owe
  more than you have". Everything assigned is ₮0.00 and no sentence (the
  owner's rule: don't tell them what they already know).
- **"Rows not categorized" left the Budget page** (owner, 2026-10-06: "great,
  but it belongs on the ledger page, not on the budget page"). It is a job
  done in the register, so it is said there: a **Not categorized (2)** tab in
  the register's tab row, after Scheduled, on an account's page and on All
  accounts, shown only while rows wait there. A click shows just those rows;
  when the last one gets a category the tab goes and every row is back. No
  amount beside it (the rows show their own), and the Budget page's You have
  row carries no note.
- **The first-period offer is a strip in the same card**, under a rule, worded
  "₮295,090.50 was spent in 7 categories before anything was assigned. It
  counts against them this period." with its two buttons. One card, not a box
  above a card.
- **The period title is the view's dropdown** ("This month · 10.01–10.31 ⌄"
  opens Month / Jeff / Jenny), as the forecast's title is: one control. The
  separate "Month ▾" beside it, built that morning ("Two earners"), read as
  the same thing twice to a first-time reader. Without pay the title is plain.
- **⌘N on the Budget page adds a category** (Add pay on the Income tab); it
  used to jump to the Ledger and open an entry row.
- Costs: about 50px taller than the old one-line common case, and it never
  jumps with the state.

### Assigned too much: no minus beside "Not assigned" (owner, 2026-10-06)

The owner, looking at "Not assigned −$4,963,768.91" with "Spend what the
categories hold and cash and bank go $4,963,768.91 below zero." beside it:
"Does it make sense to have a negative assigned. Shouldn't it then say I
assigned more than I have?" The first answer kept the minus, because the
three rows are a sum, and only reworded the sentence. The owner: "You're
thinking like a computer. The arithmetic is right, but it's confusing to
users."

- **"Not assigned" never goes below zero.** With more assigned than there
  is, nothing is left unassigned, so it reads $0.00, in plain ink.
- **A coral row of its own, "Assigned too much", sits under it** with the
  amount, big, no minus, and only when there is one. No sentence: the label
  and the figure say it. With two currencies the figure is in the column of
  the one that is over and the other column is empty. The card is a row
  taller in that state.
- Rejected (three were sketched; the owner picked this one): $0.00 with a
  coral sentence beside it carrying the amount (the number a person needs
  inside small text, which the key was built to end); the coral amount in
  Not assigned's place with "too much" after it (the row would still be
  labeled Not assigned). Rejected first, by the owner: keeping the minus
  so the sum checks.

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
  **Rows on its own day count too (2026-10-15, version 0.34.3):** the owner typed a
  balance in setup, which dates it today, then imported the bank's last 15 days, and
  the balance came out off by today's rows: the line only caught rows dated *before*
  the balance's day. A balance typed today is what the bank showed after today's
  rows, so rows on that day are now held by it too ("dated on or before"); "Leave it"
  still covers a balance typed before a later row that day.
- **A match's date (owner, 2026-09-30, option a):** the typed date stays unless the
  bank's is in another month; then it takes the bank's, so the month's reconcile
  matches the statement. The preview says so ("dated 10.02, the bank's"). *Rejected:*
  always the bank's date (b); always the typed one (c).
- **Categories:** each new row gets the income or spending category last used with its
  payee on that account (never another account, so an own-name payee can't turn rows
  into transfers); otherwise **Not categorized** (Ангилаагүй), an ordinary category the app
  makes in the language showing, which the person can rename or delete. It isn't
  called "Unassigned": in an envelope budget that means money waiting for a job.

**Three calls on a US credit union's files (owner, 2026-10-06; detail in ADR 0002 "The
owner's calls"):**

- **The bank's own category is not brought in.** ("No, I don't want to use the bank's
  categorization.") A column named Classification or Category, or an OFX memo that
  holds nothing else, starts left out; the person can still pick it. Rejected: putting
  it in the memo, which is the field for their own notes.
- **An OFX file's one balance is shown** with its day against the cleared balance after
  the import, as the table's last balance is.
- **Rows already imported from the bank's other kind of file are caught** by day and
  amount and start left out, tagged "Already in · same day and amount"; a click brings
  one in. The owner's worry, two things at one price on one day, is answered by
  counting (one row already in answers for one row of the file) and by name.

**A new account can be answered by its bank file (owner, 2026-10-06: "Don't you think
on the account creation wizard there should be an import option that could answer the
balance question?"; picked A of three):**

- Beside **Start account** on "What's in this account today?" is **Or import a file
  from your bank** (not on a cash account: there's no file). It opens the import
  window, whose first line reads "This file starts at $412.08 on 1 June 2026 and
  ends at $1,860.75 on 5 October 2026. The account starts from it."
- **The starting balance is the file's**, dated the day before its first row: a
  table's first balance less its first row; an OFX file's one balance less every row.
  Import writes it and the rows together, and one ⌘Z takes both back to the question.
- **A file with no balance says so and asks** the same question in the window ("This
  file doesn't give a balance. What's in this account today?"); what's typed is worked
  back through the rows coming in. Left empty, the account starts at zero before them.
- *Rejected:* B, type the balance first and be offered Import after (answering a
  question the file could have); C, type it and import, the app comparing the two (the
  safest, and the most work; the window already shows the bank's figure to check
  against the banking app).
- **This changes the onboarding sequence below:** import was step 3, "optional and
  skipped by default", after every balance had been typed in step 2. It is now one of
  the two ways to answer step 2 for an account that has a file.
- **Start from** (owner, 2026-10-06: "Yes, it should default to the current budget
  period"; the `budget-expert` agent's advice). The window has a **Start from** date,
  first set to the first day of the budget period today is in (the month, or the pay
  period the Budget page is viewed by) when the file reaches back before it, else to
  the file's first row. Rows before it don't come in and aren't listed; beside the date
  it says "4,474 earlier rows in this file are left out" and a **The whole file**
  button brings them back. The line under it reads "The account starts on 1 October
  2026 at $2,140.11. The file ends at $1,860.75 on 5 October 2026.", the balance being
  the file's for that day. *Why not everything:* rows from before the budget began
  change no figure on the Budget page, a new ledger has no categories for them to
  learn, Savings looks back three months only, and 4,500 rows waiting in Not
  categorized never get done. A short start can be made longer later (importing the
  file again offers to move the opening balance back); a long one can't be made
  shorter once the session's undo is gone. *Rejected:* defaulting to the whole file.

**The Not categorized tab holds this budget period's rows** (owner, 2026-10-06: "don't
give the user all that noise that serves no purpose. The uncategorized tab's view
should default to those transactions that are uncategorized within a given budget
period."). The tab and its count are the rows waiting in the period today is in (the
month, or the pay period the Budget page is viewed by); with none in it the tab isn't
there. Older ones are still in All, and a search for "Not categorized" finds them.
*Not built:* choosing another period for the tab.

### One currency left, one account left (owner, 2026-10-07)

The owner deleted every account but one, in tugrik, added a category, and its Edit
still offered a Currency dropdown of tugrik and dollars; **Paid from** read "All
accounts" with one account to choose from ("I don't even know if this is worth
changing").

- **A new category is made in a currency there is an account in.** It used to start
  in the currency the budget began in (`budget.currency`, kept so that adding a
  dollar account can't change what amounts mean), which here was dollars with no
  dollar account left: the category came out in dollars, with no choice shown, and
  that is why its Edit offered both. Now it starts in the budget's currency only
  while an account is in it, else in the currency the accounts are in.
- **The budget is in the currency it began in only while something is in it**
  (`Budget.currencyOf`): an account, archived ones included, or a spending category.
  Once the last is gone, it is the currency the accounts are in, so the Budget page
  doesn't lead with a column for a currency nothing is in.
- **A category that really is in a currency with no account left keeps the dropdown**
  in its Edit: it is the one way to bring it over, and changing a category's currency
  drops its plan and says what it loses first (rule 28). It isn't changed on its own.
- **Paid from names the account when there is only one** in the category's currency
  ("TDB Checking"); "All accounts" is for two or more, and "No accounts" when the
  currency has none.
- **Deleting a category asks where its rows go only when it has rows that still
  exist** (owner, same day: clearing out the dollar categories, each Delete said "Only
  deleted rows are filed under it. They move to:" and wouldn't go on until a category
  was picked, for rows that went with the dollar account). A row that was deleted,
  on its own or with its account, isn't counted: nobody can see it, so nobody can say
  where it belongs. The category is deleted at once, with the usual popup and Undo,
  and the deleted rows stay filed under it. They can only come back by undoing their
  own delete, which the session's undo reaches after it has undone the category's
  (newest first), so they find it there. *Before:* the database refused to delete a
  category with any row at all, deleted ones included, so that an old delete undone
  later would find a live category; that made a required choice out of something the
  owner couldn't see. A merge (Delete with rows, or a rename onto another name) still
  moves deleted rows along.

### The popup is a card (owner, 2026-10-06)

The owner sent the popup after a category was picked, in light mode, and said "Not
loving the way this looks". It was one line as wide as its words, centered on the
window: with a bank's 41-letter payee it ran nearly the window's width, lay over Net
worth in the sidebar and the last row, said the payee and the category twice, and was
white on brown (light mode's deeper gold), which read as a warning. The design
committee ran on it; two mockups went to the owner, who picked A.

- **A card 440 wide in the page's bottom-right corner** (40 from the right, 36 from
  the bottom), on every page. It never reaches the sidebar. In a register it covers
  the last rows' amounts and balances and the right 75 px or so of their Category
  column (a long chip such as "Not categorized" runs a little under it; the code
  review of 2026-10-07 corrected the claim here that the chips were left free). One
  width, so Undo and × are in the same place in every popup.
- **Three parts, each only when there's something for it.** What happened, with Undo
  and × at its right; it wraps as far as it needs and is never cut (its last clause is
  often the amount). Then **the row it happened to, on its own line**, smaller, cut
  with "…": a bank's payee is data, not part of a sentence, so the sentence above it
  never contains it ("Filed under Bank fees", not "EB-INTERBANK… → Bank fees"), and
  Mongolian never has to hang a case ending on a bank's string. An undo keeps the
  line, so "Undone · Filed under Bank fees" still says which row. Only a row's
  category and Always file use the line so far; the other popups keep their one
  sentence. Then **the one further thing on offer, as an outlined button** across the
  card.
- **Gold with dark text in both modes** (`Mid.toast`, `Mid.onToast`): light mode had
  drifted to white on its deeper gold. In light mode the card has an edge in that
  deeper gold and a lighter shadow.
- **It stays while the pointer is on it**, so it can't go from under a click.
  Otherwise 6 seconds, 12 with an offer, as before. From the reviews (2026-10-07),
  which found three ways the first build broke that promise:
  - Once the pointer leaves, it stays the longer of what's left of its own time and
    four seconds. (Leaving used to restart it at four, so an offer the pointer merely
    crossed on its way elsewhere went after 5 seconds instead of 12.)
  - A popup that takes the place of one the pointer is on (⌘Z, the card's own Undo,
    its offer button) stays under the pointer too. (It used to run its 6 seconds and
    go, and the click meant for its Undo landed on the row beneath.)
  - Only a pointer that moved or clicked on the card holds it. One that appears under
    a pointer left resting in that corner leaves in its own time. (It used to stay for
    good, over the last rows' amounts.)
- **A click on the card isn't a click away** from a row open for typing: × or the
  offer leaves an empty Add row open and a half-typed one its cursor.
- **Opening an Edit puts the card away** (a row's, or a category's on the Budget
  page): in the corner it lay over the Edit's Cancel and Save, and a pointer going
  for Save landed on the card and held it there. ⌘Z still undoes what it said. For
  the same reason **a new category says nothing in a popup**: its Edit opens under
  its row, which is the confirmation (as a new account says nothing).
- **A row with no payee has no second line** (it was drawn empty).
- **Undo is level with the sentence on a Mac** (owner's screenshot, 2026-10-07). A
  Mac draws buttons 8 shorter than the tests' platform does (Flutter's compact
  density on desktop), so in the real app Undo sat 4 above the sentence beside it and
  the offer button was 26 high, not 34, while every golden showed them right. The
  card's two buttons now keep the standard size on every platform, and a test run as
  a Mac checks it. **The same gap may be elsewhere:** goldens are drawn at standard
  density, so they can't show a button the Mac shrinks.
- *Rejected:* **B**, centered on the page at 520 wide with the payee on top, a filled
  button and a sentence under it (more lines, and it sits over the category chips);
  keeping the strip and capping its width (still the row of controls); asking it as a
  question with "Yes, every row" (it promises more than happens: only this account's
  rows still in Not categorized are filed).
- *Not built, a new feature to ask about:* the same offer at the foot of a row's
  category dropdown, so one that was missed can be found again. *Left as they were:*
  popups that aren't saved changes (why a row can't be saved, "Couldn't…") take the
  same card.

**"Always file LoveSol under Income"** (owner, 2026-10-06: "you'd need to treat income
the same as any other category. If I get something from LoveSol, and I choose my
Loveland Solutions pay check from the ledger category dropdown, then the app should
offer to remember that for the future."):

- Picking a category from a row's dropdown shows, in the popup at the bottom, a
  button: **Always file this payee here, and 9 more rows now** (reworded 2026-10-06
  with the popup's redesign: the payee and the category are on the popup's own lines
  above it, so the button names neither; it used to read "Always file LoveSol under
  Income · 9 more rows waiting". One sentence since the words pass of 2026-10-07:
  after a dot, "9 more rows now" had no verb and read as a count, where "and" carries
  "file" over to the rows). Taken back, the popup reads "Undone · Always filed under
  Income" and no longer says rows were filed. Clicking it files that payee's rows still in Not categorized
  on this account and keeps the rule; the popup then reads "Always filed under Income ·
  9 more rows filed" over the payee. One ⌘Z takes back the rows and the rule. Not offered on a transfer or split, for Not categorized
  itself, or when it's already the rule.
- **A payee fits when its name starts with the one clicked**, whatever the capitals
  (owner: "This is all good" to that), because banks put a date or a number after a
  name. The longest beginning wins. Kept per account
  (`import.rules.<account>` in preferences, `PayeeRule` in `import/mapping.dart`; no
  schema change). An import asks the rule first, then the category the payee had last.
- **Each pay is in the dropdown by its name** (owner, 2026-10-06: "if there is an
  income transaction, then the Income categories should be at the top of the dropdown.
  Otherwise, the outflow should be there. Obviously, you'd need to be able to assign
  income to a given paycheck otherwise the whole budget app would fall apart").
  - **On money in**, the dropdown starts with each pay paid into that account
    ("Income · Loveland Solutions"; "Income · paycheck" for a single pay with no name),
    then Income, then the spending categories. **On money out**, the spending
    categories come first and Income last, and no pay is offered.
  - **Picking a pay makes the row that pay's paycheck** (`takeAsPay`): it's filed
    under Income and tied to the pay, so the Budget page's Income tab counts it as
    received; the payday it stands for (the nearest planned one, early or late) stops
    being expected, so the forecast doesn't count it twice; the next payday is
    scheduled. The row's chip then reads "Income · Loveland Solutions". One ⌘Z.
  - **The offer carries the pay:** after "Filed under Income · Loveland Solutions",
    the button moves that payee's waiting money-in rows as paychecks, oldest first,
    and the next import does the same (`PayeeRule.payId`; `ImportRecord.paid` for the
    import's undo). Money out from the same payee is never a paycheck.
  - **Typing a new row** (owner, 2026-10-06: "Well. Build it."): the Category field
    lists each pay paid into the row's account by the same names, filed under Income.
    Saving makes the row that pay's paycheck, in the same write and the same ⌘Z. The
    list follows the same order: with `+` typed before the amount (money in) the pays
    and Income lead; otherwise the spending categories do. A payee's remembered
    category never fills in a pay by itself. A row dated ahead is only scheduled, and
    stays plain income until it comes. Not while editing a row: there the dropdown on
    the row does it.
- **Loose ends:** the offer isn't made from a row's Edit, only from the dropdown.
  The list of rules, and the way to drop one, is the Payees section (below, "Payees:
  its own section").

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

### Onboarding: the first half hour (owner, 2026-10-05)

A new person's first launch opened on the demo's TDB Checking and Golomt Visa with
nothing saying it was a demo, and Settings → Start over was the only way to their own
money. The `budget-expert` agent designed the setup from the accounting: what has to be
true before the first period's numbers mean anything. Its three findings about the app
as it stood:

- **An unmarked home loan makes the Budget page unusable.** "You have" is cash and bank
  less what the cards owe (`Budget.of`, `BudgetPool.money`), and a mortgage or student
  loan is left out of it only if the account carries that role — which could only be set
  on the Savings page. A ₮68,000,000 home loan added as "Card or loan" gave You have
  = −₮61,210,000 and a top pane reading "Cards owe more than you have", with nothing
  saying why.
- **A savings balance switches the coral warning off.** Money in Khan Savings counts in
  Not assigned, so "more assigned than you have" can't fire until that money is spoken
  for. On ₮6,790,000 across the accounts with ₮1,755,000 assigned, Not assigned read
  ₮5,035,000 in black, ₮6,200,000 of it renovation money.
- **Nobody chose when the budget started.** `BudgetKeys.began` was written as a side
  effect of the first assignment (`_setBudgetAmount`), set to the period's first day.

The decisions:

- **Money already saved gets an envelope in the wizard** (owner, 2026-10-05). A step
  asks what the saved money is for and makes a category with that one account checked,
  on the dedicated-account rule and the Stop at cap. Nothing changes in how money is
  counted; the coral warning starts working because the money has a job. *Rejected:*
  leaving accounts marked as the fund out of You have (spending from them then breaks:
  the money was never in the pool it's spent from), and saying it in words under Not
  assigned while the warning stays off.
- **What's owed is not the Budget page's job** (owner, 2026-10-05: "Cards should just be
  budget categories. We'll track their balance and paydown later on the Savings page." …
  "Same with Loans." … "the savings page that we haven't really worked on will track what
  they owe and help them pay it off. That's not the job of the budget screen."). This
  **reverses the 2026-09-30 call** recorded above under the first build ("Card debt
  reduces the money", option A, which rejected a card-payment category as the common
  convention). What forced the reversal: option A made the pane's first figure an
  intermediate subtotal — accounts less debt — that no bank shows, nobody holds in their
  head, and nothing can be checked against. The owner asked twice what it meant ("What
  does 'You have' mean???"), which is the answer.
  - **"You have" is cash and bank, and nothing else.** No subtraction, nothing hidden,
    no tooltip doing the real work. It ties to the sidebar and to a bank app. In the
    demo ledger it reads ₮16,868,950 while net worth reads ₮16,228,750; the difference
    is the Visa, which is what net worth is for.
  - **A credit card or loan's payment is budgeted as a category, like rent** (owner's
    choice of two): you make a category, give it an amount and a due date, and paying
    the card from the bank is that category's spending. *Rejected:* a category that
    fills itself as the card is used — always arithmetically right, but it's the
    convention other apps use and it's a category that behaves unlike every other one.
  - **What is owed, and paying it down, belong to Savings**, which is barely built. The
    Budget page never shows a balance owed.
  - **The consequence, accepted:** buying on a credit card *raises* Not assigned, by the
    amount of the purchase, until the card is paid. The category records the spending
    while no money leaves the bank, and `notAssigned = money − held` does the rest. This
    is unavoidable once a balance owed is out of the sum — the only alternative is the
    self-filling category that was rejected. Covered by a test in `budget_test.dart`.
  - **Two predicates, not one.** `Budget.counts` is money to budget: assets only.
    `Budget.spendable` is the accounts a category can be spent from: cash, bank and
    credit cards, never a mortgage or student loan — the owner's 2026-10-02 correction
    ("a card is an account; if they plan to pay with it, let them") lives here. They were
    one function, and separating them is what keeps the Visa in a category's **Paid
    from** list while taking it out of the money.
  - **Every credit card and loan can name the category its payment comes from**, through
    the account menu's "Payments come out of ▸"; it used to be offered for a mortgage or
    student loan only.
  - **Gone with it:** "Credit cards owe more than you have" on the pane (impossible now),
    and the `paidOverTime` role plus the "Paid off" question on Add account, both built
    earlier the same day for the superseded model. Keeping a control that changes nothing
    would have been an element without a purpose.
  - **Say "credit card", never "card"** (owner, 2026-10-05: "Are they gift cards?").
    "Credit card or loan" on Add account and in the account menu, "Credit cards owe…"
    wherever it survives. The UI-card sense in translator notes is left alone.
  - **The first row is "Cash & bank"**, not "You have" (owner, 2026-10-06: "come up with
    something better than 'You have', for heaven's sake"; the `ux-writer` pass chose it).
    The figure stopped being a possession and became a place — the money sitting in two
    kinds of account — so the label names the place. **Deliberately the same words as the
    sidebar group**, so the number can be checked twice: against the sidebar and against
    a bank app. It also ends the collision with **Net worth** below it, which counts what
    's owed and is therefore smaller: one row says where the money is, the sidebar says
    what it all comes to. The pane now reads `Cash & bank → In categories → Not assigned`.
    *Rejected:* "In accounts" (good parallel with "In categories", but a credit card is
    an account, so it would be wrong about the Visa and would need the tooltip back);
    "In the bank" (leaves out cash, which is not a rounding error in Mongolia);
    "Accounts" bare (reads as a section heading); and "Spendable", "Available",
    "To Budget", "Ready to Assign" — other apps' words, and abstractions nothing can be
    checked against.
  - **"Not assigned" stays.** The "reads like an error state" finding came from the vague
    row above it; with the top row naming a place, the bottom row is plainly the rest.
  - **The tooltip is gone.** `planKeyHaveTip` said "Cash and bank", which is now the
    label — an element with no purpose. Its Mongolian still said "less what the cards
    owe", which had become false. The `tip:` parameter it was the only user of went too.
  - **The label column is measured from the Mongolian**, not the English: "Бэлэн мөнгө ба
    банк" wrapped to two lines at 120 px and made the first row ragged, so it is 150.
  - `planOverConsequence` now says cash and bank go below zero, not "the accounts" — a
    credit card is an account but isn't in this sum.
  - **Cash is its own Type** (owner, 2026-10-06: "I don't even think we should call it
    'Cash and bank' unless one of the accounts is cash. That should probably be an
    account type."). Add account offers **Bank account · Cash · Credit card or loan**.
    Both of the first two are `AccountType.asset` to the ledger — the double-entry model
    is untouched — and the Type the person picked is kept in the sidebar-group column,
    which was already derived from the type and is never edited by hand
    (`LedgerGroups.cash` / `.bank` / `.credit`, `AccountInfo.isCash`).
    - **A cash account is offered neither Reconcile nor Import**, and loses the "Last
      reconciled" line: there is no statement to be checked against and no bank file to
      read. This is what earns the Type beyond the label; it was wrong before and nobody
      had noticed. A counting flow for cash is still not wanted and stays on the roadmap.
    - **The sidebar has three groups**, Bank / Cash / Credit, where it had two.
    - **The Budget row names what the ledger actually holds**: "Cash & bank" only with
      both, otherwise "Bank" or "Cash" — the same principle as telling two currencies
      apart only when a ledger holds both. With no asset accounts at all it reads
      "Cash & bank", the fullest name for what could go there.
    - **Schema v18** renames the old `Cash & bank` group to `Bank`. **No existing
      account is made cash**: the ledger can't know which is a wallet, and guessing from
      a name would be wrong in any language. The person says so, by making it or by
      changing its Type. Covered in `migration_test.dart`.
    - Cash counts as money to budget exactly as before. Nothing about the arithmetic
      moved.
- **No demo at first launch** (owner, 2026-10-05). The wizard is the first screen, on an
  empty ledger. What a filled-in Budget page looks like is shown as a picture where an
  envelope has to be explained — nothing written to the database. Fake money teaches
  nothing about the person's own money. *Rejected:* the demo as a labelled second ledger
  opened and closed from Help (the app has no notion of two ledgers; worth revisiting as
  a tour), and leaving it as it was.
- **The sequence**, six screens of real work, about half an hour. The recovery key stays
  first, before any data, and is never mentioned again.
  1. **One date for every opening balance**, defaulted to today — the heading of step 2,
     not a screen of its own. Accounts dated different days make You have a figure from
     no single day.
  2. **The accounts and what's in each today**, with a list to jog memory (the bank pay
     goes into, other banks, savings, cash in the wallet, every card, Storepay or
     лизинг, a dollar account, a home loan, money for a business — a business till
     inside the household wallet makes the shop's takings read as income). **An account
     that owes money is asked how it gets paid** — in full each month, or a set amount —
     which is what decides whether its balance comes off You have ("Only debt due now"
     above), and a set amount leads on to the payment as a bill. A home or student loan
     is marked here too, not left on the Savings page. One cash question: "How do you pay
     for everyday things? Card and bank · Cash · Both", because the drift from unrecorded
     cash never corrects itself.
     **Corrected (owner, 2026-10-07: "we only want them to add bank accounts they
     want to track").** The step doesn't ask for every account. Its line is "Add the
     accounts you want to track", and the memory list is gone: the mockup had drawn it
     as nine add buttons under "Add every account you keep money in or owe money on",
     which pressed for completeness. The add buttons are the app's three Types.
     Cash & bank is then the money in the accounts they chose to track.
  3. **Import, optional and skipped by default** — and **before the first assignment**,
     because rows imported into a budgeted period push envelopes under with no warning.
     Placed earlier, the first-period offer catches them. It buys payee autocomplete and
     real figures to look at; nothing the budget's correctness needs.
  4. **Which period the budget starts in:** this one, or the next when the period is
     more than half gone and nothing has been assigned.
  5. **Pay**, the setup that exists, reached in order instead of from the gold nag.
     Answered, never skipped: "I don't have regular pay" is one of the answers, or the
     Income tab wears a gold dot an irregular earner can never clear. The amount is
     **what arrives in the bank, after any loan taken from the salary** — typed gross,
     the forecast is optimistic every period.
  6. **The bills with dates:** rent or the home loan payment, СӨХ, electricity and
     heating, water, phone and internet, kindergarten or school, insurance, an
     instalment. These are the ones that fail silently.
  7. **Two or three everyday amounts:** food, transport, everything else. Every field
     may be left empty, so it blocks nothing.
  8. **Money already saved: what is it for?** Shown only when an account they don't
     spend from holds money. "Nothing yet" is a valid answer.
  9. **Assign what you have now**, the bills due before the next payday first.
  10. **What to do tomorrow**, one screen and no data: record everything including cash;
      **moving money between your own accounts is a transfer, never a category** (the
      commonest way an envelope budget breaks: the envelope empties and the money reads
      as spent); confirm a scheduled bill instead of typing it fresh; come back on
      payday and assign the rest.
- **Eight to ten categories on day one, not fourteen.** Three to six dated bills, two or
  three everyday amounts, one line for money already saved. Splitting a category later
  is a name and one question; un-splitting four is a merge. *Rejected on day one:* a
  category per card or instalment (a card envelope can never be spent from), and
  "Bank fees" as its own ₮380 line.
- **Decided along the owner's rules rather than asked:** Paid from defaults to the one
  account pay lands in (answering the 2026-10-05 open question — a dated bill with no
  account left checked is in nobody's forecast); the wizard writes the budget's start
  on purpose instead of it falling out of the first assignment; a mid-period start says
  so in a quiet line ("This period counts from 10.10") because Spent is then only part
  of a month and the plans read short until payday; the first period's Income reads ₮0
  with opening balances only, which is a line and not data (recording the paycheck would
  take the money out of the accounts twice).
- **Uncleared rows are not asked about at setup.** The opening balance is cleared, the
  bank's figure already holds everything posted, and the budget and forecast read posted
  rows whatever their cleared state. One sentence beside a card covers the exception: a
  charge made today that hasn't posted means the owed figure is low.
- **The wizard sets `ledger.started` the moment it opens**, or a wizard opened and
  abandoned gets the demo seeded underneath it at the next launch
  (`seedDemoIfEmpty` skips only a ledger where `startedOwnLedger()` is true).

Still to build for the sequence: the loan question, writing `began` deliberately, the
mid-period line, and every step after the accounts.

**Presentation: setup inside the app's own window** (owner, 2026-10-07, "Let's do A",
from three mockups drawn out of the design committee's reports in
[committee/onboarding/](../committee/onboarding/)). The sidebar is the real one, empty
at first, and fills under Bank / Cash / Credit as accounts are added; the page holds one
step; the steps are named in words across the top once there is more than one. The
balances on the left stand still while categories are assigned on the right, which is
the answer to the first-time reader who thought assigning moved money at the bank.
*Rejected:* one "Set up" page of lines that open in place (the order — import before
assigning, saved money before assigning — is the accounting, and a list only suggests
it), and one large question per screen with the accounts in a side panel.

**The accounts step, built first (0.14.0):**

- **A new, empty ledger opens on setup, and the app no longer seeds the demo.**
  `LedgerScreen.demo` is false in the app and true in most tests.
- **Setup shows** while `setup.done` is unset and either `setup.date` is set or the
  ledger has never had an account, deleted ones counted (`inSetup`,
  `domain/setup.dart`). A ledger that had accounts before setup existed has neither key
  and never sees it, even with its last account deleted (the code review caught the
  first version opening setup there). Three keys in the existing
  `Preferences` table; no schema change.
- **One line per account**: name, currency, and Balance or You owe, opened by one of
  three buttons (Bank account, Cash, Credit card or loan) that set its Type. The
  account and its balance are one write and one ⌘Z. × removes one, with Undo on the
  popup.
- **"Balances as of"** is one date above the list. Changing it moves every opening
  balance already typed (`redateOpeningBalances`), and ⌘Z moves them back.
  A reconciled opening balance stays where its statement has it.
- **The foot total** is "Cash & bank" (named as the Budget page names it) and what's
  owed, one line for each currency.
- **A line still being typed is kept.** Another Type's button keeps its name and
  amount, and "Open my ledger" adds it first; if its amount can't be read, that is said
  and setup stays. A name left empty is the Type's word, which is what the field shows
  in grey.
- **"How do you pay for everyday things?"** is asked only while there is no Cash
  account, since that is the only time the answer changes anything. From the bank
  (card, QR or transfer) · Cash · Both. "Card and bank" was the committee's wording; bare "card" is a word the
  owner rejected. With Cash or Both and no Cash account, a gold line says what will go
  wrong (money from an ATM reads as spent the day it's taken out, and the wallet isn't
  counted) and offers "Add a Cash account"; nothing is refused.
- **"BetterBudget never connects to your bank."** Said once, under the heading: the
  first-time reader expected a bank login, and nothing said otherwise.
- **Decided along the owner's rules rather than asked:** an account that owes money is
  not asked how it gets paid here. The answer once decided whether the balance came off
  "You have"; since 2026-10-05 nothing owed does. Whether there is a set payment each
  month is asked on the Bills step, where it becomes a bill. The step names across the
  top wait for the second step: one name alone is an element with nothing to do.
  Settings can't be reached during setup, so the language is the Mac's until it ends.

**The Pay step, built second (0.15.0):**

- **The step names are across the top**, in words: Accounts › Pay. The one on the page
  is underlined; the other is a click. Pay is grey until there is an account, since
  until then there is nothing for it. Only steps that are built are named.
- **Steps only move.** Continue, Back and a step's name write nothing but which step
  setup is on (`setup.step`), so a quit comes back to it. Continue and the Pay name add
  an account line still being typed first, as "Open my ledger" used to.
- **"Your pay" is the pay form that exists, on the page** instead of in a dialog
  (`_PayForm`; `_PaySetupDialog` now only wraps it). The page has the heading, so the
  form doesn't repeat it. Same fields, same words, same writes and the same ⌘Z.
- **One new line, under the amount, in setup only:** "The amount that lands in the
  account, not your salary before tax. A loan payment the bank takes afterwards is a
  bill." The first-time reader would have typed the salary. The committee's wording,
  "after tax and any loan taken from your salary", was dropped on the budget review: a
  loan the bank takes the day after pay lands would be taken off here and again as a
  bill. Not shown when pay goes into a Cash account, and not added to the dialog the
  owner already uses.
- **Two answers and no bare Continue:** "Save pay" and "I don't have regular pay".
  While neither is given the form is open, with no Cancel (nothing to go back to) and
  no "Open my ledger". Back still leaves.
- **Once answered, the answer is what the page shows**: each pay on a line worded as
  the Income tab words it ("₮2,100,000 · monthly on the 25th · into TDB Checking · next
  10.23") with Edit, and "Add other pay" for a second earner; or the one line "No
  regular pay" with "Add your pay". No popup: the line appearing is the confirmation.
  "Open my ledger" is at the foot, and isn't there while the form is open, since
  what's typed in it would be dropped.
- **Pay starts in the first bank account**, not a wallet listed above it.
- **The amount has the keys on arriving**, so a number can be typed at once (the
  form's own autofocus doesn't take on a page, where the register holds the keys).
  Esc closes an Edit or "Add other pay" wherever the last click was, as Cancel does.
- **A pay whose account was since removed** is still listed, without Edit, under the
  line saying pay needs an account. Removing an account doesn't stop its pay, in setup
  or in the app: not decided.
- **With only an account that owes**, the page says pay goes into a bank account or
  Cash and to add one on Accounts; the ledger still opens.
- **Decided along the owner's rules rather than asked:** the filled button on the Pay
  step is still "Open my ledger" because Pay is the last step built; it becomes
  Continue when Bills is. The filled buttons in setup no longer show a ⌘N tooltip (⌘N
  does nothing there).


### Four Savings steps (owner, 2026-10-09)

The owner: "Let's work on the savings portion of this budget. There will be four
steps. 1. Build a safety net 2. Eliminated Debt (credit cards, vehicles, not house)
3. Build a three to six month savings 4. Final Save for the future." They are the
four pictures the owner drew (`assets/logo/Images/Savings_*`). This replaces rule 25's
six steps; everything else in rule 25 stands.

- **The titles are the owner's words:** Build a safety net · Eliminate debt · Build
  three to six months of savings · Save for the future. Each step shows its picture
  to the left of its number, the night copy on a dark page (`SavingsPicture` in
  `ui/brand.dart`; the files are copied into `app/assets/brand/` by `prepare.py`).
- **Step 1, the safety net, is still one month of expenses** (rule 25). The owner
  renamed the step and gave no new amount.
- **A month of expenses comes from the budget** (owner, on seeing the step: "Shouldn't
  you know what a month of their expenses is? Maybe pull it from the budget and let
  them adjust it."). In order: the figure they typed; else what the budget holds for
  this calendar month (for each spending category, what its plan asks for the month
  or what is assigned to it, whichever is more), said as "from your budget"; else the
  three-month average of spending as before; else it asks. A card or loan payment
  budgeted as a category is in it like rent, which the average left out. "Type your
  own month" stays.
- **The safety net is kept apart: "in a different account (ideally) or a different
  category"** (owner's correction, the same day). The first build counted the whole
  of the account picked, and with one account that was every tugrik they had, their
  rent money included ("No, man"). A second build let them tick accounts and
  categories in a "Kept in" menu; the owner could not follow it ("I don't know what
  you're saying here"), and it counted money twice once a ticked category's money
  was moved into a ticked account.
- **The safety net is one budget category, and its Left is the count** (owner,
  2026-10-09: "Yes, build a, but I'll need to use it to see if it works"; the
  `budget-expert` agent's way A of three). The owner's two cases, saving straight
  into a savings account and assigning to a category then moving the money when they
  can, come to one figure: a transfer between their own accounts changes where the
  money is, never how much is saved.
  - **Safety net is built into the app, like Income** (owner, shown a button that
    made the category: "No, I think we should have a dedicated safety net category
    built into the app"). Every ledger past setup has one: it is made, with no
    button and no question, the first time such a ledger is opened without it, in
    the currency most accounts are in. It is the spending category carrying the
    mark an account used to carry (`AccountRole.emergencyFund`), so there is no
    schema change. It can be renamed and edited like any category; its menu has no
    Delete and its Edit no Archive. A category the owner had made with the earlier
    button, or one already named Safety net, becomes it, with its rows and amounts
    as they were.
  - The step counts what is Left in it. When the category's **Paid from** is only
    some accounts, the step says where the money is: "₮600,000 in Khan Savings ·
    ₮400,000 still to move there", or "All of it is in Khan Savings". With two or
    more accounts and no such limit, it says how to set one.
  - Money saved straight into an account is Not assigned on the Budget page; the
    step says "₮1,000,000 in your budget is not assigned to anything." with a
    button, "Assign ₮1,000,000 to Safety net" (no more than fills it).
  - The category is left out of a month of expenses.
  - **On the Budget page it sits last, under a quiet heading "Saved"** (owner: "we
    should probably create some type of visual separation"; and "Just safety net"
    when asked whether every category being saved in goes there). The top line is
    unchanged.
  - *Rejected:* B, both ticks with the overlap taken off (the figure rests on a rule
    nobody can see, and money saved straight into the account still reads Not
    assigned); C, only the savings account counts (with one account there could
    never be a safety net).
  - **An account marked as holding the fund before this is no longer counted.** Its
    mark stays in the ledger and nothing reads it.
- **Step 2 is every card and loan owing except the house:** not one marked Mortgage,
  and not a card marked "Paid in full every month". **A student loan counts here now**
  (it waited with the mortgage before): the owner left out only the house. "Student
  loan" is offered in a debt's menu only to an account already marked one. What was
  "Consumer debt" on a debt's line reads **"Debt to pay off"**.
- **Step 3** is as before. Its title no longer carries the number of months, so the
  3, 4, 5, 6 months buttons always show on it, not only while it is the current step.
- **Step 4, Save for the future, holds what were steps 5 and 6** as two headed parts:
  "Saving for retirement" (I am / Not yet) and "Paying off the mortgage" (as step 6
  was, less student loans). It is done when both are. What else belongs in it is the
  owner's to say (ROADMAP D: goals with dates).
- **Health coverage is no longer a step.** An answer already given stays in the
  ledger (`ready.health`) and nothing reads it.
- **Nothing in a ledger is changed or dropped,** and there is no schema change. The
  three steps that carried over keep the names a set-aside step is stored under; a
  set-aside "health", "retirement" or "longLoans" is passed over.
- **The page fills the window** (the owner's correction on the Budget page), with
  each step's words held to a width that reads.
- **From the reviews** (decided along the lines above): an account marked a student
  loan under the six steps shows as "Debt to pay off", already ticked, and picking
  that leaves its mark alone (the mark still keeps its payments in a month of
  expenses); "Paying extra on it" with no loan marked reads "Paying extra", not the
  question again. What the budget review found and was left for the owner is in
  STATUS ("Waiting on the owner" 17, and "Known bugs").

### A debt's interest rate on step 2 (owner, 2026-10-14)

Asked whether each debt on Eliminate debt should take its interest rate and its
monthly payment, the owner: "There should be a place to record the interest rate.
They should be able to update it there in savings or when they create the card.
There should be a tooltip or something that tells the interest rate is used in step
2." No monthly payment was asked for.

- **The rate sits on each debt's line** (layout A of three, the owner's pick): "Add
  rate" while there is none, else "2% a month"; a click opens a field under the line
  with %, the switch, Cancel and Save (Enter saves, Esc cancels, empty takes it off,
  one undo). An ⓘ beside it: "Step 2 uses this rate to show which debt costs you
  the most each month, so you know where to pay extra first." *Rejected:* B, the
  rate behind the debt's menu (out of sight); C, a table with Owed, Rate and
  Interest a month headings (busier).
- **A month's rate or a year's is the person's choice** (owner: "Let them chose how
  the interest rate works so that they have something that works in both the US and
  in Mongolia"). A switch, "a month" / "a year", beside the field. Where it starts
  is a default, not a question: a tugrik card or loan starts at "a month", since
  Mongolian banks say сарын хүү; any other currency at "a year".
- **On Add account**, a credit card or loan has an optional Interest rate line with
  the same switch, and under it: "Not required. Step 2 of Savings uses it to show
  which debt costs you the most each month."
- **What it shows:** under a debt with a rate, "about ₮48,000 a month in interest"
  (what's owed × the month's rate; a year's rate over twelve; whole tugrik).
  Debts are listed by that, most first, those without a rate last. Once two or more
  have a rate, the costliest reads "· costs you the most"; with one, there's
  nothing to compare. **The debt to pay extra on is still the smallest unless one is
  picked**: the order says what each costs, the pick stays theirs.
- **Kept as a Savings answer, not an account column:** `ready.rate.<account id>`,
  "2 month" or "24 year". No schema change, so the phone needs no new build; the
  other computer gets it through the change files like any preference. An account
  added and then undone leaves its rate unread beside it; redo brings both back.
- **The line "In the order of Personal Finances for Self-Reliance…" is gone** (owner:
  the steps are their own now). With it went the need for the course's Mongolian
  title.
- **Save for the future stays as it is** (owner: "We can put something on the road
  map, but let's keep it as is for now"); goals with dates are in ROADMAP D.
- A step's sentences stay 640 wide; the step is 760, so a debt line's name, amount,
  rate, what it counts as and "Pay extra here" fit in English and Mongolian.
- **From the reviews** (decided along the lines above):
  - The tip and the Add account line say only what the figure is: "Step 2 uses this
    rate to show about how much interest each debt costs you a month." The first
    wording added "so you know where to pay extra first", which the figure doesn't
    measure: a big loan at 1.5% a month costs more each month than a small card at
    3%, yet extra money saves more on the card.
  - "About" is said in two figures: ₮48,000, not ₮47,836. The costliest reads
    "about ₮300,000 a month in interest, the most of your debts", and not when the
    top two read the same.
  - Debts are sorted by cost only once two or more have a rate; until then, smallest
    first as before.
  - A rate that looks typed under the wrong period is warned about under the field,
    never refused: over 8% a month ("21.6% a month is 259.2% a year. If your bank's
    21.6% is a year's rate, pick a year."), or a tugrik rate under 3% a year.
  - "Add interest rate", not "Add rate" (the app has exchange rates too). A rate is
    digits with one decimal point or comma, and an optional %.

### Two computers: what is said when the ledger comes from another one (2026-10-09)

Built with step 1 of "More than one computer on one ledger"
([ADR 0005](0005-mobile-companion.md)); the owner has not seen these yet.
**The Undo described below was taken off on 2026-10-10** ("Two computers: combined
without a question, and no Undo on another's changes", at the end of this record).

- **A newer ledger opened by itself** is a popup, since it is a saved change: "Opened
  the ledger saved on Tom’s MacBook Air", under it the folder and when, as Settings
  writes them ("My Drive/BetterBudget · Yesterday 21:40"), and Undo. ⌘Z doesn't
  reach it, as with the phones' entries.
- **Both changed** is a question, "Your ledger was changed on two computers": a line
  for each ledger in real numbers ("In the folder · 21 transactions · 4 accounts",
  with "Saved on The laptop · Today 10:00" under it; "On this computer · 20
  transactions · 4 accounts"), then what it means and what waiting costs, and three
  buttons: Not now, Keep this computer's ledger, Keep the folder's ledger. None is
  the default: either choice sets work aside. Esc and a click away are Not now.
  One verb, **keep**, here and on the Settings button ("Choose which to keep…")
  (budget review: the first wording had "use", "keep" and "go on with").
- **Said where it's fixed:** while it is undecided the "Stored in" line is red,
  "My Drive/BetterBudget · changed on another computer too · this computer’s
  changes aren’t in the folder", with the button beside the folder's other buttons,
  and the gear has its dot.
- This question is the stand-in until the app combines the two; it goes when that is
  built. Offered by the budget review and not built, because combining replaces it:
  listing under each line the entries only that side has.

### Phone screens: Ledger first (owner, 2026-10-08)

"On the phone app, I don't want all the pluses on the categories. I want this UI to be
intuitive. I want it to open ledger first with everything they need to enter a
transaction. They can select and/or type the category from a dropdown." Said after
using option B below, which this replaces where the two differ. What B settled about
payees, bills, overspent words, cents and the Accounts link still holds.

- **Two screens, Ledger and Budget, with the switch along the bottom.** The app opens
  on Ledger. What is being typed stays through a look at Budget. The phone's Back on
  Budget goes to Ledger.
- **Ledger is the entry**: the amount in red with a minus, then Payee, Category, Paid
  from and Date (Today), the pad's own number keys, and Save. **Payee is above
  Category** (owner, 2026-10-08: "I want the payee to be above the Category"; the
  first build had Category first). Anything can be filled in first; Save names the
  first thing missing above it, in the screen's order ("Enter an amount", "Enter a
  payee", "Choose a category", "Choose an account"). **Clear** is at the top right only
  once something is typed or chosen.
- **Nothing is said about what is left until a category is chosen**; then the line
  under the amount reads as before. Its place is kept, so the rows don't move.
- **Category opens a list of every category** with what is left in each, the bills
  apart, in Budget's order. A box at the top narrows it as a name is typed: names that
  begin with the letters, then names that hold them; the first is marked and the
  keyboard's Done takes it. The keyboard stays down until the box is tapped, so the
  whole list can be scrolled.
- **"+ New category" is at the foot of that list** ("In a pinch, if they're out of the
  house, they should be able to create a new category. I know this deviates from what I
  said earlier, but it's what they would need"). With nothing typed it puts the cursor
  in the box; with "Cof" typed it reads "+ New category “Cof”", makes it and goes back
  to the entry with it chosen, asking nothing. A name that is already a category,
  whatever its capitals, is in the list and isn't offered again.
- **A category made on the phone holds nothing**, and says so: "Nothing assigned yet"
  under the amount and under its name on Budget, not "Overspent by", which would blame
  them for a category made a moment ago. What is spent in it shows red on Budget. It is
  in the currency of the account being paid from, and waits for the Mac as entries do:
  "1 of your entries and 1 new category are waiting for your computer". The waiting list
  shows it with Delete, which first says what goes with it: "Delete Coffee and the 1
  entry in it (₮4,500.00)?".
- **Budget has "+ New category" too**, where the new row lands: after the money to
  spend, above Bills. It asks the name; a name already taken is said under the box.
- **A category row on Budget has no +.** Tapping it goes to Ledger with that category
  chosen and whatever was typed kept.
- **Paid from is never filled in for them** (owner, 2026-10-08: "Don't autofill. I
  don't want to set people up for bad data entry in the name of convenience"). The row
  is empty until an account is chosen, and Save says "Choose an account". The first
  build showed the first account, then the chosen category's own account in the
  ledger; the owner was asked which of two guesses to show and wanted neither. It is
  empty again after each Save. Only a ledger with one account it could be shows that
  account: there is nothing to choose. The accounts offered are those in the
  category's currency.
- **After Save the form empties, and a toast says what the entry did to its category**
  (owner, 2026-10-08: "There should be some type of a toast notification showing how
  the transaction impacted the given category"). It reads "Saved · Nomin −₮12,500.00",
  and under it "Groceries · ₮135,500.00 left", or "Eating out · overspent by
  ₮48,400.00" in red, or "Coffee · nothing assigned yet", with Undo.
- **It is a real toast** (owner, same day: "It's not really toast. I would like it if
  it appeared and disappeared like a regular toast notification"). It slides in over
  the top of Ledger, where the emptied form shows nothing, and goes after 6 seconds or
  at the next key or choice, so its Undo can't write over an entry begun since. Two
  builds were sent back: a line above Save that said only what was saved, then a card
  set into the page above Save that stayed until the next key. Not at the foot: there
  it covers Save and the switch to Budget.
- **A payee is always needed** (owner, same day, asked whether Save could go ahead
  without one for a taxi or a market stall: "What? No. There should always be a payee.
  They would write 'Taxi' or 'Market Stall'").
- **The phone says "your computer", not "the Mac"** (owner, same day: "Your computer
  would obviously be better, or 'a computer' considering they may be sharing with a
  partner"): "From your computer today 08:10", "waiting for your computer". "Your" was
  taken because the phone's setup screens already say it.
- **Money in is a +/− button beside the amount** (owner, 2026-10-08: "What if I go to
  walmart and return some things. Wouldn't I want to create a positive entry in my
  phone ledger? I don't think it lets you do that right now"). A small round button to
  the left of the amount turns −₮12,500 in red into +₮12,500 in green, and back. With
  money in, Paid from reads **Paid into**, and the line under the amount goes up:
  "₮148,000.00 left now · ₮160,500.00 after this", or for an overspent category
  "Overspent by ₮18,400.00 · ₮81,600.00 left after this". The toast reads "Saved ·
  Walmart +₮12,500.00" over "Groceries · ₮160,500.00 left". Money in filed in a
  spending category is a refund to it, as on the computer. The next entry is money out
  again, Clear takes money in back, and the waiting list shows it green with its plus.
  Three ways were sketched and the owner took this one over the one recommended.
  Rejected: a two-part switch at the top left, Money out | Money in (recommended, for
  saying it in words); a fifth row, Refund, with an on/off switch (refunds only, and it
  pushes Save further down a small phone).
- **With money in, the Category list offers Income first** (owner, same day, asked
  whether ₮50,000 someone pays them in cash should be recordable, or refunds only:
  "Offer Income too"). It is the app's one Income, with no figure beside it. Nothing is
  said under the amount, since Income holds no budget, and the toast is its one line.
  Money out never offers it, and an entry turned back to money out with Income chosen
  has its Category emptied. Neither the list nor Budget's "+ New category" makes a
  category called Income, in either language. Income's name typed in the list while
  the entry is money out isn't a blank page: under the box it says "To record income,
  tap +/− beside the amount first." Income has no currency of its own: the amount is
  in the currency of the account it is paid into.
- **An account the chosen category can't use is let go** (from the code review of
  money in). Paid from set to a dollar account, then a tugrik category chosen: the row
  is empty again, and stays empty when the category changes later. The first build
  only hid the account, and choosing Income brought it back unasked, which is the
  autofill the owner turned down.

Asked of four reviewers first (layout, flow, words, a first-time reader). Where they
disagreed: the pad stays (the first digit lands with no tap; the layout review wanted
the phone's keyboard), and the category box isn't focused on open. Rejected: a + on
each row; a dialog for the new category's name in the list.

Not built: renaming a category made on the phone, fixing a waiting entry, and all of
what reaches the Mac.

### Phone screens: Budget is home (owner, 2026-10-07; replaced in part on 2026-10-08)

The phone app ([ADR 0005](0005-mobile-companion.md)) records a transaction and shows
what is left in a category. Three ways to arrange that were drawn
(<https://claude.ai/artifact/9Eogm6wChncxhKgRbdmPAc>) and the owner chose **B**, after
first leaning to A.

- **The app opens on "Left in October"**: every spending category with what is left in
  it, and under the heading when the figures came from the Mac ("From your Mac today
  08:10"). An overspent category's amount is red with a minus.
- **Each row has a +.** Tapping the row opens the amount pad with that category already
  chosen: the amount in red with a minus, "₮148,000.00 left now · ₮135,500.00 after
  this" under it, then Payee, Paid from and Date (Today), the pad's own number keys,
  and Save. Cancel is at the top right.
- **No payee is filled in, and none are laid out to pick from** (owner, 2026-10-07,
  after using it: "It should not have any payee, and I don't like the prefilled
  options there, either. Maybe autofill based on history"). The first build chose the
  category's last payee and showed three more as buttons, so amount then Save could
  record the wrong shop. Payee is an empty row; tapping it opens a box on the phone's
  keyboard, and as a name is typed the ledger's own payees that fit are offered under
  it, this category's first.
- **An overspent category is said in words** under the amount: "Overspent by
  ₮18,400.00 · by ₮30,900.00 after this", not a minus beside "left".
- **Money waiting for a bill is listed apart** (owner, 2026-10-07: "Let's make it
  look less confusing"). A category saving for a bill not yet paid (Rent, due on the
  20th) comes after the categories with money to spend, under a small heading,
  **Bills**, with "Due 10.20" under its name and its amount in quieter ink. Its + still
  opens the amount pad, to pay it. With no such category there is no heading. The
  first build listed it among the rest in the same ink, where ₮1,800,000.00 read as
  money to spend.
- **Examples use the names a person would** (same day: "Why would rent be in my
  housing budget?? It would be in my rent budget category"). The question about this
  was asked with the demo ledger's category, Housing; the rent category is Rent.
- **The heading follows the Mac's Budget page**: "Left in October" by months, "Left
  until 10.14" by pay periods.
- **Save with something missing says it above Save** ("Enter an amount", "Enter a
  payee") and saves nothing.
- **Entries the Mac hasn't taken in** are counted in what is left at once. While there
  are any, a line under the list says "3 of your entries are waiting for the Mac";
  it opens the list, where each can be deleted.
- **Accounts** is a link at the top right: each balance, a card or loan as "Owed ₮X".
- **The full amount, cents included, while there is room** (owner: "Show the full
  tugrik amount if there is room"). Where a long name and a large amount don't both
  fit a row, the cents go and the name stays whole.

Rejected: **A**, two tabs with Add first (the amount pad, then Payee, Category, Paid
from and Date as four rows): the category is the slowest thing to choose on a phone
and "can I afford this?" is asked before anything is typed. **C**, a form that starts
with the payee on the phone's own keyboard, its Budget tab sorted into Overspent, Money
left and Nothing left.

**Transfers on the phone are picked in the Category list** (owner, 2026-10-09, of
three sketched; asked with ₮100,000 taken out of an ATM from TDB Checking into Cash
wallet). The list ends with a heading, "Move to an account", and the other accounts
as the computer writes a transfer, "→ Cash wallet", each with its balance ("Owed
₮312,000.00" on a card). Picked, the entry is a transfer: the Payee row and the +/−
button go (nobody was paid, and it is neither out nor in; a payee typed before is
dropped), the amount is plain ink with no sign, the Category row reads "→ Cash
wallet", the account row is **From**, and under the amount "TDB Checking ·
₮2,331,800.00 after this", red if that is below zero. The toast reads "Saved · TDB
Checking → Cash wallet ₮100,000.00" over "Cash wallet · ₮186,000.00 now" (a card:
"Golomt Visa · ₮112,000.00 owed now"), with Undo; the waiting list names it "TDB
Checking → Cash wallet" over "Transfer · 2026.10.07". Offered: accounts in the same
currency as the one paying, never that one, never for money in, and only where there
are two accounts in a currency; between tugrik and dollars it is still done on the
computer. "ATM" or "Transfer" typed in the list's box brings the accounts up, as
does a word that fits no category, so cash taken out isn't made a new category;
an account's name narrows them and the keyboard's Done takes it. Rejected: a third
turn of the +/− button (⇄), and a screen of its own behind a "Transfer" link.

Not built yet: fixing a waiting entry instead of deleting it, other
phones' entries, and the figures coming from the Mac at all: the screens run on
invented figures (`app/lib/phone_preview.dart`) until the Mac writes its snapshot.
"Left in October" names the calendar month though a category can run by a pay period;
that heading has to be settled when real figures arrive.

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

### Two computers: combined without a question, and no Undo on another's changes (2026-10-10)

Built as step 2 of "More than one computer on one ledger"
([ADR 0005](0005-mobile-companion.md), "Built, 2026-10-10").

- **What another computer changed arrives as a popup**, worded as the phone's is:
  "4 transactions from Tom’s MacBook Air"; "4 transactions and other changes from …"
  when it also changed something that isn't a new transaction (one changed or
  deleted counts here, so the number is only ever of rows that arrived); "Changes
  from …" when no transaction is new. Its second line is the folder and the time,
  unless there is something to look at.
- **Undo is only for what the person at this computer did or decided** (owner,
  2026-10-10, asked whether Undo on that popup should say first that it takes Tom's
  four transactions out of the ledger on both computers, or give way to Show: "Only
  undo what the user in front of the computer did or decided. Nothing else"). So
  the popup has no Undo. Nor has "Opened the ledger saved on …", which step 1 gave
  one: taking in a newer ledger is also the other computer's doing. In both cases
  this computer's ledger as it was is in Backups (`before-restore-…`), and Restore
  from… is the person's own act. Rejected: Undo with a warning naming what it
  removes on both computers (the recommendation). The phone's popup keeps its Undo
  (owner, 2026-10-08): those are entries the same person typed.
- **A row that looks the same as one already here is said, not settled** (owner,
  2026-10-10: yes). One person typed "Nomin ₮45,000" and the other imported the
  bank file with it: both rows are in, and the popup's second line says "1 looks
  the same as one already here", with **Show**, which opens the account with the
  row that came chosen. Alike means the same account and amount within 6 days (the
  span "Already in this account" uses), against rows made here since the two
  computers last agreed, each matched once. Nothing is merged or deleted for them.
- **More assigned than there is, is said** (owner, 2026-10-10: yes). Each assigns
  one pay to different categories and the two together assign it twice: the popup
  says "₮3,000,000 more is assigned than you have", the Budget page's Assigned too
  much, only when combining made it so or made it worse. With a row alike as well,
  each has its own line.
- The question's sentence "BetterBudget can’t put the two together yet" lost its
  "yet": it now comes up only when the two can't both stand.

### A second computer set up in one step (2026-10-12)

The owner set up a second account as a second computer on 2026-10-10: Restore
from… the folder's `Ledger.betterbudget` brought the ledger over, and nothing said
that "Move my ledger to a folder…" had to follow, so that computer went its own way
("let's put this on a list of things to do"; taken up 2026-10-12).

- **The restore dialog offers it, ticked.** When the file picked is
  `Ledger.betterbudget` in a folder that isn't the app's own, and the ledger here
  is stored on this computer, "Restore this backup?" has a checkbox under its note,
  ticked: **Share the ledger in My Drive/BetterBudget** (owner, 2026-10-12:
  "Definitely"; it first read "Keep this computer on this folder's ledger"), and
  under it "What you
  change here goes to My Drive/BetterBudget, and what is changed on another
  computer comes here." Restore then does both. A default rather than a required
  choice: unticked, it is the restore it always was. A backup under any other name,
  or one opened with another ledger's recovery key, is offered nothing.
- **Rejected: a second question after Restore** ("Keep this computer on this
  folder's ledger?", Yes the main button, as the roadmap first had it). It is one
  more dialog in a row of them, and closing it has no plain meaning: the person
  has already pressed Restore.
- **On a Mac the folder is chosen once more**, in the Mac's own dialog, which opens
  on that folder with the button "Use This Folder". The Mac gives a sandboxed app
  the file that was picked and nothing around it, and the app needs the folder
  (the phones' files are there too). Closed without choosing, or another folder
  chosen, the restore dialog is back and nothing was done.
- **The popup** says "This computer is now on the ledger in My Drive/BetterBudget ·
  what you had is saved", with Undo: this is the person's own act. Undo takes the
  computer off the folder before putting back what it had, so that never reaches
  the ledger the computers share.
- The offer at first launch says where to look, first: "If your ledger is stored in
  a folder, such as Google Drive, open Ledger.betterbudget there."
- **It is called a ledger, not a backup** (budget review): for the folder's file the
  dialog is titled "Bring this ledger here?", says "Last changed" where a backup
  has "Backup from", and "Everything here is replaced by this ledger." The button
  stays Restore. Unticked, the note under the box changes to what that leaves:
  "This computer gets its own copy. What you change here won't reach My
  Drive/BetterBudget." On a Mac the ticked note ends "Your Mac asks for the folder
  next: press Use This Folder." The review's "Share the ledger in My Drive/BetterBudget" for the
  checkbox was put to the owner and taken. Its "Bring your ledger here?" as the
  first offer's title was put too, and the owner asked instead whether a new
  computer should open on three choices (Start fresh, Restore from backup, Open
  ledger): not decided, sketches to come.

### How a new computer starts (2026-10-12)

A computer with no ledger opened on "Enter your recovery key", with "New to
BetterBudget? Set up a ledger" as a small link under it, and someone who typed a key
was then asked "Open your newest backup?". Asked whether that question should be
retitled, the owner asked instead: "Do we always assume they have a backup? This may
need to change. We may just have wizard like they're installing an OS: 1. Start
Fresh 2. Restore from Backup 3. Open Ledger (it shouldn't matter if they're sharing
or not)."

- **Three ways to start, and the one clicked opens in place** (owner, 2026-10-12,
  from three sketches at <https://claude.ai/artifact/Nzasw8pEQATkPRZpBEpSL5>: "I
  like that one best"). "How do you want to start?" over three rows, in the owner's
  order: **Start fresh**, **Restore from backup**, **Open ledger**. Start fresh goes
  to the screen that shows a new recovery key. The other two open where they are,
  with the recovery key and one button, "Choose the backup…" or "Choose the
  folder…". A click on an open row's name closes it; another row opens in its place.
- **Each row says who it is for, without leaning on "ledger"** (owner, 2026-10-12:
  "the word 'Ledger' may be jargon that throws them off. Just ask if they already
  use BetterBudget"): "My household is new to BetterBudget." / "I have a backup
  file, saved with Back up to… in Settings. This computer gets its own copy." /
  "My household already uses BetterBudget on another computer, and the ledger is
  in a folder, such as Google Drive. This computer shares it." A newcomer never
  has to know the word. It is the household, not "I" (budget review): a spouse
  setting up the second laptop has never opened the app, and "I'm new to
  BetterBudget" was true of them. The last two end with what this computer ends
  up with, its own copy or the shared ledger, since that is all that parts them.
- **The key is kept only once it opens what was picked.** The button under the key
  opens the file or folder dialog first; the key is then tried on what was picked,
  and only if it opens is it stored and a ledger made here. A key from another
  ledger, a folder with no ledger, a dialog closed: said under the key field,
  where it is fixed, with nothing stored. (As first built the key was stored
  before the pick, and a wrong one left no way back: both reviews.) Under the
  field: "It was shown when BetterBudget was first set up, and is in
  “BetterBudget recovery key.txt” if it was saved." Esc closes an open row.
- **Pointing at My Drive is enough**: the one folder directly inside it that holds
  a ledger is the one meant.
- **Open ledger is one pick, of the folder.** The ledger there is brought here and
  this computer stays on it: no file to pick, no Share box, no second Mac dialog,
  and no question about what it replaces, since nothing is here. The popup says
  "This computer is now on the ledger in My Drive/BetterBudget", with Undo. A
  folder with no `Ledger.betterbudget` in it is never written to: "There's no
  ledger in My Drive/Photos · if the folder is still arriving on this computer, try
  again in a minute" (now: "There's no ledger in My Drive/Photos · choose the folder
  that holds Ledger.betterbudget. If it is still copying to this computer, try
  again in a minute.").
- **With a key kept and still no ledger, it asks where the ledger is.** The
  restore cancelled at its last question, or one that failed, brings "Where is
  your ledger?": In a backup / In a folder, such as Google Drive / Start empty.
  The same question comes at each later launch while the ledger is still empty
  and unanswered. "Start empty" stays its own word: it goes on with the key
  already typed, where Start fresh makes a new one. It
  replaces "Open your newest backup?", which assumed a backup.
- Rejected: A, the three rows each leading to a screen of its own (the owner liked
  it, then C more); B, "Do you already have a BetterBudget ledger?" then where it
  is (liked, but for its word "ledger"; its plain question went into C's rows).
- A ledger already on the computer that the kept key doesn't open, or with no key
  kept, still gets "Enter your recovery key" as before.

### Payees: its own section (owner, 2026-10-12)

Asked where the list of "Always file" rules should be, with three sketches (on the
account's menu, recommended; a section of Settings; a line in the category's Edit),
the owner took none: "I don't want to hide this. For now, let's put it on its own
Payees row under Savings. I know it's unorthodox, and I may change it later, but I
find myself often needing to manage it, and I think it deserves its own dedicated
section." A thing they manage often gets a place of its own in the sidebar, not a
menu item.

- **Payees is the sidebar's fourth section, under Savings.** Its page fills the
  window and is one table, a line per rule, every open account's together, by name
  (a shop paid from two accounts has its lines together):
  - **Payee starts with**: the beginning the rule goes by, in the capitals it was
    written in (the row it was made from, or as typed here; `PayeeRule.name`, kept
    beside the lower-case beginning that is matched. A rule kept before this takes
    its capitals from a row of that payee). Clicked, it is retyped in place: Enter or
    a click away saves, Esc leaves it, as the account's name does. A bank puts a date
    or a number after a name, so a rule made on "NOMIN 0412" is cut back to "Nomin"
    here. A beginning the account already has isn't saved: the popup says "Nomin is
    already in the list".
  - **Account**, only while the ledger has more than one: with one there is nothing
    for it to tell apart.
  - **Always filed under**: the category, as the chip a row has, and a dropdown of
    the categories in the account's currency. Once the payee is income, the pays
    paid into the account lead the list by their names, as on a row. Picking another
    changes what the next import does and moves no row already in the ledger.
  - **Stop**: the payee is no longer filed by itself. Rows already filed stay.
- **Each of the three is a saved change**: the popup says it ("No longer always
  filed under Groceries", "Always filed under Phone & internet") with the payee on
  its own line, and has Undo; ⌘Z and ⌘⇧Z too.
- **A retyped beginning says what it now fits**, in real numbers: "14 rows in TDB
  Checking start with this", or "No row in TDB Checking starts with this yet". It was
  first "Payee changed", which read as the payee renamed through the ledger (budget
  review, 2026-10-12); nothing in the ledger is renamed. A typo shows as no row and a
  beginning cut too short ("IB-") as a large count: said, not prevented. Where some
  of those rows are still in Not categorized, the popup's button files them, "File
  the 9 still in Not categorized", as making a rule does; its own Undo takes the rows
  back and leaves the beginning as retyped.
- **With no rule** the page says how one is made: "No payee is always filed yet.
  Pick a category on a row in the Ledger, and the popup offers “Always file this
  payee here”."
- **Rules are read and written in one step** (`changePayeeRules`), so two changes
  made a moment apart both count (code review, 2026-10-12). A payee on an archived
  account isn't listed until the account is back.
- *Rejected by the owner:* the three places sketched, each of which put the list
  behind something else. *Not built:* making a rule on this page for a payee that has
  none; the offer from a row's Edit. *Asked again and not understood as worded*
  (2026-10-12): the same offer at the foot of a row's category dropdown; it needs
  asking with a picture of the row, not in words.
- **Owner, 2026-10-12, on seeing the questions about the page:** "What is 'Stop'? I
  don't know what you mean by this", and "You aren't using plain language. I don't
  understand what 'always filed' is." The words "Always filed under", "Stop" and the
  popup's "Always file this payee here" are not plain; they are to be replaced with
  the owner's own way of saying it (2026-10-06: "the app should offer to remember
  that for the future"). *Rejected by the owner:* an offer to move the rows already
  filed under the old category when a payee's category is changed ("No, that would
  be really bad").
- **Owner, 2026-10-12, later:** "Just put delete. Why would you put stop?" The button
  is **Delete**, the popup "Deleted" with the payee on its line. The column is
  **Category**, and the popup's offer is in the owner's own words from 2026-10-06
  ("remember that for the future"): "Remember this for next time", then "Groceries
  remembered for next time · 9 more rows filed". The page is to become a real
  feature ("Like 'contains' this text, etc."): the expert's brief and the owner's
  choice are recorded under "Payees: the real feature" when made.

### Payees: the real feature (owner, 2026-10-12)

"Let's make this a real feature. Fire up an agent who is expert in this area and see
what feature we need to add to make this really nice. Like 'contains' this text,
etc." The expert's brief (ROADMAP "Payees: the real feature") found that "starts
with the payee" misses most rows of a Mongolian bank file: a TDB row with no
counterparty is the bank's own text ("POS 12345678: НОМИН"), and Khan and Golomt
put the shop or person in the middle. Two layouts were drawn
(<https://claude.ai/artifact/7RXhhAREPqtfxLMDrU12ac>); the owner: "B. Looks
great." Then: "We should allow them to apply a payee rule to multiple accounts."

- **A payee is a row of a table now** (`payee_rules`, schema v19), not JSON in a
  setting: its words, where they are looked for, its category or pay, and the
  accounts it holds on (`payee_rule_accounts`). The upgrade carries every rule the
  setting `import.rules.<account>` held over, with an id that is the same on every
  computer that carries the same setting (the first look after both upgrade still
  asks, as any change of version does; from then on the two hold one rule, not
  two), and leaves the setting in place. One whose
  category is gone is left behind.
- **Layout B.** A closed line reads as a sentence: "starts with «Unitel»" or "has
  «Номин» anywhere", the words in ink and the rest quiet, whatever order the
  language puts them in; then its accounts (one by name, "All accounts" with more
  than one, a few by name; the column only with more than one account), its
  category as a row's chip, and **Delete**. A click on the line, or **Add a payee**
  (green, top right; ⌘N on this page), opens its Edit in place: the words as the
  heading field; **Where**, two buttons, "At the start of the payee" and "Anywhere
  in the payee or the bank's description"; **Accounts**, a dropdown of checkboxes
  as Paid from is, nothing ticked on a new payee (owner: no autofill; with one
  account there is no row and no choice); **Category**, the row's dropdown with the
  accounts' pays leading by name; the count in real numbers as the words are typed,
  "14 rows have this · 9 still in Not categorized · 2 in another category" (a word
  too short, "QPay", shows itself as a large count: said, not prevented); **How a
  row will read**, one real row that fits, drawn with the chosen category; Cancel
  and Save. Enter saves, Esc closes (a dropdown first), a click on the page away
  from it closes it. Save with something missing says what, in red: "Type a payee,
  or a word in it · Pick an account · Pick a category".
- **Save says what it remembered**, "Groceries remembered for next time", and
  offers "File the 9 still in Not categorized": those rows, and only those, are
  filed under the category (or taken as the pay's paychecks), its own Undo. Rows
  already in a category are never moved (owner: "No, that would be really bad").
- **Delete means the app stops putting that payee there by itself.** The popup:
  "Deleted · new rows of this payee stop going to Groceries by themselves". An
  import with no rule files a payee where it went last, which would put it straight
  back, so a deleted payee is kept as deleted and that fallback is skipped for its
  category; a row filed under another category by hand afterwards takes over. Rows
  already filed stay.
- **On import**, the longest words win, then the one made later (the latest
  decision), then the id; words anywhere look in the payee and the bank's
  description; "at the start" looks only at the payee. The same words twice on one
  account aren't saved ("«Nomin» is already in the list"). The popup on a ledger
  row still remembers the payee by the start of its name, on that account.
- *Not built, on the list* (ROADMAP): a payee that is money moved to another
  account; "Shown as" (a clean name on import); only money in or out; an amount
  floor; a second spelling on one line; the offer from a row's Edit and at the foot
  of its category dropdown.

**The owner's answers the same day:** (1) TDB's export carries no shop name on a card
row (the payee is the card's number, the memo the terminal's and the bank's words
for a purchase): "Nope. That's why it's so important for users to enter their
transactions rather than relying on TDB." Nothing to build; the app's worth is in
what people enter themselves (the phone, the entry row), and an import is the
check. (2) The popup on a row keeps remembering the whole payee by its start: "By
default, yes, it should remember the whole thing, but they should have the
ability to fine tune if needed"; the Payees page is where it is fine-tuned. (3)
Instead of a line at the foot of a row's category dropdown: "Let's add a check box
on the transaction for associating the payee with the category."

- **A box under the row**, in the new-transaction row and a row's Edit: "Remember
  this category for this payee", level with the lines under the category and
  amount (where "still owed" sits), out of Tab order so Enter still saves. Shown
  only while there is a payee and a category to remember (a new one too; not a
  transfer, not Not categorized) and the payee isn't already remembered so on that
  account. Unticked to start. Ticked, the category is remembered when the row is
  saved, in the same write and the same undo as the row: the popup reads "Gobi
  added · Clothing remembered for next time", or "Changes saved · Dining out
  remembered for next time", with the offer to file that payee's rows still in Not
  categorized. The popup's own offer after a category is picked stays.

### Two computers: the one row both changed (2026-10-12)

Built as the rest of decision 1 of "More than one computer on one ledger"
([ADR 0005](0005-mobile-companion.md), "Built, 2026-10-12: asking about the one
row"). Owner, 2026-10-12, told the app would still ask which whole ledger to keep
when two computers changed one row's amount two ways: "There is no way around this.
If they both changed the same entry, you'll have to have someone decide which one
to keep if they're different. Let's do it."

- **Three sketches were offered** (one list of every row with two sides each; one
  row at a time; a list with "all of this computer's" and "all of the laptop's"
  at the top). The owner chose none of them as drawn: "It would be very rare that
  there would be multiples like this, but if there did, there should be an option
  to accept from remote machine, accept from local machine or reject altogether
  for each entry. We can have those buttons on every transaction being asked
  about, though, so there aren't a million screens to look at." So: **one window,
  a card for each thing, three buttons on each card**: **Keep this computer's**,
  **Keep The laptop's** (the other computer's own name), **Neither: as it was**.
  Each card says what each computer says and, under both, "As it was: …". One
  **Save my choices**; **Not now** and Esc leave it as it is.
- **What is asked**: a transaction changed two ways (an amount, a date, a payee, a
  memo, the category), a transaction deleted on one and changed on the other (the
  card says Deleted), and what one category is assigned for one budget period
  changed two ways. The owner said yes to the deleted-and-changed kind too ("Also
  deleted vs changed"). A row both made, a pay or plan changed on both, an
  account renamed on both, a setting changed on both, and **a reconciled row**
  still ask which whole ledger to keep: a lock the owner chose stays whatever is
  picked.
- **A default, not a required choice**: each card starts on Keep this computer's,
  which changes nothing on this screen. Save is never greyed.
- **Nothing comes in, and nothing is written to the folder, until it is answered**,
  so that only one computer is ever asked. What doesn't conflict comes in with the
  answer, in one write. Put off, Settings says "changed on another computer too",
  in red, with **Choose…** (the same button the whole-ledger question has).
- The popup after is the one for other computers' changes, with no Undo: this
  computer's ledger as it was is in Backups.
- Sent to the budget-app review and the code review before it was called done;
  see STATUS.
- **The same day, the owner reopened the whole design** ("I don't want them to
  have to make this decision"; "Databases are made for this type of thing") and,
  after four expert reports, chose a change file per computer with the shared
  ledger a derived snapshot (ADR 0005 "Two computers: the way chosen,
  2026-10-12"). This window survives it; it will read as a thing already done
  that the person may change, since both computers settle a crossed change the
  same way first. Rejected with it: patching the one shared file (A) and the
  owner's master-plus-lock proposal as written (C).

### Two computers, step 4: told after, not asked before (2026-10-17)

Step 4 of ADR 0005's change files: both computers settle a change made two ways the
same way at once (a fact first, then the computer that had seen more, then a fixed
order), so the ledgers agree and nothing waits for an answer. Only the person whose
change was replaced is told. Three sketches were offered for how (a popup in the
corner with Show; the popup plus a "Changed on both" tab in the register; the window
opening by itself, saying it's done). The owner chose **A, the popup** (2026-10-17:
"let's go with A").

- **The popup is the one for another computer's changes** (gold, in the corner), with
  a whole sentence per thing replaced: "Nomin on 2026.10.07 was changed on both
  computers. The laptop's ₮21,000 is kept on both; yours was ₮17,000." More than
  one: a count and Show. It **stays until closed or Show is clicked** (the first run
  on two Mac accounts: a popup went away before the owner looked).
- **Show opens the row window as a thing already done**: titled "Changed on both
  computers", "Both computers now show the same, so nothing waits on you. Change any
  you want, and The laptop gets your change too. What was replaced is saved in
  Backups." Each card keeps its three buttons, with the version in the ledger
  marked "in the ledger now" and its button on; **Done** closes it, saving any
  button changed. An answer is an ordinary change the other computer takes in.
  There's no Undo on the popup (another computer's doing); a button changed in the
  window is this person's own act, with undo and redo.
- **Nothing is held back any more**: this computer's changes and the phones'
  entries go to the folder at once. "Not now", the red "changed on another computer
  too" line in Settings and its Choose… go.
- Settled with no card at all (the money rules agreed 2026-10-12): a rename on both
  keeps this computer's name; deleted on one and changed on the other stays, said
  with Show and "Delete it anyway"; one payday confirmed on both is one payday.
- Rejected: B, a register tab that would almost always be empty; C, a window over
  the person's work for something already settled.
- **Built 2026-10-17** (ADR 0005, "Built, 2026-10-17: step 4"). Decided along
  the way: a rename on both can't keep each computer's own name (the two
  ledgers would never agree), so one name is kept on both by the same rule as
  everything else, and the computer whose name was replaced is told: "Groceries
  was renamed on both computers. The laptop’s name, Food, is kept on both; yours
  was Food & drink." A pay, a plan or a setting changed on both, and an account
  deleted here and used there (it stays), are said in the popup only, with no
  card in the window. A row whose reconciled or bank-matched money was kept
  with the other computer's category shows a third box, "In the ledger now",
  since neither computer's version is what the ledger holds; no button is on
  until one is picked. The version in the ledger now is marked "in the ledger
  now" in gold (done and safe). The popup's sentence names what differs, as a
  person would say it: the amount, else the categories, the date, the payee or
  the memo.
- **From the reviews, decided (2026-10-18).**
  - *The popup that says something was replaced is never replaced.* Any other
    popup shows above it; bringing in the other computer's changes and the
    phones' entries goes on while it is up. What it says is kept in the
    encrypted ledger as this computer's own setting (`sync.told`, with the
    ledger's id) until the window is opened or it is closed with ×, so after a
    quit it is back at launch; it goes with a restore, an erase, a ledger taken
    whole from the folder, and when the folder is stopped, and is never shown
    on another ledger. Show reads each thing again from the ledger as it is
    now, the lock with it: a row reconciled or matched to the bank since keeps
    that money whatever is picked.
  - *The window lists everything the popup counts.* A pay, a plan, a setting or
    something that stays is its whole sentence, with no buttons.
  - *The title keeps the payee* when one transaction came: "E-Mart from The
    laptop", "E-Mart and 1 change from The laptop"; the thing settled isn't
    counted among "other changes".
  - *The sentence is about what this computer changed*: "Your cleared tick on
    Nomin ₮17,000 (2026.10.07) was undone; The desk Mac changed it at the same
    time." A row deleted here that stays gives its amount, account and what
    that does to the balance: "You deleted Nomin ₮17,000 (TDB Checking) on
    2026.10.07; The laptop changed it, so it’s back, and TDB Checking is
    ₮17,000 lower than you left it." The account is named when it differs, a
    transfer's amount is said once, a split gives each category's amount, the
    sign is kept when the two go opposite ways, and an empty memo or payee is
    said ("no memo"). A pay gives its amount and day ("The laptop’s ₮2,500,000
    on the 15th is kept on both; yours was ₮2,450,000 on the 10th"); a pay is
    settled column by column. A setting is named where it can be; "stays" names
    the transaction put in it.
  - *When a fact decided, the fact is said*, not the computer: "₮21,000, the
    amount the bank shows, is kept on both; yours was ₮17,000", "…the amount
    reconciled on 2026.10.05…".
  - *Assigned as a person says it*: "Groceries in October", or "for the pay
    period starting …"; an amount moved between two categories while the
    other changed one of them names both in one sentence.
  - *A locked row in the window*: on a row whose amount is reconciled or the
    bank's, the buttons change only the payee, memo and categories, and the
    card says "The amount is the one reconciled on 2026.10.05 and stays." (or
    "…the one the bank shows and stays.").
  - *Three or more computers*: a row changed two ways is asked in the window
    before anything comes in, as before step 4 (Not now, Save my choices, the
    red line in Settings), since the rule is exact for two.

### Two computers: asked before, after all (2026-10-20)

Testing step 4 on the two Mac accounts, the owner met the asking window
instead of the popup: the folder still held change files from three earlier
test installs, so the app counted more than two computers and asked. They
chose it over sketch A ("I actually like how that showed me"; "Yes, let's
reverse it"). This reverses "Two computers, step 4: told after, not asked
before" above.

- **A row changed two ways is asked before anything comes in, with two
  computers as with more**: the window with both versions, the three buttons
  on each card, **Not now** and **Save my choices**, and the red line in
  Settings while it waits. Until then this computer's changes and the phones'
  entries stay out of the folder, as the window says. Answered on one
  computer, the other takes the answer in and is not asked again (seen in the
  real app, and in `two_computers_test.dart`).
- **The window's first sentence goes**: "Three or more computers share this
  ledger, so BetterBudget asks rather than settling it by itself." It opens on
  "Choose which to keep for each.", in Mongolian too, so no new Mongolian.
- **"the other computer" inside a sentence is lowercase**: "Keep the other
  computer’s" (it was "Keep The other computer’s").
- What else step 4 built stays: the change files, what each computer had
  applied, shared ids, the locks on reconciled and bank-matched money, the
  title that names the payee.
- The settling rule, the popup that stays and the window opened as a thing
  already done are removed (0.41.1, #218), with their sentences. The popup's
  setting a 0.41.0 ledger may hold is cleared at launch. A folder file from a
  build before change files with anything changed on both (a row, a setting,
  a payee or account, one deleted on one and used on the other) now gets the
  whole-ledger question: step 4 had settled it, and there is no window to ask
  from a whole file.
- Rejected: sketch A, told after (2026-10-17), now that the owner has seen
  both.

## Where a row came from: a Source column (2026-10-13)

Owner, watching the first run on two Mac accounts, after the popup went away before
they looked: "Let's add a small transaction that shows the original source of the
transaction", chosen as A, "Each new transaction records which computer made it, and
whether it was typed, imported from a bank file, or came from the phone", "this is
optional. We should be able to turn off this column", and "we should also be able to
list a given phone as a source".

- **A column between Category and Amount**, headed Source, one line per row: "Entered
  locally", "Entered on Mac mini", "Imported on …", "From Pixel", "Scheduled", "Opening balance",
  "Reconcile adjustment". On, and Settings → Register → "Show where each transaction
  came from" turns it off (the owner asked for a column they could turn off, and
  first saw none because it had been built off). The entry row keeps the column's
  place empty so the others line up. A row whose payee already says it (Opening
  balance, Reconcile adjustment) says nothing in it. At the smallest window (1360 ×
  760) it takes about 144 px from the payee, which then shortens; if that bites,
  the answer is to hide the column on a narrow window, not to shrink it further.
- **A phone is named in the same panel**, one box per phone that has sent a row.
- Rows from before this say nothing in the column; it isn't guessed.
- Rejected: an Edit-only line (the owner asked for a column), a mark on the row.
- Wording and the Mongolian are a draft ([mongolian-review.csv](../mongolian-review.csv)).
- **Words, settled the same day:** a row made on the computer reading it says
  "Entered locally" (first "Typed here", which the owner found confusing: "Why not
  Entered locally or something"; "typed" became "Entered" throughout); and a name is kept against the id, so
  renaming a computer or a phone in Settings shows on every row ("We should have a
  rename. The name should be associated with a primary key").
- **The same Mac reads "Entered locally" under both of its accounts** (owner,
  2026-10-13: "since it's the same computer, it's local on both accounts").


## One receipt over several categories: the split card (2026-10-17)

Owner, 2026-10-12: "I go to Walmart and buy clothing and groceries under one receipt.
I'll need to be able to handle that." Shown three sketches on 2026-10-17 (one
Nomin receipt of ₮135,500: ₮98,000 groceries, ₮37,500 clothing), they chose **C, a
card for the receipt**, and that **Add waits** while some of the total has no category.

- **"Split over categories…" sits under Category's list**, below a line, so it isn't
  scrolled past in a long list of categories. Picking it opens a card under the row:
  "Nomin, ₮135,500.00" at the top, with what's left to place on the right
  ("₮37,500.00 left", "₮2,000.00 too much", nothing when it adds up), a Category and
  an Amount on each line, ✕ to take a line off (while there's more than one), "+
  Another category", Cancel and Done. The first line takes the category Category
  named, if it named one; amounts are never filled in for them.
- **Done** closes the card and Category reads "2 categories"; a click on it opens the
  card again. Empty lines go. One line left that takes the whole amount makes the row
  an ordinary one in that category. With Amount empty, Done puts the lines' sum in it.
  **Cancel** or Esc puts the lines back as they were when the card opened.
- **Add waits** until the lines add up: the popup says "Place the last ₮37,500.00"
  and the card opens on the line to fix. Rejected: saving the rest as Not
  categorized.
- Enter in a line's amount goes on to the next line still missing its category or
  amount, then opens a new line while some is left, otherwise it is Done. Line
  amounts take the calculator, as Amount does. A line the other way from the row (a
  return on the same receipt) is typed with a minus, and the register shows it with
  its sign ("Clothing +₮5,000" on money out).
- The option is offered whatever Category says, and the first line starts from the
  category named there. Category reads the count of lines while the card is open,
  then the categories they name.
- A split whose lines are all Income is money in, as a row filed under Income is.
- **Editing a split**: double-click its category and the card opens on its lines.
  A reconciled split keeps its date and total, and its lines can still move between
  categories (only the bank's side is on a statement); undo moves them back.
- A split saved with its lines and total untouched (a new memo) leaves its entries
  alone, so a deleted category on one of its lines doesn't stop the save.
- Lines take existing categories in the row's currency (a tugrik and a dollar
  Groceries can both exist; the database refuses the wrong one); a name no category
  has is offered as "+ New category “Toys”" on its line too (see below). Two lines for one category are
  saved as one. Not categorized isn't offered on a line: a split never shows in the
  Not categorized tab, so money put there would be forgotten.
- **A split names each category once** (owner, 2026-10-17, trying it: "It lets me
  choose the same category twice in the same split. Can't think of a time that
  would be useful"). A line's list leaves out the categories other lines have; one
  typed anyway gets "“Groceries” is already on another line" on Add. A split saved
  before with a category twice (after a merge) opens with those lines as one.
- A split brought down to one category in its card is saved as an ordinary row in
  that category, reconciled or not.
- **From the reviews, decided** (2026-10-17, issue #197):
  - A line's category list offers "+ New category “Toys”", as the row's own list
    does, in the row's currency; picked, the category is made when the row is
    added, and the undo of the add takes it away with the row. Only picked: a name
    typed and left gets "There's no category “Toys”" on Add, so a typo doesn't
    quietly become a category.
  - A split is found as the bill already in when an ordinary row with the same
    payee, dates and total would be. A plan's bill confirmed as a split stays that
    bill while one of its lines is in the bill's category; once none is, it no
    longer counts as that bill (the next bill and "already in" see it so; the tie
    stays on the row, so a line moved back makes it the bill again). A split with a
    line in the bill's category is tied to the plan when "Already in" picks it.
  - Merging a category into another where one receipt has lines in both makes them
    one line, the amounts added; the merge's undo puts the two lines back as they
    were. Two that cancel out (a return of what was bought) leave no line when the
    receipt has another.
  - Search finds a split by any of its lines' categories.
  - The row's second line shows the breakdown, then the memo ("Groceries ₮98,000 ·
    Clothing ₮37,500 · birthday"), cut at the end as before; each share as money
    shows elsewhere, unrounded ($45.99 stays $45.99).
  - With Amount empty and lines typed, the card says "The total is money out." (or
    in) under its heading, with "Change to money in" beside it: money out is the
    default, not a question. Done or Add puts the total in Amount that way.
  - An even exchange on one receipt (a ₮37,500 shirt returned for ₮37,500 of
    groceries) is a split of 0 when its lines go both ways; the card says "The
    lines even out, so the account's balance doesn't change." It is stored as any
    split, the account's side at 0 (no schema change). Lines one way can't come to
    0.
- Rejected: A, lines straight under the row; B, a total that adds itself up and
  is never checked against the receipt.
- Not yet on the phone.
- **On the phone** (owner, 2026-10-17: "It needs to be able to split"), chosen from
  two sketches as **A, a split page**: "Split over categories…" sits at the foot of
  the phone's Category list beside "+ New category"; it opens a page with the total
  and what's left, a line for each category (the one already chosen first), "+ Another
  category", and the amount pad, which types into the chosen line; tapping a chosen
  line again changes its category. Done goes back to the entry screen, where Category
  reads "2 categories" and each share shows under the amount. Save waits until the
  lines add up, and each category is on one line, as on the computer. The toast says
  what's left in each category, a line each. Rejected: B, the lines inside the entry
  screen, which crowded it and shrank the pad. How it travels: ADR 0005.
  From the reviews (decided along those lines): the split page offers only categories
  in the receipt's currency; it says "₮37,500 to place", not "left", which on the
  phone is what a budget has; Save that finds the lines don't add up, or a line whose
  category has gone, opens the split page; a category tapped on Budget while a split is
  being typed joins its lines instead of replacing them; deleting a category made on
  the phone says the whole amount of a split that uses it, since the split goes whole;
  and a waiting split shows its shares, or says "A category in it was deleted on your
  computer. Delete this and enter it again." A line the other way from the receipt (a
  return) is marked **Returned** on the split page (ADR 0005, "From the reviews of the
  phone split").

## The phone's categories: a dropdown on the entry screen (2026-10-17)

Owner, after splits came to the phone: "I don't like how you have to switch to the
budgets page to pick stuff. Let's have users just choose from a dropdown on the same
screen with Split (and a split icon next to it) at the top." The Category list was a
page of its own in front of the entry screen, with every category as a card and what's
left in it: it read as the Budget page.

- **The Category row opens a dropdown under it**, as wide as the row: **Split** with
  the split icon first, then Income (money in only), each category with what's left
  in it, those waiting for a bill under Bills, the accounts money can be moved to under
  "Move to an account", and "+ New category" last, which asks for the name in a box.
  A split's Category row opens its split page, as before.
- **On the split page**, "+ Another category" and a chosen line open the same dropdown
  (no Split in it; only the receipt's currency; no category another line has).
- Gone with the page: the box that narrowed the list as a name was typed, "ATM" or an
  account's name finding the accounts, and Income found by its Mongolian name. The
  dropdown lists everything; a long one scrolls.
- **On the computer too** (owner, 2026-10-17, after trying the phone: "On the computer,
  I want it similar. The split icon next to 'Split' at the top of the category
  dropdown"): the entry row's Category list opens with **Split** and its icon at the
  top, over a line, then the categories. It was "Split over categories…" at the foot.
  Typing still narrows the list and Split stays at its top; the keys start on the first
  category, so "Gro" and Enter picks Groceries, and Up from it reaches Split.

## No overflow stripe: amounts shrink, names end in "…" (2026-10-20)

Owner, 2026-10-14: "that yellow and black overflow appears in both the phone app and the
computer app. We need to constrain things so the user doesn't see that." It showed in an
account's header, where a working balance of more than a hundred million tugrik, with
cents, ran past its box (issue #127).

- **An amount or a date is drawn smaller until it fits** (`Shrink` in `theme.dart`),
  never cut, never wrapped onto a second line: a cut amount reads as a different
  number. Every `Money` does this by itself; where it fits it is drawn exactly as
  before. So do the header's Working line, the forecast's "Lowest … on …" and its bills
  line, Budget's three sums and Net worth in the sidebar.
- **A name ends in "…"**: an account, category or payee in a row, a button or a list.
  The words the app writes wrap.
- **A sentence with an amount in it wraps**, so the amount is whole (from the
  reviews): the phone's "… left after this" and a split's shares over the pad, the
  forecast's "runs out on … · … short", the reconcile hint. One exception: a row's
  memo line in the register, which holds a split's shares, stays one line and ends in
  "…"; the row opens to every share whole.
- **Two names that start the same may read the same once cut**, and that stays (owner,
  2026-10-20, on the review's offer of a hover or a cut in the middle: "Life is
  rough. This isn't an issue, this is just the nature of space on the screen").
- **New account's Type buttons** fit in one row in Mongolian: the card is 600 wide (was
  560), and a font that draws them wider puts the third on a line of its own.
- `test/overflow_test.dart` lays out every page, panel and phone screen with balances
  past a billion tugrik, with cents, and names some fifty letters longer, in English
  and Mongolian, at the smallest window and a large one (the phone at 390 and 320
  wide). It fails on any overflow, on text cut off without "…", on an amount that
  wraps, on an amount cut with "…", and on one drawn below 60% of its size.

## New category: one window with everything (2026-10-22)

Owner, 2026-10-22 (#237): "when they select add category, I want to have a pop up
window with all the options, and an option to add another." Add category (and ⌘N on
Budget) opens a **New category** window holding the category's Edit form as it is:
name, currency (with accounts in two), "Is there a due date?" and its answers, Paid
from, and the row as it will read. Nothing new to learn: the same questions and words
as Edit. Buttons: **Cancel**, **Add another** (⌘↩, Ctrl+Enter), **Add** (Enter). This
replaces the name-only box whose Edit opened under the new row (2026-10-05): everything
is set before it's made, so nothing opens after Add.

- Sketched three ways (design committee): **A, Edit's form in a window (chosen)**;
  B, the form on the left and the row on the right (rejected: a second layout, wider);
  C, a list of several new categories added with one button (rejected: one category,
  the usual case, gets harder, and Cancel throws away all of them).
- **Add another** adds this one and empties the form, cursor in the name. Only the
  currency stays: a Yes kept from Rent would make Food a bill unseen. "Added: Mobicom ·
  Taxi" under the title is the sign they went in.
- Each Add is its own undo, the category with its accounts and plan together.
- A name already in use says so as it's typed: a category ("Groceries is already a
  category. Add opens it.": Add closes the window and opens its Edit), an archived one
  ("… is archived. Add brings it back.", with what the window set), or a bank account
  ("An account is already called TDB Checking. Give the category another name.": one
  list of names holds both, so this one stops Add). No name: "Enter a name".
- Esc, Cancel or a click outside close it; what was added stays.
- A bill's Set aside each month shows the amount alone, here and in Edit (owner:
  "Remove 'worked out from the date'").
- **The entry row's "+ New category"** (in Category and on a split's line) opens the
  same window (owner, 2026-10-22). It's always in the list: **New category**, with a
  plus, at the top beside Split, opens it with no name; a name typed that isn't a
  category yet shows "+ New category “Toys”" in its place (owner, on the first build:
  "I don't see a 'new category' option in the category dropdown"; it was there only
  after typing). Either opens it with the name typed, in the row's currency (no
  choice of another: the row couldn't take it), and no Add another: a row takes one
  category. Add makes the category, its own undo, and puts it in the row, cursor in
  the amount; the row's ⌘Z is a second one. A name that's already a category says
  "Groceries is already a category. Add puts it in this row." Cancel leaves the name
  typed: saving the row then makes it bare, as before. A new name typed and saved
  with Enter, without picking "+ New category", still makes it bare with the row, in
  one undo, so typing a row isn't stopped by a window it didn't ask for.
- **The phone's "+ New category"** (on Budget and in an entry's Category list) opens
  the same questions on one page (owner, 2026-10-22, the pick of three sketches): **A,
  one scrolling page (chosen)**, Cancel at the top, Add another and Add at the bottom;
  B, a box over the screen (rejected: cramped, the keyboard covers half); C, one
  question per screen with Next (rejected: more taps, unlike the computer). Same order
  and words as the computer's window: name, currency (from Budget, with accounts in
  two), "Is there a due date?", then what that needs, Paid from, Set aside, and the row
  as it will read on the computer's Budget page. A choice opens a list from the bottom;
  Custom… opens its own page. From an entry it's in the entry's currency with no Add
  another, and a name that's already a category says "… Add puts it in this row."; on
  Budget that name stops Add, as an account's name does. The category waits with the
  phone's entries and comes in on the computer with its plan and Paid from, its bill
  scheduled; the take's undo takes the bill too. A pay or account gone on the computer
  meanwhile is left out (a plan on a gone pay: the category comes in bare). A name the
  computer already has (made there meanwhile, or archived where the phone can't see
  it) takes the phone's bill when it has no plan, and an archived one comes back; one
  with a plan keeps the computer's, and its own Paid from either way (budget review).
  A due date is picked from today on, as a date typed on the computer rolls ahead. A
  computer on an older version takes the category in bare.


## Move money between categories (2026-10-23)

Rule 26 said "money can be moved in from another category any time"; until now that
meant typing two Assigned amounts (#99). The owner picked **A of three** from sketches
("I like both A's", both directions of it):

- **Click a category's Left.** A box opens under it (above it when the window has
  more room there) with **From**, **To** and **Amount**, Cancel and **Move** (Enter);
  Esc or a click away closes it. One side is the category clicked, as plain text; the
  other is a list, empty until chosen ("Choose a category"), each choice with what it
  has: "₮18,500 left", or "₮32,000 overspent" in coral.
- **With money in it, the money goes out** (From is this category). **At zero or
  below, money comes in** (To is this category), and Amount starts at what it's short:
  the one figure the screen already shows, not a guess.
- **Not assigned** is first in the list, apart: in To always, in From only while it
  holds money, with its amount alone (no "left"). Then every other category in the
  same currency (rule 28); a category in another currency isn't offered, and nothing
  says so. With nothing to trade with, Left is plain, not a button.
- **More than it has still moves** (warn, don't block), said in plain ink with the
  real numbers: "Groceries has ₮18,500 left. After this, it will be ₮13,500
  overspent." From Not assigned: "Only ₮420,000 is not assigned. After this, you will
  have assigned ₮30,000 too much."
- A move lowers one Assigned and raises the other in the period on screen, one undo
  and redo; nothing new is stored, so no schema change. Unlike typing an amount it
  has a toast, since it changes two lines: "Moved ₮32,000 from Groceries to Dining
  out", "Assigned ₮32,000 more to Dining out", "Moved ₮32,000 from Groceries back to
  not assigned". A plan's "assign ₮X" offer comes back on the line money left, as it
  would after typing a lower amount, for the rest of the period (owner, asked
  2026-10-23: "Yes").
- Words by the UX writer: "Cover" (other apps' word) and "Transfer" (in the ledger,
  money between accounts) were left out.
- Rejected: **B**, drag a Left onto another category (quick, but nothing on the page
  says it can be done); **C**, a "Move money…" button on the top line opening a window
  (easy to find, but both sides must be picked, even from the line that's short).
- **Bills and the safety net stand apart in the list** (budget review): categories
  waiting for a bill under **Bills**, the safety net under **Saved**, as on the phone
  and the Budget page, so neither reads as money to spend.
- **A category budgeted by a pay, seen by month, takes the whole move in one of its
  own pay periods**: the one today is in, or the last one in the month (both reviews).
  Spread over every pay in the month, part landed on a pay already over and Left moved
  by less than the toast said.
- **Found by pointing at a row** (owner, 2026-10-23: "Looks good, but it's a hidden
  feature. How would people know that's how they do it?"). With the pointer anywhere
  on a row, its Left is outlined with **Move money** beside the amount ("it should
  say 'Move money'", not "Move"); at rest the page is as before. The Left column is
  wider for it, and a plan's note under a name wraps instead of being cut. The design
  committee's sketches: **2, the row pointed at (chosen)**; 1, "Move money in" under
  every amount that's short (rejected: the same words seven times on a bad month); 3,
  short amounts outlined at all times and "Assigned too much" opening the box
  (rejected: a column of red boxes). The first-time reader would have clicked
  Assigned or the ⋯ first: "Left" reads as a result, not a thing to change.
- **Money coming in lists the categories with most to give first** (first-time
  reader: Groceries was under three lines at ₮0).
- **Either way from any row** (owner, 2026-10-23: "I think they should be able to
  move money in or out regardless"). The box still opens out when there's money and
  in when it's short, and **Swap** beside the fixed side turns it around (the
  ledger's word for turning a transfer around); a choice that can't be on its new
  side (Not assigned with nothing in it, as From) is let go.
- The computer only: the phone records and checks (ADR 0005).

## Uninstall leaves nothing behind (2026-10-23)

The Store app first kept its ledger in the zip download's folder, so an uninstall
wouldn't take it. The owner: "I call it garbage." What an app leaves behind on
uninstall is garbage; the person keeps their recovery key, and uninstall removes the
saved one from the machine. The Store app now keeps everything in its package's
folder, which Windows deletes with it (ADR 0001 "Where the ledger lives on Windows").
