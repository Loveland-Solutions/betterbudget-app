import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_mn.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of Words
/// returned by `Words.of(context)`.
///
/// Applications need to include `Words.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: Words.localizationsDelegates,
///   supportedLocales: Words.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the Words.supportedLocales
/// property.
abstract class Words {
  Words(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static Words of(BuildContext context) {
    return Localizations.of<Words>(context, Words)!;
  }

  static const LocalizationsDelegate<Words> delegate = _WordsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('mn'),
  ];

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageSameAsMac.
  ///
  /// In en, this message translates to:
  /// **'Same as this Mac'**
  String get languageSameAsMac;

  /// No description provided for @languageSameAsWindows.
  ///
  /// In en, this message translates to:
  /// **'Same as Windows'**
  String get languageSameAsWindows;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageMongolian.
  ///
  /// In en, this message translates to:
  /// **'Монгол'**
  String get languageMongolian;

  /// No description provided for @languageShowingNow.
  ///
  /// In en, this message translates to:
  /// **'Showing {language} now · changes when {system} does'**
  String languageShowingNow(String language, String system);

  /// No description provided for @languageUndoLabel.
  ///
  /// In en, this message translates to:
  /// **'Language: {choice}'**
  String languageUndoLabel(String choice);

  /// No description provided for @theMac.
  ///
  /// In en, this message translates to:
  /// **'the Mac'**
  String get theMac;

  /// No description provided for @windowsName.
  ///
  /// In en, this message translates to:
  /// **'Windows'**
  String get windowsName;

  /// A date inside a sentence or list, year left out. month and day come zero-padded (09, 05).
  ///
  /// In en, this message translates to:
  /// **'{month}.{day}'**
  String dayMonth(String month, String day, int monthNumber, int dayNumber);

  /// A full date inside a sentence or list.
  ///
  /// In en, this message translates to:
  /// **'{year}.{month}.{day}'**
  String dayMonthYear(
    String year,
    String month,
    String day,
    int monthNumber,
    int dayNumber,
  );

  /// The calendar's title.
  ///
  /// In en, this message translates to:
  /// **'{month} {year}'**
  String calendarMonth(String month, String year, int monthNumber);

  /// Twelve month names separated by |. Mongolian numbers its months, so its value is unused there.
  ///
  /// In en, this message translates to:
  /// **'January|February|March|April|May|June|July|August|September|October|November|December'**
  String get monthNames;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// Button in the “Where is your ledger?” dialog: go on with the empty ledger.
  ///
  /// In en, this message translates to:
  /// **'Start empty'**
  String get ledgerStartEmpty;

  /// Toast and undo-menu label after something new is added. name is a payee, account or category name.
  ///
  /// In en, this message translates to:
  /// **'{name} added'**
  String ledgerAdded(String name);

  /// Toast after a transaction is added from All accounts. name is the payee; account is the account it went into.
  ///
  /// In en, this message translates to:
  /// **'{name} added to {account}'**
  String ledgerAddedTo(String name, String account);

  /// Part of a toast, after " · ": the category typed in the row did not exist and was made.
  ///
  /// In en, this message translates to:
  /// **'new category “{name}”'**
  String ledgerNewCategory(String name);

  /// Part of a toast, after " · ": the new transaction is dated in the future. date is a full date.
  ///
  /// In en, this message translates to:
  /// **'scheduled for {date}'**
  String ledgerScheduledFor(String date);

  /// Part of a toast, after " · ": the saved row is hidden by the search or filter in force.
  ///
  /// In en, this message translates to:
  /// **'not in this view'**
  String get ledgerNotInThisView;

  /// Toast after a future-dated transaction is added. date is a full date.
  ///
  /// In en, this message translates to:
  /// **'Scheduled for {date} · not in balances until confirmed'**
  String ledgerScheduledToast(String date);

  /// Error under the entry row or as a toast; error is the technical reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save: {error}'**
  String ledgerCouldntSave(String error);

  /// Toast when Undo is pressed on an older toast. shortcut is ⌘Z or Ctrl+Z.
  ///
  /// In en, this message translates to:
  /// **'Undo the newer changes first · {shortcut}'**
  String ledgerUndoNewerFirst(String shortcut);

  /// Toast when ⌘Z is pressed with nothing to undo.
  ///
  /// In en, this message translates to:
  /// **'Nothing to undo'**
  String get ledgerNothingToUndo;

  /// Toast when ⌘⇧Z is pressed with nothing to redo.
  ///
  /// In en, this message translates to:
  /// **'Nothing to redo'**
  String get ledgerNothingToRedo;

  /// Popup when undo fails because the data changed. action is the undo label, e.g. "Coffee added", or "Filed under Bank fees" with the row's payee on the line under it.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t undo “{action}” · it changed since'**
  String ledgerCouldntUndo(String action);

  /// Popup when redo fails because the data changed. action is the undo label, e.g. "Coffee added", or "Filed under Bank fees" with the row's payee on the line under it.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t redo “{action}” · it changed since'**
  String ledgerCouldntRedo(String action);

  /// Popup after ⌘Z. action is what was undone, e.g. "Coffee added", or "Filed under Bank fees" with the row's payee on the line under it.
  ///
  /// In en, this message translates to:
  /// **'Undone · {action}'**
  String ledgerUndone(String action);

  /// Popup after ⌘⇧Z. action is what was redone, e.g. "Coffee added", or "Filed under Bank fees" with the row's payee on the line under it.
  ///
  /// In en, this message translates to:
  /// **'Redone · {action}'**
  String ledgerRedone(String action);

  /// Button at the top right of the popup card, in the page's bottom-right corner.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get ledgerUndo;

  /// Toast when leaving a row that has unsaved edits.
  ///
  /// In en, this message translates to:
  /// **'Save with Enter, or press Esc to discard your changes'**
  String get ledgerSaveOrDiscard;

  /// Toast when a forecast dot is clicked while reconciling.
  ///
  /// In en, this message translates to:
  /// **'Finish or cancel the reconcile first'**
  String get ledgerFinishReconcileFirst;

  /// Undo-menu label after a scheduled transaction is confirmed. name is the payee.
  ///
  /// In en, this message translates to:
  /// **'{name} confirmed'**
  String ledgerConfirmed(String name);

  /// Toast start after a scheduled transaction is confirmed. when is "early" if confirmed before its date, else "other". amount is money like ₮45,000.
  ///
  /// In en, this message translates to:
  /// **'{when, select, early{{name} confirmed early · {amount}} other{{name} confirmed · {amount}}}'**
  String ledgerConfirmedAmount(String when, String name, String amount);

  /// Toast start after a scheduled transaction is confirmed for a different amount than planned. when is "early" or "other". amount and planned are money.
  ///
  /// In en, this message translates to:
  /// **'{when, select, early{{name} confirmed early · {amount}, planned {planned}} other{{name} confirmed · {amount}, planned {planned}}}'**
  String ledgerConfirmedAmountPlanned(
    String when,
    String name,
    String amount,
    String planned,
  );

  /// Part of the confirm toast, after " · ": part paid, the rest stays scheduled. date is month.day.
  ///
  /// In en, this message translates to:
  /// **'{amount} still owed, due {date}'**
  String ledgerStillOwed(String amount, String date);

  /// Part of the confirm toast, after " · ": the confirmed row is dated today, not its planned day.
  ///
  /// In en, this message translates to:
  /// **'posted today, {date}'**
  String ledgerPostedToday(String date);

  /// Part of the confirm toast, after " · ": the confirmed row got a date other than planned.
  ///
  /// In en, this message translates to:
  /// **'posted {date}'**
  String ledgerPostedOn(String date);

  /// Part of the confirm toast, after " · ": a bill came in under its estimate.
  ///
  /// In en, this message translates to:
  /// **'{amount} under the estimate · lower it on the Budget screen'**
  String ledgerUnderEstimate(String amount);

  /// Undo-menu label after a transaction is edited. name is the payee.
  ///
  /// In en, this message translates to:
  /// **'{name} edited'**
  String ledgerEdited(String name);

  /// Toast when an edit moves a transaction to a future date. date is a full date.
  ///
  /// In en, this message translates to:
  /// **'Moved to {date} · now scheduled, out of balances until confirmed'**
  String ledgerMovedToFuture(String date);

  /// Toast after a transaction is edited.
  ///
  /// In en, this message translates to:
  /// **'Changes saved'**
  String get ledgerChangesSaved;

  /// Reconcile panel, under the statement date field. example is today as month.day, e.g. 09.30.
  ///
  /// In en, this message translates to:
  /// **'Type a date like {example}'**
  String ledgerTypeADate(String example);

  /// Reconcile panel, under the statement date field.
  ///
  /// In en, this message translates to:
  /// **'The statement can’t be after today'**
  String get ledgerStatementAfterToday;

  /// Reconcile panel, under the statement date field. date is month.day.
  ///
  /// In en, this message translates to:
  /// **'Already reconciled through {date}'**
  String ledgerAlreadyReconciled(String date);

  /// Toast when the rows changed while reconciling.
  ///
  /// In en, this message translates to:
  /// **'The cleared rows changed · check the difference again'**
  String get ledgerClearedRowsChanged;

  /// Toast and undo-menu label after a reconcile. date is month.day.
  ///
  /// In en, this message translates to:
  /// **'{account} reconciled through {date}'**
  String ledgerReconciledThrough(String account, String date);

  /// Part of the reconcile toast, after " · ": how many rows were locked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 locked} other{{count} locked}}'**
  String ledgerLocked(int count);

  /// Part of the reconcile toast, after " · ": a row making up the difference was added.
  ///
  /// In en, this message translates to:
  /// **'{amount} adjustment added'**
  String ledgerAdjustmentAdded(String amount);

  /// Toast and undo-menu label after the latest reconcile is taken back. date is month.day.
  ///
  /// In en, this message translates to:
  /// **'Reconcile of {date} undone'**
  String ledgerReconcileUndone(String date);

  /// Part of the undo-reconcile toast, after " · ".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row back to cleared} other{{count} rows back to cleared}}'**
  String ledgerBackToCleared(int count);

  /// Undo-menu label after a row is marked cleared (the bank has it). name is the payee.
  ///
  /// In en, this message translates to:
  /// **'{name} marked cleared'**
  String ledgerMarkedCleared(String name);

  /// Undo-menu label after a row is marked uncleared (pending). name is the payee.
  ///
  /// In en, this message translates to:
  /// **'{name} marked uncleared'**
  String ledgerMarkedUncleared(String name);

  /// Toast when Delete is pressed on a transfer reconciled in the other account.
  ///
  /// In en, this message translates to:
  /// **'Can’t delete · this transfer is reconciled in {account}'**
  String ledgerCantDeleteTransfer(String account);

  /// Toast when Delete is pressed on a reconciled row.
  ///
  /// In en, this message translates to:
  /// **'Can’t delete · it matches a bank statement'**
  String get ledgerCantDeleteReconciled;

  /// Toast and undo-menu label after a row, category or account is deleted.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted'**
  String ledgerDeleted(String name);

  /// Undo-menu label after a scheduled bill was deleted because the real one was already in. name is the payee.
  ///
  /// In en, this message translates to:
  /// **'Scheduled {name} deleted'**
  String ledgerScheduledDeleted(String name);

  /// Toast after a scheduled bill was deleted because the real one was already in the account. name is the payee, date a day like 10.05.
  ///
  /// In en, this message translates to:
  /// **'Scheduled {name} deleted · already in on {date}'**
  String ledgerScheduledDeletedAlreadyIn(String name, String date);

  /// Toast when moving a row to another account is refused; reason comes from the app.
  ///
  /// In en, this message translates to:
  /// **'Can’t move · {reason}'**
  String ledgerCantMove(String reason);

  /// Toast when moving a row to another account failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t move it'**
  String get ledgerCouldntMove;

  /// Toast and undo-menu label after a row is moved to another account. name is the payee.
  ///
  /// In en, this message translates to:
  /// **'{name} moved to {account}'**
  String ledgerMovedTo(String name, String account);

  /// Toast after a scheduled bill was deleted because a row for it was already in the account, when that row was for less than the bill: short, like ₮800,000, is the part of the bill that is now neither paid nor scheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled {name} deleted · {short} of it is no longer scheduled'**
  String ledgerScheduledDeletedShort(String name, String short);

  /// Button on the toast after a row is moved to another account: opens that account with the row chosen.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get ledgerShowMoved;

  /// Toast after a transfer is moved to another account. payee is the account the money went to.
  ///
  /// In en, this message translates to:
  /// **'Transfer to {payee} moved to {account}'**
  String ledgerTransferToMovedTo(String payee, String account);

  /// Toast after a transfer is moved to another account. payee is the account the money came from.
  ///
  /// In en, this message translates to:
  /// **'Transfer from {payee} moved to {account}'**
  String ledgerTransferFromMovedTo(String payee, String account);

  /// Part of the move toast, after " · ": the moved row starts uncleared in its new account.
  ///
  /// In en, this message translates to:
  /// **'uncleared there until it clears'**
  String get ledgerUnclearedThere;

  /// Toast when pay setup is opened with no bank account.
  ///
  /// In en, this message translates to:
  /// **'Add a bank account first'**
  String get ledgerAddBankAccountFirst;

  /// Undo-menu label after a pay schedule is stopped.
  ///
  /// In en, this message translates to:
  /// **'Pay stopped'**
  String get ledgerPayStopped;

  /// Toast after a pay schedule is stopped.
  ///
  /// In en, this message translates to:
  /// **'Pay no longer scheduled · paydays already past stay'**
  String get ledgerPayStoppedToast;

  /// Toast after stopping a pay and moving the categories per it. how is "Every month" or "Every pay period · Jenny".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Pay no longer scheduled · 1 category now {how}} other{Pay no longer scheduled · {count} categories now {how}}}'**
  String ledgerPayStoppedMoved(int count, String how);

  /// Toast and undo-menu label after a pay schedule is saved.
  ///
  /// In en, this message translates to:
  /// **'Pay saved'**
  String get ledgerPaySaved;

  /// Toast after a pay schedule is saved. date is a full date.
  ///
  /// In en, this message translates to:
  /// **'Pay saved · next payday {date}'**
  String ledgerPaySavedNext(String date);

  /// Undo-menu label after "I don’t have regular pay" is chosen.
  ///
  /// In en, this message translates to:
  /// **'No regular pay'**
  String get ledgerNoRegularPay;

  /// Undo-menu label after Settings → "ask again" for pay.
  ///
  /// In en, this message translates to:
  /// **'Asking for pay again'**
  String get ledgerAskingForPayAgain;

  /// Toast after "I don’t have regular pay" is chosen.
  ///
  /// In en, this message translates to:
  /// **'No regular pay · the app won’t ask for it · the Budget page’s Income tab changes this'**
  String get ledgerNoRegularPayToast;

  /// Toast after Settings → ask for pay again.
  ///
  /// In en, this message translates to:
  /// **'The forecast will ask for your pay again'**
  String get ledgerAskForPayAgainToast;

  /// Undo-menu label (no toast): the Budget page is now viewed by calendar month.
  ///
  /// In en, this message translates to:
  /// **'Budget viewed by month'**
  String get ledgerBudgetByMonth;

  /// Undo-menu label (no toast): the Budget page is now viewed by one pay's periods, named by the pay.
  ///
  /// In en, this message translates to:
  /// **'Budget viewed by pay period · {name}'**
  String ledgerBudgetByPayPeriod(String name);

  /// Settings → Appearance card, title.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get ledgerAppearanceTitle;

  /// Settings → Appearance card, choice button: light colors.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get ledgerAppearanceLight;

  /// Settings → Appearance card, choice button: dark colors.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get ledgerAppearanceDark;

  /// Undo-menu label after the appearance is changed. choice is the button chosen, e.g. "Dark".
  ///
  /// In en, this message translates to:
  /// **'Appearance: {choice}'**
  String ledgerAppearanceUndoLabel(String choice);

  /// Settings → Appearance card, under the choices when following the system. system is "the Mac" or "Windows".
  ///
  /// In en, this message translates to:
  /// **'Showing light now · changes when {system} does'**
  String ledgerShowingLightNow(String system);

  /// Settings → Appearance card, under the choices when following the system. system is "the Mac" or "Windows".
  ///
  /// In en, this message translates to:
  /// **'Showing dark now · changes when {system} does'**
  String ledgerShowingDarkNow(String system);

  /// Title of the All accounts register.
  ///
  /// In en, this message translates to:
  /// **'All accounts'**
  String get ledgerAllAccounts;

  /// All accounts, filter chip above the rows: showing one category.
  ///
  /// In en, this message translates to:
  /// **'Category: {name}'**
  String ledgerCategoryChip(String name);

  /// Blue button above the register: add a transaction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get ledgerAdd;

  /// All accounts, beside the category chip: how many posted rows show. Followed by " · " and the total.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row} other{{count} rows}}'**
  String ledgerFilterRows(int count);

  /// All accounts, beside the category chip: the category’s total. kind is received / paidBack (Income) or spent / refunded (spending).
  ///
  /// In en, this message translates to:
  /// **'{kind, select, received{{amount} received} paidBack{{amount} paid back} refunded{{amount} refunded} other{{amount} spent}}'**
  String ledgerFilterTotal(String kind, String amount);

  /// Like ledgerFilterTotal, over all time: date is the first row’s full date.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, received{{amount} received since {date}} paidBack{{amount} paid back since {date}} refunded{{amount} refunded since {date}} other{{amount} spent since {date}}}'**
  String ledgerFilterTotalSince(String kind, String amount, String date);

  /// All accounts, after the category total and " · ": future rows not in the total.
  ///
  /// In en, this message translates to:
  /// **'{count} scheduled'**
  String ledgerFilterScheduled(int count);

  /// Toast when adding an account failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t add the account'**
  String get ledgerCouldntAddAccount;

  /// Toast when a new card's interest rate couldn't be saved; the account itself was added.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t keep the interest rate. The account was added; type the rate on Savings, step 2.'**
  String get ledgerCouldntKeepRate;

  /// Toast when a new account’s starting balance failed to save.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save the balance'**
  String get ledgerCouldntSaveBalance;

  /// Toast when a change to an account failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t change the account'**
  String get ledgerCouldntChangeAccount;

  /// Toast when saving or stopping pay failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t change the pay'**
  String get ledgerCouldntChangePay;

  /// Toast when switching budget by month / pay period failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t change the budget period'**
  String get ledgerCouldntChangeBudgetPeriod;

  /// Toast when a change to a category failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t change the category'**
  String get ledgerCouldntChangeCategory;

  /// Toast and undo-menu label after an account or category is renamed.
  ///
  /// In en, this message translates to:
  /// **'Renamed {old} to {name}'**
  String ledgerRenamed(String old, String name);

  /// Toast and undo-menu label after an account’s kind is changed to owed money.
  ///
  /// In en, this message translates to:
  /// **'{name} is now a credit card or loan'**
  String ledgerIsNowCardOrLoan(String name);

  /// Toast and undo-menu label after an account’s kind is changed to a bank account.
  ///
  /// In en, this message translates to:
  /// **'{name} is now a bank account'**
  String ledgerIsNowBankAccount(String name);

  /// Part of the change-kind toast, after " · ": the starting balance’s sign changed too.
  ///
  /// In en, this message translates to:
  /// **'its opening balance flipped with it'**
  String get ledgerOpeningBalanceFlipped;

  /// Title of the warning before archiving an account that still holds money or bills.
  ///
  /// In en, this message translates to:
  /// **'Archive {name}?'**
  String ledgerArchiveTitle(String name);

  /// Button in the archive warning.
  ///
  /// In en, this message translates to:
  /// **'Archive {name}'**
  String ledgerArchiveAction(String name);

  /// Undo-menu label after an account or category is archived.
  ///
  /// In en, this message translates to:
  /// **'{name} archived'**
  String ledgerArchived(String name);

  /// Toast and undo-menu label after an account is unarchived.
  ///
  /// In en, this message translates to:
  /// **'{name} back in the sidebar'**
  String ledgerBackInSidebar(String name);

  /// Toast after an account is archived.
  ///
  /// In en, this message translates to:
  /// **'{name} archived · Settings brings it back'**
  String ledgerAccountArchivedToast(String name);

  /// Title of the warning before deleting an account.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String ledgerDeleteTitle(String name);

  /// Red button in the delete-account warning.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}'**
  String ledgerDeleteAction(String name);

  /// Toast when a new category’s name is taken.
  ///
  /// In en, this message translates to:
  /// **'{name} is already a category'**
  String ledgerAlreadyCategory(String name);

  /// Toast and undo-menu label after a category is unarchived.
  ///
  /// In en, this message translates to:
  /// **'{name} back in the menus'**
  String ledgerBackInMenus(String name);

  /// Toast after a category is archived.
  ///
  /// In en, this message translates to:
  /// **'{name} archived · its rows keep it; new rows can’t pick it'**
  String ledgerCategoryArchivedToast(String name);

  /// Toast after a category is renamed onto / deleted into another.
  ///
  /// In en, this message translates to:
  /// **'{name} merged into {target}'**
  String ledgerMergedInto(String name, String target);

  /// Part of the merge toast, after " · ".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row moved} other{{count} rows moved}}'**
  String ledgerRowsMoved(int count);

  /// Toast after a category with rows is deleted; target is the category they moved to.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted · {count, plural, =1{1 row} other{{count} rows}} moved to {target}'**
  String ledgerDeletedRowsMovedTo(String name, int count, String target);

  /// Confirm button of the system save dialog for "Back up to…".
  ///
  /// In en, this message translates to:
  /// **'Back Up'**
  String get ledgerBackUpButton;

  /// Toast when the system save dialog failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open the save dialog'**
  String get ledgerCouldntOpenSaveDialog;

  /// Toast when saving a backup failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t back up · check the drive has room and try again'**
  String get ledgerCouldntBackUp;

  /// Toast after a backup is saved; file is its file name.
  ///
  /// In en, this message translates to:
  /// **'Backed up · {file}'**
  String ledgerBackedUp(String file);

  /// File type name in the system open dialog for "Restore from…".
  ///
  /// In en, this message translates to:
  /// **'BetterBudget backup'**
  String get ledgerBackupFileType;

  /// Confirm button of the system open dialog for "Restore from…".
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get ledgerChoose;

  /// Toast when the system open dialog failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open the file dialog'**
  String get ledgerCouldntOpenFileDialog;

  /// Toast when the chosen backup can’t be read.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t read that backup'**
  String get ledgerCouldntReadBackup;

  /// Toast when a restore failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t restore · nothing was changed'**
  String get ledgerCouldntRestore;

  /// Toast and undo-menu label after a restore. date is a full date.
  ///
  /// In en, this message translates to:
  /// **'Restored the copy from {date}'**
  String ledgerRestoredFrom(String date);

  /// Part of the restore toast, after " · ".
  ///
  /// In en, this message translates to:
  /// **'what you had is saved'**
  String get ledgerWhatYouHadIsSaved;

  /// Erase-everything dialog: an archived account in the list of what goes.
  ///
  /// In en, this message translates to:
  /// **'{name} (archived)'**
  String ledgerArchivedName(String name);

  /// Toast when erasing everything failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t start a new ledger · nothing was changed'**
  String get ledgerCouldntStartNewLedger;

  /// Undo-menu label after everything is erased.
  ///
  /// In en, this message translates to:
  /// **'New ledger started'**
  String get ledgerNewLedgerStarted;

  /// Toast after everything is erased.
  ///
  /// In en, this message translates to:
  /// **'Everything erased · what you had is saved in Backups'**
  String get ledgerEverythingErased;

  /// Shown instead of the app when the ledger can’t be read.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open the ledger: {error}'**
  String ledgerCouldntOpenLedger(String error);

  /// Sidebar heading over accounts with no group.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get ledgerGroupAccounts;

  /// Sidebar heading over bank accounts and cash. Kept for a ledger made before cash was its own Type.
  ///
  /// In en, this message translates to:
  /// **'Cash & bank'**
  String get ledgerGroupCashBank;

  /// Sidebar heading over bank accounts (checking, savings).
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get ledgerGroupBank;

  /// Sidebar heading over cash accounts (a wallet, a tin).
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get ledgerGroupCash;

  /// Sidebar heading over credit cards and loans.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get ledgerGroupCredit;

  /// Sidebar section: the accounts and their transactions.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get ledgerSectionLedger;

  /// Sidebar section.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get ledgerSectionBudget;

  /// Sidebar section: steps to getting financially prepared.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get ledgerSectionSavings;

  /// Sidebar, bottom: label over the total of all accounts.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get ledgerNetWorth;

  /// Sidebar, under net worth: money in archived accounts it includes.
  ///
  /// In en, this message translates to:
  /// **'incl. {amount} in archived'**
  String ledgerInclArchived(String amount);

  /// Sidebar, small line under Net worth, shown once it has been more than 30 days since Settings → Back up to… was last used on this computer (the owner read "elsewhere" as another machine having done it: say only what this computer did). Clicking it opens Settings. days is 31 or more.
  ///
  /// In en, this message translates to:
  /// **'Last backup {days} days ago'**
  String ledgerLastCopiedElsewhere(int days);

  /// Sidebar, small line under Net worth, shown after 30 days when the ledger has never been saved somewhere other than this computer with Settings → Back up to…. Clicking it opens Settings.
  ///
  /// In en, this message translates to:
  /// **'No backup yet'**
  String get ledgerNeverCopiedElsewhere;

  /// Settings → Backups card, row label (120px wide), shown while the ledger is stored on this computer only: when it was last saved somewhere else with the Back up to… button under it.
  ///
  /// In en, this message translates to:
  /// **'Backed up'**
  String get ledgerCopiedElsewhere;

  /// Settings → Backups card, value of the Copied elsewhere row when Back up to… has never been used on this computer. Names the button below it.
  ///
  /// In en, this message translates to:
  /// **'Not yet · Back up to… saves a copy to another drive'**
  String get ledgerCopiedElsewhereNever;

  /// Tooltip on the Settings gear’s coral dot.
  ///
  /// In en, this message translates to:
  /// **'The daily copy is failing'**
  String get ledgerDailyCopyFailing;

  /// Sidebar item and title of the Settings page.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get ledgerSettings;

  /// Settings → Backups card, title.
  ///
  /// In en, this message translates to:
  /// **'Backups'**
  String get ledgerBackupsTitle;

  /// Settings → Backups card, row label (120px wide).
  ///
  /// In en, this message translates to:
  /// **'Daily copy'**
  String get ledgerDailyCopy;

  /// Settings → Backups: when a copy was made. day is Today, Yesterday or a date; time is 14:05.
  ///
  /// In en, this message translates to:
  /// **'{day} {time}'**
  String ledgerTimeAt(String day, String time);

  /// Settings → Backups card, Daily copy row, in coral: the daily copy fails. when is like "Today 14:05".
  ///
  /// In en, this message translates to:
  /// **'Failing · the last one is from {when}. Check the disk has room, and back up to another drive.'**
  String ledgerDailyCopyFailingSince(String when);

  /// Settings → Backups card, Daily copy row, in coral: the daily copy fails and none was ever made.
  ///
  /// In en, this message translates to:
  /// **'Failing. Check the disk has room, and back up to another drive.'**
  String get ledgerDailyCopyFailingNone;

  /// Settings → Backups card, Daily copy row: no copy yet.
  ///
  /// In en, this message translates to:
  /// **'None yet · one is made each day the app is open'**
  String get ledgerDailyCopyNone;

  /// Settings → Backups card, Daily copy row: when the newest was made.
  ///
  /// In en, this message translates to:
  /// **'{when} · on this computer'**
  String ledgerDailyCopyWhen(String when);

  /// Settings → Backups card, row label (120px wide): which copies are kept.
  ///
  /// In en, this message translates to:
  /// **'Kept'**
  String get ledgerKept;

  /// Settings → Backups card, Kept row.
  ///
  /// In en, this message translates to:
  /// **'The newest 14, plus the first of each month for a year'**
  String get ledgerKeptWhich;

  /// Settings → Backups card, button: save a copy to a place the user picks.
  ///
  /// In en, this message translates to:
  /// **'Back up to…'**
  String get ledgerBackUpTo;

  /// Settings → Backups card, button: put a backup back.
  ///
  /// In en, this message translates to:
  /// **'Restore from…'**
  String get ledgerRestoreFrom;

  /// Settings → Backups card, note under the buttons.
  ///
  /// In en, this message translates to:
  /// **'The daily copies are on this computer, so they won’t help if it’s lost or breaks: back up to another drive or a USB stick now and then. Restoring saves what you have first, and Undo brings it back.'**
  String get ledgerBackupsNote;

  /// Settings → Security card, title.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get ledgerSecurityTitle;

  /// Settings → Security card, when the recovery key was saved.
  ///
  /// In en, this message translates to:
  /// **'Your ledger and backups are encrypted. Your recovery key opens them on another computer, but only the copies you saved off this one (Back up to…) survive losing it. BetterBudget doesn’t keep a copy of the key.'**
  String get ledgerSecurityKeySaved;

  /// Settings → Security card, in coral, when the recovery key was never saved.
  ///
  /// In en, this message translates to:
  /// **'Your ledger and backups are encrypted. Your recovery key wasn’t saved or copied when it was shown, and BetterBudget doesn’t keep a copy: if this computer is lost, they can’t be opened.'**
  String get ledgerSecurityKeyNotSaved;

  /// Settings → Security card, button.
  ///
  /// In en, this message translates to:
  /// **'Check my recovery key…'**
  String get ledgerCheckRecoveryKey;

  /// Settings → Start over card, title.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get ledgerStartOverTitle;

  /// Settings → Start over card, text.
  ///
  /// In en, this message translates to:
  /// **'This erases every account and transaction in this ledger, so you start empty. You choose whether your categories stay. What you have now is saved in Backups first, and Undo brings it back.'**
  String get ledgerStartOverNote;

  /// Settings, bottom of the page: the app's version and, in brackets, its build number (the repo's commit count). Example: Version 0.1.0 (134).
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({build})'**
  String settingsVersion(String version, String build);

  /// Settings, bottom of the page, under the version line: who helped design the app. Keep the name in Latin letters.
  ///
  /// In en, this message translates to:
  /// **'The Budget page was laid out with help from Cynthia G. Loveland.'**
  String get settingsCredit;

  /// Settings → Start over card, button.
  ///
  /// In en, this message translates to:
  /// **'Erase everything and start over…'**
  String get ledgerEraseAndStartOverButton;

  /// Restore dialog title.
  ///
  /// In en, this message translates to:
  /// **'Restore this backup?'**
  String get ledgerRestoreTitle;

  /// Restore dialog, row label (110px wide): when the backup was made.
  ///
  /// In en, this message translates to:
  /// **'Backup from'**
  String get ledgerBackupFrom;

