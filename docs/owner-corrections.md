# What the owner has corrected

Read this before any work on a screen or its words. Each item is something that was
built, or proposed, and that the owner sent back; what they wanted is in the brackets.
The reasoning and the date of each are in [ADR 0004](decisions/0004-ledger-ui.md).
When the owner corrects something new, write it into ADR 0004 and add it to the end of
this list. Moved here word for word from CLAUDE.md on 2026-10-07.

no In/Out columns, no month subheadings, symbols that look like checkboxes, entry that
only works left to right, no savings suggestions yet, shortcuts that swallowed typing,
no way to edit a transaction, "not posted" wording for uncleared (banks show pending), a
dash symbol that read as a minus sign, a separate big balance above the header sum,
"latest cleared" date (noise), a reconciled amount (only the date matters), a sidebar
layout (option A chosen), Delete removing reconciled rows, a chevron on sidebar sections
(it promised a toggle), an always-visible blank entry row, a "+ for money in" hint,
multi-select (not wanted yet), a toast on every cleared-symbol click (toasts are for
saved changes; ⌘Z undoes anything), and an income name under the forecast's end date
(both ends show plain dates), a bank balance prefilled with the cleared total,
reconciled rows whose payee couldn't be fixed, a row hover as faint as the row stripe, a
separate cash-account counting flow (not wanted yet; on the roadmap), "a different
amount each day" for split pay (it's each paycheck), a dark theme built from one color
in lighter and darker shades (surfaces should differ), "tögrög" in English (spell it
"tugrik"), and sidebar balances rounded to whole units (show the cents), a toast when an
account is made, "settled" (the app's word is cleared), "Put in how much comes" for pay,
and a forecast a new user couldn't read (unlabeled chart, "Never below today's",
"Pay"/"Next pay", a hint and link that read as AI-speak), and search at the top of the
page (it belongs in the register's tab row), "Put in" for budget amounts (the word is
**Assigned**), and questions worded in the app's internals instead of a plain example,
and a logo recolored by the scheme, a light band behind it, and a white glow around it
(the sidebar shows a dark-mode logo), and a Budget page that stopped two-thirds of the
way across the window (pages fill it), and a window that shrank until an account page
ran out of room (it stops at 1360 × 760), and credit cards left out of a category's list
of accounts (a card is an account; if they plan to pay with it, let them), and too many
menus on a budget category (its menu is Edit and Delete, a double-click opens Edit, and
everything about it is in Edit), and an Edit that Esc or a second double-click didn't
close, and a button for each currency (a Currency dropdown: every currency is to be
supported), and a category's accounts laid out as a list in the panel (a dropdown of
checkboxes), and a currency's code at the start of some rows and the end of others
(always at the end), and made-up currency symbols (`CA$` where Canadians write `$`: show
the real one, and tell two apart only when a ledger holds both), and income categories
(there's one built-in Income; "not assigned" is where money needing a category shows),
and "Came in" for a period's income (the word is **Income**; use the plain word people
say), and "Everything has cleared" beside a zero Uncleared line (don't tell them what
they already know), and ⌘K shown as the search key (it's ⌘F; ⌘K was copied from other
apps), and "Say how much arrives in…" squeezed beside Add (why a row can't be saved goes
in the popup at the bottom, worded like "Enter an amount", not like a child talking),
and an Edit only Esc could close (everything must work with just the mouse: a Cancel
button, and a click away), and "Kind" for an account's type (the word is **Type**), and
five plan types of which two came to the same number (two now, behind one question: "Is
there a due date?"), and "Any time" as an answer to when money is spent (a non-answer:
"it's going to be spent some time"), and a category's Edit laid out as a row of fields
("all the features shoved on a page": it's designed as one thing, the name as heading, a
short labelled form, the row drawn as it will read), and a wizard for making a category
(the one question is the panel's first line), and two account dropdowns in a category's
Edit (one row, **Paid from**), and a new category left closed after Add (its Edit
opens), and "Every…" for the repeat you set up yourself (the word is **Custom…**), and
Budget by as a setting (it's a view on the Budget page, and each category has its own
period: month or a named pay; a set amount seen by another period is prorated by days),
and a minus beside "Not assigned" (it stops at zero and a red row, **Assigned too
much**, holds the amount), defended because "the sum adds up" (arithmetic that's right
can still confuse; don't think like a computer), and "2 rows not categorized" on the
Budget page (it belongs on the ledger page: a tab in the register's tab row; say a thing
where it's fixed), and the bank's own category brought in as an imported row's memo (not
wanted; it's left out), and a tab listing every row ever left without a category (noise:
the Not categorized tab holds the current budget period's), and questions written as
fragments that lean on work the owner hasn't seen (whole sentences, with what's on
screen), and dollar categories offered in a tugrik account's category list (a row is
offered the categories in its own currency), and a popup that was one long line across
the window, over the sidebar, saying the payee twice (it's a card in the page's corner:
what happened, the payee on its own line, the offer as a button), and money out in plain
ink with no sign (it's red with a minus in front), and a currency choice, and a new
category made in dollars, with only a tugrik account left (a thing is offered only while
there's something for it), and "All accounts" on a category with one account (it's
named), and being made to pick where a category's deleted rows go (don't ask about what
they can't see), and a setup that asked for every account they keep money in or owe
money on (they add only the accounts they want to track), and three rebuilt budget rows offered
when the Assigned, Spent and Left columns were hard to tell apart (two vertical dotted
lines between the columns: take the small fix they'd reach for before redesigning), and the
Mac's file in the cloud folder described as a small summary for the phones, with the
ledger staying on the Mac (all of the data goes in the cloud folder: the whole ledger,
as an encrypted copy the Mac keeps current there; ADR 0005), and a line saying where the ledger is
that appeared only after a folder was picked (it always says where the ledger is stored
now: "This computer", or the folder), and "Keep my ledger in a folder…" (the word is
**move**), and the ledger in the folder named with `.sqlite` (its own extension:
`Ledger.betterbudget`), and a new extension given to some of the app's
files and not others (all of them or none: every ledger file ends in `.betterbudget`), and a payee already chosen on the phone's amount
screen, with more as buttons under it (no payee filled in and none laid out; the
ledger's payees are offered only as one is typed), and rent's money listed on the phone among the money to
spend, in the same ink (categories waiting for a bill go under their own heading,
**Bills**, quieter), asked about with a category called Housing (rent is in a Rent
category: an example uses the names a person would), and a + on every
category row of the phone's first screen, which opened on the budget (it opens on
**Ledger**, everything a transaction needs on one screen; the category is picked from a
list or typed, and the list can make a new one; Budget is the other screen), and being asked whether
Save could go ahead with no payee (there is always a payee: they'd write "Taxi"), and
"the Mac" on the phone (it's **your computer**), and a line after Save that said only
what was saved (a toast that says what the entry did to its category: "Groceries ·
₮135,500.00 left"), and that toast built as a card set into the page (a toast
appears over the page and goes away by itself), and an account already
filled in under the phone's Paid from, then a question about which account to fill in
(don't autofill: the row is empty until they choose), and color options for a navy and
green logo that came out navy and blue, because green had been kept for money in alone
("Why no green in the color scheme?": the logo's colors are at work in the app, so the
main buttons are its green; a rule that takes a brand color out is a trade to show,
not to settle for them), and gold on about forty things that weren't done yet or were
only a heads-up, a scheduled bill among them ("Gold is an accent color. Don't overuse
it": gold is for what is done and safe; not-yet is gray with a blue Confirm, and a
heads-up is plain ink), and money out in red (ordinary ink, with its minus: "I said I
wanted the outflow to be normal color instead of red"; this replaces "it's red with a
minus in front" above. Red is left for a shortfall), and "Last copied elsewhere 41 days ago"
under Net worth ("Did it actually detect that someone on another machine backed it up
somewhere else?": a line says only what this computer did, in the word on the button
that does it: "Last backup 41 days ago"), and being asked to type a month of expenses
the budget already holds (it comes from the budget, and they can adjust it), and a
safety net counted as everything in the one account they spend from (it is kept apart:
in a different account, ideally, or in its own budget category, and only that counts), and a menu of accounts and categories to tick for where the safety net is kept and then a button that made a Safety net category (Safety net is built into the app, as Income is; its Left is the count, and on Budget it sits apart under **Saved**)., and an Undo on what another computer changed, even one that warned what it would take out on both ("Only undo what the user in front of the computer did or decided. Nothing else": the popups for another computer's changes have none; what was here is in Backups)., and "Keep this computer on this folder's ledger" for the box that keeps a second computer on the shared ledger (the word is **share**: "Share the ledger in My Drive/BetterBudget"). And a new computer that opened on "Enter your recovery key" and then asked "Open your newest backup?" (don't assume a backup: three ways to start, as when installing an OS, Start fresh, Restore from backup, Open ledger, the one clicked opening in place), and "ledger" in the first question a newcomer reads (it may be jargon: ask whether they already use BetterBudget). And a list of the payees that are always filed offered behind a menu, a section of Settings or a category's Edit ("I don't want to hide this": what they manage often gets its own section in the sidebar, **Payees**, under Savings). And "Stop" and "always filed" for a payee whose category the app remembers ("You aren't using plain language": say it as they did, the app remembers the category for that payee), and an offer to move rows already in the ledger when that category is changed ("that would be really bad"). And "Stop" on a payee the app remembers ("Just put delete. Why would you put stop?": the plain word is **Delete**).