  /// Restore dialog, row label (110px wide): what the backup holds.
  ///
  /// In en, this message translates to:
  /// **'It holds'**
  String get ledgerItHolds;

  /// Restore dialog, row label (110px wide): what the ledger holds now.
  ///
  /// In en, this message translates to:
  /// **'Here now'**
  String get ledgerHereNow;

  /// Restore dialog, row value.
  ///
  /// In en, this message translates to:
  /// **'{transactions, plural, =1{1 transaction} other{{transactions} transactions}} · {accounts, plural, =1{1 account} other{{accounts} accounts}}'**
  String ledgerCounts(int transactions, int accounts);

  /// Restore dialog, note.
  ///
  /// In en, this message translates to:
  /// **'Everything here is replaced by the backup. What you have now is saved first, and Undo brings it back.'**
  String get ledgerRestoreNote;

  /// Dialog button.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get ledgerCancel;

  /// Restore dialog, main button.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get ledgerRestore;

  /// A card or loan’s balance in the sidebar and Erase-everything dialog.
  ///
  /// In en, this message translates to:
  /// **'{amount} owed'**
  String ledgerOwed(String amount);

  /// Erase-everything dialog, list of what goes.
  ///
  /// In en, this message translates to:
  /// **'Your pay'**
  String get ledgerYourPay;

  /// Erase-everything dialog, list of what goes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 reconcile} other{{count} reconciles}}'**
  String ledgerReconciles(int count);

  /// Erase-everything dialog, list of what goes.
  ///
  /// In en, this message translates to:
  /// **'Payees'**
  String get ledgerPayees;

  /// Erase-everything dialog, list of what goes.
  ///
  /// In en, this message translates to:
  /// **'Budget and Savings settings'**
  String get ledgerBudgetSavingsSettings;

  /// Erase-everything dialog, after the first 8 accounts.
  ///
  /// In en, this message translates to:
  /// **'+ {count, plural, =1{1 more account} other{{count} more accounts}}'**
  String ledgerMoreAccounts(int count);

  /// Erase-everything dialog, beside their date range.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction} other{{count} transactions}}'**
  String ledgerTransactionCount(int count);

  /// Erase-everything dialog title, in coral.
  ///
  /// In en, this message translates to:
  /// **'Erase everything and start over?'**
  String get ledgerEraseTitle;

  /// Erase-everything dialog, over the list of what goes.
  ///
  /// In en, this message translates to:
  /// **'All of this is erased:'**
  String get ledgerAllOfThisErased;

  /// Erase-everything dialog.
  ///
  /// In en, this message translates to:
  /// **'You start with no accounts and no money in the app.'**
  String get ledgerStartWithNothing;

  /// Erase-everything dialog, over the keep / erase choice.
  ///
  /// In en, this message translates to:
  /// **'Your {count, plural, =1{1 category} other{{count} categories}}'**
  String ledgerYourCategories(int count);

  /// Erase-everything dialog, choice: keep the categories with no rows.
  ///
  /// In en, this message translates to:
  /// **'Keep them, empty'**
  String get ledgerKeepThemEmpty;

  /// Erase-everything dialog, choice: erase the categories too.
  ///
  /// In en, this message translates to:
  /// **'Erase them too'**
  String get ledgerEraseThemToo;

  /// Erase-everything dialog, under the choice when keeping.
  ///
  /// In en, this message translates to:
  /// **'Kept with no rows in them, ready for your real accounts.'**
  String get ledgerKeptNoRows;

  /// Erase-everything dialog, under the choice when erasing.
  ///
  /// In en, this message translates to:
  /// **'You’ll add categories again on the Budget screen.'**
  String get ledgerAddCategoriesAgain;

  /// Erase-everything dialog, note.
  ///
  /// In en, this message translates to:
  /// **'What you have now is saved in Backups first. Undo brings it back, and so does Restore from… later.'**
  String get ledgerEraseNote;

  /// Erase-everything dialog, red button.
  ///
  /// In en, this message translates to:
  /// **'Erase everything'**
  String get ledgerEraseEverything;

  /// Search field hint above the register (280px wide).
  ///
  /// In en, this message translates to:
  /// **'Search payee, memo, amount'**
  String get ledgerSearchHint;

  /// All accounts, filter chip: rows of the budget’s current span. period is "This month" or "This pay period"; start and end are month.day.
  ///
  /// In en, this message translates to:
  /// **'{period} · {start}–{end}'**
  String ledgerPeriodChip(String period, String start, String end);

  /// Under the row editor or as a toast: a reconciled row’s date and amount can’t change.
  ///
  /// In en, this message translates to:
  /// **'Reconciled · the date and amount match a bank statement'**
  String get ledgerDbReconciled;

  /// Under the row editor or as a toast: a transfer to the account it is in.
  ///
  /// In en, this message translates to:
  /// **'It can’t move money to its own account'**
  String get ledgerDbOwnAccount;

  /// Under the row editor: a scheduled row confirmed with a date after today.
  ///
  /// In en, this message translates to:
  /// **'It can’t be confirmed on a future date'**
  String get ledgerDbFutureConfirm;

  /// Toast after "Can’t move · ": opening balances and reconcile adjustments stay in their account.
  ///
  /// In en, this message translates to:
  /// **'An opening balance or adjustment stays put'**
  String get ledgerDbOpeningStays;

  /// Toast after "Can’t move · ": the transfer already touches the account picked.
  ///
  /// In en, this message translates to:
  /// **'It already moves money in that account'**
  String get ledgerDbAlreadyThere;

  /// Toast or editor error: the row is no longer in this account.
  ///
  /// In en, this message translates to:
  /// **'Not in this account'**
  String get ledgerDbNotInAccount;

  /// Toast after "Can’t move · ": the target isn’t an account.
  ///
  /// In en, this message translates to:
  /// **'Not an account'**
  String get ledgerDbNotAnAccount;

  /// Under the row editor: a split transaction’s amount or category.
  ///
  /// In en, this message translates to:
  /// **'Change a split’s categories in its own card'**
  String get ledgerDbSplitNotEditable;

  /// Toast after "Can’t move · ": the row changed meanwhile.
  ///
  /// In en, this message translates to:
  /// **'It changed since'**
  String get ledgerDbChangedSince;

  /// Toast when a change is refused (rare; usually a row changed in the meantime).
  ///
  /// In en, this message translates to:
  /// **'It still has rows; pick where they go'**
  String get ledgerDbStillHasRows;

  /// Toast when a change is refused (rare; usually a row changed in the meantime).
  ///
  /// In en, this message translates to:
  /// **'Not a single-category transaction'**
  String get ledgerDbNotSingleCategory;

  /// Toast when a change is refused (rare; usually a row changed in the meantime).
  ///
  /// In en, this message translates to:
  /// **'Pay is money in'**
  String get ledgerDbPayIsIn;

  /// Toast when a change is refused (rare; usually a row changed in the meantime).
  ///
  /// In en, this message translates to:
  /// **'Not a category'**
  String get ledgerDbNotCategory;

  /// Toast when a change is refused (rare; usually a row changed in the meantime).
  ///
  /// In en, this message translates to:
  /// **'Same category'**
  String get ledgerDbSameCategory;

  /// Toast when a change is refused (rare; usually a row changed in the meantime).
  ///
  /// In en, this message translates to:
  /// **'That account was deleted'**
  String get ledgerDbAccountDeleted;

  /// Toast when a change is refused (rare; usually a row changed in the meantime).
  ///
  /// In en, this message translates to:
  /// **'Never reconciled'**
  String get ledgerDbNeverReconciled;

  /// Account header, balance sum: note beside the pending line; count = pending transactions
  ///
  /// In en, this message translates to:
  /// **'{count} not cleared yet'**
  String planNotClearedYet(int count);

  /// Account header, balance sum: name of the total (cleared + pending), the big number
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get planWorking;

  /// Account header, balance sum: name of the total on a credit card or loan
  ///
  /// In en, this message translates to:
  /// **'Owed'**
  String get planOwed;

  /// Account header, balance sum: the account was never reconciled
  ///
  /// In en, this message translates to:
  /// **'Never reconciled'**
  String get planNeverReconciled;

  /// Account header, balance sum: when the account was last reconciled; date like 09.16 / 9-р сарын 16
  ///
  /// In en, this message translates to:
  /// **'Last reconciled on {date}'**
  String planLastReconciled(String date);

  /// Account header, balance sum: button that starts reconciling
  ///
  /// In en, this message translates to:
  /// **'Reconcile'**
  String get planReconcile;

  /// Account header, forecast panel: gold note; several incomes are past due and not counted. amount like ₮2,500,000
  ///
  /// In en, this message translates to:
  /// **'+{amount} in, {count} not arrived'**
  String planLateSeveral(String amount, int count);

  /// Account header, forecast panel: gold note; an income due today has not arrived
  ///
  /// In en, this message translates to:
  /// **'+{amount} in, due today'**
  String planLateToday(String amount);

  /// Account header, forecast panel: gold note; an income is days late
  ///
  /// In en, this message translates to:
  /// **'+{amount} in, {days, plural, =1{1 day late} other{{days} days late}}'**
  String planLateDays(String amount, int days);

  /// Account header, forecast panel: after the late-income note; the late money is left out of the forecast
  ///
  /// In en, this message translates to:
  /// **' · not counted'**
  String get planLateNotCounted;

  /// Account header, forecast panel: headline when no bills or income are scheduled
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled'**
  String get planNothingScheduled;

  /// Account header, forecast panel (credit card): headline, the card will be overpaid after the last scheduled charge or payment
  ///
  /// In en, this message translates to:
  /// **'{amount} in credit after {date}'**
  String planCreditAfter(String amount, String date);

  /// Account header, forecast panel (credit card): headline, what will be owed after the last scheduled charge or payment
  ///
  /// In en, this message translates to:
  /// **'{amount} owed after {date}'**
  String planOwedAfterDate(String amount, String date);

  /// Account header, forecast panel (credit card): line under the headline, scheduled charges and their total
  ///
  /// In en, this message translates to:
  /// **'{charges, plural, =1{1 charge} other{{charges} charges}} · {chargeTotal} through {date}'**
  String planCardCharges(int charges, String chargeTotal, String date);

  /// Account header, forecast panel (credit card): line under the headline, scheduled payments to the card and their total
  ///
  /// In en, this message translates to:
  /// **'{payments, plural, =1{1 payment} other{{payments} payments}} · {paymentTotal} through {date}'**
  String planCardPayments(int payments, String paymentTotal, String date);

  /// Account header, forecast panel (credit card): line under the headline, scheduled charges and payments
  ///
  /// In en, this message translates to:
  /// **'{charges, plural, =1{1 charge} other{{charges} charges}} · {chargeTotal} · {payments, plural, =1{1 payment} other{{payments} payments}} · {paymentTotal} through {date}'**
  String planCardChargesPayments(
    int charges,
    String chargeTotal,
    int payments,
    String paymentTotal,
    String date,
  );

  /// Account header, forecast panel (credit card): line under the headline when nothing is scheduled
  ///
  /// In en, this message translates to:
  /// **'No charges or payments in the next 30 days'**
  String get planCardNothing;

  /// Account header, forecast panel: red headline, the balance is already below zero
  ///
  /// In en, this message translates to:
  /// **'Below zero now'**
  String get planBelowZeroNow;

  /// Account header, forecast panel: red headline, already below zero and going lower
  ///
  /// In en, this message translates to:
  /// **'Below zero now · up to {amount} short'**
  String planBelowZeroShort(String amount);

  /// Account header, forecast panel: red headline on payday, below zero unless today’s income arrives
  ///
  /// In en, this message translates to:
  /// **'Below zero now unless {amount} due today comes'**
  String planBelowZeroUnless(String amount);

  /// Account header, forecast panel: red headline on payday, money runs out on a date unless today’s income arrives
  ///
  /// In en, this message translates to:
  /// **'Runs out {date} unless {amount} due today comes'**
  String planRunsOutUnless(String date, String amount);

  /// Account header, forecast panel: red headline, the day money runs out and how short it gets
  ///
  /// In en, this message translates to:
  /// **'Runs out on {date} · up to {amount} short'**
  String planRunsOut(String date, String amount);

  /// Sidebar, tooltip on the coral dot beside an account: the day its balance first goes below zero and how far below it is that day
  ///
  /// In en, this message translates to:
  /// **'Runs out on {date} · {amount} short'**
  String planRunsOutBy(String date, String amount);

  /// Account header, the forecast's bill list: after a payday or bill the app expects from the pay plan or a category's plan past the scheduled one (not a row yet)
  ///
  /// In en, this message translates to:
  /// **'expected'**
  String get planExpected;

  /// Account header, forecast panel: after the bill count under the headline when some bills are the app's expectation past the scheduled rows (4 bills · ₮X through 12.15 · 2 of them expected)
  ///
  /// In en, this message translates to:
  /// **'{count} of them expected'**
  String planOfThemExpected(int count);

  /// Budget page, Edit under a category's row (Yes): note beside Paid from while two or more accounts are checked (the bill is scheduled only in a single account)
  ///
  /// In en, this message translates to:
  /// **'Checked in {count} accounts, so this bill isn’t in any forecast. Uncheck down to one to see it there.'**
  String planPaidFromSeveral(int count);

  /// Budget page, Edit under a category's row (Yes): note beside Paid from while no account is checked
  ///
  /// In en, this message translates to:
  /// **'No account is checked, so this bill isn’t in any forecast.'**
  String get planPaidFromNoneChecked;

  /// Account header, forecast panel: red headline when the balance lands exactly on zero that day (nothing left, nothing short yet); also the sidebar dot's tooltip
  ///
  /// In en, this message translates to:
  /// **'Runs out on {date}'**
  String planRunsOutZero(String date);

  /// Account header, forecast panel: coral line above the Forecast title when the balance goes below zero later than the span on screen reaches ({end} is the span's last day; {amount} is how far below zero it is that day); a click looks that far
  ///
  /// In en, this message translates to:
  /// **'After {end}: runs out on {date} · {amount} short'**
  String planShortAhead(String end, String date, String amount);

  /// Account header, forecast panel: the coral line above the Forecast title when the balance lands exactly on zero later than the span on screen reaches
  ///
  /// In en, this message translates to:
  /// **'After {end}: runs out on {date}'**
  String planShortAheadZero(String end, String date);

  /// Account header, forecast panel: tooltip on the coral line above the Forecast title; clicking it widens the forecast's span to include that day
  ///
  /// In en, this message translates to:
  /// **'Look as far as {date}'**
  String planShortAheadTip(String date);

  /// Account header, forecast panel: headline, the lowest the balance gets before next income
  ///
  /// In en, this message translates to:
  /// **'Lowest {amount} on {date}'**
  String planLowest(String amount, String date);

  /// Title of the forecast part of the account header, bold and centered.
  ///
  /// In en, this message translates to:
  /// **'Forecast'**
  String get planForecast;

  /// Forecast list, first line: the account's Working balance today.
  ///
  /// In en, this message translates to:
  /// **'Today’s balance'**
  String get planTodaysBalance;

  /// Forecast list: a payday the pay plan expects, with its amount. Deliberately general: the app doesn't know what kind of income it is.
  ///
  /// In en, this message translates to:
  /// **'Expected income'**
  String get planExpectedIncome;

  /// Forecast, under the list when pay is known but nothing is budgeted or scheduled to go out. The owner's wording (2026-09-30).
  ///
  /// In en, this message translates to:
  /// **'Nothing has been budgeted. Once you fill out your budget, this area will show you a forecast.'**
  String get planNothingBudgeted;

  /// Forecast, small label above it: it runs up to that payday (the paycheck on that day isn't counted).
  ///
  /// In en, this message translates to:
  /// **'Until your {date} paycheck'**
  String planUntilPaycheck(String date);

  /// Forecast headline when no scheduled bill takes the balance below today's.
  ///
  /// In en, this message translates to:
  /// **'Lowest {amount}, today'**
  String planLowestToday(String amount);

  /// Forecast chart, label on the step up where the next paycheck lands.
  ///
  /// In en, this message translates to:
  /// **'+{amount} pay'**
  String planChartPay(String amount);

  /// Forecast headline when the lowest point comes after the next paycheck, so it counts on that pay arriving on time and in full.
  ///
  /// In en, this message translates to:
  /// **'Lowest {amount} on {date}, after payday'**
  String planLowestAfterPay(String amount, String date);

  /// Account header, forecast panel: line under the headline when nothing is scheduled
  ///
  /// In en, this message translates to:
  /// **'No bills or income in the next 30 days'**
  String get planNoBillsOrIncome;

  /// Account header, forecast panel: line under the headline when no bills come before the next income
  ///
  /// In en, this message translates to:
  /// **'No bills through {date}'**
  String planNoBillsBefore(String date);

  /// Account header, forecast panel: line under the headline, money coming in (transfers, refunds) and no bills
  ///
  /// In en, this message translates to:
  /// **'+{amount} in through {date}'**
  String planInBefore(String amount, String date);

  /// Account header, forecast panel: clickable line under the headline, the bills before the end date and their total
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 bill} other{{count} bills}} · {amount} through {date}'**
  String planBillsBefore(int count, String amount, String date);

  /// Account header, forecast panel: clickable line under the headline, bills and their total, plus money coming in
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 bill} other{{count} bills}} · {amount} through {date} · +{inAmount} in'**
  String planBillsBeforeIn(
    int count,
    String amount,
    String date,
    String inAmount,
  );

  /// Account header, forecast panel: small title above the headline when there is no payday ahead, or the 30-day span was chosen; also that choice in the span dropdown
  ///
  /// In en, this message translates to:
  /// **'Next 30 days'**
  String get planNext30Days;

  /// Account header, forecast panel: the small title and its dropdown's choices for a span of 60 or 90 days
  ///
  /// In en, this message translates to:
  /// **'Next {count} days'**
  String planNextDays(int count);

  /// Account header, forecast panel: the small title and its dropdown's choice for a span of six months
  ///
  /// In en, this message translates to:
  /// **'Next 6 months'**
  String get planNext6Months;

  /// Account header, forecast panel: the small title and its dropdown's choice for a span of a year from today
  ///
  /// In en, this message translates to:
  /// **'Next year'**
  String get planNextYear;

  /// Account header, forecast panel: tooltip on the small title, which is a dropdown of spans (until the paycheck after next, 30, 60 or 90 days, 6 months, a year)
  ///
  /// In en, this message translates to:
  /// **'How far ahead the forecast looks'**
  String get planSpanTip;

  /// Account header, forecast panel: gold link after the small title; opens pay setup
  ///
  /// In en, this message translates to:
  /// **' · no payday ahead · Add your pay →'**
  String get planAddPay;

  /// Account header, forecast panel: bill list header (left), the list runs until this date
  ///
  /// In en, this message translates to:
  /// **'Through {date}'**
  String planUntilDate(String date);

  /// Account header, forecast panel: bill list and dot card, the column/line with the balance after each bill
  ///
  /// In en, this message translates to:
  /// **'Balance after'**
  String get planBalanceAfter;

  /// Account header, forecast panel (credit card): bill list and dot card, what is owed after each
  ///
  /// In en, this message translates to:
  /// **'Owed after'**
  String get planOwedAfter;

  /// Account header, forecast panel: bill list and dot card, a scheduled transfer out to another account
  ///
  /// In en, this message translates to:
  /// **'To {account}'**
  String planTransferTo(String account);

  /// Account header, forecast panel: bill list and dot card, a scheduled transfer in from another account
  ///
  /// In en, this message translates to:
  /// **'From {account}'**
  String planTransferFrom(String account);

  /// Account header, forecast panel: dot card, under an income that varies; the forecast counts on the least
  ///
  /// In en, this message translates to:
  /// **'{category} · at least, an estimate'**
  String planAtLeastEstimate(String category);

  /// Budget page: page title
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get planBudget;

  /// Budget page: button, top right
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get planAddCategory;

  /// Budget page: tooltip on the Add category button
  ///
  /// In en, this message translates to:
  /// **'Add a category'**
  String get planAddCategoryTip;

  /// Budget page, Income tab: tooltip on the top-right Add your pay / Add other pay button
  ///
  /// In en, this message translates to:
  /// **'Set up a paycheck: how much, how often, and the account it goes into'**
  String get setupAddPayTip;

  /// Budget page, Income tab, beside the Income line: this period's pay that has come, of what the pay schedules expect in it, per currency (the owner's wording)
  ///
  /// In en, this message translates to:
  /// **'{received} received of {expected} expected this period'**
  String planIncomeExpected(String received, String expected);

  /// Budget page, the panel's top row: the second tab, beside Spending; it holds this period's income and the pay that is set up
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get planIncomeTab;

  /// Budget page, Income tab, under a pay's name: how much and when, and the account it is paid into, when no payday is scheduled
  ///
  /// In en, this message translates to:
  /// **'{amounts} · into {account}'**
  String planPayInto(String amounts, String account);

  /// Budget page, Income tab, under a pay's name: how much and when, the account it is paid into, and the next payday
  ///
  /// In en, this message translates to:
  /// **'{amounts} · into {account} · next {date}'**
  String planPayIntoNext(String amounts, String account, String date);

  /// Budget page: group title, and the kind toggle in the new-category form
  ///
  /// In en, this message translates to:
  /// **'Spending'**
  String get planSpending;

  /// Budget page: link that shows archived categories
  ///
  /// In en, this message translates to:
  /// **'Show archived ({count})'**
  String planShowArchived(int count);

  /// Budget page: link that hides archived categories
  ///
  /// In en, this message translates to:
  /// **'Hide archived ({count})'**
  String planHideArchived(int count);

  /// Budget page: button on an archived category, un-archives it
  ///
  /// In en, this message translates to:
  /// **'Show in menus'**
  String get planShowInMenus;

  /// Budget page: the pay note beside the Income line; the user said there is no regular pay
  ///
  /// In en, this message translates to:
  /// **'No regular pay'**
  String get planPaydayNoRegular;

  /// Budget page: the pay note beside the Income line, gold, when pay is not set up yet
  ///
  /// In en, this message translates to:
  /// **'Pay not set up'**
  String get planPaydayNotSetUp;

  /// Budget page: added at the end of the pay note when there are more pay schedules
  ///
  /// In en, this message translates to:
  /// **' · +{count} more pay'**
  String planMorePay(int count);

  /// Budget page: gold suggestion in the pay note, pay that varies (two amounts a month)
  ///
  /// In en, this message translates to:
  /// **'Your last 6 all came in over 5% above the estimate · raise it?'**
  String get planRaiseSplit;

  /// Budget page: gold suggestion in the pay note, pay that varies
  ///
  /// In en, this message translates to:
  /// **'Your lowest of the last 6 was {amount} · raise the estimate?'**
  String planRaiseLowest(String amount);

  /// Budget page: gold suggestion in the pay note, the same pay came in lower twice
  ///
  /// In en, this message translates to:
  /// **'Last 2 came in at {amount}, less than planned · update it?'**
  String planLastTwoLess(String amount);

  /// Budget page: gold suggestion in the pay note, the same pay came in different twice
  ///
  /// In en, this message translates to:
  /// **'Last 2 came in at {amount} · update the amount?'**
  String planLastTwoMore(String amount);

  /// Budget page: the pay note beside the Income line; pay is the amount and when (e.g. ₮2,100,000 monthly on the 25th)
  ///
  /// In en, this message translates to:
  /// **'Pay: {pay}'**
  String planPaydayPay(String pay);

  /// Budget page: the pay note beside the Income line, with the next payday
  ///
  /// In en, this message translates to:
  /// **'Pay: {pay} · next {date}'**
  String planPaydayPayNext(String pay, String date);

  /// Budget page: usage on a category with no transactions
  ///
  /// In en, this message translates to:
  /// **'no rows'**
  String get planNoRows;

  /// Budget page: usage on a category, how many transactions
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row} other{{count} rows}}'**
  String planUsageRows(int count);

  /// Budget page: usage on a category, how many transactions and the latest date
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row} other{{count} rows}} · last {date}'**
  String planUsageRowsLast(int count, String date);

  /// Budget page: usage on a category, scheduled transactions (joined to the rest with ·)
  ///
  /// In en, this message translates to:
  /// **'{count} scheduled'**
  String planUsageScheduled(int count);

  /// Budget page: tooltip on a category’s usage, opens its transactions
  ///
  /// In en, this message translates to:
  /// **'Show these rows'**
  String get planShowTheseRows;

  /// Budget page, Edit under a category's row: button that archives the category
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get planArchive;

  /// Budget page, a category's menu (⋯ or right-click): red, opens a confirmation when the category has rows
  ///
  /// In en, this message translates to:
  /// **'Delete…'**
  String get planDeleteMenu;

  /// Budget page, new category form: field hint
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get planCategoryName;

  /// Budget page, new category form and delete-category dialog: button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get planCancel;

  /// Budget page, new category form: button
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get planAdd;

  /// Delete category dialog: body when merging and the category has no transactions
  ///
  /// In en, this message translates to:
  /// **'Nothing is filed under it yet.'**
  String get planNothingFiled;

  /// Delete category dialog: body, followed by a category picker
  ///
  /// In en, this message translates to:
  /// **'Only deleted rows are filed under it. They move to:'**
  String get planOnlyDeletedFiled;

  /// Delete category dialog: body, followed by a category picker
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row is filed under it. It moves to:} other{{count} rows are filed under it. They move to:}}'**
  String planRowsFiled(int count);

  /// Delete category dialog: body, some of the transactions are scheduled
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row is filed under it, {scheduled} of them scheduled. It moves to:} other{{count} rows are filed under it, {scheduled} of them scheduled. They move to:}}'**
  String planRowsFiledScheduled(int count, int scheduled);

  /// Delete category dialog: gold note, moving spending rows into Income
  ///
  /// In en, this message translates to:
  /// **'{name} is income: money in these rows will count as income, and money out will take away from it.'**
  String planIntoIncome(String name);

  /// Delete category dialog: gold note, moving rows (some scheduled) into Income
  ///
  /// In en, this message translates to:
  /// **'{name} is income: money in these rows will count as income, money out will take away from it, and scheduled money in can end a forecast.'**
  String planIntoIncomeScheduled(String name);

  /// Delete category dialog: title when a rename matched another category
  ///
  /// In en, this message translates to:
  /// **'Merge {name} into {into}?'**
  String planMergeTitle(String name, String into);

  /// Delete category dialog: title
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String planDeleteTitle(String name);

  /// Delete category dialog: red, when there is nowhere to move the rows
  ///
  /// In en, this message translates to:
  /// **'There’s no other category to move them to. Add one first.'**
  String get planNoOtherCategory;

  /// Delete category dialog: picker button before a category is picked
  ///
  /// In en, this message translates to:
  /// **'Pick a category'**
  String get planPickCategory;

  /// Delete category dialog: red confirm button, disabled until a category is picked
  ///
  /// In en, this message translates to:
  /// **'Delete {name}'**
  String planDeleteButton(String name);

  /// Delete category dialog: red confirm button when merging
  ///
  /// In en, this message translates to:
  /// **'Merge into {into}'**
  String planMergeButton(String into);

  /// Delete category dialog: red confirm button; into is a category name
  ///
  /// In en, this message translates to:
  /// **'Move to {into} and delete'**
  String planMoveAndDelete(String into);

  /// Savings page: page title
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get planSavings;

  /// Savings page: subtitle beside the title
  ///
  /// In en, this message translates to:
  /// **'Every step is done'**
  String get planAllStepsDone;

  /// Savings page: subtitle beside the title
  ///
  /// In en, this message translates to:
  /// **'Getting prepared, one step at a time'**
  String get planOneStepAtATime;

  /// Savings page, step title (step 1): a month of expenses set aside
  ///
  /// In en, this message translates to:
  /// **'Build a safety net'**
  String get planStepOneMonth;

  /// Savings page, step title (step 2): every credit card and loan except the mortgage
  ///
  /// In en, this message translates to:
  /// **'Eliminate debt'**
  String get planStepConsumerDebt;

  /// Savings page, step title (step 3): three to six months of expenses set aside
  ///
  /// In en, this message translates to:
  /// **'Build three to six months of savings'**
  String get planStepMoreMonths;

  /// Savings page, step title (step 4): retirement and the mortgage
  ///
  /// In en, this message translates to:
  /// **'Save for the future'**
  String get planStepFuture;

  /// Savings page, step 4 (Save for the future): heading of its first part
  ///
  /// In en, this message translates to:
  /// **'Saving for retirement'**
  String get planStepRetirement;

  /// Savings page, step 4 (Save for the future): heading of its second part
  ///
  /// In en, this message translates to:
  /// **'Paying off the mortgage'**
  String get planStepLongLoans;

  /// Savings page: blue tag beside the current step’s title
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get planNow;

  /// Savings page: grey tag beside a step the user set aside
  ///
  /// In en, this message translates to:
  /// **'Set aside'**
  String get planSetAside;

  /// Budget page: end of the note under a category's name, a one-time amount that has all been assigned
  ///
  /// In en, this message translates to:
  /// **'set aside'**
  String get planSetAsideState;

  /// Savings page: toast and undo label after setting a step aside
  ///
  /// In en, this message translates to:
  /// **'“{step}” set aside'**
  String planSetAsideUndo(String step);

  /// Savings page: toast and undo label after bringing a step back
  ///
  /// In en, this message translates to:
  /// **'“{step}” back in the steps'**
  String planBackInStepsUndo(String step);

  /// Savings page, safety net step: nothing budgeted and not enough history to know a month
  ///
  /// In en, this message translates to:
  /// **'A month of your expenses isn’t known yet. It comes from your budget once you fill that in, or you can type it.'**
  String get planMonthUnknown;

  /// Savings page, emergency fund steps: history but no spending
  ///
  /// In en, this message translates to:
  /// **'No spending in the last {days} days to go by. Type a month of your expenses.'**
  String planMonthNoSpending(int days);

  /// Savings page, safety net step: the month is what the budget holds for this month; amount like ₮2,400,000
  ///
  /// In en, this message translates to:
  /// **'A month of expenses: {amount}, from your budget'**
  String planMonthBudget(String amount);

  /// Savings page, emergency fund steps: the month the user typed
  ///
  /// In en, this message translates to:
  /// **'A month of expenses: {amount}, as you typed it'**
  String planMonthTyped(String amount);

  /// Savings page, emergency fund steps: averaged month. loans is yes when mortgage/student loan payments are counted
  ///
  /// In en, this message translates to:
  /// **'A month of expenses: {amount}, the average of the last 3 months{loans, select, yes{, loan payments included} other{}}'**
  String planMonthAverage3(String amount, String loans);

  /// Savings page, emergency fund steps: averaged month over under 3 months of history (28+ days)
  ///
  /// In en, this message translates to:
  /// **'A month of expenses: {amount}, the average of the last {days} days{loans, select, yes{, loan payments included} other{}}'**
  String planMonthAverageDays(String amount, int days, String loans);

  /// Savings page, emergency fund steps: progress, what is in the fund of the goal
  ///
  /// In en, this message translates to:
  /// **'{fund} of {target}'**
  String planFundOf(String fund, String target);

  /// Savings page, emergency fund steps: progress and what is still missing
  ///
  /// In en, this message translates to:
  /// **'{fund} of {target} · {left} to go'**
  String planFundOfToGo(String fund, String target, String left);

  /// Savings page, emergency fund steps: guidance when no account is picked
  ///
  /// In en, this message translates to:
  /// **'Your safety net is the Safety net category in your budget: money you assign to it and don’t spend. A separate savings account is the best place to keep it; until you have one, it can sit in the account you spend from.'**
  String get planWhichAccount;

  /// The name the app gives its built-in Safety net budget category when it makes it
  ///
  /// In en, this message translates to:
  /// **'Safety net'**
  String get planFundCategoryName;

  /// Savings page, safety net step: how much of the safety net is already in the account(s) its category is paid from, and how much is still elsewhere; names is one or more account names
  ///
  /// In en, this message translates to:
  /// **'{there} in {names} · {move} still to move there'**
  String planFundWhere(String there, String names, String move);

  /// Savings page, safety net step: the whole safety net is in the account(s) its category is paid from
  ///
  /// In en, this message translates to:
  /// **'All of it is in {names}'**
  String planFundAllIn(String names);

  /// Savings page, safety net step: guidance when the category uses every account; Edit and Paid from are the Budget page’s own words
  ///
  /// In en, this message translates to:
  /// **'Keeping it in a savings account? On the Budget page, open the category’s Edit and set Paid from to that account. This step then shows how much you’ve moved there.'**
  String get planFundSetPaidFrom;

  /// Savings page, safety net step: money not assigned in the budget, above a button offering to assign it to the safety net
  ///
  /// In en, this message translates to:
  /// **'{amount} in your budget is not assigned to anything.'**
  String planFundNotAssigned(String amount);

  /// Budget page: quiet heading above the safety net’s category, under the spending categories
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get planSaved;

  /// Savings page, step 1: guidance
  ///
  /// In en, this message translates to:
  /// **'Keep it where you can reach it. If you use it, fill it back up before anything else.'**
  String get planKeepReachable;

  /// Savings page, step 1: guidance; names are the cards and loans owing
  ///
  /// In en, this message translates to:
  /// **'Until it’s full, pay only the minimums on {names}.'**
  String planMinimumsOn(String names);

  /// Savings page, step 3: guidance
  ///
  /// In en, this message translates to:
  /// **'Enough to get through losing a job or a long illness.'**
  String get planEnoughForJobLoss;

  /// Savings page, retirement step: answered yes
  ///
  /// In en, this message translates to:
  /// **'You’re putting money into it'**
  String get planRetirementYes;

  /// Savings page, retirement step: what it means, before an answer
  ///
  /// In en, this message translates to:
  /// **'Into a retirement plan, from your pay or on your own'**
  String get planRetirementWhat;

  /// Savings page, retirement step: guidance
  ///
  /// In en, this message translates to:
  /// **'If your employer matches what you put in, put in at least enough to get all of it.'**
  String get planEmployerMatch;

  /// Savings page, retirement step: answer button (to “saving for retirement”)
  ///
  /// In en, this message translates to:
  /// **'I am'**
  String get planIAm;

  /// Savings page: undo label after answering a step yes
  ///
  /// In en, this message translates to:
  /// **'{step}: yes'**
  String planAnswerYesUndo(String step);

  /// Savings page: undo label after answering a step not yet
  ///
  /// In en, this message translates to:
  /// **'{step}: not yet'**
  String planAnswerNotYetUndo(String step);

  /// Savings page, consumer debt step: nothing owed
  ///
  /// In en, this message translates to:
  /// **'No credit cards or loans owing'**
  String get planNoCardsOwing;

  /// Savings page, consumer debt step: total owed
  ///
  /// In en, this message translates to:
  /// **'{amount} owed'**
  String planAmountOwed(String amount);

  /// Savings page, consumer debt step: guidance
  ///
  /// In en, this message translates to:
  /// **'Pay extra on one at a time, smallest balance or highest interest first; both get you there. When one is paid off, put its payment toward the next.'**
  String get planPayExtraGuide;

  /// Savings page, mortgage step: the user said there are none
  ///
  /// In en, this message translates to:
  /// **'You have none'**
  String get planLongNone;

  /// Savings page, mortgage step: question before an answer
  ///
  /// In en, this message translates to:
  /// **'Do you have a mortgage?'**
  String get planLongAsk;

  /// Savings page, mortgage part of step 4: guidance; Eliminate debt is step 2’s title
  ///
  /// In en, this message translates to:
  /// **'If a loan under Eliminate debt is the mortgage, mark it there.'**
  String get planLongMarkThere;

  /// Savings page, mortgage step: answer button
  ///
  /// In en, this message translates to:
  /// **'I have none'**
  String get planIHaveNone;

  /// Savings page, mortgage step: answer button
  ///
  /// In en, this message translates to:
  /// **'Paying extra on it'**
  String get planPayingExtraOnThem;

  /// Savings page: answer button
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get planNotYet;

  /// Savings page, mortgage step: undo label
  ///
  /// In en, this message translates to:
  /// **'No mortgage'**
  String get planNoLongLoansUndo;

  /// Savings page, mortgage step: undo label
  ///
  /// In en, this message translates to:
  /// **'Paying extra on the mortgage'**
  String get planPayingExtraUndo;

  /// Savings page, mortgage step: undo label
  ///
  /// In en, this message translates to:
  /// **'Mortgage: not yet'**
  String get planLoansNotYetUndo;

  /// Savings page, mortgage step: undo label
  ///
  /// In en, this message translates to:
  /// **'Not paying extra on the mortgage'**
  String get planNotPayingExtraUndo;

  /// Savings page, mortgage step: nothing left owing
  ///
  /// In en, this message translates to:
  /// **'Paid off'**
  String get planPaidOff;

  /// Savings page, mortgage step: total still owed
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String planAmountLeft(String amount);

  /// Savings page, mortgage step: answer button
  ///
  /// In en, this message translates to:
  /// **'Paying extra'**
  String get planPayingExtra;

  /// Savings page: the last two names of a list; first may already hold several joined by commas
  ///
  /// In en, this message translates to:
  /// **'{first} and {last}'**
  String planNamesAnd(String first, String last);

  /// Savings page: toast and undo label after clearing the typed month
  ///
  /// In en, this message translates to:
  /// **'A month of expenses: no longer the one you typed'**
  String get planMonthBackToAverage;

  /// Savings page: toast and undo label after typing a month
  ///
  /// In en, this message translates to:
  /// **'A month of expenses: {amount}'**
  String planMonthSet(String amount);

  /// Savings page, step 1: gold button when no month is known
  ///
  /// In en, this message translates to:
  /// **'Type a month of expenses'**
  String get planTypeMonth;

  /// Savings page, step 1: button when the user typed the month
  ///
  /// In en, this message translates to:
  /// **'Change the month'**
  String get planChangeMonth;

  /// Savings page, step 1: button when the month is averaged
  ///
  /// In en, this message translates to:
  /// **'Type your own month'**
  String get planTypeOwnMonth;

  /// Savings page, step 1: field hint
  ///
  /// In en, this message translates to:
  /// **'A month of expenses'**
  String get planMonthHint;

  /// Savings page, step 1, beside the month field; and the Budget page, Edit under a category's row: button that keeps what was changed
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get planSave;

  /// Savings page, step 1: note beside the month field
  ///
  /// In en, this message translates to:
  /// **'Empty goes back to your budget or your average'**
  String get planEmptyToAverage;

  /// Savings page, step 3: choice of 3 to 6 months
  ///
  /// In en, this message translates to:
  /// **'{count} months'**
  String planMonthsChoice(int count);

  /// Savings page, step 3: undo label
  ///
  /// In en, this message translates to:
  /// **'Aiming for {count} months'**
  String planAimingFor(int count);

  /// Savings page: what a card or loan counts as (menu and label)
  ///
  /// In en, this message translates to:
  /// **'Mortgage'**
  String get planRoleMortgage;

  /// Savings page: what a card counts as (menu and label)
  ///
  /// In en, this message translates to:
  /// **'Paid in full every month'**
  String get planRolePaidMonthly;

  /// Savings page: what a card or loan counts as (menu and label)
  ///
  /// In en, this message translates to:
  /// **'Debt to pay off'**
  String get planRoleConsumer;

  /// Savings page: undo label
  ///
  /// In en, this message translates to:
  /// **'{account} counts as mortgage'**
  String planCountsAsMortgage(String account);

  /// Savings page: undo label
  ///
  /// In en, this message translates to:
  /// **'{account} counts as paid in full every month'**
  String planCountsAsPaidMonthly(String account);

  /// Savings page: undo label
  ///
  /// In en, this message translates to:
  /// **'{account} counts as debt to pay off'**
  String planCountsAsConsumer(String account);

  /// Savings page: a card or loan line with nothing owed
  ///
  /// In en, this message translates to:
  /// **'nothing owed'**
  String get planNothingOwed;

  /// Savings page: toast and undo label after picking the debt to pay extra on
  ///
  /// In en, this message translates to:
  /// **'Paying extra on {account}'**
  String planPayingExtraOn(String account);

  /// Savings page: menu item on a debt line
  ///
  /// In en, this message translates to:
  /// **'Pay extra on this one'**
  String get planPayExtraOnThis;

  /// Savings page: blue tag on the debt to pay extra on
  ///
  /// In en, this message translates to:
  /// **'Pay extra here'**
  String get planPayExtraHere;

  /// Savings page, step 2: on a debt's line with no interest rate yet; a click opens the field
  ///
  /// In en, this message translates to:
  /// **'Add interest rate'**
  String get planRateAdd;

  /// Savings page, step 2: a debt's interest rate, said by the month
  ///
  /// In en, this message translates to:
  /// **'{rate}% a month'**
  String planRateMonthly(String rate);

  /// Savings page, step 2: a debt's interest rate, said by the year
  ///
  /// In en, this message translates to:
  /// **'{rate}% a year'**
  String planRateYearly(String rate);

  /// Tooltip on the ⓘ beside a debt's interest rate on Savings, step 2
  ///
  /// In en, this message translates to:
  /// **'Step 2 uses this rate to show about how much interest each debt costs you a month.'**
  String get planRateTip;

  /// Interest rate field: the switch that reads the rate as a month's (сарын хүү)
  ///
  /// In en, this message translates to:
  /// **'a month'**
  String get planRatePerMonth;

  /// Interest rate field: the switch that reads the rate as a year's (жилийн хүү)
  ///
  /// In en, this message translates to:
  /// **'a year'**
  String get planRatePerYear;

  /// Savings page, step 2: under a debt, what its rate costs a month
  ///
  /// In en, this message translates to:
  /// **'about {amount} a month in interest'**
  String planInterestAMonth(String amount);

  /// Savings page, step 2: under the debt whose rate costs the most a month, when two or more have a rate
  ///
  /// In en, this message translates to:
  /// **'about {amount} a month in interest, the most of your debts'**
  String planInterestCostsMost(String amount);

  /// Popup and undo label after an interest rate is saved; rate is e.g. “2% a month”
  ///
  /// In en, this message translates to:
  /// **'Interest rate for {name}: {rate}'**
  String planRateSet(String name, String rate);

  /// Popup and undo label after an interest rate is emptied and saved
  ///
  /// In en, this message translates to:
  /// **'Interest rate for {name} taken off'**
  String planRateRemoved(String name);

  /// Beside the interest rate field while a rate is set
  ///
  /// In en, this message translates to:
  /// **'Clear the field to take the rate off'**
  String get planRateEmptyToRemove;

  /// Under the interest rate field, a warning when a month's rate is very high; nothing is refused
  ///
  /// In en, this message translates to:
  /// **'{rate}% a month is {year}% a year. If your bank’s {rate}% is a year’s rate, pick a year.'**
  String planRateLooksYearly(String rate, String year);

  /// Under the interest rate field, a warning when a tugrik debt's yearly rate is very low; nothing is refused
  ///
  /// In en, this message translates to:
  /// **'{rate}% a year is {month}% a month. If your bank’s {rate}% is a month’s rate, pick a month.'**
  String planRateLooksMonthly(String rate, String month);

  /// Add account form: label of the interest rate line, shown for a credit card or loan
  ///
  /// In en, this message translates to:
  /// **'Interest rate'**
  String get setupRate;

  /// Add account form: under the interest rate line
  ///
  /// In en, this message translates to:
  /// **'Step 2 of Savings uses it to show about how much interest this debt costs you a month.'**
  String get setupRateHint;

  /// Savings page: warning under a card marked paid in full every month; date like 2026.09.16
  ///
  /// In en, this message translates to:
  /// **'Owed every day since {date}: a balance is carrying over. It’s left out of the debt to pay off only because it’s marked paid in full.'**
  String planCarried(String date);

  /// Savings page: step ⋯ menu item on a set-aside step
  ///
  /// In en, this message translates to:
  /// **'Bring it back'**
  String get planBringBack;

  /// Savings page: step ⋯ menu item
  ///
  /// In en, this message translates to:
  /// **'Set this step aside'**
  String get planSetStepAside;

  /// Register, Scheduled tab, shown when the list is empty
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled'**
  String get rowsNothingScheduled;

  /// Register, after the payee of the next scheduled row shown at the top of All: it is the next of this many scheduled transactions. Clickable, opens the Scheduled tab
  ///
  /// In en, this message translates to:
  /// **'next of {count} scheduled'**
  String rowsNextOfScheduled(int count);

  /// Register, on the one scheduled row shown at the top of All when it is past its date and so are others: how many other scheduled rows are past their date (1 or more). Follows 'due 7 days ago'. Clickable, opens the Scheduled tab. Lowercase in English.
  ///
  /// In en, this message translates to:
  /// **'{count} more overdue'**
  String rowsMoreOverdue(int count);

  /// Register, under a scheduled bill being confirmed, when a row that looks to be the same bill is already in the account: confirming would put the bill in twice. Names that row as the register shows it: date like 10.05, payee, amount like −₮900,000.00.
  ///
  /// In en, this message translates to:
  /// **'Already in this account · {date} · {payee} · {amount}'**
  String rowsAlreadyIn(String date, String payee, String amount);

  /// As rowsAlreadyIn, when that row is for less than the scheduled bill being confirmed: short is the difference, like ₮800,000.
  ///
  /// In en, this message translates to:
  /// **'Already in this account · {date} · {payee} · {amount} · {short} less than this bill'**
  String rowsAlreadyInLess(
    String date,
    String payee,
    String amount,
    String short,
  );

  /// Button beside rowsAlreadyIn: deletes the scheduled bill being confirmed, since the real one is already in.
  ///
  /// In en, this message translates to:
  /// **'Delete the scheduled one'**
  String get rowsAlreadyInDelete;

  /// Register, after the payee of the only scheduled row shown at the top of All
  ///
  /// In en, this message translates to:
  /// **'scheduled'**
  String get rowsScheduledOnly;

  /// Register, shown when an account has no transactions to list
  ///
  /// In en, this message translates to:
  /// **'No transactions'**
  String get rowsNoTransactions;

  /// Register, shown when the search finds nothing. search is what the user typed
  ///
  /// In en, this message translates to:
  /// **'Nothing matches “{search}”'**
  String rowsNothingMatches(String search);

  /// Register title line while reconciling: the list shows rows not yet reconciled dated up to the statement date. date is a full date
  ///
  /// In en, this message translates to:
  /// **'Not reconciled, through {date}'**
  String rowsNotReconciledThrough(String date);

  /// Register column header
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get rowsColumnDate;

  /// Register column header: who the money went to or came from
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get rowsColumnPayee;

  /// Register column header
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get rowsColumnCategory;

  /// Register column header
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get rowsColumnAmount;

  /// Register column header, the running balance after each row
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get rowsColumnBalance;

  /// Register column header on a credit card or loan: the running amount owed after each row
  ///
  /// In en, this message translates to:
  /// **'Owed'**
  String get rowsColumnOwed;

  /// Register column header while reconciling: running balance of cleared rows only. Short column
  ///
  /// In en, this message translates to:
  /// **'Cleared balance'**
  String get rowsColumnClearedBalance;

  /// Register column header in All accounts view: which account each row is in
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get rowsColumnAccount;

  /// Register filter tab: every transaction
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get rowsTabAll;

  /// Register filter tab: transactions the bank hasn’t settled yet (pending)
  ///
  /// In en, this message translates to:
  /// **'Uncleared'**
  String get rowsTabUncleared;

  /// Register filter tab: future bills and income not yet confirmed
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get rowsTabScheduled;

  /// Popup at the bottom, and the undo label, after a row's category is picked from its dropdown. The row's payee is on the line under it. category may be Income, or Income and a pay's name.
  ///
  /// In en, this message translates to:
  /// **'Filed under {category}'**
  String ledgerFiledUnder(Object category);

  /// Button in the popup card after a row's category is picked from the dropdown: remember it for this payee, and file the payee's other rows still in Not categorized now. One sentence, so "file" carries over to the rows. The payee and the category are on the lines above it, so it names neither. count is those other rows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Remember this for next time} =1{Remember this for next time, and file 1 more row now} other{Remember this for next time, and file {count} more rows now}}'**
  String ledgerAlwaysFile(int count);

  /// Popup card after Remember is clicked; with count 0 it is also the undo label ("Undone · Income remembered for next time": the rows are back, so it doesn't say they were filed). The payee is on the line under it. category may be Income, or Income and a pay's name.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{{category} remembered for next time} =1{{category} remembered for next time · 1 more row filed} other{{category} remembered for next time · {count} more rows filed}}'**
  String ledgerAlwaysFiled(int count, Object category);

  /// A row's category dropdown and chip: income that is one pay's paycheck. pay is the name the person gave the pay (Loveland Solutions).
  ///
  /// In en, this message translates to:
  /// **'Income · {pay}'**
  String rowsIncomeFrom(Object pay);

  /// A row's category dropdown and chip: income that is the paycheck of the one pay set up, when it has no name.
  ///
  /// In en, this message translates to:
  /// **'Income · paycheck'**
  String get rowsIncomePaycheck;

  /// Register filter tab, shown only while rows wait in the Not categorized category (imported rows the app couldn’t match to a category): click shows just those rows. A count follows in brackets. Same words as the category’s name.
  ///
  /// In en, this message translates to:
  /// **'Not categorized'**
  String get rowsTabUncategorized;

  /// Button in the action bar under a selected transaction
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get rowsEdit;

  /// Button in the action bar under a selected transaction, opens a list of categories
  ///
  /// In en, this message translates to:
  /// **'Categorize'**
  String get rowsCategorize;

  /// Button in the action bar under a selected transaction: mark it as settled at the bank
  ///
  /// In en, this message translates to:
  /// **'Mark cleared'**
  String get rowsMarkCleared;

  /// Button in the action bar under a selected transaction: mark it as not yet settled at the bank
  ///
  /// In en, this message translates to:
  /// **'Mark uncleared'**
  String get rowsMarkUncleared;

  /// Button in the action bar under a selected transaction, opens a list of accounts to move it to (it was entered in the wrong account). Not a transfer
  ///
  /// In en, this message translates to:
  /// **'Move to'**
  String get rowsMoveTo;

  /// Button in the action bar under a selected transaction
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get rowsDelete;

  /// Action bar under a reconciled transaction: why Delete and clearing are missing
  ///
  /// In en, this message translates to:
  /// **'Reconciled · date and amount locked'**
  String get rowsReconciledLocked;

  /// Action bar under a reconciled transaction. date is the statement date it was reconciled against (month and day)
  ///
  /// In en, this message translates to:
  /// **'Reconciled on {date} · date and amount locked'**
  String rowsReconciledOnLocked(String date);

  /// Button in the action bar under a row locked by the account’s latest reconcile
  ///
  /// In en, this message translates to:
  /// **'Undo this reconcile'**
  String get rowsUndoThisReconcile;

  /// Action bar under a transfer whose other side was reconciled in another account. account is that account’s name
  ///
  /// In en, this message translates to:
  /// **'Reconciled in {account} · date and amount locked'**
  String rowsReconciledInLocked(String account);

  /// Tooltip on the status symbol at the start of a register row. status is uncleared, cleared or reconciled
  ///
  /// In en, this message translates to:
  /// **'{status, select, uncleared{Uncleared — the bank hasn’t cleared it yet, even if it shows there as pending. Click once it clears.} cleared{Cleared — the bank has cleared it. Click to mark uncleared.} other{Reconciled — matches a statement, so its date and amount are locked.}}'**
  String rowsStatusTip(String status);

  /// Tooltip on the status symbol of a transfer, when the status shown is the other side’s. account is the other account’s name; status is uncleared, cleared or reconciled
  ///
  /// In en, this message translates to:
  /// **'{status, select, uncleared{In {account}: Uncleared — the bank hasn’t cleared it yet, even if it shows there as pending. Click once it clears.} cleared{In {account}: Cleared — the bank has cleared it. Click to mark uncleared.} other{In {account}: Reconciled — matches a statement, so its date and amount are locked.}}'**
  String rowsStatusTipIn(String account, String status);

  /// Register row of a transfer out: the quiet word shown BEFORE the other account’s name (which is shown bold). Leave empty if your language puts the word after the name
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get rowsTransferToBefore;

  /// Register row of a transfer out: the quiet word shown AFTER the other account’s name. Empty in English ("To Golomt Visa")
  ///
  /// In en, this message translates to:
  /// **''**
  String get rowsTransferToAfter;

  /// Register row of a transfer in: the quiet word shown BEFORE the other account’s name (which is shown bold). Leave empty if your language puts the word after the name
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get rowsTransferFromBefore;

  /// Register row of a transfer in: the quiet word shown AFTER the other account’s name. Empty in English ("From Golomt Visa")
  ///
  /// In en, this message translates to:
  /// **''**
  String get rowsTransferFromAfter;

  /// Scheduled register row of a transfer out. account is the other account’s name
  ///
  /// In en, this message translates to:
  /// **'To {account}'**
  String rowsScheduledTransferTo(String account);

  /// Scheduled register row of a transfer in. account is the other account’s name
  ///
  /// In en, this message translates to:
  /// **'From {account}'**
  String rowsScheduledTransferFrom(String account);

  /// Tooltip on the calendar symbol of a scheduled register row
  ///
  /// In en, this message translates to:
  /// **'Scheduled — not in any balance until confirmed'**
  String get rowsScheduledTip;

  /// Button on a scheduled row, and the entry row’s button when confirming one: it happened, make it a real transaction
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get rowsConfirm;

  /// Last line of the category list while typing a name that isn’t a category yet; picking it creates one. name is what was typed
  ///
  /// In en, this message translates to:
  /// **'+ New category “{name}”'**
  String rowsNewCategoryOption(String name);

  /// Entry row, note by Add when the category typed is an account’s name: → before an account means a transfer to it
  ///
  /// In en, this message translates to:
  /// **'Did you mean “→ {account}”?'**
  String rowsDidYouMeanTransfer(String account);

  /// Entry row, note by Add when the category typed is part of one existing name. first is that category
  ///
  /// In en, this message translates to:
  /// **'“{typed}” isn’t a category · pick {first}, or + New category'**
  String rowsNotACategoryPickOne(String typed, String first);

  /// Entry row, note by Add when the category typed is part of existing names. first and second are two of them
  ///
  /// In en, this message translates to:
  /// **'“{typed}” isn’t a category · pick {first} or {second}, or + New category'**
  String rowsNotACategoryPickTwo(String typed, String first, String second);

  /// Entry row, note by Add: saving will create this category
  ///
  /// In en, this message translates to:
  /// **'new category'**
  String get rowsNewCategoryNote;

  /// Entry row, line under a transfer being typed, before an amount is typed: which way it goes. from and to are account names
  ///
  /// In en, this message translates to:
  /// **'From {from} to {to}'**
  String rowsTransferFromTo(String from, String to);

  /// Entry row, line under a transfer being typed: which way the money goes. amount is formatted money; from and to are account names
  ///
  /// In en, this message translates to:
  /// **'{amount} from {from} to {to}'**
  String rowsTransferAmountFromTo(String amount, String from, String to);

  /// Popup at the bottom when an entry row can’t be saved when the date typed isn’t a real date. Keep the example date as is
  ///
  /// In en, this message translates to:
  /// **'Enter the date as 2026.09.16'**
  String get rowsErrorDate;

  /// Popup at the bottom when an entry row can’t be saved: a transfer to the account the row is in
  ///
  /// In en, this message translates to:
  /// **'Can’t transfer to the same account'**
  String get rowsErrorSameAccount;

  /// Popup at the bottom when an entry row can’t be saved: the → name typed in Category isn’t an account
  ///
  /// In en, this message translates to:
  /// **'No account “{name}”'**
  String rowsErrorNoAccount(String name);

  /// Popup at the bottom when an entry row can’t be saved: the amount typed isn’t a number. typed is what was typed
  ///
  /// In en, this message translates to:
  /// **'“{typed}” isn’t a valid amount'**
  String rowsErrorAmount(String typed);

  /// The box under the new-transaction row and a row's Edit (owner, 2026-10-12). Ticked, the category is remembered for the payee when the row is saved, as the popup's offer does.
  ///
  /// In en, this message translates to:
  /// **'Remember this category for this payee'**
  String get rowsRemember;

  /// Entry row button when editing an existing transaction
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get rowsSave;

  /// Entry row button that adds the new transaction
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get rowsAdd;

  /// Entry row, note by Add while the amount is a calculation (100+50): its result. sum is formatted money
  ///
  /// In en, this message translates to:
  /// **'= {sum}'**
  String rowsSum(String sum);

  /// Entry row, note by Add: a calculation’s result, then a note such as “new category”
  ///
  /// In en, this message translates to:
  /// **'= {sum} · {note}'**
  String rowsSumWithNote(String sum, String note);

  /// Entry row, note by Add: the one required field still empty. field is when (the date), account, payee, category or amount
  ///
  /// In en, this message translates to:
  /// **'{field, select, when{needs date} account{needs account} payee{needs payee} category{needs category} other{needs amount}}'**
  String rowsNeeds(String field);

  /// Entry row, note by Add: how many required fields are still empty (2 or more)
  ///
  /// In en, this message translates to:
  /// **'needs {count} more'**
  String rowsNeedsMore(int count);

  /// Entry row, button beside Save while editing a transaction: closes the row without saving
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get rowsCancelEdit;

  /// Last entry in an entry row’s Category list: opens the card that shares the amount over several categories (one receipt for groceries and clothing).
  ///
  /// In en, this message translates to:
  /// **'Split over categories…'**
  String get rowsSplitOption;

  /// Heading of the split card under an entry row: the payee and the receipt’s total, e.g. 'Nomin, ₮135,500.00'.
  ///
  /// In en, this message translates to:
  /// **'{payee}, {amount}'**
  String rowsSplitTitle(String payee, String amount);

  /// Split card, top right: how much of the total has no category yet, e.g. '₮37,500.00 left'.
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String rowsSplitLeft(String amount);

  /// Split card, top right: the lines add up to more than the total, e.g. '₮2,000.00 too much'.
  ///
  /// In en, this message translates to:
  /// **'{amount} too much'**
  String rowsSplitTooMuch(String amount);

  /// Split card, top right, when no total was typed in Amount: what the lines add up to. Done puts it in Amount.
  ///
  /// In en, this message translates to:
  /// **'{amount} in all'**
  String rowsSplitInAll(String amount);

  /// Split card: adds a line for one more category.
  ///
  /// In en, this message translates to:
  /// **'+ Another category'**
  String get rowsSplitAnother;

  /// Split card: tooltip on the ✕ beside a line.
  ///
  /// In en, this message translates to:
  /// **'Take this category off'**
  String get rowsSplitRemove;

  /// Split card: closes it and keeps its lines; the row is then saved with Add or Save as usual.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get rowsSplitDone;

  /// Popup at the bottom when a split row can’t be saved: part of the total has no category yet, e.g. 'Place the last ₮37,500.00'.
  ///
  /// In en, this message translates to:
  /// **'Place the last {amount}'**
  String rowsErrorSplitLeft(String amount);

  /// Popup at the bottom when a split row can’t be saved: its lines add up to more than its amount.
  ///
  /// In en, this message translates to:
  /// **'The lines are {amount} more than the total'**
  String rowsErrorSplitTooMuch(String amount);

  /// Popup at the bottom when a split row can’t be saved: a line has an amount but no category.
  ///
  /// In en, this message translates to:
  /// **'Pick a category for {amount}'**
  String rowsErrorSplitNoCategory(String amount);

  /// Popup at the bottom when a split row can’t be saved: a line names a category that doesn’t exist. New categories are made from the row’s own Category field or the Budget page.
  ///
  /// In en, this message translates to:
  /// **'There’s no category “{name}”'**
  String rowsErrorSplitUnknown(String name);

  /// Popup at the bottom when a split row can’t be saved: two lines name the same category. A split names each category once.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is already on another line'**
  String rowsErrorSplitTwice(String name);

  /// Phone app: heading of the page that shares one entry over several categories.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get phoneSplitTitle;

  /// Under the row editor: a split’s lines and its total differ.
  ///
  /// In en, this message translates to:
  /// **'The split’s lines don’t add up to its amount'**
  String get ledgerDbSplitDoesntAddUp;

  /// Tooltip on a locked date, amount or transfer account while editing a reconciled transaction
  ///
  /// In en, this message translates to:
  /// **'Reconciled · this matches a bank statement, so it can’t change'**
  String get rowsReconciledTip;

  /// Tooltip on the locked category while editing an account's opening balance.
  ///
  /// In en, this message translates to:
  /// **'An opening balance belongs to its account'**
  String get rowsOpeningBalanceTip;

  /// Tooltip on the locked category while editing the difference a reconcile posted.
  ///
  /// In en, this message translates to:
  /// **'An adjustment belongs to its account'**
  String get rowsAdjustmentTip;

  /// Tooltip on the locked category while editing a transfer whose other account is deleted.
  ///
  /// In en, this message translates to:
  /// **'The other account is deleted'**
  String get rowsOtherAccountDeleted;

  /// Tooltip on the locked category while editing a transfer whose other account is archived.
  ///
  /// In en, this message translates to:
  /// **'The other account is archived'**
  String get rowsOtherAccountArchived;

  /// Entry row, placeholder in the payee field while editing
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get rowsHintPayee;

  /// Entry row, placeholder in the payee field of a new transaction
  ///
  /// In en, this message translates to:
  /// **'New transaction — payee'**
  String get rowsHintNewPayee;

  /// Entry row, placeholder in the memo field
  ///
  /// In en, this message translates to:
  /// **'Memo'**
  String get rowsHintMemo;

  /// Entry row, placeholder in the category field
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get rowsHintCategory;

  /// Placeholder in a date field (entry row, statement date)
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get rowsHintDate;

  /// Entry row in All accounts, placeholder in the account picker: which account the new row goes in
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get rowsHintAccount;

  /// Confirming money in that came short, line under the entry row; two choices follow. amount is formatted money
  ///
  /// In en, this message translates to:
  /// **'{amount} less than planned:'**
  String rowsLessThanPlanned(String amount);

  /// Choice after “less than planned”: the missing part is still to come, kept scheduled on this date (month and day)
  ///
  /// In en, this message translates to:
  /// **'Still owed, due {date}'**
  String rowsStillOwedDue(String date);

  /// Choice after “less than planned”: nothing more is coming
  ///
  /// In en, this message translates to:
  /// **'Paid in full'**
  String get rowsPaidInFull;

  /// Tooltip on Swap, beside the line saying which way a transfer goes
  ///
  /// In en, this message translates to:
  /// **'Turn it around'**
  String get rowsTurnItAround;

  /// Small button beside the line saying which way a transfer goes: turns its direction around
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get rowsSwap;

  /// Date picker calendar, tooltip on the left arrow
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get rowsPreviousMonth;

  /// Date picker calendar, tooltip on the right arrow
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get rowsNextMonth;

  /// Date picker calendar, the weekday column heads, Monday first, separated by |. Two letters each
  ///
  /// In en, this message translates to:
  /// **'Mo|Tu|We|Th|Fr|Sa|Su'**
  String get rowsWeekdayInitials;

  /// Date picker calendar, under the days when a future day is hovered or picked
  ///
  /// In en, this message translates to:
  /// **'After today · it will be scheduled'**
  String get rowsAfterTodayScheduled;

  /// Tooltip on the entry row’s Add / Save button. key is the Enter key’s name
  ///
  /// In en, this message translates to:
  /// **'Or press {key} in any field'**
  String rowsOrPressKey(String key);

  /// Title of the reconcile panel that replaces the balance header while matching the account to a bank statement
  ///
  /// In en, this message translates to:
  /// **'Reconcile'**
  String get rowsReconcileTitle;

  /// Reconcile panel, label beside the date field. Short label column
  ///
  /// In en, this message translates to:
  /// **'Statement date'**
  String get rowsStatementDate;

  /// Reconcile panel on a credit card or loan, label beside the field for what the bank says is owed. Short label column
  ///
  /// In en, this message translates to:
  /// **'Bank says you owe'**
  String get rowsBankSaysYouOwe;

  /// Reconcile panel, label beside the field for the balance on the bank statement. Short label column
  ///
  /// In en, this message translates to:
  /// **'Bank balance'**
  String get rowsBankBalance;

  /// Reconcile panel, beside the empty bank balance field: bank apps also show an available balance (minus pending holds), which won’t match
  ///
  /// In en, this message translates to:
  /// **'Not the “available” balance'**
  String get rowsNotAvailableBalance;

  /// Reconcile panel, label: total of the cleared rows in this app. Short label column
  ///
  /// In en, this message translates to:
  /// **'Cleared here'**
  String get rowsClearedHere;

  /// Reconcile panel, label: the difference between the bank and this app
  ///
  /// In en, this message translates to:
  /// **'Off by'**
  String get rowsOffBy;

  /// Reconcile panel, shown in place of the difference when it is zero
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get rowsMatches;

  /// Reconcile panel, beside the difference: the bank’s balance is lower than here
  ///
  /// In en, this message translates to:
  /// **'Bank is lower'**
  String get rowsBankIsLower;

  /// Reconcile panel, beside the difference: the bank’s balance is higher than here
  ///
  /// In en, this message translates to:
  /// **'Bank is higher'**
  String get rowsBankIsHigher;

  /// Reconcile panel on a credit card or loan, beside the difference
  ///
  /// In en, this message translates to:
  /// **'Bank says you owe less'**
  String get rowsBankSaysOweLess;

  /// Reconcile panel on a credit card or loan, beside the difference
  ///
  /// In en, this message translates to:
  /// **'Bank says you owe more'**
  String get rowsBankSaysOweMore;

  /// Reconcile panel, under the difference when no single row explains it
  ///
  /// In en, this message translates to:
  /// **'Clear the rows your bank shows'**
  String get rowsHintClearRows;

  /// Reconcile panel, under the difference: this one uncleared row is exactly the difference. date is month and day; amount is formatted money
  ///
  /// In en, this message translates to:
  /// **'{payee} on {date} is {amount} and isn’t cleared'**
  String rowsHintNotCleared(String payee, String date, String amount);

  /// Reconcile panel, under the difference: this row dated after the statement date is exactly the difference
  ///
  /// In en, this message translates to:
  /// **'{payee} is {amount} but dated {date}, after the statement'**
  String rowsHintDatedAfter(String payee, String date, String amount);

  /// Reconcile panel, under the difference: this cleared row is exactly the difference, maybe not at the bank yet
  ///
  /// In en, this message translates to:
  /// **'{payee} on {date} is {amount} and cleared here · not at the bank yet?'**
  String rowsHintClearedEarly(String payee, String date, String amount);

  /// Reconcile panel button: stop reconciling
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get rowsCancel;

  /// Reconcile panel button when the numbers don’t match: posts the difference as an adjustment row, then locks. amount is formatted money
  ///
  /// In en, this message translates to:
  /// **'Add {amount} adjustment and lock'**
  String rowsAddAdjustmentAndLock(String amount);

  /// Reconcile panel button when there’s nothing new to lock
  ///
  /// In en, this message translates to:
  /// **'Mark reconciled'**
  String get rowsMarkReconciled;

  /// Reconcile panel button, dimmed until the numbers match: locks the cleared rows against the statement
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Lock 1 transaction} other{Lock {count} transactions}}'**
  String rowsLockTransactions(int count);

  /// Archive-account warning: what a card or loan still owes. amount is money like ₮120,000.
  ///
  /// In en, this message translates to:
  /// **'You still owe {amount} on it.'**
  String setupOwedStill(String amount);

  /// Archive-account warning: a card or loan paid past zero.
  ///
  /// In en, this message translates to:
  /// **'It’s {amount} in credit: the bank owes you.'**
  String setupInCredit(String amount);

  /// Archive-account warning: money still in a bank account.
  ///
  /// In en, this message translates to:
  /// **'{amount} is still in it.'**
  String setupStillIn(String amount);

  /// Archive-account warning: a bank account below zero.
  ///
  /// In en, this message translates to:
  /// **'It’s {amount} overdrawn.'**
  String setupOverdrawn(String amount);

  /// Sidebar, under the accounts; also the New account page's main button.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get setupAddAccount;

  /// New account page title; also the name given (and shown as the hint) when the name is left empty.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get setupNewAccount;

  /// Pay setup, label beside the name field (first line): what the user calls this pay, to tell two earners' apart. Short.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get setupName;

  /// New account page, label beside the two kinds of account.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get setupKind;

  /// New account page, a kind of account (checking or savings). Short button.
  ///
  /// In en, this message translates to:
  /// **'Bank account'**
  String get setupKindBank;

  /// New account page, a kind of account: cash in hand, a wallet or a tin. Short button.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get setupKindCash;

  /// New account page, note under the kinds when Cash is picked.
  ///
  /// In en, this message translates to:
  /// **'Cash you hold: a wallet, a tin at home. There’s no statement to check it against, so it’s yours to keep true — type what you spend.'**
  String get setupKindCashHint;

  /// New account page, a kind of account (credit card, loan, Storepay). Short button.
  ///
  /// In en, this message translates to:
  /// **'Credit card or loan'**
  String get setupKindOwed;

  /// New account page, note under the kinds when Credit card or loan is picked.
  ///
  /// In en, this message translates to:
  /// **'A credit card, a loan or Storepay: shows what you owe, as a positive amount, the way the bank does.'**
  String get setupKindOwedHint;

  /// New account page, note under the kinds when Bank account is picked.
  ///
  /// In en, this message translates to:
  /// **'Checking or savings, at a bank.'**
  String get setupKindBankHint;

  /// Button that closes a form or dialog without doing anything (new account page, account warnings, pay setup).
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get setupCancel;

  /// First screen of a new card or loan account, title, when the date is today.
  ///
  /// In en, this message translates to:
  /// **'What do you owe on it today?'**
  String get setupStartOwedToday;

  /// First screen of a new bank account, title, when the date is today.
  ///
  /// In en, this message translates to:
  /// **'What’s in this account today?'**
  String get setupStartInToday;

  /// First screen of a new card or loan account, title, when an earlier date is typed. date is like 09.16 / 9-р сарын 16.
  ///
  /// In en, this message translates to:
  /// **'What did you owe on it on {date}?'**
  String setupStartOwedOn(String date);

  /// First screen of a new bank account, title, when an earlier date is typed. date is like 09.16 / 9-р сарын 16.
  ///
  /// In en, this message translates to:
  /// **'What was in it on {date}?'**
  String setupStartInOn(String date);

  /// First screen of a new card or loan account, label beside the amount field.
  ///
  /// In en, this message translates to:
  /// **'You owe'**
  String get setupYouOwe;

  /// First screen of a new bank account, label beside the amount field.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get setupBalance;

  /// First screen of a new account, label beside the date field ("as of this date").
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get setupOn;

  /// First screen of a new account, red note when the typed amount isn't a number. text is what was typed.
  ///
  /// In en, this message translates to:
  /// **'Can’t read “{text}” as an amount'**
  String setupCantRead(String text);

  /// Red note when a typed date can't be read. example is today as 2026.09.30.
  ///
  /// In en, this message translates to:
  /// **'Date should look like {example}'**
  String setupDateShouldLook(String example);

  /// A new card or loan's first screen, under the amount. zero is ₮0 or $0.
  ///
  /// In en, this message translates to:
  /// **'What you’ve used, not the available limit · empty starts at {zero}'**
  String setupStartOwedHint(Object zero);

  /// A new bank account's first screen, under the amount. zero is ₮0 or $0.
  ///
  /// In en, this message translates to:
  /// **'From the bank app, a statement or what you count, not the “available” balance · empty starts at {zero}'**
  String setupStartBankHint(Object zero);

  /// New account, beside Start account: answer the balance question with the bank's file instead of typing. Opens the Mac's open dialog, then the import window.
  ///
  /// In en, this message translates to:
  /// **'Or import a file from your bank'**
  String get setupStartImport;

  /// First screen of a new account, main button.
  ///
  /// In en, this message translates to:
  /// **'Start account'**
  String get setupStartAccount;

  /// Account menu (⋯ beside the name, or right-click in the sidebar).
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get setupRename;

  /// Account menu: turn a card or loan account into a bank account.
  ///
  /// In en, this message translates to:
  /// **'Change to bank account'**
  String get setupToBank;

  /// Account menu: turn a bank account into a card or loan account.
  ///
  /// In en, this message translates to:
  /// **'Change to credit card or loan'**
  String get setupToOwed;

  /// Account menu: take the account out of the sidebar (asks first).
  ///
  /// In en, this message translates to:
  /// **'Archive…'**
  String get setupArchiveMenu;

  /// Account menu: delete the account (asks first).
  ///
  /// In en, this message translates to:
  /// **'Delete…'**
  String get setupDeleteMenu;

  /// Tooltip on the account name at the top of its page.
  ///
  /// In en, this message translates to:
  /// **'Click to rename'**
  String get setupClickToRename;

  /// Archive-account warning. balance is one of the sentences about what's in the account (e.g. "₮5,000 is still in it.").
  ///
  /// In en, this message translates to:
  /// **'{balance} It stays in net worth, but the account won’t be in the sidebar.'**
  String setupArchiveBalance(String balance);

  /// Archive-account warning: future bills or income on the account. list is up to three "payee date" items, comma-separated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 scheduled row ({list}) won’t show in any forecast.} other{{count} scheduled rows ({list}) won’t show in any forecast.}}'**
  String setupArchiveScheduled(int count, String list);

  /// Archive-account warning: future transfers to another account. list is up to three "payee date" items.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 scheduled transfer stays on the other account’s forecast ({list}). Delete it there if cancelled.} other{{count} scheduled transfers stay on the other account’s forecast ({list}). Delete them there if cancelled.}}'**
  String setupArchiveTransfers(int count, String list);

  /// Delete-account warning, first line, when the account has no transactions.
  ///
  /// In en, this message translates to:
  /// **'This deletes the account. It has no rows of its own.'**
  String get setupDeleteNoRows;

  /// Delete-account warning, first line. count is how many transactions it has.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This deletes the account and its 1 row.} other{This deletes the account and its {count} rows.}}'**
  String setupDeleteRows(int count);

  /// Delete-account warning, first line, when some of its transactions are reconciled.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This deletes the account and its 1 row, {reconciled} of them reconciled.} other{This deletes the account and its {count} rows, {reconciled} of them reconciled.}}'**
  String setupDeleteRowsReconciled(int count, int reconciled);

  /// Delete-account warning: deleting money you have.
  ///
  /// In en, this message translates to:
  /// **'Net worth goes down by {amount}.'**
  String setupWorthDown(String amount);

  /// Delete-account warning: deleting an overdrawn bank account.
  ///
  /// In en, this message translates to:
  /// **'Net worth goes up by {amount}.'**
  String setupWorthUp(String amount);

  /// Delete-account warning: deleting a card or loan that still owes.
  ///
  /// In en, this message translates to:
  /// **'Net worth goes up by {amount}, since what you owe on it is no longer counted.'**
  String setupWorthUpOwed(String amount);

  /// Delete-account warning: scheduled transfers with other accounts that stay. list is up to three "account date" items.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One is still scheduled ({list}). Confirmed later, it moves money from an account that no longer exists; delete it there if cancelled.} other{{count} are still scheduled ({list}). Confirmed later, they move money from an account that no longer exists; delete them there if cancelled.}}'**
  String setupDeletePending(int count, String list);

  /// Delete-account warning: transfers with one other account stay there. other is that account; label is how the deleted one will be named there, e.g. “Khan (deleted)”.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Its 1 transfer with {other} stay on {other} as “{label}”.} other{Its {count} transfers with {other} stay on {other} as “{label}”.}}'**
  String setupKeptOne(int count, String other, String label);

  /// Delete-account warning: transfers with several other accounts stay there. label is how the deleted account will be named, e.g. “Khan (deleted)”; list is items like "3 on Khan", comma-separated.
  ///
  /// In en, this message translates to:
  /// **'Its transfers stay on the other accounts as “{label}”: {list}.'**
  String setupKeptMany(String label, String list);

  /// Delete-account warning, one item of the list: how many transfers stay on an account.
  ///
  /// In en, this message translates to:
  /// **'{count} on {account}'**
  String setupKeptOn(int count, String account);

  /// Settings, card title: accounts taken out of the sidebar.
  ///
  /// In en, this message translates to:
  /// **'Archived accounts'**
  String get setupArchived;

  /// Settings → Archived accounts: what an archived card or loan owes.
  ///
  /// In en, this message translates to:
  /// **'{amount} owed'**
  String setupAmountOwed(String amount);

  /// Settings → Archived accounts, button that un-archives.
  ///
  /// In en, this message translates to:
  /// **'Show in sidebar'**
  String get setupShowInSidebar;

  /// Sidebar, top: every account's rows in one register.
  ///
  /// In en, this message translates to:
  /// **'All accounts'**
  String get setupAllAccounts;

  /// Tooltip on ✕ of a filter chip on All accounts. Esc is the key.
  ///
  /// In en, this message translates to:
  /// **'Show every row · Esc'**
  String get setupShowEveryRow;

  /// Pay setup, note by Save when the amount is empty.
  ///
  /// In en, this message translates to:
  /// **'Type how much you’re paid'**
  String get setupAmountMissing;

  /// Pay setup (twice a month, different amounts), note when one amount is empty. day is startDayOn: English "10th", Mongolian "10-нд".
  ///
  /// In en, this message translates to:
  /// **'Type how much you’re paid on the {day}'**
  String setupAmountMissingOn(String day);

  /// Pay setup (twice a month, different amounts), note before the days are typed.
  ///
  /// In en, this message translates to:
  /// **'Type how much you’re paid on the first payday'**
  String get setupAmountMissingFirst;

  /// Pay setup (twice a month, different amounts), note before the days are typed.
  ///
  /// In en, this message translates to:
  /// **'Type how much you’re paid on the second payday'**
  String get setupAmountMissingSecond;

  /// Pay setup, label beside one payday's amount (twice a month). Short. day is startDayOn: English "10th", Mongolian "10-нд".
  ///
  /// In en, this message translates to:
  /// **'On the {day}'**
  String setupOnDay(String day);

  /// Pay setup, label beside one payday's amount when pay varies. Short. day is startDayOn: English "10th", Mongolian "10-нд".
  ///
  /// In en, this message translates to:
  /// **'At least, on the {day}'**
  String setupAtLeastOnDay(String day);

  /// Pay setup, label beside the first payday's amount before the days are typed. Short.
  ///
  /// In en, this message translates to:
  /// **'On the first payday'**
  String get setupOnFirst;

  /// Pay setup, label beside the second payday's amount before the days are typed. Short.
  ///
  /// In en, this message translates to:
  /// **'On the second payday'**
  String get setupOnSecond;

  /// Pay setup, label as above when pay varies. Short.
  ///
  /// In en, this message translates to:
  /// **'At least, on the first payday'**
  String get setupAtLeastOnFirst;

  /// Pay setup, label as above when pay varies. Short.
  ///
  /// In en, this message translates to:
  /// **'At least, on the second payday'**
  String get setupAtLeastOnSecond;

  /// Pay setup, note by Save when the monthly day is missing.
  ///
  /// In en, this message translates to:
  /// **'Which day of the month?'**
  String get setupWhichDay;

  /// Pay setup, note when a twice-a-month day is missing.
  ///
  /// In en, this message translates to:
  /// **'Which two days of the month?'**
  String get setupWhichTwoDays;

  /// Pay setup, note when both twice-a-month days are the same.
  ///
  /// In en, this message translates to:
  /// **'Two different days of the month'**
  String get setupTwoDifferentDays;

  /// Pay setup, note when the number of weeks is missing.
  ///
  /// In en, this message translates to:
  /// **'Every how many weeks?'**
  String get setupHowManyWeeks;

  /// Pay setup, note when the every-few-weeks start date is missing. example is today as 2026.09.30.
  ///
  /// In en, this message translates to:
  /// **'When is a payday? ({example})'**
  String setupWhenPayday(String example);

  /// Pay setup dialog title for new pay; the Budget page's Income tab button when there is no pay yet.
  ///
  /// In en, this message translates to:
  /// **'Add your pay'**
  String get setupAddYourPay;

  /// Pay setup dialog title when editing pay.
  ///
  /// In en, this message translates to:
  /// **'Your pay'**
  String get setupYourPay;

  /// Pay setup, label beside the account pay goes into. Also the phone app’s Ledger, in place of Paid from, when the entry is money in: the account a refund or income went into. Short.
  ///
  /// In en, this message translates to:
  /// **'Paid into'**
  String get setupPaidInto;

  /// Pay setup, label beside the employer field. Short.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get setupFrom;

  /// Pay setup, hint in the empty employer field.
  ///
  /// In en, this message translates to:
  /// **'Employer (optional)'**
  String get setupEmployerHint;

  /// Pay setup, hint in the empty name field.
  ///
  /// In en, this message translates to:
  /// **'Jenny, or Jeff’s job (optional)'**
  String get setupNameHint;

  /// Pay setup, label beside "About the same each time" / "It varies". Short.
  ///
  /// In en, this message translates to:
  /// **'Pay is'**
  String get setupPayIs;

  /// Pay setup, choice: the amount doesn't change.
  ///
  /// In en, this message translates to:
  /// **'About the same each time'**
  String get setupPaySame;

  /// Pay setup, choice: the amount changes each time.
  ///
  /// In en, this message translates to:
  /// **'It varies'**
  String get setupPayVaries;

  /// Pay setup, note under "It varies".
  ///
  /// In en, this message translates to:
  /// **'Hourly, shifts, overtime: it changes each time. Leave bonuses out; they aren’t every payday.'**
  String get setupVariesHint;

  /// Pay setup, label beside the amount when pay varies. Short.
  ///
  /// In en, this message translates to:
  /// **'Expect at least'**
  String get setupExpectAtLeast;

  /// Pay setup, label beside the amount. Short.
  ///
  /// In en, this message translates to:
  /// **'Each payday'**
  String get setupEachPayday;

  /// Pay setup (twice a month), choice: one amount both days.
  ///
  /// In en, this message translates to:
  /// **'The same each paycheck'**
  String get setupSameEachPaycheck;

  /// Pay setup (twice a month), choice: an advance one day, the rest the other.
  ///
  /// In en, this message translates to:
  /// **'A different amount each paycheck'**
  String get setupDifferentEachPaycheck;

  /// Pay setup, note: the one paycheck found in the ledger.
  ///
  /// In en, this message translates to:
  /// **'Your last paycheck: {amount}'**
  String setupLastPaycheck(String amount);

  /// Pay setup, note: the range of recent paychecks found (count is 2 or more).
  ///
  /// In en, this message translates to:
  /// **'Your last {count}: lowest {lowest} · highest {highest}'**
  String setupLastPaychecks(int count, String lowest, String highest);

  /// Pay setup, note when pay varies.
  ///
  /// In en, this message translates to:
  /// **'The forecast counts on this, so the low end is safer: finding more on payday is better than finding less.'**
  String get setupLowEndSafer;

  /// Pay setup, amber warning when the typed amount is above some recent paychecks.
  ///
  /// In en, this message translates to:
  /// **'Higher than {above} of your last {count} paychecks: the forecast may look better than it’ll be.'**
  String setupHigherThan(int above, int count);

  /// Pay setup, label beside how often pay comes. Short.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get setupWhen;

  /// Pay setup, choice.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get setupMonthly;

  /// Pay setup, choice.
  ///
  /// In en, this message translates to:
  /// **'Twice a month'**
  String get setupTwiceMonthly;

  /// Pay setup, choice.
  ///
  /// In en, this message translates to:
  /// **'Every few weeks'**
  String get setupEveryFewWeeks;

  /// Pay setup, monthly: the words around the day-of-month box. field is where the box goes; keep it exactly once.
  ///
  /// In en, this message translates to:
  /// **'On the {field}'**
  String setupOnDayField(String field);

  /// Pay setup, twice a month: the words around the two day-of-month boxes. first and second are where the boxes go.
  ///
  /// In en, this message translates to:
  /// **'On the {first}  and the {second}'**
  String setupOnDaysField(String first, String second);

  /// Pay setup, every few weeks: the words around the weeks box and the start-date box. weeks and date are where the boxes go; count is the number typed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every {weeks} week, from {date}} other{Every {weeks} weeks, from {date}}}'**
  String setupEveryWeeksField(int count, String weeks, String date);

  /// Pay setup, amber note when both twice-a-month days are the 28th or later.
  ///
  /// In en, this message translates to:
  /// **'In shorter months both days land on the last day: one payday that month, not two.'**
  String get setupDaysMeet;

  /// Pay setup, label: where a payday that falls on a weekend moves. Short.
  ///
  /// In en, this message translates to:
  /// **'On a weekend'**
  String get setupOnWeekend;

  /// Pay setup, choice: a weekend payday moves to the Friday before.
  ///
  /// In en, this message translates to:
  /// **'Friday before'**
  String get setupFridayBefore;

  /// Pay setup, choice: a weekend payday moves to the Monday after.
  ///
  /// In en, this message translates to:
  /// **'Monday after'**
  String get setupMondayAfter;

  /// Pay setup, choice: a weekend payday stays on its Saturday or Sunday (some are paid on a Saturday).
  ///
  /// In en, this message translates to:
  /// **'Keep the day'**
  String get setupKeepTheDay;

  /// Was the pay setup's "Budget by" choice; unused since 2026-10-05, kept for the Mongolian review sheet.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get setupMonth;

  /// Pay setup, note for every-two-weeks pay (26 paydays).
  ///
  /// In en, this message translates to:
  /// **'{count} paydays a year: two months a year have three.'**
  String setupPaydaysAYear(int count);

  /// Pay setup, summary by Save. date is a full date in a sentence.
  ///
  /// In en, this message translates to:
  /// **'Next payday {date} · {amount}'**
  String setupNextPayday(String date, String amount);

  /// Pay setup, summary by Save when pay varies.
  ///
  /// In en, this message translates to:
  /// **'Next payday {date} · {amount} or more'**
  String setupNextPaydayOrMore(String date, String amount);

  /// Pay setup, summary by Save when pay comes more than once a month.
  ///
  /// In en, this message translates to:
  /// **'Next payday {date} · {amount} · about {perMonth} a month'**
  String setupNextPaydayMonthly(String date, String amount, String perMonth);

  /// Pay setup, summary by Save when pay varies and comes more than once a month.
  ///
  /// In en, this message translates to:
  /// **'Next payday {date} · {amount} or more · about {perMonth} a month'**
  String setupNextPaydayOrMoreMonthly(
    String date,
    String amount,
    String perMonth,
  );

  /// Pay setup, button: self-employed or between jobs; stops asking for pay.
  ///
  /// In en, this message translates to:
  /// **'I don’t have regular pay'**
  String get setupNoRegularPay;

  /// Pay setup (editing), red button that removes the pay schedule.
  ///
  /// In en, this message translates to:
  /// **'Stop scheduling pay'**
  String get setupStopPay;

  /// Dialog title when stopping a pay that categories are budgeted per. Coral.
  ///
  /// In en, this message translates to:
  /// **'Stop this pay?'**
  String get stopPayTitle;

  /// Stop-pay dialog: which categories have a set amount each of its pay periods or a bill every payday of it. names is a comma list.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 category is budgeted per this pay: {names}} other{{count} categories are budgeted per this pay: {names}}}'**
  String stopPayPerIt(int count, String names);

  /// Stop-pay dialog, label over the choices: Every month, or another pay's periods.
  ///
  /// In en, this message translates to:
  /// **'From now, budget them'**
  String get stopPayFromNow;

  /// Stop-pay dialog, under Every month when some of the categories are bills every payday of this pay. names is a comma list.
  ///
  /// In en, this message translates to:
  /// **'A bill every payday comes every month from its next payday: {names}.'**
  String stopPayBillsMonthly(String names);

  /// Pay setup, main button.
  ///
  /// In en, this message translates to:
  /// **'Save pay'**
  String get setupSavePay;

  /// Budget page, Income tab (a pay's line) and a pay's title: an account that was archived.
  ///
  /// In en, this message translates to:
  /// **'{name} (archived · no paydays until it’s back)'**
  String setupNameArchived(String name);

  /// A pay with no name and no employer, when there is more than one pay: Income into the account it goes into (the Income tab, the view dropdown, How often).
  ///
  /// In en, this message translates to:
  /// **'{category} into {account}'**
  String setupCategoryInto(String category, String account);

  /// Was Settings → Budget's label beside the pay list; unused since 2026-10-05 (pay is listed on the Budget page's Income tab).
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get setupPay;

  /// Budget page, Income tab, one pay. amounts is like "₮2,100,000 · monthly on the 25th".
  ///
  /// In en, this message translates to:
  /// **'{category} · {amounts} · into {account}'**
  String setupPayLine(String category, String amounts, String account);

  /// Budget page, Income tab, button beside a pay.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get setupEdit;

  /// Budget page, Income tab, after "I don't have regular pay".
  ///
  /// In en, this message translates to:
  /// **'You said you don’t have regular pay, so the forecast doesn’t ask for it.'**
  String get setupSaidNoPay;

  /// Budget page, Income tab, button that undoes "I don't have regular pay".
  ///
  /// In en, this message translates to:
  /// **'Ask me again'**
  String get setupAskAgain;

  /// Budget page, Income tab, the add button when some pay is already set up.
  ///
  /// In en, this message translates to:
  /// **'Add other pay'**
  String get setupAddOtherPay;

  /// Suggested file name in the Save dialog when saving the recovery key to a text file. Keep .txt.
  ///
  /// In en, this message translates to:
  /// **'BetterBudget recovery key.txt'**
  String get startKeyFileName;

  /// Confirm button of the macOS Save dialog for the recovery key file.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get startSave;

  /// Whole content of the text file the recovery key is saved to (Save… on the recovery key screen). key is the key itself (letters and digits); date is 2026.09.30. Keep the blank lines.
  ///
  /// In en, this message translates to:
  /// **'BetterBudget recovery key\n\n{key}\n\nMade {date}.\n\nIt opens your BetterBudget ledger and its backups on another computer, or on a phone that records spending. BetterBudget doesn’t keep a copy, and it can’t be replaced: without it, the ledger can’t be opened anywhere else.\n\nKeep it somewhere safe, away from this computer, where the other person who manages the money can find it. Don’t keep this file in the same folder as your backups.\n'**
  String startKeyFileText(String key, String date);

  /// Recovery key setup screen (shown once at first launch), title.
  ///
  /// In en, this message translates to:
  /// **'Your recovery key'**
  String get startKeyTitle;

  /// Recovery key setup screen, paragraph under the title, above the key.
  ///
  /// In en, this message translates to:
  /// **'BetterBudget encrypts your ledger and its backups. This key opens them on another computer, and on each phone that records spending. This is the only time it’s shown: BetterBudget doesn’t keep a copy, and it can’t be replaced.'**
  String get startKeyIntro;

  /// Recovery key setup screen, small note right under the key.
  ///
  /// In en, this message translates to:
  /// **'Keep it away from this computer, where the other person who manages the money can find it: printed with your important papers, or on another drive.'**
  String get startKeyWhere;

  /// Recovery key setup screen, button that opens a Save dialog to save the key to a file.
  ///
  /// In en, this message translates to:
  /// **'Save…'**
  String get startSaveEllipsis;

  /// Recovery key setup screen, the Save… button once the key file was saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get startSaved;

  /// Recovery key setup screen, button that copies the key.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get startCopy;

  /// Recovery key setup screen, the Copy button once the key was copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get startCopied;

  /// Recovery key setup screen, shown when an existing unencrypted ledger is about to be encrypted. 'Back up to…' is the name of the button in Settings → Backups; use the same name.
  ///
  /// In en, this message translates to:
  /// **'Copies you saved elsewhere with Back up to… before today aren’t encrypted. Replace them with a new Back up to….'**
  String get startOldCopies;

  /// Recovery key setup screen, red warning after the key was copied but not saved.
  ///
  /// In en, this message translates to:
  /// **'Copied · paste it somewhere off this computer before you continue. The clipboard is cleared in a minute.'**
  String get startCopiedWarning;

  /// Recovery key setup screen, red warning while the key is neither saved nor copied.
  ///
  /// In en, this message translates to:
  /// **'If you continue without saving or copying it, it’s gone: BetterBudget can’t show it again, and if this computer is lost, your ledger and its backups can’t be opened.'**
  String get startNotKeptWarning;

  /// Button on the recovery key setup and entry screens.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get startContinue;

  /// Recovery key entry screen (this computer has no key), title.
  ///
  /// In en, this message translates to:
  /// **'Enter your recovery key'**
  String get startEnterTitle;

  /// Recovery key entry screen, red text button when a ledger is already on this computer; opens a warning.
  ///
  /// In en, this message translates to:
  /// **'Start a new ledger instead…'**
  String get startNewLedgerInstead;

  /// Warning dialog before starting fresh when a ledger is on this computer, title.
  ///
  /// In en, this message translates to:
  /// **'Start a new ledger?'**
  String get startSetAsideTitle;

  /// Start a new ledger? dialog, body. name is a file name like betterbudget.set-aside-20260930-101500.sqlite.
  ///
  /// In en, this message translates to:
  /// **'The ledger already on this computer can only be opened with its own recovery key. It won’t be deleted: it’s moved aside as {name}, in BetterBudget’s folder, so you can open it later if you find its key.'**
  String startSetAsideBodyNamed(String name);

  /// Start a new ledger? dialog, body, when the new file name isn't known.
  ///
  /// In en, this message translates to:
  /// **'The ledger already on this computer can only be opened with its own recovery key. It won’t be deleted: it’s moved aside, in BetterBudget’s folder, so you can open it later if you find its key.'**
  String get startSetAsideBody;

  /// Cancel button in the recovery key dialogs.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get startCancel;

  /// Start a new ledger? dialog, red confirm button.
  ///
  /// In en, this message translates to:
  /// **'Move it aside and start new'**
  String get startSetAsideConfirm;

  /// Settings → Security → Check my recovery key… dialog, title.
  ///
  /// In en, this message translates to:
  /// **'Check your recovery key'**
  String get startCheckTitle;

  /// Check your recovery key dialog, text above the field.
  ///
  /// In en, this message translates to:
  /// **'Type the key you saved. BetterBudget checks whether it opens this ledger. It never shows the key.'**
  String get startCheckBody;

  /// Check your recovery key dialog, button.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get startCheckAction;

  /// Check your recovery key dialog, error under the field when the key is wrong.
  ///
  /// In en, this message translates to:
  /// **'No · this key doesn’t open this ledger'**
  String get startCheckNo;

  /// Check your recovery key dialog, green line when the key is right.
  ///
  /// In en, this message translates to:
  /// **'Yes · this key opens this ledger'**
  String get startCheckYes;

  /// Dialog when restoring a backup made under another ledger's key, title.
  ///
  /// In en, this message translates to:
  /// **'This backup has its own key'**
  String get startBackupKeyTitle;

  /// Backup with its own key dialog, text above the field.
  ///
  /// In en, this message translates to:
  /// **'It isn’t encrypted with this ledger’s key. It may be from another ledger: type that ledger’s recovery key to restore it. Your own key doesn’t change.'**
  String get startBackupKeyBody;

  /// Backup with its own key dialog, button.
  ///
  /// In en, this message translates to:
  /// **'Open backup'**
  String get startBackupKeyAction;

  /// Check your recovery key dialog, button once the key matched.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get startClose;

  /// Error under the recovery key field when Cyrillic letters are typed. The key is Latin letters and digits; ABC is the macOS keyboard name.
  ///
  /// In en, this message translates to:
  /// **'Your keyboard is typing Cyrillic · switch to ABC to type the key'**
  String get startKeyCyrillic;

  /// Error under the recovery key field when too few or too many characters are typed, e.g. '17 of 25 characters'.
  ///
  /// In en, this message translates to:
  /// **'{typed} of {total} characters'**
  String startKeyLength(int typed, int total);

  /// Error under the recovery key field when the key's check character doesn't match (a typo).
  ///
  /// In en, this message translates to:
  /// **'A character is wrong · check the key against your copy'**
  String get startKeyChecksum;

  /// Recovery key entry screen, message under the title when the stored key doesn't fit the ledger.
  ///
  /// In en, this message translates to:
  /// **'The key kept on this computer doesn’t open the ledger here. Type the ledger’s recovery key to open it.'**
  String get startEntryKeptKeyWrong;

  /// Recovery key entry screen, message when this computer has no key but has a ledger.
  ///
  /// In en, this message translates to:
  /// **'There’s a ledger on this computer. Type its recovery key to open it.'**
  String get startEntryLedgerHere;

  /// Recovery key entry screen (Linux without a keychain), message when there's a ledger here.
  ///
  /// In en, this message translates to:
  /// **'This computer has no keychain BetterBudget can use, so it asks for your recovery key each time it opens. There’s a ledger on this computer. Type its recovery key to open it.'**
  String get startEntryLedgerHereEveryLaunch;

  /// Recovery key entry screen, error under the field.
  ///
  /// In en, this message translates to:
  /// **'That key doesn’t open the ledger on this computer'**
  String get startKeyWrongHere;

  /// Recovery key entry screen, error under the field. error is a technical error type name, left in English.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t keep the key on this computer · {error}'**
  String startCouldntKeepKey(String error);

  /// Full-screen heading at launch, after the recovery key setup, when the key couldn't be stored.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t keep the key on this computer'**
  String get startCouldntKeepKeyNothingEncrypted;

  /// Full-screen error at launch, the line under 'Couldn’t keep the key on this computer'.
  ///
  /// In en, this message translates to:
  /// **'Nothing was encrypted.'**
  String get startNothingEncrypted;

  /// Full-screen heading at launch when the ledger couldn't be opened.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open your ledger'**
  String get startCouldntOpen;

  /// Full-screen heading at launch when the computer's keychain wouldn't give the ledger's key.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t read the key kept on this computer'**
  String get startCouldntReadKey;

  /// Full-screen error at launch, the line under 'Couldn’t read the key kept on this computer'.
  ///
  /// In en, this message translates to:
  /// **'Your ledger hasn’t been touched.'**
  String get startLedgerNotTouched;

  /// Button on the full-screen error at launch: does the step that failed again.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get startTryAgain;

  /// Link on the full-screen error at launch: shows the technical error under it.
  ///
  /// In en, this message translates to:
  /// **'Show details'**
  String get startShowDetails;

  /// Toast after launch when some old backup copies couldn't be encrypted. names is a comma-separated list of file names.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 old copy couldn’t be encrypted and is still readable: {names}} other{{count} old copies couldn’t be encrypted and are still readable: {names}}}'**
  String startCopiesFailed(int count, String names);

  /// Toast after launch when old backup copies were encrypted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Encrypted 1 old copy of your ledger} other{Encrypted {count} old copies of your ledger}}'**
  String startCopiesEncrypted(int count);

  /// Reason shown after 'Couldn’t open the ledger · ' when encrypting the ledger file failed its check. name is a file name.
  ///
  /// In en, this message translates to:
  /// **'The encrypted copy of {name} didn’t check out'**
  String startEncryptedCopyFailed(String name);

  /// Settings → Backups, restore error toast: there's no ledger file to restore into.
  ///
  /// In en, this message translates to:
  /// **'Nothing to restore into'**
  String get startRestoreNothingInto;

  /// Settings → Backups, restore error toast.
  ///
  /// In en, this message translates to:
  /// **'That backup is from a newer BetterBudget · update the app first'**
  String get startRestoreNewer;

  /// Settings → Backups, restore error toast.
  ///
  /// In en, this message translates to:
  /// **'That file isn’t a BetterBudget backup'**
  String get startRestoreNotABackup;

  /// Settings → Backups, restore error.
  ///
  /// In en, this message translates to:
  /// **'That backup can’t be opened with this ledger’s key · it may be from another ledger, or damaged'**
  String get startRestoreNeedsKey;

  /// Backup with its own key dialog, error under the key field.
  ///
  /// In en, this message translates to:
  /// **'That key doesn’t open this backup · it may be from another ledger, or damaged'**
  String get startRestoreWrongKey;

  /// Settings → Backups, restore error toast.
  ///
  /// In en, this message translates to:
  /// **'That backup is damaged'**
  String get startRestoreDamaged;

  /// Settings → Backups, restore error toast.
  ///
  /// In en, this message translates to:
  /// **'That backup has no accounts in it'**
  String get startRestoreNoAccounts;

  /// Name of a transaction's cleared state: the bank hasn't confirmed it yet (pending). Shown in the header key and register tabs.
  ///
  /// In en, this message translates to:
  /// **'Uncleared'**
  String get startUncleared;

  /// Name of a transaction's cleared state: the bank has it.
  ///
  /// In en, this message translates to:
  /// **'Cleared'**
  String get startCleared;

  /// Name of a transaction's cleared state: matched to a bank statement and locked.
  ///
  /// In en, this message translates to:
  /// **'Reconciled'**
  String get startReconciled;

  /// Register row, payee of an account's opening balance.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get startOpeningBalance;

  /// Register row, category column of an account's opening balance (the account the app keeps them in). Singular: each row is one account's.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get startOpeningBalances;

  /// Register row, category column of the difference a reconcile posted to match a bank statement.
  ///
  /// In en, this message translates to:
  /// **'Balance adjustments'**
  String get startBalanceAdjustments;

  /// Register row, payee of the difference a reconcile posted to match a bank statement.
  ///
  /// In en, this message translates to:
  /// **'Reconcile adjustment'**
  String get startReconcileAdjustment;

  /// Register row, category column of a transfer between two accounts.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get startTransfer;

  /// Register row, category column of a split transaction, e.g. '3 categories'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 category} other{{count} categories}}'**
  String startSplitCategories(int count);

  /// How a row names an account that was deleted, e.g. 'TDB Checking (deleted)'.
  ///
  /// In en, this message translates to:
  /// **'{name} (deleted)'**
  String startDeletedAccount(String name);

  /// Register row, small note on a pending row the bank still hasn't confirmed after 14+ days. Lowercase in English.
  ///
  /// In en, this message translates to:
  /// **'not cleared for {days} days'**
  String startStaleNote(int days);

  /// Register row, small note on a row still not cleared though the account was reconciled to a bank statement dated on or after it: the bank's statement didn't have it, so it may never have happened. date is a day like 09.10. Lowercase in English.
  ///
  /// In en, this message translates to:
  /// **'not on the {date} statement'**
  String startNotOnStatement(String date);

  /// Register row and bill list, small note on a scheduled bill or income one day past its date. Lowercase in English.
  ///
  /// In en, this message translates to:
  /// **'due yesterday'**
  String get startDueYesterday;

  /// Register row and bill list, small note on a scheduled bill or income past its date, e.g. 'due 7 days ago'.
  ///
  /// In en, this message translates to:
  /// **'due {days} days ago'**
  String startDueDaysAgo(int days);

  /// A day of the month something happens on, inside the pay phrases below: English '25th'. Mongolian puts the dative ending on the number ('25-нд', '2-т'); isTwo is 'yes' when the number ends in 2 (хоёр → хоёрт).
  ///
  /// In en, this message translates to:
  /// **'{ordinal}'**
  String startDayOn(String ordinal, int day, String isTwo);

  /// How often pay comes, e.g. 'monthly on the 25th'. day comes from startDayOn. Lowercase in English: it's used inside lines.
  ///
  /// In en, this message translates to:
  /// **'monthly on the {day}'**
  String startPayMonthly(String day);

  /// Pay twice a month, e.g. 'on the 10th and 25th'. first and second come from startDayOn; firstDay is the bare number of the first day.
  ///
  /// In en, this message translates to:
  /// **'on the {first} and {second}'**
  String startPayTwiceMonthly(String first, String second, int firstDay);

  /// How often pay comes.
  ///
  /// In en, this message translates to:
  /// **'every week'**
  String get startPayEveryWeek;

  /// How often pay comes, e.g. 'every 2 weeks'.
  ///
  /// In en, this message translates to:
  /// **'every {weeks} weeks'**
  String startPayEveryWeeks(int weeks);

  /// Pay line, e.g. '₮2,100,000 monthly on the 25th'. when is one of the pay phrases above.
  ///
  /// In en, this message translates to:
  /// **'{amount} {when}'**
  String startPayAmountWhen(String amount, String when);

  /// Pay line for pay that varies, e.g. '₮2,100,000 or more monthly on the 25th'.
  ///
  /// In en, this message translates to:
  /// **'{amount} or more {when}'**
  String startPayAmountOrMoreWhen(String amount, String when);

  /// Pay line in Settings, e.g. '₮2,100,000 · monthly on the 25th'.
  ///
  /// In en, this message translates to:
  /// **'{amount} · {when}'**
  String startPayAmountDotWhen(String amount, String when);

  /// Pay line in Settings for pay that varies, e.g. '₮2,100,000 or more · monthly on the 25th'.
  ///
  /// In en, this message translates to:
  /// **'{amount} or more · {when}'**
  String startPayAmountOrMoreDotWhen(String amount, String when);

  /// Pay twice a month with a different amount each payday, e.g. '₮500,000 on the 10th and ₮1,600,000 on the 25th'. The days come from startDayOn.
  ///
  /// In en, this message translates to:
  /// **'{first} on the {firstDay} and {second} on the {secondDay}'**
  String startPaySplit(
    String first,
    String firstDay,
    String second,
    String secondDay,
  );

  /// Like startPaySplit, for pay that varies: 'at least ₮500,000 on the 10th and ₮1,600,000 on the 25th'.
  ///
  /// In en, this message translates to:
  /// **'at least {first} on the {firstDay} and {second} on the {secondDay}'**
  String startPaySplitAtLeast(
    String first,
    String firstDay,
    String second,
    String secondDay,
  );

  /// Name of the budget span when budgeting by pay period, e.g. on a filter chip before its dates.
  ///
  /// In en, this message translates to:
  /// **'This pay period'**
  String get startThisPayPeriod;

  /// Name of the budget span when budgeting by calendar month, e.g. on a filter chip before its dates.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get startThisMonth;

  /// Account header, beside Reconcile: button that opens a bank file to bring its rows in.
  ///
  /// In en, this message translates to:
  /// **'Import…'**
  String get importButton;

  /// Import window title. account is the account's name.
  ///
  /// In en, this message translates to:
  /// **'Import into {account}'**
  String importTitle(Object account);

  /// Open dialog: name of the file type group for .xls and .xlsx.
  ///
  /// In en, this message translates to:
  /// **'Excel files'**
  String get importExcelFiles;

  /// Open dialog: name of the file type group for .csv and .txt.
  ///
  /// In en, this message translates to:
  /// **'Text files (CSV)'**
  String get importTextFiles;

  /// Open dialog: name of the file type group for .ofx, .qfx and .qbo, the download banks label Quicken or Microsoft Money.
  ///
  /// In en, this message translates to:
  /// **'Bank downloads (OFX, QFX, QBO)'**
  String get importOfxFiles;

  /// Toast when a picked file can't be read.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t read {file}. BetterBudget reads Excel (.xls, .xlsx), CSV and OFX files.'**
  String importCouldntRead(Object file);

  /// Toast when a file has nothing that looks like a transaction.
  ///
  /// In en, this message translates to:
  /// **'{file} has no rows with a date in them.'**
  String importNoDates(Object file);

  /// Import window, when the file has the same layout as the last one imported into this account.
  ///
  /// In en, this message translates to:
  /// **'Read with the columns you set for this account last time.'**
  String get importSavedColumns;

  /// Import window: button that shows the file's columns to change what each holds.
  ///
  /// In en, this message translates to:
  /// **'Change columns'**
  String get importChangeColumns;

  /// Import window, above the file's columns.
  ///
  /// In en, this message translates to:
  /// **'Choose what each column holds. The app filled in its best guess; check the date and the amount.'**
  String get importColumnsHint;

  /// Import window, a column's choice: the column is left out.
  ///
  /// In en, this message translates to:
  /// **'Not used'**
  String get importRoleIgnore;

  /// Import window, a column's choice.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get importRoleDate;

  /// Import window, a column's choice: one column with money in and out, signed.
  ///
  /// In en, this message translates to:
  /// **'Amount (+ in, − out)'**
  String get importRoleAmount;

  /// Import window, a column's choice.
  ///
  /// In en, this message translates to:
  /// **'Money in'**
  String get importRoleIn;

  /// Import window, a column's choice.
  ///
  /// In en, this message translates to:
  /// **'Money out'**
  String get importRoleOut;

  /// Import window, a column's choice: who the money went to or came from.
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get importRolePayee;

  /// Import window, a column's choice: the bank's description.
  ///
  /// In en, this message translates to:
  /// **'Memo'**
  String get importRoleMemo;

  /// Import window, a column's choice: the bank's running balance after each row, used to check the reading.
  ///
  /// In en, this message translates to:
  /// **'Bank’s balance'**
  String get importRoleBalance;

  /// Import window, when no rows can be read yet.
  ///
  /// In en, this message translates to:
  /// **'Choose the date column and the amount (or money in and money out).'**
  String get importNeedDateAmount;

  /// Import window, before two choices, when a date like 03.04 could be read either way.
  ///
  /// In en, this message translates to:
  /// **'Dates in this file:'**
  String get importDateOrder;

  /// Import window, date choice. date is the file's first date read this way, in words.
  ///
  /// In en, this message translates to:
  /// **'Day first: {date}'**
  String importDayFirst(Object date);

  /// Import window, date choice. date is the file's first date read this way, in words.
  ///
  /// In en, this message translates to:
  /// **'Month first: {date}'**
  String importMonthFirst(Object date);

  /// Import window, before two choices, when one column holds the amount.
  ///
  /// In en, this message translates to:
  /// **'In the amount column:'**
  String get importSignLabel;

  /// Import window, sign choice (the usual).
  ///
  /// In en, this message translates to:
  /// **'minus is money out'**
  String get importMinusOut;

  /// Import window, sign choice (some card statements).
  ///
  /// In en, this message translates to:
  /// **'plus is money out'**
  String get importPlusOut;

  /// Import window summary, first clause; clauses are joined with " · ".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new row} other{{count} new rows}}'**
  String importCountNew(int count);

  /// Import window summary clause.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 matches a row you typed, which becomes cleared} other{{count} match rows you typed, which become cleared}}'**
  String importCountMatch(int count);

  /// Import window summary clause: rows imported before (by their key), skipped.
  ///
  /// In en, this message translates to:
  /// **'{count} already in the ledger'**
  String importCountAlready(int count);

  /// Import window: the file's own balance column agrees with the amounts read.
  ///
  /// In en, this message translates to:
  /// **'The bank’s running balance adds up on every row, {opening} to {closing}.'**
  String importBalanceOk(Object opening, Object closing);

  /// Import window warning: the balance column doesn't agree with the amounts.
  ///
  /// In en, this message translates to:
  /// **'Row {row} of the file: the bank’s balance is {found}, but the amounts before it come to {expected}. A column may be set wrong. You can still import.'**
  String importBalanceOff(int row, Object found, Object expected);

  /// Import window, after the balance warning, when more than one row is off.
  ///
  /// In en, this message translates to:
  /// **'{count} rows don’t add up in all.'**
  String importBalanceOffCount(int count);

  /// Import window: the account's cleared balance after importing equals the file's last balance.
  ///
  /// In en, this message translates to:
  /// **'After this, the cleared balance matches the bank: {amount}.'**
  String importClearedMatches(Object amount);

  /// Import window: the account's cleared balance after importing differs from the file's last balance.
  ///
  /// In en, this message translates to:
  /// **'After this, the cleared balance is {ours}; the bank’s file ends at {bank}, {diff} apart. Rows from before this file, or ones not cleared, can make the difference.'**
  String importClearedDiffers(Object ours, Object bank, Object diff);

  /// Import window, an OFX file: the account's cleared balance after importing equals the one balance the file gives. date in words.
  ///
  /// In en, this message translates to:
  /// **'After this, the cleared balance matches the bank’s on {date}: {amount}.'**
  String importClearedMatchesOn(Object amount, Object date);

  /// Import window, an OFX file: the account's cleared balance after importing differs from the one balance the file gives. date in words.
  ///
  /// In en, this message translates to:
  /// **'After this, the cleared balance is {ours}; the bank’s was {bank} on {date}, {diff} apart. Rows after that day, rows from before this file, or ones not cleared, can make the difference.'**
  String importClearedDiffersOn(
    Object ours,
    Object bank,
    Object date,
    Object diff,
  );

  /// Import window, preview row tag: a row imported before from the bank's other kind of file has this row's day and amount, so it starts left out. Clicking it brings the row in.
  ///
  /// In en, this message translates to:
  /// **'Already in · same day and amount'**
  String get importFateRepeat;

  /// Import window note: rows that repeat ones imported earlier under another key (the bank's table once, its OFX file the next time).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row has the day and amount of a row already imported from another kind of file, so it’s left out. Click its tag to bring it in.} other{{count} rows have the day and amount of rows already imported from another kind of file, so they’re left out. Click a row’s tag to bring it in.}}'**
  String importRepeats(int count);

  /// Import window for a new account: the balance before the file's first row and after its last, which the account's opening balance is made from. from/to in words.
  ///
  /// In en, this message translates to:
  /// **'This file starts at {start} on {from} and ends at {end} on {to}. The account starts from it.'**
  String importStartsEnds(Object start, Object from, Object end, Object to);

  /// Import window for a new credit card or loan: what was owed before the file's first row and after its last. from/to in words.
  ///
  /// In en, this message translates to:
  /// **'This file starts with {start} owed on {from} and ends with {end} owed on {to}. The account starts from it.'**
  String importStartsEndsOwed(Object start, Object from, Object end, Object to);

  /// Import window for a new account: label before the date the file's rows come in from.
  ///
  /// In en, this message translates to:
  /// **'Start from'**
  String get importStartFrom;

  /// Import window for a new account: button beside the Start from date that sets it back to the file's first row.
  ///
  /// In en, this message translates to:
  /// **'The whole file'**
  String get importWholeFile;

  /// Import window for a new account, beside the Start from date: rows dated before it don't come in.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 earlier row in this file is left out} other{{count} earlier rows in this file are left out}}'**
  String importEarlierLeftOut(int count);

  /// Import window for a new account started partway into its file: the balance worked out for the start day, and the file's last balance. from/to in words.
  ///
  /// In en, this message translates to:
  /// **'The account starts on {from} at {start}. The file ends at {end} on {to}.'**
  String importStartsOn(Object from, Object start, Object end, Object to);

  /// Import window for a new credit card or loan started partway into its file. from/to in words.
  ///
  /// In en, this message translates to:
  /// **'The account starts on {from} with {start} owed. The file ends with {end} owed on {to}.'**
  String importStartsOnOwed(Object from, Object start, Object end, Object to);

  /// Import window for a new account whose file has no balance in it; question is the new account's own question (What's in this account today? / What do you owe on it today?), a whole sentence.
  ///
  /// In en, this message translates to:
  /// **'This file doesn’t give a balance. {question}'**
  String importNoBalance(Object question);

  /// Import window for a new account, beside the amount field shown when the file has no balance.
  ///
  /// In en, this message translates to:
  /// **'Empty starts the account at {zero} before the file’s first row'**
  String importNoBalanceHint(Object zero);

  /// Import window, preview row tag: this row will be added.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get importFateNew;

  /// Import window, preview row tag: a row the user typed that becomes cleared. date in words.
  ///
  /// In en, this message translates to:
  /// **'Matches {payee}, {date}'**
  String importFateMatch(Object payee, Object date);

  /// Import window, preview row tag: imported before, left out.
  ///
  /// In en, this message translates to:
  /// **'Already in'**
  String get importFateAlready;

  /// Import window, main button. count is new rows plus matched ones.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Import 1 row} other{Import {count} rows}}'**
  String importDo(int count);

  /// Import window, in place of the main button when every row is already in.
  ///
  /// In en, this message translates to:
  /// **'Nothing new in this file'**
  String get importNothingNew;

  /// Import window button.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get importCancel;

  /// Toast and undo-menu label after an import.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Imported 1 row} other{Imported {count} rows}}'**
  String importDone(int count);

  /// Part of the import toast, after " · ".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 typed row now cleared} other{{count} typed rows now cleared}}'**
  String importMatchedToast(int count);

  /// Part of the import toast, after " · ": rows whose payee has no earlier category went to the app's holding category.
  ///
  /// In en, this message translates to:
  /// **'{count} in “{name}”'**
  String importUncategorizedToast(int count, Object name);

  /// Name of the category the app makes for imported rows whose payee has no earlier category. Saved in the language showing when it's made.
  ///
  /// In en, this message translates to:
  /// **'Not categorized'**
  String get importUncategorized;

  /// Toast when an import fails; nothing was written.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t import: {problem}'**
  String importCouldntImport(Object problem);

  /// Import window, main button when typed rows match too. count is new rows, cleared the typed rows that become cleared.
  ///
  /// In en, this message translates to:
  /// **'Import {count} rows · clear {cleared}'**
  String importDoClear(int count, int cleared);

  /// Import window, main button when nothing is new but typed rows match.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Clear 1 typed row} other{Clear {count} typed rows}}'**
  String importDoOnlyClear(int count);

  /// Import window summary clause, quiet: lines that aren't transactions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 line without a date (a heading or total) left out} other{{count} lines without a date (headings, totals) left out}}'**
  String importCountNoDate(int count);

  /// Import window warning. rows is a list of row numbers, like 12, 15, 40.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Row {rows} of the file has a date but no amount this can read, so it’s left out.} other{Rows {rows} of the file have a date but no amount this can read, so they’re left out.}}'**
  String importNoAmountRows(int count, Object rows);

  /// Import window summary clause: rows the person clicked to leave out.
  ///
  /// In en, this message translates to:
  /// **'{count} left out by you'**
  String importCountLeftOut(int count);

  /// Import window, above the rows.
  ///
  /// In en, this message translates to:
  /// **'Click a row’s New or Matches to add it as its own row or leave it out.'**
  String get importTagHint;

  /// Import window, preview row tag, when the typed row has no payee. date in words.
  ///
  /// In en, this message translates to:
  /// **'Matches your row of {date}'**
  String importFateMatchDate(Object date);

  /// Import window, preview row tag: the person chose not to bring this row in.
  ///
  /// In en, this message translates to:
  /// **'Left out'**
  String get importFateLeftOut;

  /// Import window warning: new rows overlap dates already imported. from/to in words.
  ///
  /// In en, this message translates to:
  /// **'The new rows fall between {from} and {to}, where this account already has {count} imported rows. If this file repeats an earlier one in another form, they’re duplicates.'**
  String importOverlap(Object from, Object to, int count);

  /// Import window button under the overlap warning.
  ///
  /// In en, this message translates to:
  /// **'Leave the new rows out'**
  String get importLeaveNewOut;

  /// Import window note: typed rows the bank file doesn't have (another amount, or not posted).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row you typed between {from} and {to} isn’t in this file: {list}. It stays not cleared.} other{{count} rows you typed between {from} and {to} aren’t in this file: {list}. They stay not cleared.}}'**
  String importUnmatched(int count, Object from, Object to, Object list);

  /// One typed row in the importUnmatched list.
  ///
  /// In en, this message translates to:
  /// **'{payee} {amount} on {date}'**
  String importUnmatchedItem(Object payee, Object amount, Object date);

  /// Last item of the importUnmatched list when it's cut short.
  ///
  /// In en, this message translates to:
  /// **'{count} more'**
  String importUnmatchedMore(int count);

  /// Entry row, under a transfer from an account in another currency: before the field for what left it.
  ///
  /// In en, this message translates to:
  /// **'Sent from {account}:'**
  String rowsLeftOther(Object account);

  /// Entry row, under a transfer to an account in another currency: before the field for what arrives there.
  ///
  /// In en, this message translates to:
  /// **'Arrives in {account}:'**
  String rowsArrivesOther(Object account);

  /// Popup at the bottom when an entry row can’t be saved: a transfer between currencies needs the other side's amount.
  ///
  /// In en, this message translates to:
  /// **'Enter the amount sent from {account}'**
  String rowsErrorLeftOther(Object account);

  /// Popup at the bottom when an entry row can’t be saved: a transfer between currencies needs the other side's amount.
  ///
  /// In en, this message translates to:
  /// **'Enter the amount arriving in {account}'**
  String rowsErrorArrivesOther(Object account);

  /// Entry row, after both amounts of a transfer between currencies: the rate they make. rate is what one unit of the dearer currency costs in the other, like ₮3,450.00; one is that unit, like $1 or €1.
  ///
  /// In en, this message translates to:
  /// **'{rate} per {one}'**
  String rowsRatePer(String rate, String one);

  /// Toast when a row can't move to an account in another currency.
  ///
  /// In en, this message translates to:
  /// **'That account is in another currency'**
  String get ledgerDbOtherCurrency;

  /// Toast when a transfer between currencies has only one amount.
  ///
  /// In en, this message translates to:
  /// **'Accounts in two currencies need a transfer with both amounts'**
  String get ledgerDbNeedsOtherAmount;

  /// New account page: label before the currency choice.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get setupCurrency;

  /// New account page, under the currency choice.
  ///
  /// In en, this message translates to:
  /// **'Every amount in this account is in it, and it can’t be changed later yet. Net worth shows each currency on its own line.'**
  String get setupCurrencyHint;

  /// Register, memo line of a transfer between currencies: the other account, what it got or sent in its currency, and the rate (rate like ₮3,450.00, one like $1).
  ///
  /// In en, this message translates to:
  /// **'{account}: {amount} · {rate} per {one}'**
  String rowsExchangeNote(
    Object account,
    Object amount,
    Object rate,
    String one,
  );

  /// Savings page: under the steps, when some accounts are in another currency than the one Savings counts (the one most accounts are in). accounts is their names; currency is that currency's name, like Mongolian Tugrik.
  ///
  /// In en, this message translates to:
  /// **'Not counted here yet: {accounts}. Savings counts one currency for now: {currency}.'**
  String savingsOnlyOne(String accounts, String currency);

  /// Import window: coral warning when the file names one currency (tugrik or dollars) and the account is in another. fileCurrency and accountCurrency are currency names, like US Dollar; example is an amount as the file means it, asIs as it would be read.
  ///
  /// In en, this message translates to:
  /// **'This file looks like it’s in {fileCurrency}, and {account} is in {accountCurrency}. Amounts come in as they are: {example} would become {asIs}.'**
  String importFileIn(
    String fileCurrency,
    String account,
    String accountCurrency,
    String example,
    String asIs,
  );

  /// After “Couldn’t open the ledger · ”: an older build opened a ledger a newer one saved, and refused.
  ///
  /// In en, this message translates to:
  /// **'it was saved by a newer version of BetterBudget. Open it with that version; nothing here was changed.'**
  String get ledgerNewerLedger;

  /// Import window warning: new rows dated on or before the account's opening balance's day would count twice.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row is dated on or before this account’s opening balance ({amount} on {date}), which already counts it.} other{{count} rows are dated on or before this account’s opening balance ({amount} on {date}), which already counts them.}}'**
  String importBeforeOpening(int count, Object amount, Object date);

  /// Import window warning, when the opening balance is reconciled and can't move.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row is dated on or before this account’s opening balance ({amount} on {date}), which already counts it. The opening balance is reconciled, so it stays; imported, the row counts twice.} other{{count} rows are dated on or before this account’s opening balance ({amount} on {date}), which already counts them. The opening balance is reconciled, so it stays; imported, they count twice.}}'**
  String importBeforeOpeningLocked(int count, Object amount, Object date);

  /// Import window choice (the default): move the opening balance before the file's rows, at the amount that keeps today's balance.
  ///
  /// In en, this message translates to:
  /// **'Move the opening balance to {date} at {amount}'**
  String importMoveOpening(Object date, Object amount);

  /// Import window choice: keep the opening balance where it is.
  ///
  /// In en, this message translates to:
  /// **'Leave it (those rows count twice)'**
  String get importKeepOpening;

  /// Import window button: leave out the rows dated before a reconciled opening balance.
  ///
  /// In en, this message translates to:
  /// **'Leave those rows out'**
  String get importLeaveBeforeOut;

  /// Import window, preview tag after a match: the typed row takes the bank's date, which is in another month.
  ///
  /// In en, this message translates to:
  /// **'dated {date}, the bank’s'**
  String importFateRedated(Object date);

  /// Part of the import toast, after " · ": the opening balance moved before the file's rows.
  ///
  /// In en, this message translates to:
  /// **'opening balance now {amount} on {date}'**
  String importOpeningMovedToast(Object date, Object amount);

  /// Budget page: column title over what's assigned to each spending category this period (rule 26; owner's word, 2026-09-30, for the unclear "Put in")
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get planAssigned;

  /// Budget page: column title over what each spending category spent this period
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get planSpent;

  /// Budget page: column title over what each spending category holds now, what carried over included
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get planLeft;

  /// Budget page: small line under a category's Left when it carried money (or minus) in from earlier periods
  ///
  /// In en, this message translates to:
  /// **'{amount} from before'**
  String planFromBefore(String amount);

  /// Budget page: the period title when budgeting by pay period and it isn't the current one
  ///
  /// In en, this message translates to:
  /// **'Pay period'**
  String get planPayPeriod;

  /// Budget page, the view dropdown beside the period: by calendar month (the other choices are each pay's name). Short.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get planViewMonth;

  /// Budget page, tooltip on the view dropdown beside the period.
  ///
  /// In en, this message translates to:
  /// **'View by month, or by one pay’s periods'**
  String get planViewTip;

  /// Budget page: the period shown, beside the arrows. name is a month name, "This month", "This pay period" or "Pay period"; start and end are month.day
  ///
  /// In en, this message translates to:
  /// **'{name} · {start}–{end}'**
  String planPeriodTitle(String name, String start, String end);

  /// Budget page: tooltip on the ‹ arrow
  ///
  /// In en, this message translates to:
  /// **'Previous period'**
  String get planPeriodPrev;

  /// Budget page: tooltip on the › arrow
  ///
  /// In en, this message translates to:
  /// **'Next period'**
  String get planPeriodNext;

  /// Budget page: link beside the period title when another period is showing
  ///
  /// In en, this message translates to:
  /// **'Back to today'**
  String get planBackToToday;

  /// Budget page: tooltip on a category's Assigned amount
  ///
  /// In en, this message translates to:
  /// **'Click to type how much to assign · Tab for the next'**
  String get planAssignTip;

  /// Undo history label for typing a category's Assigned amount (shown in Undone/Redone toasts)
  ///
  /// In en, this message translates to:
  /// **'Assign {amount} to {category}'**
  String planAssignUndo(String amount, String category);

  /// Budget page, Edit under a category's row: a line at the bottom left; usage is e.g. "42 rows · last 09.12 · 1 scheduled"; clicking it opens every row, all time
  ///
  /// In en, this message translates to:
  /// **'{usage} · show them'**
  String planShowAllRows(String usage);

  /// Budget page, gold note after the first amount is assigned in a period that already started (owner's call: offer to start next period)
  ///
  /// In en, this message translates to:
  /// **'{amount} was spent in {count} categories before anything was assigned. It counts against them this period.'**
  String planStartOffer(String amount, String count);

  /// Budget page: button on the first-period note; moves what was assigned to the next period, which is where the budget then starts
  ///
  /// In en, this message translates to:
  /// **'Start the budget on {date} instead'**
  String planStartLater(String date);

  /// Budget page: button on the first-period note; closes it
  ///
  /// In en, this message translates to:
  /// **'Keep it as it is'**
  String get planStartKeep;

  /// Undo history label and toast for moving the budget's start to the next period
  ///
  /// In en, this message translates to:
  /// **'Start the budget on {date}'**
  String planStartLaterUndo(String date);

  /// Toast after deleting a category, or changing it to income, that held money in the budget
  ///
  /// In en, this message translates to:
  /// **'{amount} assigned to {category} goes back to not assigned'**
  String planMoneyBack(String amount, String category);

  /// Account menu on a mortgage or student loan: submenu title; picks the spending category its payments come out of in the budget
  ///
  /// In en, this message translates to:
  /// **'Payments come out of'**
  String get setupLoanPaidFrom;

  /// Account menu, loan's payments submenu: its payments come out of the money not assigned
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get setupLoanNoCategory;

  /// Toast and undo label after picking the category a loan's payments come out of
  ///
  /// In en, this message translates to:
  /// **'{loan} paid from {category}'**
  String setupLoanPaidFromUndo(String loan, String category);

  /// Toast and undo label after taking a loan's category off
  ///
  /// In en, this message translates to:
  /// **'{loan} paid from no category'**
  String setupLoanNoCategoryUndo(String loan);

  /// Settings → Appearance card, heading above the color schemes to pick from.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get appearanceColorsTitle;

  /// Undo-menu label after a color scheme is picked. name is the scheme, e.g. "Stormy morning".
  ///
  /// In en, this message translates to:
  /// **'Colors: {name}'**
  String appearanceColorsUndoLabel(String name);

  /// Settings → Appearance, the first color scheme: the app's own colors (the default). The app's name; keep it as is.
  ///
  /// In en, this message translates to:
  /// **'BetterBudget'**
  String get schemeBetterBudget;

  /// Settings → Appearance, heading over a group of color schemes (Figma's "Monochromatic" combinations).
  ///
  /// In en, this message translates to:
  /// **'Monochromatic'**
  String get schemeGroupMonochromatic;

  /// Settings → Appearance, heading over a group of color schemes (Figma's "Romantic" combinations).
  ///
  /// In en, this message translates to:
  /// **'Romantic'**
  String get schemeGroupRomantic;

  /// Settings → Appearance, heading over a group of color schemes (Figma's "Playful" combinations).
  ///
  /// In en, this message translates to:
  /// **'Playful'**
  String get schemeGroupPlayful;

  /// Settings → Appearance, heading over a group of color schemes (Figma's "Vibrant" combinations).
  ///
  /// In en, this message translates to:
  /// **'Vibrant'**
  String get schemeGroupVibrant;

  /// Settings → Appearance, heading over a group of color schemes (Figma's "Neutral" combinations).
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get schemeGroupNeutral;

  /// Settings → Appearance, heading over a group of color schemes (Figma's "Tranquil" combinations).
  ///
  /// In en, this message translates to:
  /// **'Tranquil'**
  String get schemeGroupTranquil;

  /// Settings → Appearance, heading over a group of color schemes (Figma's "Seasonal" combinations).
  ///
  /// In en, this message translates to:
  /// **'Seasonal'**
  String get schemeGroupSeasonal;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 1, "Stormy morning"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Stormy morning'**
  String get schemeStormyMorning;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 2, "Mossy hollow"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Mossy hollow'**
  String get schemeMossyHollow;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 3, "Blue eclipse"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Blue eclipse'**
  String get schemeBlueEclipse;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 4, "Lush forest"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Lush forest'**
  String get schemeLushForest;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 5, "Green juice"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Green juice'**
  String get schemeGreenJuice;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 6, "Chili spice"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Chili spice'**
  String get schemeChiliSpice;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 7, "Chocolate truffle"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Chocolate truffle'**
  String get schemeChocolateTruffle;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 8, "Ink wash"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Ink wash'**
  String get schemeInkWash;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 9, "Golden taupe"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Golden taupe'**
  String get schemeGoldenTaupe;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 10, "Wisteria bloom"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Wisteria bloom'**
  String get schemeWisteriaBloom;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 11, "Burnt sienna"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Burnt sienna'**
  String get schemeBurntSienna;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 12, "Blooming romance"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Blooming romance'**
  String get schemeBloomingRomance;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 13, "Desert dusk"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Desert dusk'**
  String get schemeDesertDusk;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 14, "Lavender fields"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Lavender fields'**
  String get schemeLavenderFields;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 15, "Hydrangea"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Hydrangea'**
  String get schemeHydrangea;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 16, "Cactus flower"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Cactus flower'**
  String get schemeCactusFlower;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 17, "Wildflowers"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Wildflowers'**
  String get schemeWildflowers;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 18, "Country garden"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Country garden'**
  String get schemeCountryGarden;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 19, "Lotus garden"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Lotus garden'**
  String get schemeLotusGarden;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 20, "Iris garden"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Iris garden'**
  String get schemeIrisGarden;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 21, "Fresh peach"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Fresh peach'**
  String get schemeFreshPeach;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 22, "Golden hour"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Golden hour'**
  String get schemeGoldenHour;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 23, "Spiced chai"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Spiced chai'**
  String get schemeSpicedChai;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 24, "Cherry blossom"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Cherry blossom'**
  String get schemeCherryBlossom;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 25, "Evening rose"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Evening rose'**
  String get schemeEveningRose;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 26, "Pastel garden"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Pastel garden'**
  String get schemePastelGarden;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 27, "Tuscan sunset"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Tuscan sunset'**
  String get schemeTuscanSunset;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 28, "Zesty lemon"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Zesty lemon'**
  String get schemeZestyLemon;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 29, "California beaches"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'California beaches'**
  String get schemeCaliforniaBeaches;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 30, "Freshly squeezed"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Freshly squeezed'**
  String get schemeFreshlySqueezed;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 31, "Pistachio dream"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Pistachio dream'**
  String get schemePistachioDream;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 32, "Mango popsicle"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Mango popsicle'**
  String get schemeMangoPopsicle;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 33, "Guava"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Guava'**
  String get schemeGuava;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 34, "Glowing horizon"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Glowing horizon'**
  String get schemeGlowingHorizon;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 35, "Sunny day"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Sunny day'**
  String get schemeSunnyDay;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 36, "Retro sunset"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Retro sunset'**
  String get schemeRetroSunset;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 37, "Bubblegum pop"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Bubblegum pop'**
  String get schemeBubblegumPop;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 38, "Cotton candy skies"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Cotton candy skies'**
  String get schemeCottonCandySkies;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 39, "Electric kiwi"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Electric kiwi'**
  String get schemeElectricKiwi;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 40, "Watermelon splash"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Watermelon splash'**
  String get schemeWatermelonSplash;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 41, "Alchemical reaction"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Alchemical reaction'**
  String get schemeAlchemicalReaction;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 42, "Electropop"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Electropop'**
  String get schemeElectropop;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 43, "Cool revival"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Cool revival'**
  String get schemeCoolRevival;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 44, "Neon jungle"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Neon jungle'**
  String get schemeNeonJungle;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 45, "Sharp edge"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Sharp edge'**
  String get schemeSharpEdge;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 46, "Electric fusion"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Electric fusion'**
  String get schemeElectricFusion;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 47, "Fireworks"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Fireworks'**
  String get schemeFireworks;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 48, "Space berries"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Space berries'**
  String get schemeSpaceBerries;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 49, "Pop art"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Pop art'**
  String get schemePopArt;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 50, "Urban graffiti"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Urban graffiti'**
  String get schemeUrbanGraffiti;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 51, "Neon noir"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Neon noir'**
  String get schemeNeonNoir;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 52, "Tropical punch"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Tropical punch'**
  String get schemeTropicalPunch;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 53, "Cobalt sky"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Cobalt sky'**
  String get schemeCobaltSky;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 54, "Technicolor dream"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Technicolor dream'**
  String get schemeTechnicolorDream;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 55, "Jewel box"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Jewel box'**
  String get schemeJewelBox;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 56, "Salt and pepper"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Salt and pepper'**
  String get schemeSaltAndPepper;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 57, "Quite clear"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Quite clear'**
  String get schemeQuiteClear;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 58, "Gothic noir"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Gothic noir'**
  String get schemeGothicNoir;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 59, "Yacht club"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Yacht club'**
  String get schemeYachtClub;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 60, "Quiet luxury"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Quiet luxury'**
  String get schemeQuietLuxury;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 61, "Night sands"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Night sands'**
  String get schemeNightSands;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 62, "Harbor haze"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Harbor haze'**
  String get schemeHarborHaze;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 63, "Old photograph"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Old photograph'**
  String get schemeOldPhotograph;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 64, "Cappuccino"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Cappuccino'**
  String get schemeCappuccino;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 65, "Breakfast tea"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Breakfast tea'**
  String get schemeBreakfastTea;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 66, "Cozy campfire"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Cozy campfire'**
  String get schemeCozyCampfire;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 67, "Stone path"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Stone path'**
  String get schemeStonePath;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 68, "Desert mirage"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Desert mirage'**
  String get schemeDesertMirage;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 69, "Honeycomb"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Honeycomb'**
  String get schemeHoneycomb;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 70, "Urban loft"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Urban loft'**
  String get schemeUrbanLoft;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 71, "Spiced mocha"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Spiced mocha'**
  String get schemeSpicedMocha;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 72, "Charming seaside"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Charming seaside'**
  String get schemeCharmingSeaside;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 73, "Calm blue"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Calm blue'**
  String get schemeCalmBlue;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 74, "Beachfront views"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Beachfront views'**
  String get schemeBeachfrontViews;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 75, "Under the moonlight"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Under the moonlight'**
  String get schemeUnderTheMoonlight;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 76, "Lavender lullaby"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Lavender lullaby'**
  String get schemeLavenderLullaby;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 77, "Minty fresh"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Minty fresh'**
  String get schemeMintyFresh;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 78, "Retro calm"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Retro calm'**
  String get schemeRetroCalm;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 79, "Siltstone"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Siltstone'**
  String get schemeSiltstone;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 80, "Emerald odyssey"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Emerald odyssey'**
  String get schemeEmeraldOdyssey;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 81, "Ocean tide"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Ocean tide'**
  String get schemeOceanTide;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 82, "Peach skyline"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Peach skyline'**
  String get schemePeachSkyline;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 83, "Mountain mist"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Mountain mist'**
  String get schemeMountainMist;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 84, "Morning dew"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Morning dew'**
  String get schemeMorningDew;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 85, "Frozen lake"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Frozen lake'**
  String get schemeFrozenLake;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 86, "Olive grove"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Olive grove'**
  String get schemeOliveGrove;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 87, "Coastal morning"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Coastal morning'**
  String get schemeCoastalMorning;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 88, "Eucalyptus grove"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Eucalyptus grove'**
  String get schemeEucalyptusGrove;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 89, "Soft spring"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Soft spring'**
  String get schemeSoftSpring;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 90, "Autumn leaves"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Autumn leaves'**
  String get schemeAutumnLeaves;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 91, "Winter chill"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Winter chill'**
  String get schemeWinterChill;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 92, "Spring energy"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Spring energy'**
  String get schemeSpringEnergy;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 93, "Pumpkin spice season"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Pumpkin spice season'**
  String get schemePumpkinSpiceSeason;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 94, "Island oasis"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Island oasis'**
  String get schemeIslandOasis;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 95, "Autumn orchard"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Autumn orchard'**
  String get schemeAutumnOrchard;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 96, "Tropical rainforest"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Tropical rainforest'**
  String get schemeTropicalRainforest;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 97, "Wildflower meadow"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Wildflower meadow'**
  String get schemeWildflowerMeadow;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 98, "Harvest moon"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Harvest moon'**
  String get schemeHarvestMoon;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 99, "Winter berry"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Winter berry'**
  String get schemeWinterBerry;

  /// Settings → Appearance, the name of a color scheme (Figma's combination 100, "Summer breeze"); under its four colors.
  ///
  /// In en, this message translates to:
  /// **'Summer breeze'**
  String get schemeSummerBreeze;

  /// Settings → Appearance, button beside the color scheme showing: unfolds every scheme to pick from. count is how many (101).
  ///
  /// In en, this message translates to:
  /// **'See all {count} colors'**
  String appearanceColorsShowAll(int count);

  /// Settings → Appearance, the same button once the schemes are showing: folds them away.
  ///
  /// In en, this message translates to:
  /// **'Hide the colors'**
  String get appearanceColorsHide;

  /// Budget page, a category's plan (Due on a date): how often the bill comes
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every month} other{Every {count} months}}'**
  String planRepeatMonths(int count);

  /// Budget page, a category's plan (Due on a date): how often the bill comes
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every year} other{Every {count} years}}'**
  String planRepeatYears(int count);

  /// Budget page: note under a category's name, what its plan puts in each month
  ///
  /// In en, this message translates to:
  /// **'{amount} a month'**
  String planEachMonth(String amount);

  /// Budget page: note under a category's name, what its plan puts in each pay period
  ///
  /// In en, this message translates to:
  /// **'{amount} each pay period'**
  String planEachPay(String amount);

  /// Budget page: note under a category's name, a dated plan's part in the last month before its date (the rest of it)
  ///
  /// In en, this message translates to:
  /// **'{amount} this month'**
  String planThisMonth(String amount);

  /// Budget page: note under a category's name, a dated plan's part in the last pay period before its date
  ///
  /// In en, this message translates to:
  /// **'{amount} this pay period'**
  String planThisPay(String amount);

  /// Budget page, a category's plan (On a date): gold line in Edit when the Paid from account has been archived
  ///
  /// In en, this message translates to:
  /// **'{account} is archived, so this isn’t scheduled'**
  String planPaidFromArchived(String account);

  /// Budget page: note under a category's name, a set amount per one of several pays' periods, named by the pay
  ///
  /// In en, this message translates to:
  /// **'{amount} each pay period · {name}'**
  String planEachPayOf(String amount, String name);

  /// Budget page: note under a category's name, viewing by month a set amount that is per pay period: its share of this month, by days
  ///
  /// In en, this message translates to:
  /// **'about {amount} this month'**
  String planAboutThisMonth(String amount);

  /// Budget page: note under a category's name, viewing by a pay's periods a set amount that is per month (or per another pay): its share of this period, by days
  ///
  /// In en, this message translates to:
  /// **'about {amount} this pay period'**
  String planAboutThisPay(String amount);

  /// Budget page: note under a category's name, seen by another period than its own, when the period before was never filled and the rest of it is in view: what that period still needs, with its dates (like 10.23–11.24)
  ///
  /// In en, this message translates to:
  /// **'{amount} still to put in for {start}–{end}'**
  String planStillFor(String amount, String start, String end);

  /// Budget page: note under a category's name, after planStillFor: the share, by days, toward the category's next own period
  ///
  /// In en, this message translates to:
  /// **'plus about {amount} toward the next'**
  String planPlusNext(String amount);

  /// Budget page: part of the note under a category's name, after the amount and a dot
  ///
  /// In en, this message translates to:
  /// **'what’s left doesn’t carry over'**
  String get planNoCarry;

  /// Budget page: part of the note under a category's name; what the period before left unspent, returned to the money not assigned
  ///
  /// In en, this message translates to:
  /// **'{amount} left last month went back to not assigned'**
  String planWentBack(String amount);

  /// Budget page: note under a category's name, a repeating bill and its next due date
  ///
  /// In en, this message translates to:
  /// **'{amount} due {date}'**
  String planDue(String amount, String date);

  /// Budget page: note under a category's name, a one-time amount whose date has passed
  ///
  /// In en, this message translates to:
  /// **'{amount} was due {date}'**
  String planWasDue(String amount, String date);

  /// Budget page: note under a category's name, a one-time amount and its date
  ///
  /// In en, this message translates to:
  /// **'{amount} by {date}'**
  String planBy(String amount, String date);

  /// Budget page: end of the note under a category's name, when a dated plan has this period's part in
  ///
  /// In en, this message translates to:
  /// **'on track'**
  String get planOnTrack;

  /// Budget page: end of the note under a category's name, in gold: what should already have been assigned by now and wasn't
  ///
  /// In en, this message translates to:
  /// **'{amount} short'**
  String planShort(String amount);

  /// Budget page: link at the end of the note under a category's name; sets Assigned to what the plan wants this period
  ///
  /// In en, this message translates to:
  /// **'Assign {amount}'**
  String planAssignThis(String amount);

  /// Budget page: tooltip on the note under a category's name; clicking it opens Edit with the cursor in the plan's amount
  ///
  /// In en, this message translates to:
  /// **'Click to change the plan'**
  String get planEditTip;

  /// Budget page: button under the top line; assigns every plan's amount that isn't assigned yet this period
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Assign what’s planned · {amount} in 1 category} other{Assign what’s planned · {amount} in {count} categories}}'**
  String planFill(int count, String amount);

  /// Budget page, the key card, beside "Assign what's planned" on the Assigned row: what it would take beyond the money free. Coral; said before it's done.
  ///
  /// In en, this message translates to:
  /// **'That’s {amount} more than you have'**
  String planFillOver(String amount);

  /// Budget page, the key card, first row's label when the ledger has bank accounts but no cash account. Matches the sidebar group.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get planKeyBank;

  /// Budget page, the key card, first row's label when the ledger has cash but no bank account. Matches the sidebar group.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get planKeyCash;

  /// Budget page, the key card, first row's label: what is in the cash and bank accounts, one figure per currency. Deliberately the same words as the sidebar group ledgerGroupCashBank, so the figure can be checked against it. Short.
  ///
  /// In en, this message translates to:
  /// **'Cash & bank'**
  String get planKeyCashBank;

  /// Budget page, the key card, second row's label: what the categories hold now (assigned, less spent since the budget began; below zero when overspent). Short.
  ///
  /// In en, this message translates to:
  /// **'In categories'**
  String get planKeyAssigned;

  /// Budget page, the key card, the result row's label under the rule: what's free to assign (You have less Assigned). Short.
  ///
  /// In en, this message translates to:
  /// **'Not assigned'**
  String get planKeyNotAssigned;

  /// Budget page, the key card, label of the coral row under Not assigned, shown only when more is assigned than there is: the figure beside it is how much too much. Not assigned shows zero then, never a minus. Short.
  ///
  /// In en, this message translates to:
  /// **'Assigned too much'**
  String get planKeyOver;

  /// Toast and undo history label after Assign what's planned
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Assigned {amount} to 1 category} other{Assigned {amount} to {count} categories}}'**
  String planFilled(int count, String amount);

  /// Undo history label for saving a category's plan (shown in Undone/Redone toasts)
  ///
  /// In en, this message translates to:
  /// **'Plan for {category}'**
  String planSetUndo(String category);

  /// Toast and undo history label for removing a category's plan
  ///
  /// In en, this message translates to:
  /// **'Remove the plan for {category}'**
  String planRemoveUndo(String category);

  /// Budget page: note under a category's name, for a set amount per pay period; what the period before left unspent, returned to the money not assigned
  ///
  /// In en, this message translates to:
  /// **'{amount} left last pay period went back to not assigned'**
  String planWentBackPay(String amount);

  /// Budget page: note under a category's name, seen by another period than its own (a per-pay amount by the month, or a monthly one by a pay): what went back at its last period end in the span, on that day
  ///
  /// In en, this message translates to:
  /// **'{amount} went back to not assigned on {date}'**
  String planWentBackOn(String amount, String date);

  /// Budget page: gold line in a category's plan before saving, and part of the toast after, when changing or removing a plan that didn't carry over brings back what earlier periods returned
  ///
  /// In en, this message translates to:
  /// **'{amount} that went back returns to {category}, so not assigned goes down by that much'**
  String planReturns(String amount, String category);

  /// Budget page, a category's currency and accounts: label over the choice of ₮ or $
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get planMoneyCurrency;

  /// Budget page: note under a category's name when it uses one account only
  ///
  /// In en, this message translates to:
  /// **'only from {account}'**
  String planOnlyFromOne(String account);

  /// Budget page: note under a category's name when some of its currency's accounts are unchecked
  ///
  /// In en, this message translates to:
  /// **'only from {count} of {total} accounts'**
  String planOnlyFromSome(int count, int total);

  /// Undo history label for changing which accounts a category uses (shown in Undone/Redone toasts)
  ///
  /// In en, this message translates to:
  /// **'Accounts for {category}'**
  String planMoneyUndo(String category);

  /// Toast and undo history label for changing a category's currency
  ///
  /// In en, this message translates to:
  /// **'{category} is now in {symbol}'**
  String planMoneyCurrencyUndo(String category, String symbol);

  /// Budget page, a category's currency and accounts: gold line before Save, and part of the toast after, when the currency is changed on a category that has amounts and a plan
  ///
  /// In en, this message translates to:
  /// **'Changing the currency takes back {amount} assigned to it and removes its plan'**
  String planMoneyChange(String amount);

  /// The same line, for a category with amounts and no plan
  ///
  /// In en, this message translates to:
  /// **'Changing the currency takes back {amount} assigned to it'**
  String planMoneyChangeAmount(String amount);

  /// The same line, for a category with a plan and nothing assigned
  ///
  /// In en, this message translates to:
  /// **'Changing the currency removes its plan'**
  String get planMoneyChangePlan;

  /// Budget page, a category's currency and accounts: line under the checklist when one account is left checked; says with real amounts what unchecking does and doesn't reserve
  ///
  /// In en, this message translates to:
  /// **'{held} of what’s in {account} is for {category}. The other {rest} there can still be assigned to any category.'**
  String planMoneyRestOne(
    String held,
    String account,
    String category,
    String rest,
  );

  /// The same line, when several accounts are left checked and some are unchecked
  ///
  /// In en, this message translates to:
  /// **'{held} of what’s in these accounts is for {category}. The other {rest} there can still be assigned to any category.'**
  String planMoneyRestSome(String held, String category, String rest);

  /// Budget page: note under a category's name when every account is unchecked
  ///
  /// In en, this message translates to:
  /// **'no account chosen'**
  String get planFromNone;

  /// Budget page: gold note under a category's name; rows in the other currency are filed under it. It stays until they're fixed; clicking shows them
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{amount} in 1 row isn’t counted here (this category is in {symbol}); it came out of {other} not assigned} other{{amount} in {count} rows isn’t counted here (this category is in {symbol}); it came out of {other} not assigned}}'**
  String planOtherRows(int count, String amount, String symbol, String other);

  /// Budget page: gold note under a category's name; this period it was paid from an account unchecked for it and the money wasn't moved there (the spending still counts)
  ///
  /// In en, this message translates to:
  /// **'{amount} paid from {account}, which this category doesn’t use'**
  String planOffAccount(String amount, String account);

  /// The same note, when more than one such account paid
  ///
  /// In en, this message translates to:
  /// **'{amount} paid from {count} accounts this category doesn’t use'**
  String planOffAccounts(String amount, int count);

  /// Budget page: coral note under a category's name; it keeps its money in one account and that account holds less than the category has left
  ///
  /// In en, this message translates to:
  /// **'{held} left here, but {account} holds {have}'**
  String planBackingOne(String held, String account, String have);

  /// The same note, when it keeps its money in several accounts
  ///
  /// In en, this message translates to:
  /// **'{held} left here, but its accounts hold {have}'**
  String planBackingSome(String held, String have);

  /// The same note, when several categories limited to the same accounts together have more left than those accounts hold
  ///
  /// In en, this message translates to:
  /// **'{held} left in {count} categories kept in the same accounts, which hold {have}'**
  String planBackingShared(String held, int count, String have);

  /// Budget page, a category's menu (⋯ or right-click): opens everything about the category under its row; a double-click on the row does the same
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get planEdit;

  /// Budget page, Edit under a category's row: label over the field with the category's name
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get planEditName;

  /// Budget page, Edit under a category's row: the one question, first line of the form; No is a set amount each period, Yes an amount by a date
  ///
  /// In en, this message translates to:
  /// **'Is there a due date?'**
  String get planDueDateQ;

  /// Budget page, Edit: note beside the question while No is picked and the budget runs by month; what that answer means, in one example
  ///
  /// In en, this message translates to:
  /// **'A set amount you spend through each month, like groceries.'**
  String get planDueNoMeans;

  /// Budget page, Edit: the same note while the budget runs by pay period
  ///
  /// In en, this message translates to:
  /// **'A set amount you spend through each pay period, like groceries.'**
  String get planDueNoMeansPay;

  /// Budget page, Edit: note beside the question while Yes is picked; what that answer means, in one example
  ///
  /// In en, this message translates to:
  /// **'An amount to have ready by a date, like rent or insurance.'**
  String get planDueYesMeans;

  /// Budget page, Edit under a category's row: the first answer to "Is there a due date?"
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get planNo;

  /// Budget page, Edit under a category's row: the second answer to "Is there a due date?"
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get planYes;

  /// Budget page, Edit under a category's row: label of the amount field (No), and of the worked-out amount (Yes), when the budget runs by month
  ///
  /// In en, this message translates to:
  /// **'Set aside each month'**
  String get planSetAsideMonth;

  /// Budget page, Edit under a category's row: the same, when the budget runs by pay period
  ///
  /// In en, this message translates to:
  /// **'Set aside each pay period'**
  String get planSetAsidePay;

  /// Budget page, Edit under a category's row: grey hint inside the empty monthly amount; empty means no plan
  ///
  /// In en, this message translates to:
  /// **'nothing set'**
  String get planNothingSet;

  /// Budget page, Edit under a category's row: note beside the empty monthly amount
  ///
  /// In en, this message translates to:
  /// **'Leave it empty and you decide each month.'**
  String get planEmptyHint;

  /// Budget page, Edit under a category's row: the same, by pay period
  ///
  /// In en, this message translates to:
  /// **'Leave it empty and you decide each pay period.'**
  String get planEmptyHintPay;

  /// Budget page, Edit under a category's row: label of the carry-over choice, by month
  ///
  /// In en, this message translates to:
  /// **'What’s left at month’s end'**
  String get planLeftMonthEnd;

  /// Budget page, Edit under a category's row: label of the carry-over choice, by pay period
  ///
  /// In en, this message translates to:
  /// **'What’s left at the period’s end'**
  String get planLeftPeriodEnd;

  /// Budget page, Edit under a category's row: the first carry-over answer, the default: what the category didn't spend stays in it
  ///
  /// In en, this message translates to:
  /// **'Stays here'**
  String get planStaysHere;

  /// Budget page, Edit under a category's row: the second carry-over answer: when a period ends, what wasn't spent returns to the money not assigned
  ///
  /// In en, this message translates to:
  /// **'Goes back to not assigned'**
  String get planGoesBack;

  /// Budget page, Edit under a category's row: label of the optional cap on a category that carries over
  ///
  /// In en, this message translates to:
  /// **'Stop at'**
  String get planStopAt;

  /// Budget page, Edit under a category's row: grey hint inside the empty cap field
  ///
  /// In en, this message translates to:
  /// **'no limit'**
  String get planNoLimit;

  /// Budget page, Edit under a category's row: note beside the cap
  ///
  /// In en, this message translates to:
  /// **'Once it holds this much, it stops asking.'**
  String get planStopAtHint;

  /// Budget page, Edit under a category's row (Yes): label of the amount field
  ///
  /// In en, this message translates to:
  /// **'Amount due'**
  String get planAmountDue;

  /// Budget page, Edit under a category's row (Yes): label of the date field and the How often dropdown beside it
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get planLabelDueDate;

  /// Budget page, Edit under a category's row (Yes): label of the dropdown Once · Every month … Every 3 years
  ///
  /// In en, this message translates to:
  /// **'How often'**
  String get planHowOften;

  /// Budget page, Edit under a category's row (Yes): the first choice of how often, the amount is wanted one time
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get planOnce;

  /// Budget page, Edit under a category's row (Yes): how often, by days
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every day} other{Every {count} days}}'**
  String planRepeatDays(int count);

  /// Budget page, Edit under a category's row (Yes): how often, by weeks
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every week} other{Every {count} weeks}}'**
  String planRepeatWeeks(int count);

  /// Budget page, Edit under a category's row (Yes): how often, each payday of the one pay schedule
  ///
  /// In en, this message translates to:
  /// **'Every payday'**
  String get planEveryPayday;

  /// Budget page, Edit under a category's row (Yes): how often, each payday of one of several pays, named by the pay's name (else who pays, else the account)
  ///
  /// In en, this message translates to:
  /// **'Every payday · {name}'**
  String planEveryPaydayOf(String name);

  /// Budget page, Edit under a category's row (No): How often for a set amount, per the one pay's periods instead of per month
  ///
  /// In en, this message translates to:
  /// **'Every pay period'**
  String get planEveryPayPeriod;

  /// Budget page, Edit under a category's row (No): How often for a set amount, per one of several pays' periods, named by the pay
  ///
  /// In en, this message translates to:
  /// **'Every pay period · {name}'**
  String planEveryPayPeriodOf(String name);

  /// Budget page, Edit under a category's row (Yes): how often, the entry that opens the Custom block (Repeat every N unit; weekdays or the nth weekday; Ends), like a calendar app's recurrence
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get planEveryCustom;

  /// Budget page, Edit under a category's row (Yes): what the How often button says while the Custom block is open under it
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get planCustomOn;

  /// Budget page, Edit, the Custom block: label of the row with the number and the unit (days, weeks, months, years)
  ///
  /// In en, this message translates to:
  /// **'Repeat every'**
  String get planRepeatEvery;

  /// Budget page, Edit, the Custom block, every so many weeks: label of the row of weekday chips (Mo … Su)
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get planOnWeekdays;

  /// Budget page, Edit, the Custom block: note beside the weekday chips while none is picked
  ///
  /// In en, this message translates to:
  /// **'Pick the days; with none picked, the date’s own weekday.'**
  String get planWeekdaysHint;

  /// Budget page, Edit, the Custom block, every so many months or years: label of the row choosing the day of the month or a weekday (the second Tuesday)
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get planOnLabel;

  /// Budget page, Edit, the Custom block: the first choice under On, the due date's own day each month
  ///
  /// In en, this message translates to:
  /// **'Day of the month'**
  String get planDayOfMonth;

  /// Budget page, Edit, the Custom block: the second choice under On; picking it shows two dropdowns, which one (first … last) and which weekday
  ///
  /// In en, this message translates to:
  /// **'A weekday'**
  String get planAWeekday;

  /// Budget page, Edit, the Custom block: which weekday of the month, in the dropdown beside A weekday
  ///
  /// In en, this message translates to:
  /// **'first'**
  String get planNthFirst;

  /// Budget page, Edit, the Custom block: which weekday of the month
  ///
  /// In en, this message translates to:
  /// **'second'**
  String get planNthSecond;

  /// Budget page, Edit, the Custom block: which weekday of the month
  ///
  /// In en, this message translates to:
  /// **'third'**
  String get planNthThird;

  /// Budget page, Edit, the Custom block: which weekday of the month
  ///
  /// In en, this message translates to:
  /// **'fourth'**
  String get planNthFourth;

  /// Budget page, Edit, the Custom block: which weekday of the month, the last one
  ///
  /// In en, this message translates to:
  /// **'last'**
  String get planNthLast;

  /// Budget page, Edit, the Custom block: the weekday dropdown beside A weekday, Monday first, separated by |
  ///
  /// In en, this message translates to:
  /// **'Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday'**
  String get planWeekdayNames;

  /// Budget page, Edit, the Custom block: label of the row saying when the repeating plan stops
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get planEnds;

  /// Budget page, Edit, the Custom block, Ends: it goes on
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get planEndsNever;

  /// Budget page, Edit, the Custom block, Ends: no bill after the date typed beside it
  ///
  /// In en, this message translates to:
  /// **'On a date'**
  String get planEndsOn;

  /// Budget page, Edit, the Custom block, Ends: so many bills, the number typed beside it, then the word times
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get planEndsAfter;

  /// Budget page, Edit, the Custom block, Ends: after the number field (After 12 times)
  ///
  /// In en, this message translates to:
  /// **'times'**
  String get planEndsTimes;

  /// Budget page, Edit, the Custom block, Ends on a date: the empty date field's hint
  ///
  /// In en, this message translates to:
  /// **'YYYY.MM.DD'**
  String get planEndDateHint;

  /// Budget page, the note under a category's name once a repeating plan's last bill (its Ends) is past: the amount and the last bill's date
  ///
  /// In en, this message translates to:
  /// **'{amount} · ended {date}'**
  String planEnded(String amount, String date);

  /// Budget page, Edit under a category's row (Yes): how often, fixed dates each year that aren't evenly spaced (taxes four times a year)
  ///
  /// In en, this message translates to:
  /// **'On these dates…'**
  String get planOnDates;

  /// Budget page, Edit under a category's row (Yes): unit after "every"
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get planUnitDays;

  /// Budget page, Edit under a category's row (Yes): unit after "every"
  ///
  /// In en, this message translates to:
  /// **'weeks'**
  String get planUnitWeeks;

  /// Budget page, Edit under a category's row (Yes): unit after "every"
  ///
  /// In en, this message translates to:
  /// **'months'**
  String get planUnitMonths;

  /// Budget page, Edit under a category's row (Yes): unit after "every"
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get planUnitYears;

  /// Budget page, Edit under a category's row (Yes): label of the field that takes the list of dates
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get planDatesLabel;

  /// Budget page, Edit under a category's row (Yes): grey example inside the empty dates field
  ///
  /// In en, this message translates to:
  /// **'04.15, 06.15, 09.15, 01.15'**
  String get planDatesHint;

  /// Budget page, Edit under a category's row (Yes): what the How often button says once dates are typed
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{On these dates} =1{1 date a year} other{{count} dates a year}}'**
  String planDatesAYear(int count);

  /// Budget page, Edit under a category's row (Yes): after the number, for a plan that follows paydays
  ///
  /// In en, this message translates to:
  /// **'days after payday'**
  String get planDaysAfterPay;

  /// Budget page, Edit under a category's row (Yes): note beside the days-after field while it is 0
  ///
  /// In en, this message translates to:
  /// **'on payday'**
  String get planOnPayday;

  /// Budget page, Edit under a category's row (Yes): weekend rule, the default: a date on a weekend stays
  ///
  /// In en, this message translates to:
  /// **'On the day'**
  String get planWeekendKeep;

  /// Budget page, Edit under a category's row (Yes): weekend rule: a Saturday or Sunday date moves to the Friday
  ///
  /// In en, this message translates to:
  /// **'Before a weekend'**
  String get planWeekendBefore;

  /// Budget page, Edit under a category's row (Yes): weekend rule: a Saturday or Sunday date moves to the Monday
  ///
  /// In en, this message translates to:
  /// **'After a weekend'**
  String get planWeekendAfter;

  /// Budget page, Edit under a category's row (Yes): note beside Paid from once an account is chosen
  ///
  /// In en, this message translates to:
  /// **'Shows in {account}’s forecast on {date}; you confirm it when it’s paid.'**
  String planPaidFromHint(String account, String date);

  /// Budget page, Edit under a category's row (Yes): note beside Paid from while more than one account, or none, is checked (the bill is scheduled only in a single account)
  ///
  /// In en, this message translates to:
  /// **'Leave one account checked and the bill shows in its forecast.'**
  String get planPaidFromHintNone;

  /// Budget page, Edit under a category's row (Yes): the amount set aside each period, which the app works out rather than asks for
  ///
  /// In en, this message translates to:
  /// **'{amount} · worked out from the date'**
  String planWorkedOut(String amount);

  /// Budget page, Edit under a category's row (Yes): in place of the worked-out amount until both are typed
  ///
  /// In en, this message translates to:
  /// **'Enter the amount and the date'**
  String get planEnterAmountDate;

  /// Budget page, Edit under a category's row (Yes): in place of the worked-out amount when the plan has all it needs
  ///
  /// In en, this message translates to:
  /// **'nothing more to set aside'**
  String get planNothingMore;

  /// Budget page, Edit under a category's row: small caption over the category's row drawn as it will look after Save
  ///
  /// In en, this message translates to:
  /// **'The row will read'**
  String get planRowWillRead;

  /// Budget page, Edit under a category's row, both answers: label of the dropdown of checkboxes over the accounts in the category's currency (cash, bank and cards), all checked to begin with; a dated plan's bill is scheduled in the one account left checked
  ///
  /// In en, this message translates to:
  /// **'Paid from'**
  String get planLabelPaidFrom;

  /// Budget page: part of the note under a category's name, after the amount and a dot; the plan's cap
  ///
  /// In en, this message translates to:
  /// **'up to {amount}'**
  String planUpTo(String amount);

  /// Budget page: note under a category's name, in place of the amount, when a capped plan holds its cap
  ///
  /// In en, this message translates to:
  /// **'{amount} set aside'**
  String planSetAsideAmount(String amount);

  /// Toast and undo history label after Edit saved more than one change to a category at once (say its name and its plan)
  ///
  /// In en, this message translates to:
  /// **'Changes to {category}'**
  String planEditedUndo(String category);

  /// Budget page, Edit under a spending category's row: what the Accounts this category uses dropdown says when every account in the category's currency is checked
  ///
  /// In en, this message translates to:
  /// **'All accounts'**
  String get planAccountsAll;

  /// Budget page, Edit under a spending category's row: what the Accounts this category uses dropdown says when every account is unchecked
  ///
  /// In en, this message translates to:
  /// **'No accounts'**
  String get planAccountsNone;

  /// Budget page, Edit under a spending category's row: what the Accounts this category uses dropdown says when only some accounts are checked (two or more; with one it shows that account's name)
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} accounts'**
  String planAccountsSome(int count, int total);

  /// Add account, the Currency dropdown: hint in the search field at the top of the list of every currency
  ///
  /// In en, this message translates to:
  /// **'Search currencies'**
  String get setupCurrencySearch;

  /// Add account, the Currency dropdown: shown in the list when the search matches nothing
  ///
  /// In en, this message translates to:
  /// **'No currency by that name'**
  String get setupCurrencyNoMatch;

  /// The app's one income category, which money coming in (not a refund) is filed under: the category menu, the entry row and register rows.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get ledgerIncome;

  /// A pay that was stopped, named where a category is still per its periods: the plan note, How often. name is the pay's title.
  ///
  /// In en, this message translates to:
  /// **'{name} (stopped)'**
  String payStopped(String name);

  /// Budget page, under the not-assigned lines: this period's income, each currency on its own, like "Income: ₮3,200,000.00 · $120.00". A click shows the rows.
  ///
  /// In en, this message translates to:
  /// **'Income: {amounts}'**
  String planIncomeLine(String amounts);

  /// Entry row, gold note when the typed category doesn't exist and the amount has a +: the new category will be a spending one, so the money is a refund, not income.
  ///
  /// In en, this message translates to:
  /// **'new category · money in counts as a refund to it; for pay, pick Income'**
  String get rowsNewCategoryRefundNote;

  /// Toast after a pay schedule is saved, joined after "Pay saved · next payday …": the user's own scheduled rows for the same pay were taken over.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{replaced the income you scheduled by hand} other{replaced {count} incomes you scheduled by hand}}'**
  String ledgerPayReplaced(int count);

  /// Setup, first screen: the page heading.
  ///
  /// In en, this message translates to:
  /// **'Your accounts'**
  String get setupYourAccounts;

  /// Setup, under the heading. Not every account: only the ones they want to follow.
  ///
  /// In en, this message translates to:
  /// **'Add the accounts you want to track.'**
  String get setupAddTracked;

  /// Setup, under the heading: said once, before any balance is typed.
  ///
  /// In en, this message translates to:
  /// **'BetterBudget never connects to your bank. You type in what your bank app shows.'**
  String get setupNeverConnects;

  /// Setup: label beside the one date every balance typed there is as of.
  ///
  /// In en, this message translates to:
  /// **'Balances as of'**
  String get setupBalancesAsOf;

  /// Undo label after setup's one balance date is changed.
  ///
  /// In en, this message translates to:
  /// **'Balances date changed'**
  String get setupDateChanged;

  /// Setup, under the amount owed on a credit card or loan being added.
  ///
  /// In en, this message translates to:
  /// **'A charge from today that the bank hasn’t shown yet isn’t in this figure.'**
  String get setupOwedTodayHint;

  /// Setup, under the accounts: a question with three answers. Also its undo label.
  ///
  /// In en, this message translates to:
  /// **'How do you pay for everyday things?'**
  String get setupEverydayQ;

  /// Setup: first answer to how everyday things are paid for.
  ///
  /// In en, this message translates to:
  /// **'From the bank (card, QR or transfer)'**
  String get setupEverydayBank;

  /// Setup: third answer to how everyday things are paid for, after From the bank and Cash.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get setupEverydayBoth;

  /// Setup: shown when they pay with cash and have added no Cash account. A warning, never a block.
  ///
  /// In en, this message translates to:
  /// **'You have no Cash account. Money you take out of an ATM will read as spent the day you take it out, and the cash in your wallet won’t be counted.'**
  String get setupNoCashWarning;

  /// Setup: button beside the no-Cash-account warning.
  ///
  /// In en, this message translates to:
  /// **'Add a Cash account'**
  String get setupAddCashAccount;

  /// Setup: the button that leaves setup for the ledger.
  ///
  /// In en, this message translates to:
  /// **'Open my ledger'**
  String get setupOpenLedger;

  /// Setup: tooltip on the × beside an account in the list.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String setupRemoveAccount(String name);

  /// Setup: second answer to how everyday things are paid for. In Mongolian it answers “with what”, so it isn’t the account Type’s word.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get setupEverydayCash;

  /// Setup, under the Balance of a Cash account being added. zero is ₮0 in the account’s currency.
  ///
  /// In en, this message translates to:
  /// **'Count what’s in your wallet now · empty starts at {zero}'**
  String setupStartCashHint(String zero);

  /// Undo label after setup is left with Open my ledger.
  ///
  /// In en, this message translates to:
  /// **'Setup finished'**
  String get setupFinished;

  /// Setup: the first step’s name in the row of step names across the top.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get setupStepAccounts;

  /// Setup: the second step’s name in the row of step names across the top. Pay as in a paycheck.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get setupStepPay;

  /// Setup: the button that goes on to the next step.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get setupContinue;

  /// Setup: the button that goes to the step before. Nothing is undone by it.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get setupBack;

  /// Setup, Pay step, under the amount of a paycheck: the figure wanted is the deposit as the bank statement shows it, not the salary before tax and social insurance. A loan payment the bank takes after the pay lands is entered later as a bill, so it must not be taken off here.
  ///
  /// In en, this message translates to:
  /// **'The amount that lands in the account, not your salary before tax. A loan payment the bank takes afterwards is a bill.'**
  String get setupPayArrives;

  /// Setup, Pay step, when the only accounts are credit cards or loans. “Accounts” is the first step’s name, “Cash” the account Type.
  ///
  /// In en, this message translates to:
  /// **'Pay goes into a bank account or Cash. Add one on Accounts to set up your pay.'**
  String get setupPayNeedsAccount;

  /// Setup, Pay step: the one line shown after “I don’t have regular pay” was chosen, with an “Add your pay” button beside it.
  ///
  /// In en, this message translates to:
  /// **'No regular pay'**
  String get setupNoRegularPayLine;

  /// Phone app, the first screen’s heading above the list of categories and what is left in each. {month} is a month’s name from monthNames.
  ///
  /// In en, this message translates to:
  /// **'Left in {month}'**
  String phoneLeftIn(String month);

  /// Phone app, under the heading: when the figures were last copied from the Mac, if that was today. {time} reads 08:10.
  ///
  /// In en, this message translates to:
  /// **'From your computer today {time}'**
  String phoneFromMacToday(String time);

  /// Phone app, under the heading: when the figures were last copied from the Mac, on an earlier day. {date} reads 2026.10.06, {time} 21:40.
  ///
  /// In en, this message translates to:
  /// **'From your computer {date} {time}'**
  String phoneFromMacOn(String date, String time);

  /// Phone app, a line under the categories: entries typed on this phone that the Mac hasn’t taken into the ledger yet. Tapping it lists them.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 of your entries is waiting for your computer} other{{count} of your entries are waiting for your computer}}'**
  String phoneWaiting(int count);

  /// Phone app: heading of the list of this phone’s entries the Mac hasn’t taken in yet.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your computer'**
  String get phoneWaitingTitle;

  /// Phone app, Accounts list: a credit card’s or loan’s balance.
  ///
  /// In en, this message translates to:
  /// **'Owed {amount}'**
  String phoneOwed(String amount);

  /// Phone app, under the amount being typed for a category, before any digit is typed: what is left in that category.
  ///
  /// In en, this message translates to:
  /// **'{left} left now'**
  String phoneLeftNow(String left);

  /// Phone app, under the amount being typed for a category: what is left in it now, and what will be left once this entry is saved.
  ///
  /// In en, this message translates to:
  /// **'{left} left now · {after} after this'**
  String phoneLeftAfter(String left, String after);

  /// Phone app: shown above Save when Save was tapped with no amount typed.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get phoneEnterAmount;

  /// Phone app: shown above Save when Save was tapped with no payee chosen or typed.
  ///
  /// In en, this message translates to:
  /// **'Enter a payee'**
  String get phoneEnterPayee;

  /// Phone app: what a screen reader says for the amount pad’s delete key.
  ///
  /// In en, this message translates to:
  /// **'Delete the last digit'**
  String get phoneDeleteDigit;

  /// Settings, Backups: label of the line that says where the ledger is stored now: on this computer, or in the folder it was moved to (a Google Drive, OneDrive, Box or Dropbox folder).
  ///
  /// In en, this message translates to:
  /// **'Stored in'**
  String get ledgerFolderLabel;

  /// Settings, Backups: the button that opens a folder picker. The ledger is then stored in that folder, saved there again after every change. The owner’s word is “move”, not “keep”.
  ///
  /// In en, this message translates to:
  /// **'Move my ledger to a folder…'**
  String get ledgerFolderChoose;

  /// The confirm button of the system folder picker opened by “Move my ledger to a folder…”.
  ///
  /// In en, this message translates to:
  /// **'Move It Here'**
  String get ledgerFolderPickButton;

  /// Settings, Backups: under the buttons, only while the ledger is stored on this computer. Says what “Move my ledger to a folder…” does.
  ///
  /// In en, this message translates to:
  /// **'Move it to a folder that Google Drive, OneDrive, Box or Dropbox keeps on this computer, and your ledger is stored there, encrypted, and saved again after each change.'**
  String get ledgerFolderNote;

  /// Settings, Backups, the “Stored in” line: the folder and when the copy there was last written, as the Daily copy line above it does. {when} reads “Today 14:32”.
  ///
  /// In en, this message translates to:
  /// **'{folder} · {when}'**
  String ledgerFolderCopied(String folder, String when);

  /// Settings, Backups, the “Stored in” line, in red: the last try at writing the copy failed (the folder is gone, full or offline).
  ///
  /// In en, this message translates to:
  /// **'{folder} · couldn’t copy · the last one is from {when}'**
  String ledgerFolderFailing(String folder, String when);

  /// Settings, Backups, the “Stored in” line, in red: writing the copy failed and none was ever written.
  ///
  /// In en, this message translates to:
  /// **'{folder} · couldn’t copy'**
  String ledgerFolderFailingNone(String folder);

  /// Settings, Backups: picks another folder to store the ledger in.
  ///
  /// In en, this message translates to:
  /// **'Move to another folder…'**
  String get ledgerFolderChange;

  /// Settings, Backups: stops storing the ledger in the folder. The file already there is not deleted.
  ///
  /// In en, this message translates to:
  /// **'Move it back to this computer'**
  String get ledgerFolderStop;

  /// Toast after a folder was chosen and the ledger written there.
  ///
  /// In en, this message translates to:
  /// **'Your ledger was moved to {folder}'**
  String ledgerFolderKept(String folder);

  /// Toast after “Move it back to this computer”.
  ///
  /// In en, this message translates to:
  /// **'Your ledger is back on this computer · the file in {folder} stays there'**
  String ledgerFolderStopped(String folder);

  /// Toast when the ledger couldn’t be written into a newly chosen folder; it stays where it was.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t move it to that folder'**
  String get ledgerFolderCouldnt;

  /// Settings, Backups, the “Stored in” line while the ledger has not been moved to a folder.
  ///
  /// In en, this message translates to:
  /// **'This computer'**
  String get ledgerFolderHere;

  /// Phone app, first launch: heading above the box for the recovery key.
  ///
  /// In en, this message translates to:
  /// **'Enter your recovery key'**
  String get phoneKeyTitle;

  /// Phone app, first launch: under the heading, says what the recovery key is and why the phone asks.
  ///
  /// In en, this message translates to:
  /// **'The 25 characters you were shown when your ledger was set up on your computer. This phone needs them once, to read your ledger.'**
  String get phoneKeyBody;

  /// Phone app, first launch: heading of the step that picks the cloud folder the ledger was moved to.
  ///
  /// In en, this message translates to:
  /// **'Where is your ledger?'**
  String get phoneFolderTitle;

  /// Phone app, first launch: under “Where is your ledger?”. “Stored in” is ledgerFolderLabel on the computer.
  ///
  /// In en, this message translates to:
  /// **'Choose the folder your ledger was moved to on your computer. In Settings there, the line “Stored in” names it.'**
  String get phoneFolderBody;

  /// Phone app: button that opens the phone’s folder picker.
  ///
  /// In en, this message translates to:
  /// **'Choose the folder'**
  String get phoneFolderChoose;

  /// Phone app: heading when the picked folder has no ledger file.
  ///
  /// In en, this message translates to:
  /// **'There is no ledger in that folder'**
  String get phoneNoLedger;

  /// Phone app: under “There is no ledger in that folder”. {file} is Ledger.betterbudget.
  ///
  /// In en, this message translates to:
  /// **'The folder should hold a file named {file}. It can take a minute to arrive after your computer saves it.'**
  String phoneNoLedgerBody(String file);

  /// Phone app: heading when the typed recovery key is a valid key but not this ledger’s.
  ///
  /// In en, this message translates to:
  /// **'That recovery key doesn’t open the ledger in this folder'**
  String get phoneKeyDoesntOpen;

  /// Phone app: button under “That recovery key doesn’t open the ledger in this folder”.
  ///
  /// In en, this message translates to:
  /// **'Enter the key again'**
  String get phoneEnterKeyAgain;

  /// Phone app: heading when the ledger file was found and the key fits, but it can’t be read (saved by a newer version of the app, or damaged).
  ///
  /// In en, this message translates to:
  /// **'The ledger in this folder couldn’t be read'**
  String get phoneCantRead;

  /// Phone app: under “The ledger in this folder couldn’t be read”.
  ///
  /// In en, this message translates to:
  /// **'It may have been saved by a newer BetterBudget than the one on this phone.'**
  String get phoneCantReadBody;

  /// Phone app: reads the folder again.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get phoneTryAgain;

  /// Phone app: opens the folder picker again.
  ///
  /// In en, this message translates to:
  /// **'Choose another folder'**
  String get phoneChooseAnother;

  /// Tooltip on the Settings gear’s red dot when the folder the ledger was moved to can’t be written.
  ///
  /// In en, this message translates to:
  /// **'Your ledger couldn’t be saved to its folder'**
  String get ledgerFolderAlert;

  /// Phone app, the first screen’s heading when the budget runs by pay periods, not months. {date} is the period’s last day, like 10.14.
  ///
  /// In en, this message translates to:
  /// **'Left until {date}'**
  String phoneLeftUntil(String date);

  /// Phone app, under a category’s name when it is saving for a bill: the day the bill is due, like 10.20.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String phoneDue(String date);

  /// Phone app, under the amount pad before a digit is typed, for a category that is already overspent.
  ///
  /// In en, this message translates to:
  /// **'Overspent by {over}'**
  String phoneOverNow(String over);

  /// Phone app, under the amount being typed: the category has money now, and this entry would overspend it.
  ///
  /// In en, this message translates to:
  /// **'{left} left now · overspent by {over} after this'**
  String phoneOverAfter(String left, String over);

  /// Phone app, under the amount being typed, for a category already overspent: by how much now, and after this entry.
  ///
  /// In en, this message translates to:
  /// **'Overspent by {over} · by {after} after this'**
  String phoneOverBoth(String over, String after);

  /// Phone app: shown above Save when no account is chosen under Paid from.
  ///
  /// In en, this message translates to:
  /// **'Choose an account'**
  String get phoneChooseAccount;

  /// Phone, Category list: heading over the user's other accounts at the foot of the list. Picking one makes the entry a transfer to it (cash from an ATM, a credit card paid) instead of spending.
  ///
  /// In en, this message translates to:
  /// **'Move to an account'**
  String get phoneMoveToAccount;

  /// Phone: an account as the destination of a transfer, in the Category list and in the Category row once picked, as the computer writes it: '→ Cash wallet'.
  ///
  /// In en, this message translates to:
  /// **'→ {account}'**
  String phoneTransferTo(String account);

  /// Phone, Ledger: label of the account row when the entry is a transfer: the account the money leaves. Takes the place of 'Paid from'.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get phoneFrom;

  /// Phone, Ledger, line under the amount of a transfer: what the account the money leaves will hold once it has gone, e.g. 'TDB Checking · ₮3,812,450.00 after this'.
  ///
  /// In en, this message translates to:
  /// **'{account} · {amount} after this'**
  String phoneTransferAfter(String account, String amount);

  /// As phoneTransferAfter, when the money leaves a credit card or loan: what will be owed on it.
  ///
  /// In en, this message translates to:
  /// **'{account} · {amount} owed after this'**
  String phoneTransferOwedAfter(String account, String amount);

  /// Phone toast after a transfer is saved, e.g. 'Saved · TDB Checking → Cash wallet ₮100,000.00'.
  ///
  /// In en, this message translates to:
  /// **'Saved · {from} → {to} {amount}'**
  String phoneSavedTransfer(String from, String to, String amount);

  /// Phone toast, second line after a transfer: what the account the money went to holds now, e.g. 'Cash wallet · ₮186,500.00 now'.
  ///
  /// In en, this message translates to:
  /// **'{account} · {amount} now'**
  String phoneTransferNow(String account, String amount);

  /// As phoneTransferNow, when the money went to a credit card or loan: what is still owed on it.
  ///
  /// In en, this message translates to:
  /// **'{account} · {amount} owed now'**
  String phoneTransferOwedNow(String account, String amount);

  /// Phone, waiting list: the name of a transfer, the two accounts, e.g. 'TDB Checking → Cash wallet'.
  ///
  /// In en, this message translates to:
  /// **'{from} → {to}'**
  String phoneTransferTitle(String from, String to);

  /// Phone app, Accounts list: a card or loan that has been paid more than was owed.
  ///
  /// In en, this message translates to:
  /// **'{amount} in credit'**
  String phoneInCredit(String amount);

  /// Phone app, the first screen: heading over the categories whose money is waiting for a bill (rent, with “Due 10.20” under its name), listed after the categories with money to spend.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get phoneBills;

  /// Phone app: the row that makes a new category, in the category list with nothing typed and at the end of the Budget screen’s list. Same words as the computer’s entry row.
  ///
  /// In en, this message translates to:
  /// **'+ New category'**
  String get phoneNewCategory;

  /// Phone app: heading of the box that asks for a new category’s name.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get phoneNewCategoryTitle;

  /// Phone app: shown above Save when Save was tapped with no category chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose a category'**
  String get phoneChooseCategory;

  /// Phone app: under the amount being typed, and under the category’s name on the Budget screen, for a category just made on the phone. Money is assigned to it on the computer; “Assigned” is the Budget page’s word.
  ///
  /// In en, this message translates to:
  /// **'Nothing assigned yet'**
  String get phoneNothingAssigned;

  /// Phone app: the line shown after an entry is saved, with Undo beside it. {amount} reads −₮12,500.00.
  ///
  /// In en, this message translates to:
  /// **'Saved · {payee} {amount}'**
  String phoneSaved(String payee, String amount);

  /// Phone app, the line that opens the waiting list, when only categories made on this phone are waiting, with no entries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new category is waiting for your computer} other{{count} new categories are waiting for your computer}}'**
  String phoneWaitingCategories(int count);

  /// Phone app, the line that opens the waiting list, when both entries and categories made on this phone are waiting.
  ///
  /// In en, this message translates to:
  /// **'{entries, plural, =1{1 of your entries} other{{entries} of your entries}} and {categories, plural, =1{1 new category} other{{categories} new categories}} are waiting for your computer'**
  String phoneWaitingBoth(int entries, int categories);

  /// Phone app, waiting list: asked before a category made on this phone is deleted while entries are filed in it. {amount} is their total, like ₮18,000.00.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete {name} and the 1 entry in it ({amount})?} other{Delete {name} and the {count} entries in it ({amount})?}}'**
  String phoneDeleteCategory(int count, String name, String amount);

  /// Phone app, top right of the entry screen once anything is typed or chosen: empties the entry being typed.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get phoneClear;

  /// Phone app, second line of the card shown after an entry is saved: what the entry left in its category. Reads “Groceries · ₮135,500.00 left”.
  ///
  /// In en, this message translates to:
  /// **'{category} · {left} left'**
  String phoneSavedLeft(String category, String left);

  /// Phone app, second line of the card shown after an entry is saved, when its category is now overspent. Reads “Eating out · overspent by ₮30,900.00”.
  ///
  /// In en, this message translates to:
  /// **'{category} · overspent by {over}'**
  String phoneSavedOver(String category, String over);

  /// Phone app, second line of the card shown after an entry is saved in a category made on this phone, which has no money assigned until that is done on the computer.
  ///
  /// In en, this message translates to:
  /// **'{category} · nothing assigned yet'**
  String phoneSavedNothingAssigned(String category);

  /// Popup on the computer when entries typed on a phone have been added to the ledger as uncleared rows; Undo takes them all out again.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction from your phone} other{{count} transactions from your phone}}'**
  String ledgerFromPhone(int count);

  /// Popup on the computer when a category made on a phone has been added, with no entries in it yet.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new category from your phone} other{{count} new categories from your phone}}'**
  String ledgerCategoryFromPhone(int count);

  /// Button on the popup that says a phone made a new category: opens that category’s Edit on the Budget page, where money is assigned to it. {name} is the category, like Coffee.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String ledgerEditCategory(String name);

  /// Phone app, under the amount being typed when the entry is money in (a refund) to a category that is overspent: by how much now, and what the refund will leave in it.
  ///
  /// In en, this message translates to:
  /// **'Overspent by {over} · {after} left after this'**
  String phoneOverThenLeft(String over, String after);

  /// Phone app, Ledger: what a screen reader says for the +/− button beside the amount while the entry is money out. Tapping it makes the entry money in (a refund, or income).
  ///
  /// In en, this message translates to:
  /// **'Change to money in'**
  String get phoneToMoneyIn;

  /// Phone app, the Category list, under the box: shown when Income's name is typed while the entry is money out. Income is offered only for money in, which the +/− button beside the amount on Ledger chooses.
  ///
  /// In en, this message translates to:
  /// **'To record income, tap +/− beside the amount first.'**
  String get phoneIncomeNeedsMoneyIn;

  /// Phone app, Ledger: what a screen reader says for the +/− button beside the amount while the entry is money in. Tapping it makes the entry money out again.
  ///
  /// In en, this message translates to:
  /// **'Change to money out'**
  String get phoneToMoneyOut;

  /// Popup when the ledger in the folder was newer than this computer's and was taken in, because another computer saved changes there and nothing was changed here. {computer} is what that computer is called, like “Tom’s MacBook Air”. Its second line is ledgerFolderCopied (the folder and when). It has no Undo: what was here is saved in Backups.
  ///
  /// In en, this message translates to:
  /// **'Opened the ledger saved on {computer}'**
  String ledgerFolderOpenedFrom(String computer);

  /// As ledgerFolderOpenedFrom, when the other computer’s name isn’t known.
  ///
  /// In en, this message translates to:
  /// **'Opened the ledger saved on another computer'**
  String get ledgerFolderOpened;

  /// Popup when this computer and another both changed the ledger, and what the other changed was brought into this one without a question. {count} is how many transactions were added, changed or deleted here; {computer} is what the other computer is called, like “Tom’s MacBook Air”. Worded as ledgerFromPhone is. Its second line is ledgerFolderCopied (the folder and when), or ledgerCombinedAlike and ledgerCombinedOverAssigned when there is one of those to say. It has no Undo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction from {computer}} other{{count} transactions from {computer}}}'**
  String ledgerCombinedFrom(int count, String computer);

  /// As ledgerCombinedFrom, when the other computer also changed something that isn’t a transaction: an account, a category, an amount assigned, a setting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction and other changes from {computer}} other{{count} transactions and other changes from {computer}}}'**
  String ledgerCombinedMoreFrom(int count, String computer);

  /// As ledgerCombinedFrom, when the other computer changed no transaction, only something else: an account, a category, an amount assigned, a setting.
  ///
  /// In en, this message translates to:
  /// **'Changes from {computer}'**
  String ledgerCombinedOtherFrom(String computer);

  /// As ledgerCombinedFrom, when the other computer’s name isn’t known.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction from another computer} other{{count} transactions from another computer}}'**
  String ledgerCombined(int count);

  /// As ledgerCombinedMoreFrom, when the other computer’s name isn’t known.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction and other changes from another computer} other{{count} transactions and other changes from another computer}}'**
  String ledgerCombinedMore(int count);

  /// As ledgerCombinedOtherFrom, when the other computer’s name isn’t known.
  ///
  /// In en, this message translates to:
  /// **'Changes from another computer'**
  String get ledgerCombinedOther;

  /// Second line of the popup that says transactions came from another computer (ledgerCombinedFrom), when some of them have the same account and amount, within a few days, as a transaction entered on this computer: a purchase one person typed and the other imported from the bank. Both are in the ledger; the popup’s Show button opens the row. {count} is how many.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 looks the same as one already here} other{{count} look the same as ones already here}}'**
  String ledgerCombinedAlike(int count);

  /// A line of the popup that says changes came from another computer, when the amounts assigned to categories on the two computers together come to more money than there is. {amount} is the shortfall with its currency, like “₮3,000,000”; it is the figure the Budget page shows as Assigned too much.
  ///
  /// In en, this message translates to:
  /// **'{amount} more is assigned than you have'**
  String ledgerCombinedOverAssigned(String amount);

  /// Popup when the newer ledger in the folder couldn’t be taken in (damaged, or it has no accounts).
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open the ledger in {folder} · nothing was changed'**
  String ledgerFolderCouldntOpen(String folder);

  /// Settings, Backups, the “Stored in” line: the folder holds a ledger file this computer can’t read, usually because the sync app is still bringing it. Nothing is written over it.
  ///
  /// In en, this message translates to:
  /// **'{folder} · the ledger there can’t be read yet'**
  String ledgerFolderArriving(String folder);

  /// Settings, Backups, the “Stored in” line, in red: another computer with a newer version of the app saved the ledger in the folder, so this computer can’t read it and won’t write over it until its app is updated.
  ///
  /// In en, this message translates to:
  /// **'{folder} · saved by a newer version of BetterBudget · update BetterBudget on this computer'**
  String ledgerFolderNewerAppLine(String folder);

  /// Settings, Backups, the “Stored in” line, in red: the ledger in the folder and the one on this computer were both changed, so neither is written over the other until the person chooses (the button ledgerFolderChooseWhich).
  ///
  /// In en, this message translates to:
  /// **'{folder} · changed on another computer too · this computer’s changes aren’t in the folder'**
  String ledgerFolderApart(String folder);

  /// Settings, Backups: a button shown only while the ledger in the folder and this computer’s were both changed. Opens the question ledgerTwoTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose which to keep…'**
  String get ledgerFolderChooseWhich;

  /// Tooltip on the Settings gear’s red dot while the ledger in the folder and this computer’s were both changed.
  ///
  /// In en, this message translates to:
  /// **'Your ledger was changed on two computers'**
  String get ledgerFolderApartAlert;

  /// Heading of the question shown when the ledger in the folder has changes this computer doesn’t, and this computer has changes the folder doesn’t.
  ///
  /// In en, this message translates to:
  /// **'Your ledger was changed on two computers'**
  String get ledgerTwoTitle;

  /// Heading of the same question when it comes up right after “Move my ledger to a folder…” picked a folder that already holds a different ledger.
  ///
  /// In en, this message translates to:
  /// **'This folder already has a ledger'**
  String get ledgerTwoTitleFolder;

  /// Under ledgerTwoTitle. {folder} is the folder’s last two parts, like “My Drive/BetterBudget”. “Restore from…” is the button ledgerRestoreFrom.
  ///
  /// In en, this message translates to:
  /// **'The ledger in {folder} has changes that aren’t on this computer, and this computer has changes that aren’t in the folder. BetterBudget can’t put these two together, so choose which one to keep. The other is saved first, and Restore from… in Settings brings it back. Until you choose, this computer’s changes and your phone’s entries stay out of the folder.'**
  String ledgerTwoBody(String folder);

  /// The question ledgerTwoTitle: label of the line that says what the folder’s ledger holds.
  ///
  /// In en, this message translates to:
  /// **'In the folder'**
  String get ledgerTwoInFolder;

  /// The question ledgerTwoTitle: label of the line that says what this computer’s ledger holds.
  ///
  /// In en, this message translates to:
  /// **'On this computer'**
  String get ledgerTwoHere;

  /// The question ledgerTwoTitle, under the folder’s line: which computer saved the folder’s ledger and when. {when} reads “Yesterday 21:40”.
  ///
  /// In en, this message translates to:
  /// **'Saved on {computer} · {when}'**
  String ledgerTwoSavedOn(String computer, String when);

  /// As ledgerTwoSavedOn, when the other computer’s name isn’t known.
  ///
  /// In en, this message translates to:
  /// **'Saved on another computer · {when}'**
  String ledgerTwoSavedWhen(String when);

  /// The question ledgerTwoTitle: closes it with nothing changed. Until one is chosen this computer’s changes aren’t written to the folder.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get ledgerTwoNotNow;

  /// The question ledgerTwoTitle: this computer’s ledger is written to the folder; the one that was there is saved as a backup first.
  ///
  /// In en, this message translates to:
  /// **'Keep this computer’s ledger'**
  String get ledgerTwoUseMine;

  /// The question ledgerTwoTitle: the folder’s ledger is opened on this computer; what this computer had is saved as a backup first.
  ///
  /// In en, this message translates to:
  /// **'Keep the folder’s ledger'**
  String get ledgerTwoUseFolder;

  /// Popup after “Use this computer’s”, with Undo.
  ///
  /// In en, this message translates to:
  /// **'This computer’s ledger is now in {folder} · the one that was there is saved in Backups'**
  String ledgerFolderKeptMine(String folder);

  /// Heading of the warning when “Move my ledger to a folder…” picked a folder holding a ledger file this computer’s recovery key doesn’t open.
  ///
  /// In en, this message translates to:
  /// **'The ledger in this folder can’t be opened'**
  String get ledgerFolderUnreadableTitle;

  /// Under ledgerFolderUnreadableTitle.
  ///
  /// In en, this message translates to:
  /// **'{folder} holds a ledger that this computer can’t open. It may be another ledger, or one that is still arriving.'**
  String ledgerFolderUnreadableBody(String folder);

  /// Second paragraph under ledgerFolderUnreadableTitle. “Restore from…” is the button ledgerRestoreFrom.
  ///
  /// In en, this message translates to:
  /// **'If you replace it, it is saved on this computer first, and Restore from… opens it with its own recovery key.'**
  String get ledgerFolderUnreadableKept;

  /// The red button of the warning ledgerFolderUnreadableTitle: writes this computer’s ledger over the one in the folder.
  ///
  /// In en, this message translates to:
  /// **'Replace it'**
  String get ledgerFolderReplace;

  /// Popup when “Move my ledger to a folder…” picked a folder whose ledger was saved by a newer version of the app. Nothing was changed.
  ///
  /// In en, this message translates to:
  /// **'The ledger in that folder was saved by a newer version of BetterBudget · update BetterBudget on this computer first'**
  String get ledgerFolderNewerApp;

  /// A ticked checkbox in the “Restore this backup?” dialog, shown when the file picked is the ledger another computer keeps in a synced folder. Ticked, this computer shares that ledger from now on. folder is the folder’s last two parts, such as “My Drive/BetterBudget”.
  ///
  /// In en, this message translates to:
  /// **'Share the ledger in {folder}'**
  String ledgerRestoreKeepOnFolder(String folder);

  /// Under the checkbox ledgerRestoreKeepOnFolder. folder is the folder’s last two parts, such as “My Drive/BetterBudget”.
  ///
  /// In en, this message translates to:
  /// **'What you change here goes to {folder}, and what is changed on another computer comes here.'**
  String ledgerRestoreKeepOnFolderNote(String folder);

  /// The confirm button of the Mac’s folder dialog, which opens on the folder the restored ledger is in so the app is given that folder.
  ///
  /// In en, this message translates to:
  /// **'Use This Folder'**
  String get ledgerUseThisFolder;

  /// Popup, and the undo list’s name, after Restore from… with “Share the ledger in …” ticked.
  ///
  /// In en, this message translates to:
  /// **'This computer is now on the ledger in {folder}'**
  String ledgerRestoredOnFolder(String folder);

  /// Popup when the restore worked but the folder couldn’t be kept: the ledger is stored on this computer only.
  ///
  /// In en, this message translates to:
  /// **'Your ledger is here, but this computer isn’t on {folder} · in Settings, use Move my ledger to a folder…'**
  String ledgerRestoredNotOnFolder(String folder);

  /// Under the checkbox ledgerRestoreKeepOnFolder while it is unticked: says what that means.
  ///
  /// In en, this message translates to:
  /// **'This computer gets its own copy. What you change here won’t reach {folder}.'**
  String ledgerRestoreNotKeptNote(String folder);

  /// Under the ticked checkbox ledgerRestoreKeepOnFolder, on a Mac only. “Use This Folder” is the button ledgerUseThisFolder.
  ///
  /// In en, this message translates to:
  /// **'Your Mac asks for the folder next: press Use This Folder.'**
  String get ledgerRestoreMacAsks;

  /// Title of the restore dialog when the file picked is the ledger kept in a synced folder, not a backup.
  ///
  /// In en, this message translates to:
  /// **'Bring this ledger here?'**
  String get ledgerBringLedgerTitle;

  /// Label in that dialog, in place of “Backup from”: when the folder’s ledger was last saved.
  ///
  /// In en, this message translates to:
  /// **'Last changed'**
  String get ledgerLastChanged;

  /// Body of that dialog, in place of ledgerRestoreNote.
  ///
  /// In en, this message translates to:
  /// **'Everything here is replaced by this ledger. What you have now is saved first, and Undo brings it back.'**
  String get ledgerBringLedgerNote;

  /// Asked after Yes, and in a dialog at a later launch while the ledger is still empty.
  ///
  /// In en, this message translates to:
  /// **'Where is your ledger?'**
  String get startWhereTitle;

  /// An answer to startWhereTitle.
  ///
  /// In en, this message translates to:
  /// **'In a folder, such as Google Drive'**
  String get startWhereFolder;

  /// Under startWhereFolder.
  ///
  /// In en, this message translates to:
  /// **'This computer shares the ledger that is there.'**
  String get startWhereFolderNote;

  /// An answer to startWhereTitle.
  ///
  /// In en, this message translates to:
  /// **'In a backup'**
  String get startWhereBackup;

  /// Under startWhereBackup. “Back up to…” is the Settings button.
  ///
  /// In en, this message translates to:
  /// **'A copy you saved with Back up to… in Settings.'**
  String get startWhereBackupNote;

  /// Popup after a folder was picked whose ledger was made under another recovery key.
  ///
  /// In en, this message translates to:
  /// **'Your recovery key doesn’t open the ledger in {folder}'**
  String ledgerFolderWrongKey(String folder);

  /// Popup after a folder was picked that holds no Ledger.betterbudget.
  ///
  /// In en, this message translates to:
  /// **'There’s no ledger in {folder} · choose the folder that holds Ledger.betterbudget. If it is still copying to this computer, try again in a minute.'**
  String ledgerFolderNoLedger(String folder);

  /// The first screen on a computer with no ledger: heading over three choices.
  ///
  /// In en, this message translates to:
  /// **'How do you want to start?'**
  String get startHowTitle;

  /// First choice: a new, empty ledger.
  ///
  /// In en, this message translates to:
  /// **'Start fresh'**
  String get startFresh;

  /// Under startFresh.
  ///
  /// In en, this message translates to:
  /// **'My household is new to BetterBudget.'**
  String get startFreshNote;

  /// Second choice.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get startRestore;

  /// Under startRestore. “Back up to…” is the Settings button.
  ///
  /// In en, this message translates to:
  /// **'I have a backup file, saved with Back up to… in Settings. This computer gets its own copy.'**
  String get startRestoreNote;

  /// Third choice: the ledger stored in a synced folder.
  ///
  /// In en, this message translates to:
  /// **'Open ledger'**
  String get startOpen;

  /// Under startOpen.
  ///
  /// In en, this message translates to:
  /// **'My household already uses BetterBudget on another computer, and the ledger is in a folder, such as Google Drive. This computer shares it.'**
  String get startOpenNote;

  /// Label over the key field inside an opened choice.
  ///
  /// In en, this message translates to:
  /// **'Recovery key'**
  String get startKeyLabel;

  /// Button under the key in Open ledger: stores the key, then opens the folder dialog.
  ///
  /// In en, this message translates to:
  /// **'Choose the folder…'**
  String get startChooseFolder;

  /// Button under the key in Restore from backup: stores the key, then opens the file dialog.
  ///
  /// In en, this message translates to:
  /// **'Choose the backup…'**
  String get startChooseBackup;

  /// Under the key field in an opened choice on the first screen: which key, and where it may be. The file name is startKeyFileName.
  ///
  /// In en, this message translates to:
  /// **'It was shown when BetterBudget was first set up, and is in “BetterBudget recovery key.txt” if it was saved.'**
  String get startKeyHint;

  /// Under the key field on the first screen, after a folder was picked whose ledger the typed key doesn’t open. Nothing was stored.
  ///
  /// In en, this message translates to:
  /// **'That key doesn’t open the ledger in {folder}. If the folder is still copying to this computer, try again in a minute.'**
  String startKeyWrongFolder(String folder);

  /// Sidebar section, under Savings, and its page's heading: the payees that are always filed under one category.
  ///
  /// In en, this message translates to:
  /// **'Payees'**
  String get ledgerSectionPayees;

  /// Payees page, column heading over each payee's sentence (payeesStartsWith or payeesHasAnywhere).
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get payeesColumnPayee;

  /// Payees page: column heading, and the label of the Edit's line of accounts (a dropdown of checkboxes, as Paid from is). Shown only with more than one account.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get payeesColumnAccounts;

  /// Payees page, button at the end of a line and in the Edit (owner, 2026-10-12: "Just put delete"): the app stops putting that payee in the category by itself.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get payeesDelete;

  /// Popup card after Delete on the Payees page; the payee is on the line under it. Rows already filed stay. category may be Income, or Income and a pay's name.
  ///
  /// In en, this message translates to:
  /// **'Deleted · new rows of this payee stop going to {category} by themselves'**
  String payeesDeletedMessage(String category);

  /// Payees page, the green button at the top right: opens an empty Edit at the top of the list.
  ///
  /// In en, this message translates to:
  /// **'Add a payee'**
  String get payeesAdd;

  /// Payees page, Edit: the small label over the words field.
  ///
  /// In en, this message translates to:
  /// **'Payee, or a word in it'**
  String get payeesWordsLabel;

  /// Payees page, Edit: label of the line with payeesAtStart and payeesAnywhere.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get payeesWhere;

  /// Payees page, Edit, Where: the payee's name has to begin with the words.
  ///
  /// In en, this message translates to:
  /// **'At the start of the payee'**
  String get payeesAtStart;

  /// Payees page, Edit, Where: the words may be anywhere in the payee or in the memo the bank wrote.
  ///
  /// In en, this message translates to:
  /// **'Anywhere in the payee or the memo'**
  String get payeesAnywhere;

  /// Payees page, a closed line: the payee's words, which a payee's name has to begin with. The «» stay: the words between them are drawn in ink.
  ///
  /// In en, this message translates to:
  /// **'starts with «{name}»'**
  String payeesStartsWith(String name);

  /// Payees page, a closed line: the words, looked for anywhere in the payee or the bank's description. The «» stay.
  ///
  /// In en, this message translates to:
  /// **'has «{name}» anywhere'**
  String payeesHasAnywhere(String name);

  /// Payees page, Edit: how many rows of the chosen accounts begin with the words typed, as they are typed. May be followed by payeesWaiting and payeesElsewhere after a dot.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No row starts with this yet} =1{1 row starts with this} other{{count} rows start with this}}'**
  String payeesFitsStarts(int count);

  /// Payees page, Edit: how many rows of the chosen accounts have the words anywhere in the payee or the bank's description.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No row has this yet} =1{1 row has this} other{{count} rows have this}}'**
  String payeesFitsAnywhere(int count);

  /// Payees page, Edit, after payeesFitsStarts or payeesFitsAnywhere: how many of those rows have no category yet.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 still in Not categorized} other{{count} still in Not categorized}}'**
  String payeesWaiting(int count);

  /// Payees page, Edit: how many of those rows are in a category other than the one chosen. Said so a word that is too short shows itself; they are never moved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 in another category} other{{count} in another category}}'**
  String payeesElsewhere(int count);

  /// Payees page, Edit: label over one real row that fits, drawn with the chosen category.
  ///
  /// In en, this message translates to:
  /// **'How a row will read'**
  String get payeesHowRowReads;

  /// Payees page, Edit: in place of the count while the words field is empty, and in red after Save with it empty.
  ///
  /// In en, this message translates to:
  /// **'Type a payee, or a word in it'**
  String get payeesNeedsWords;

  /// Payees page, Edit: in red after Save with no category chosen.
  ///
  /// In en, this message translates to:
  /// **'Pick a category'**
  String get payeesNeedsCategory;

  /// Payees page, Edit: in red after Save with no account ticked.
  ///
  /// In en, this message translates to:
  /// **'Pick an account'**
  String get payeesNeedsAccount;

  /// Payees page with nothing on it. The quoted words are the popup's button (ledgerAlwaysFile with count 0); "add a payee" is the button payeesAdd.
  ///
  /// In en, this message translates to:
  /// **'Nothing remembered yet. Pick a category on a row in the Ledger and the popup offers “Remember this for next time”, or add a payee here.'**
  String get payeesEmpty;

  /// Payees page, column heading over each payee's category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get payeesColumnFiled;

  /// Popup card after Delete on the Payees page; the payee is on the line under it. Also what Undo names.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get payeesDeleted;

  /// Popup card after payeesFileWaiting is clicked; the payee's beginning is on the line under it. Also what Undo names.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row filed under {category}} other{{count} rows filed under {category}}}'**
  String payeesFiled(int count, String category);

  /// Button on the popup after a payee's beginning is retyped: files the rows it now fits that are still in Not categorized under the payee's category.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{File the 1 still in Not categorized} other{File the {count} still in Not categorized}}'**
  String payeesFileWaiting(int count);

  /// Popup card when Save on the Payees page finds the words are another line's on one of the same accounts: that line's words and category. The Edit stays open.
  ///
  /// In en, this message translates to:
  /// **'«{payee}» is already in the list, as {category}'**
  String payeesAlreadyListed(String payee, String category);

  /// Payees page, Edit, after the count: how many of the rows that fit are in the chosen category already.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 already in {category}} other{{count} already in {category}}}'**
  String payeesAlreadyIn(int count, String category);

  /// Payees page, Edit, after "No row starts with this yet": how many rows would fit with Where set to anywhere.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 has it anywhere} other{{count} have it anywhere}}'**
  String payeesAnywhereWould(int count);

  /// Payees page, in place of a category's name once the category was deleted.
  ///
  /// In en, this message translates to:
  /// **'A deleted category'**
  String get payeesCategoryGone;

  /// Title of the question that lists what two computers each changed in a way that can’t both stand: a transaction’s amount or details, or what a category is assigned for a period. {count} is how many.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One thing was changed on both computers} other{{count} things were changed on both computers}}'**
  String ledgerRowsTitle(int count);

  /// Under ledgerRowsTitle. {computer} is the other computer’s name, or ledgerRowsOtherComputer.
  ///
  /// In en, this message translates to:
  /// **'Choose which to keep for each. Everything else {computer} changed comes in with your choices. The one you don’t keep is saved in Backups. Until you choose, this computer’s changes and your phone’s entries stay out of the folder.'**
  String ledgerRowsBody(String computer);

  /// Heading over this computer’s version of a thing both computers changed.
  ///
  /// In en, this message translates to:
  /// **'This computer'**
  String get ledgerRowsThisComputer;

  /// The other computer’s name, when it isn’t known.
  ///
  /// In en, this message translates to:
  /// **'The other computer'**
  String get ledgerRowsOtherComputer;

  /// Button under one thing both computers changed: keep the version made on this computer.
  ///
  /// In en, this message translates to:
  /// **'Keep this computer’s'**
  String get ledgerRowsKeepHere;

  /// Button under one thing both computers changed: keep the version made on the other computer. {computer} is its name.
  ///
  /// In en, this message translates to:
  /// **'Keep {computer}’s'**
  String ledgerRowsKeepTheirs(String computer);

  /// Button in the question ledgerRowsTitle when this computer deleted the transaction and the other changed it: leave it deleted.
  ///
  /// In en, this message translates to:
  /// **'Keep it deleted'**
  String get ledgerRowsKeepDeletedHere;

  /// Button in the question ledgerRowsTitle when the other computer deleted the transaction and this one changed it: delete it. {computer} is the other computer’s name.
  ///
  /// In en, this message translates to:
  /// **'Keep it deleted ({computer}’s)'**
  String ledgerRowsKeepDeletedTheirs(String computer);

  /// Button under one thing both computers changed: put it back as it was before either changed it.
  ///
  /// In en, this message translates to:
  /// **'Neither: as it was'**
  String get ledgerRowsKeepNeither;

  /// Button of the question ledgerRowsTitle: makes the choices and brings in everything else the other computer changed.
  ///
  /// In en, this message translates to:
  /// **'Save my choices'**
  String get ledgerRowsSave;

  /// Heading over a category’s assigned amount both computers changed for one budget period. {date} is the period’s first day.
  ///
  /// In en, this message translates to:
  /// **'{category} · Assigned, period starting {date}'**
  String ledgerRowsAssigned(String category, String date);

  /// One version of a transaction in the question ledgerRowsTitle: it was deleted there.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get ledgerRowsDeleted;

  /// Heading over a transaction in the question ledgerRowsTitle that has no payee.
  ///
  /// In en, this message translates to:
  /// **'No payee'**
  String get ledgerRowsNoPayee;

  /// Line under a thing both computers changed: what it said before either changed it. {what} is its amount and category.
  ///
  /// In en, this message translates to:
  /// **'As it was: {what}'**
  String ledgerRowsAsItWas(String what);

  /// Popup after the question ledgerRowsTitle is answered and there was nothing else to bring in.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Your choice is saved} other{Your {count} choices are saved}}'**
  String ledgerRowsSaved(int count);

  /// Popup when the ledger changed under the question ledgerRowsTitle.
  ///
  /// In en, this message translates to:
  /// **'Something changed on this computer while you were choosing, so nothing was saved. You’ll be asked again.'**
  String get ledgerRowsChangedMeanwhile;

  /// Register column header, shown only when the person turns it on in Settings
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get rowsColumnSource;

  /// Where a transaction came from: typed in the register on a computer, named
  ///
  /// In en, this message translates to:
  /// **'Entered on {computer}'**
  String sourceTypedOn(String computer);

  /// Where a transaction came from: typed, the computer not known
  ///
  /// In en, this message translates to:
  /// **'Entered'**
  String get sourceTyped;

  /// Where a transaction came from: a bank file, imported on a computer, named
  ///
  /// In en, this message translates to:
  /// **'Imported on {computer}'**
  String sourceImportedOn(String computer);

  /// Where a transaction came from: a bank file, the computer not known
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get sourceImported;

  /// Where a transaction came from: saved on a phone, named by the person
  ///
  /// In en, this message translates to:
  /// **'From {phone}'**
  String sourcePhone(String phone);

  /// Where a transaction came from: the only phone that has sent one
  ///
  /// In en, this message translates to:
  /// **'From your phone'**
  String get sourceYourPhone;

  /// Where a transaction came from: one of several phones, not yet named; id is the first four characters of its id
  ///
  /// In en, this message translates to:
  /// **'From phone {id}'**
  String sourcePhoneId(String id);

  /// Where a transaction came from: a payday or bill the app scheduled
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get sourceScheduled;

  /// Settings section title for the register’s own choices
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get settingsRegisterTitle;

  /// Settings switch: adds the Source column to the register
  ///
  /// In en, this message translates to:
  /// **'Show where each transaction came from'**
  String get settingsSourceColumn;

  /// Settings: the phones that have saved entries, to name each
  ///
  /// In en, this message translates to:
  /// **'Your phones'**
  String get settingsPhonesTitle;

  /// Settings: the label of the box where a phone is named; id is the first four characters of its id
  ///
  /// In en, this message translates to:
  /// **'Name for phone {id}'**
  String settingsPhoneName(String id);

  /// Settings: example in the box where a phone is named
  ///
  /// In en, this message translates to:
  /// **'For example, Pixel'**
  String get settingsPhoneNameHint;

  /// Where a transaction came from: typed on this computer
  ///
  /// In en, this message translates to:
  /// **'Entered locally'**
  String get sourceTypedHere;

  /// Where a transaction came from: a bank file imported on this computer
  ///
  /// In en, this message translates to:
  /// **'Imported locally'**
  String get sourceImportedHere;

  /// Where a transaction came from: typed on a computer that has no name yet
  ///
  /// In en, this message translates to:
  /// **'Entered on another computer'**
  String get sourceTypedElsewhere;

  /// Where a transaction came from: imported on a computer that has no name yet
  ///
  /// In en, this message translates to:
  /// **'Imported on another computer'**
  String get sourceImportedElsewhere;

  /// Settings: the computers that made transactions, to name each
  ///
  /// In en, this message translates to:
  /// **'Your computers'**
  String get settingsComputersTitle;

  /// Settings: the label of the box where this computer is named
  ///
  /// In en, this message translates to:
  /// **'Name for this computer'**
  String get settingsComputerThis;

  /// Settings: the label of the box where another computer is named; id is the first four characters of its id
  ///
  /// In en, this message translates to:
  /// **'Name for computer {id}'**
  String settingsComputerName(String id);
}

class _WordsDelegate extends LocalizationsDelegate<Words> {
  const _WordsDelegate();

  @override
  Future<Words> load(Locale locale) {
    return SynchronousFuture<Words>(lookupWords(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'mn'].contains(locale.languageCode);

  @override
  bool shouldReload(_WordsDelegate old) => false;
}

Words lookupWords(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return WordsEn();
    case 'mn':
      return WordsMn();
  }

  throw FlutterError(
    'Words.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
