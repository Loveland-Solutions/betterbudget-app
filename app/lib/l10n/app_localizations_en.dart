// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class WordsEn extends Words {
  WordsEn([String locale = 'en']) : super(locale);

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSameAsMac => 'Same as this Mac';

  @override
  String get languageSameAsWindows => 'Same as Windows';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageMongolian => 'Монгол';

  @override
  String languageShowingNow(String language, String system) {
    return 'Showing $language now · changes when $system does';
  }

  @override
  String languageUndoLabel(String choice) {
    return 'Language: $choice';
  }

  @override
  String get theMac => 'the Mac';

  @override
  String get windowsName => 'Windows';

  @override
  String dayMonth(String month, String day, int monthNumber, int dayNumber) {
    return '$month.$day';
  }

  @override
  String dayMonthYear(
    String year,
    String month,
    String day,
    int monthNumber,
    int dayNumber,
  ) {
    return '$year.$month.$day';
  }

  @override
  String calendarMonth(String month, String year, int monthNumber) {
    return '$month $year';
  }

  @override
  String get monthNames =>
      'January|February|March|April|May|June|July|August|September|October|November|December';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get ledgerStartEmpty => 'Start empty';

  @override
  String ledgerAdded(String name) {
    return '$name added';
  }

  @override
  String ledgerOpeningCountsIt(String amount, String date) {
    return 'it’s dated on or before the opening balance ($amount on $date), which already counts it';
  }

  @override
  String ledgerOpeningOfCountsIt(String account, String amount, String date) {
    return 'it’s dated on or before the opening balance of $account ($amount on $date), which already counts it';
  }

  @override
  String get ledgerTakeOutOfBothOpenings =>
      'Take it out of both opening balances';

  @override
  String ledgerOpeningOfNow(String account, String amount, String date) {
    return 'Opening balance of $account now $amount on $date';
  }

  @override
  String get ledgerOpeningTookIt => 'it was taken out of the opening balance';

  @override
  String ledgerOpeningOfTookIt(String account) {
    return 'it was taken out of the opening balance of $account';
  }

  @override
  String get ledgerCorrectBothOpenings => 'Correct both opening balances';

  @override
  String ledgerOpeningBackTo(String amount) {
    return 'Opening balance back to $amount';
  }

  @override
  String ledgerMakeOpening(String amount) {
    return 'Make the opening balance $amount';
  }

  @override
  String ledgerMoreRowsFiled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more rows filed',
      one: '1 more row filed',
    );
    return '$_temp0';
  }

  @override
  String rowsAdjustOwedUpAndLock(String amount) {
    return 'Add $amount to what you owe and lock';
  }

  @override
  String rowsAdjustOwedDownAndLock(String amount) {
    return 'Take $amount off what you owe and lock';
  }

  @override
  String get ledgerTakeOutOfOpening => 'Take it out of the opening balance';

  @override
  String ledgerOpeningNow(String amount, String date) {
    return 'Opening balance now $amount on $date';
  }

  @override
  String ledgerAddedTo(String name, String account) {
    return '$name added to $account';
  }

  @override
  String ledgerNewCategory(String name) {
    return 'new category “$name”';
  }

  @override
  String ledgerScheduledFor(String date) {
    return 'scheduled for $date';
  }

  @override
  String get ledgerNotInThisView => 'not in this view';

  @override
  String ledgerScheduledToast(String date) {
    return 'Scheduled for $date · not in balances until confirmed';
  }

  @override
  String get ledgerCouldntSave => 'Couldn’t save that change';

  @override
  String ledgerCouldntSaveBecause(String reason) {
    return 'Couldn’t save: $reason';
  }

  @override
  String get ledgerShowDetails => 'Show details';

  @override
  String get ledgerHideDetails => 'Hide details';

  @override
  String ledgerUndoNewerFirst(String shortcut) {
    return 'Undo the newer changes first · $shortcut';
  }

  @override
  String get ledgerNothingToUndo => 'Nothing to undo';

  @override
  String get ledgerNothingToRedo => 'Nothing to redo';

  @override
  String ledgerCouldntUndo(String action) {
    return 'Couldn’t undo “$action” · it was changed afterwards';
  }

  @override
  String ledgerCouldntRedo(String action) {
    return 'Couldn’t redo “$action” · it was changed afterwards';
  }

  @override
  String ledgerUndone(String action) {
    return 'Undone · $action';
  }

  @override
  String ledgerRedone(String action) {
    return 'Redone · $action';
  }

  @override
  String get ledgerUndo => 'Undo';

  @override
  String get ledgerSaveOrDiscard => 'Save or cancel the open row first';

  @override
  String get ledgerFinishReconcileFirst =>
      'Finish or cancel the reconcile first';

  @override
  String ledgerConfirmed(String name) {
    return '$name confirmed';
  }

  @override
  String ledgerConfirmedAmount(String when, String name, String amount) {
    String _temp0 = intl.Intl.selectLogic(when, {
      'early': '$name confirmed early · $amount',
      'other': '$name confirmed · $amount',
    });
    return '$_temp0';
  }

  @override
  String ledgerConfirmedAmountPlanned(
    String when,
    String name,
    String amount,
    String planned,
  ) {
    String _temp0 = intl.Intl.selectLogic(when, {
      'early': '$name confirmed early · $amount, planned $planned',
      'other': '$name confirmed · $amount, planned $planned',
    });
    return '$_temp0';
  }

  @override
  String ledgerStillOwed(String amount, String date) {
    return '$amount still owed, due $date';
  }

  @override
  String ledgerPostedToday(String date) {
    return 'entered today, $date';
  }

  @override
  String ledgerPostedOn(String date) {
    return 'entered $date';
  }

  @override
  String ledgerUnderEstimate(String amount) {
    return '$amount under the estimate · lower it on the Budget page';
  }

  @override
  String ledgerEdited(String name) {
    return '$name edited';
  }

  @override
  String ledgerMovedToFuture(String date) {
    return 'Moved to $date · now scheduled, out of balances until confirmed';
  }

  @override
  String get ledgerChangesSaved => 'Changes saved';

  @override
  String ledgerTypeADate(String example) {
    return 'Enter the date like $example';
  }

  @override
  String get ledgerStatementAfterToday => 'The statement can’t be after today';

  @override
  String ledgerAlreadyReconciled(String date) {
    return 'Already reconciled through $date';
  }

  @override
  String get ledgerClearedRowsChanged =>
      'The cleared rows changed · check the difference again';

  @override
  String ledgerReconciledThrough(String account, String date) {
    return '$account reconciled through $date';
  }

  @override
  String ledgerLocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count locked',
      one: '1 locked',
    );
    return '$_temp0';
  }

  @override
  String ledgerAdjustmentAdded(String amount) {
    return '$amount adjustment added';
  }

  @override
  String ledgerReconcileUndone(String date) {
    return 'Reconcile of $date undone';
  }

  @override
  String ledgerBackToCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows back to cleared',
      one: '1 row back to cleared',
    );
    return '$_temp0';
  }

  @override
  String ledgerMarkedCleared(String name) {
    return '$name marked cleared';
  }

  @override
  String ledgerMarkedUncleared(String name) {
    return '$name marked uncleared';
  }

  @override
  String ledgerCantDeleteTransfer(String account) {
    return 'Can’t delete · this transfer is reconciled in $account';
  }

  @override
  String get ledgerCantUnclearReconciled =>
      'Can’t mark it uncleared · it matches a bank statement';

  @override
  String get ledgerCantDeleteReconciled =>
      'Can’t delete · it matches a bank statement';

  @override
  String ledgerDeleted(String name) {
    return '$name deleted';
  }

  @override
  String ledgerCantMove(String reason) {
    return 'Can’t move · $reason';
  }

  @override
  String get ledgerCouldntMove => 'Couldn’t move it';

  @override
  String ledgerMovedTo(String name, String account) {
    return '$name moved to $account';
  }

  @override
  String get ledgerShowMoved => 'Show';

  @override
  String ledgerTransferToMovedTo(String payee, String account) {
    return 'Transfer to $payee moved to $account';
  }

  @override
  String ledgerTransferFromMovedTo(String payee, String account) {
    return 'Transfer from $payee moved to $account';
  }

  @override
  String get ledgerUnclearedThere => 'uncleared there until it clears';

  @override
  String get ledgerAddBankAccountFirst => 'Add a bank account first';

  @override
  String get ledgerPayStopped => 'Pay stopped';

  @override
  String get ledgerPayStoppedToast =>
      'Pay no longer scheduled · paydays already past stay';

  @override
  String ledgerPayStoppedMoved(int count, String how) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pay no longer scheduled · $count categories now $how',
      one: 'Pay no longer scheduled · 1 category now $how',
    );
    return '$_temp0';
  }

  @override
  String get ledgerPaySaved => 'Pay saved';

  @override
  String ledgerPaySavedNext(String date) {
    return 'Pay saved · next payday $date';
  }

  @override
  String get ledgerNoRegularPay => 'No regular pay';

  @override
  String get ledgerAskingForPayAgain => 'Asking for pay again';

  @override
  String get ledgerNoRegularPayToast =>
      'No regular pay · the app won’t ask for it · the Budget page’s Income tab changes this';

  @override
  String get ledgerAskForPayAgainToast =>
      'The forecast will ask for your pay again';

  @override
  String get ledgerBudgetByMonth => 'Budget viewed by month';

  @override
  String ledgerBudgetByPayPeriod(String name) {
    return 'Budget viewed by pay period · $name';
  }

  @override
  String get ledgerAppearanceTitle => 'Appearance';

  @override
  String get ledgerAppearanceLight => 'Light';

  @override
  String get ledgerAppearanceDark => 'Dark';

  @override
  String ledgerAppearanceUndoLabel(String choice) {
    return 'Appearance: $choice';
  }

  @override
  String ledgerShowingLightNow(String system) {
    return 'Showing light now · changes when $system does';
  }

  @override
  String ledgerShowingDarkNow(String system) {
    return 'Showing dark now · changes when $system does';
  }

  @override
  String get ledgerAllAccounts => 'All accounts';

  @override
  String ledgerCategoryChip(String name) {
    return 'Category: $name';
  }

  @override
  String get ledgerAdd => 'Add';

  @override
  String ledgerFilterRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$_temp0';
  }

  @override
  String ledgerFilterTotal(String kind, String amount) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'received': '$amount received',
      'paidBack': '$amount paid back',
      'refunded': '$amount refunded',
      'other': '$amount spent',
    });
    return '$_temp0';
  }

  @override
  String ledgerFilterTotalSince(String kind, String amount, String date) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'received': '$amount received since $date',
      'paidBack': '$amount paid back since $date',
      'refunded': '$amount refunded since $date',
      'other': '$amount spent since $date',
    });
    return '$_temp0';
  }

  @override
  String ledgerFilterScheduled(int count) {
    return '$count scheduled';
  }

  @override
  String get ledgerCouldntAddAccount => 'Couldn’t add the account';

  @override
  String get ledgerCouldntKeepRate =>
      'Couldn’t keep the interest rate. The account was added; type the rate on Savings, step 2.';

  @override
  String get ledgerCouldntSaveBalance => 'Couldn’t save the balance';

  @override
  String get ledgerCouldntChangeAccount => 'Couldn’t change the account';

  @override
  String get ledgerCouldntChangePay => 'Couldn’t change the pay';

  @override
  String get ledgerCouldntChangeBudgetPeriod =>
      'Couldn’t change the budget period';

  @override
  String get ledgerCouldntChangeCategory => 'Couldn’t change the category';

  @override
  String ledgerRenamed(String old, String name) {
    return 'Renamed $old to $name';
  }

  @override
  String ledgerIsNowCardOrLoan(String name) {
    return '$name is now a credit card or loan';
  }

  @override
  String ledgerIsNowBankAccount(String name) {
    return '$name is now a bank account';
  }

  @override
  String get ledgerOpeningBalanceFlipped =>
      'its opening balance flipped with it';

  @override
  String ledgerArchiveTitle(String name) {
    return 'Archive $name?';
  }

  @override
  String ledgerArchiveAction(String name) {
    return 'Archive $name';
  }

  @override
  String ledgerArchived(String name) {
    return '$name archived';
  }

  @override
  String ledgerBackInSidebar(String name) {
    return '$name back in the sidebar';
  }

  @override
  String ledgerAccountArchivedToast(String name) {
    return '$name archived · Settings brings it back';
  }

  @override
  String ledgerDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String ledgerDeleteAction(String name) {
    return 'Delete $name';
  }

  @override
  String ledgerAlreadyCategory(String name) {
    return '$name is already a category';
  }

  @override
  String ledgerBackInMenus(String name) {
    return '$name back in the menus';
  }

  @override
  String ledgerCategoryArchivedToast(String name) {
    return '$name archived · its rows keep it; new rows can’t pick it';
  }

  @override
  String ledgerMergedInto(String name, String target) {
    return '$name merged into $target';
  }

  @override
  String ledgerRowsMoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows moved',
      one: '1 row moved',
    );
    return '$_temp0';
  }

  @override
  String ledgerDeletedRowsMovedTo(String name, int count, String target) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$name deleted · $_temp0 moved to $target';
  }

  @override
  String get ledgerBackUpButton => 'Back Up';

  @override
  String get ledgerCouldntOpenSaveDialog => 'Couldn’t open the save dialog';

  @override
  String get ledgerCouldntBackUp =>
      'Couldn’t back up · check the drive has room and try again';

  @override
  String ledgerBackedUp(String file) {
    return 'Backed up · $file';
  }

  @override
  String get ledgerBackupFileType => 'BetterBudget backup';

  @override
  String get ledgerChoose => 'Choose';

  @override
  String get ledgerCouldntOpenFileDialog => 'Couldn’t open the file dialog';

  @override
  String get ledgerCouldntReadBackup => 'Couldn’t read that backup';

  @override
  String get ledgerCouldntRestore => 'Couldn’t restore · nothing was changed';

  @override
  String ledgerRestoredFrom(String date) {
    return 'Restored the copy from $date';
  }

  @override
  String get ledgerWhatYouHadIsSaved => 'what you had is saved';

  @override
  String ledgerArchivedName(String name) {
    return '$name (archived)';
  }

  @override
  String get ledgerCouldntStartNewLedger =>
      'Couldn’t start a new ledger · nothing was changed';

  @override
  String get ledgerNewLedgerStarted => 'New ledger started';

  @override
  String get ledgerEverythingErased =>
      'Everything erased · what you had is saved in Backups';

  @override
  String ledgerCouldntOpenLedger(String error) {
    return 'Couldn’t open the ledger: $error';
  }

  @override
  String get ledgerGroupAccounts => 'Accounts';

  @override
  String get ledgerGroupCashBank => 'Cash & bank';

  @override
  String get ledgerGroupBank => 'Bank';

  @override
  String get ledgerGroupCash => 'Cash';

  @override
  String get ledgerGroupCredit => 'Credit';

  @override
  String get ledgerSectionLedger => 'Ledger';

  @override
  String get ledgerSectionBudget => 'Budget';

  @override
  String get ledgerSectionSavings => 'Savings';

  @override
  String get ledgerNetWorth => 'Net worth';

  @override
  String ledgerInclArchived(String amount) {
    return 'incl. $amount in archived';
  }

  @override
  String ledgerLastCopiedElsewhere(int days) {
    return 'Last backup $days days ago';
  }

  @override
  String get ledgerNeverCopiedElsewhere => 'No backup yet';

  @override
  String get ledgerCopiedElsewhere => 'Backed up';

  @override
  String get ledgerCopiedElsewhereNever =>
      'Not yet · Back up to… saves a copy to another drive';

  @override
  String get ledgerDailyCopyFailing => 'The daily copy is failing';

  @override
  String get ledgerSettings => 'Settings';

  @override
  String get reportProblem => 'Report a problem…';

  @override
  String get reportProblemFailed =>
      'The browser didn’t open. The form is at lls.mn/en/contact.';

  @override
  String get detailsCopy => 'Copy';

  @override
  String get detailsCopied => 'Copied';

  @override
  String get recentProblemsTitle => 'Recent problems';

  @override
  String get recentProblemsNote =>
      'Kept on this computer only. To send them to us, choose Copy all, then paste them into the form that Report a problem… opens.';

  @override
  String get phoneRecentProblemsNote =>
      'Kept on this phone only. To send them to us, choose Copy all, then paste them into the form that Report a problem… opens.';

  @override
  String get recentProblemsCopyAll => 'Copy all';

  @override
  String recentProblemsMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count earlier problems are in Copy all.',
      one: '1 earlier problem is in Copy all.',
    );
    return '$_temp0';
  }

  @override
  String get phoneProblemFolderLost => 'Couldn’t find the folder chosen before';

  @override
  String get phoneProblemNotKept =>
      'Couldn’t save this phone’s entries on the phone. While the app is open, it tries again every half minute.';

  @override
  String get problemCouldntUndo => 'Couldn’t undo a change';

  @override
  String get problemCouldntRedo => 'Couldn’t redo a change';

  @override
  String get ledgerBackupsTitle => 'Backups';

  @override
  String get ledgerDailyCopy => 'Daily copy';

  @override
  String ledgerTimeAt(String day, String time) {
    return '$day $time';
  }

  @override
  String ledgerDailyCopyFailingSince(String when) {
    return 'Failing · the last one is from $when. Check the disk has room, and back up to another drive.';
  }

  @override
  String get ledgerDailyCopyFailingNone =>
      'Failing. Check the disk has room, and back up to another drive.';

  @override
  String get ledgerDailyCopyNone =>
      'None yet · one is made each day the app is open';

  @override
  String ledgerDailyCopyWhen(String when) {
    return '$when · on this computer';
  }

  @override
  String get ledgerKept => 'Kept';

  @override
  String get ledgerKeptWhich =>
      'The newest 14, plus the first of each month for a year';

  @override
  String get ledgerBackUpTo => 'Back up to…';

  @override
  String get ledgerRestoreFrom => 'Restore from…';

  @override
  String get ledgerBackupsNote =>
      'The daily copies are on this computer, so they won’t help if it’s lost or breaks: back up to another drive or a USB stick now and then. Restoring saves what you have first, and Undo brings it back.';

  @override
  String get ledgerSecurityTitle => 'Security';

  @override
  String get ledgerSecurityKeySaved =>
      'Your ledger and backups are encrypted. Your recovery key opens them on another computer, but only the copies you saved off this one (Back up to…) survive losing it. BetterBudget doesn’t keep a copy of the key.';

  @override
  String get ledgerSecurityKeyNotSaved =>
      'Your ledger and backups are encrypted. Your recovery key wasn’t saved or copied when it was shown, and BetterBudget doesn’t keep a copy: if this computer is lost, they can’t be opened.';

  @override
  String get ledgerCheckRecoveryKey => 'Check my recovery key…';

  @override
  String get ledgerStartOverTitle => 'Start over';

  @override
  String get ledgerStartOverNote =>
      'This erases every account and transaction in this ledger, so you start empty. You choose whether your categories stay. What you have now is saved in Backups first, and Undo brings it back.';

  @override
  String settingsVersion(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get settingsCredit =>
      'The Budget page was laid out with help from Cynthia G. Loveland.';

  @override
  String get ledgerEraseAndStartOverButton =>
      'Erase everything and start over…';

  @override
  String get ledgerRestoreTitle => 'Restore this backup?';

  @override
  String get ledgerBackupFrom => 'Backup from';

  @override
  String get ledgerItHolds => 'It holds';

  @override
  String get ledgerHereNow => 'Here now';

  @override
  String ledgerCounts(int transactions, int accounts) {
    String _temp0 = intl.Intl.pluralLogic(
      transactions,
      locale: localeName,
      other: '$transactions transactions',
      one: '1 transaction',
    );
    String _temp1 = intl.Intl.pluralLogic(
      accounts,
      locale: localeName,
      other: '$accounts accounts',
      one: '1 account',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get ledgerRestoreNote =>
      'Everything here is replaced by the backup. What you have now is saved first, and Undo brings it back.';

  @override
  String get ledgerCancel => 'Cancel';

  @override
  String get ledgerRestore => 'Restore';

  @override
  String ledgerOwed(String amount) {
    return '$amount owed';
  }

  @override
  String get ledgerYourPay => 'Your pay';

  @override
  String ledgerReconciles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reconciles',
      one: '1 reconcile',
    );
    return '$_temp0';
  }

  @override
  String get ledgerPayees => 'Payees';

  @override
  String get ledgerBudgetSavingsSettings => 'Budget and Savings settings';

  @override
  String ledgerMoreAccounts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more accounts',
      one: '1 more account',
    );
    return '+ $_temp0';
  }

  @override
  String ledgerTransactionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return '$_temp0';
  }

  @override
  String get ledgerEraseTitle => 'Erase everything and start over?';

  @override
  String get ledgerAllOfThisErased => 'All of this is erased:';

  @override
  String get ledgerStartWithNothing =>
      'You start with no accounts and no money in the app.';

  @override
  String ledgerYourCategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories',
      one: '1 category',
    );
    return 'Your $_temp0';
  }

  @override
  String get ledgerKeepThemEmpty => 'Keep them, empty';

  @override
  String get ledgerEraseThemToo => 'Erase them too';

  @override
  String get ledgerKeptNoRows =>
      'Kept with no rows in them, ready for your real accounts.';

  @override
  String get ledgerAddCategoriesAgain =>
      'You’ll add categories again on the Budget page.';

  @override
  String get ledgerEraseNote =>
      'What you have now is saved in Backups first. Undo brings it back, and so does Restore from… later.';

  @override
  String get ledgerEraseEverything => 'Erase everything';

  @override
  String get ledgerSearchHint => 'Search payee, memo, amount';

  @override
  String ledgerPeriodChip(String period, String start, String end) {
    return '$period · $start–$end';
  }

  @override
  String get ledgerDbReconciled =>
      'Reconciled · the date and amount match a bank statement';

  @override
  String get ledgerDbOwnAccount => 'It can’t move money to its own account';

  @override
  String get ledgerDbFutureConfirm => 'It can’t be confirmed on a future date';

  @override
  String get ledgerDbOpeningStays =>
      'An opening balance or adjustment stays put';

  @override
  String get ledgerDbAlreadyThere => 'It already moves money in that account';

  @override
  String get ledgerDbNotInAccount => 'Not in this account';

  @override
  String get ledgerDbNotAnAccount => 'Not an account';

  @override
  String get ledgerDbSplitNotEditable =>
      'Change a split’s categories in its own card';

  @override
  String get ledgerDbChangedSince => 'It was changed afterwards';

  @override
  String get ledgerDbStillHasRows => 'It still has rows; pick where they go';

  @override
  String get ledgerDbNotSingleCategory => 'Not a single-category transaction';

  @override
  String get ledgerDbPayIsIn => 'Pay is money in';

  @override
  String get ledgerDbNotCategory => 'Not a category';

  @override
  String get ledgerDbSameCategory => 'Same category';

  @override
  String get ledgerDbAccountDeleted => 'That account was deleted';

  @override
  String get ledgerDbNeverReconciled => 'Never reconciled';

  @override
  String planNotClearedYet(int count) {
    return '$count not cleared yet';
  }

  @override
  String get planWorking => 'Working';

  @override
  String get planOwed => 'Owed';

  @override
  String get planNeverReconciled => 'Never reconciled';

  @override
  String planLastReconciled(String date) {
    return 'Last reconciled on $date';
  }

  @override
  String get planReconcile => 'Reconcile';

  @override
  String planLateSeveral(String amount, int count) {
    return '+$amount in, $count not arrived';
  }

  @override
  String planLateToday(String amount) {
    return '+$amount in, due today';
  }

  @override
  String planLateDays(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days late',
      one: '1 day late',
    );
    return '+$amount in, $_temp0';
  }

  @override
  String get planLateNotCounted => ' · not counted';

  @override
  String get planNothingScheduled => 'Nothing scheduled';

  @override
  String planCreditAfter(String amount, String date) {
    return '$amount in credit after $date';
  }

  @override
  String planOwedAfterDate(String amount, String date) {
    return '$amount owed after $date';
  }

  @override
  String planCardCharges(int charges, String chargeTotal, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      charges,
      locale: localeName,
      other: '$charges charges',
      one: '1 charge',
    );
    return '$_temp0 · $chargeTotal through $date';
  }

  @override
  String planCardPayments(int payments, String paymentTotal, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      payments,
      locale: localeName,
      other: '$payments payments',
      one: '1 payment',
    );
    return '$_temp0 · $paymentTotal through $date';
  }

  @override
  String planCardChargesPayments(
    int charges,
    String chargeTotal,
    int payments,
    String paymentTotal,
    String date,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      charges,
      locale: localeName,
      other: '$charges charges',
      one: '1 charge',
    );
    String _temp1 = intl.Intl.pluralLogic(
      payments,
      locale: localeName,
      other: '$payments payments',
      one: '1 payment',
    );
    return '$_temp0 · $chargeTotal · $_temp1 · $paymentTotal through $date';
  }

  @override
  String get planCardNothing => 'No charges or payments in the next 30 days';

  @override
  String get planBelowZeroNow => 'Below zero now';

  @override
  String planBelowZeroShort(String amount) {
    return 'Below zero now · up to $amount short';
  }

  @override
  String planBelowZeroUnless(String amount) {
    return 'Below zero now unless $amount due today comes';
  }

  @override
  String planRunsOutUnless(String date, String amount) {
    return 'Runs out $date unless $amount due today comes';
  }

  @override
  String planRunsOut(String date, String amount) {
    return 'Runs out on $date · up to $amount short';
  }

  @override
  String planRunsOutBy(String date, String amount) {
    return 'Runs out on $date · $amount short';
  }

  @override
  String get planExpected => 'expected';

  @override
  String planOfThemExpected(int count) {
    return '$count of them expected';
  }

  @override
  String planPaidFromSeveral(int count) {
    return '$count accounts are checked, so this bill isn’t in any forecast. Leave one checked to see it there.';
  }

  @override
  String get planPaidFromNoneChecked =>
      'No account is checked, so this bill isn’t in any forecast.';

  @override
  String planRunsOutZero(String date) {
    return 'Runs out on $date';
  }

  @override
  String planShortAhead(String end, String date, String amount) {
    return 'After $end: runs out on $date · $amount short';
  }

  @override
  String planShortAheadZero(String end, String date) {
    return 'After $end: runs out on $date';
  }

  @override
  String planShortAheadTip(String date) {
    return 'Look as far as $date';
  }

  @override
  String planLowest(String amount, String date) {
    return 'Lowest $amount on $date';
  }

  @override
  String get planForecast => 'Forecast';

  @override
  String get planTodaysBalance => 'Today’s balance';

  @override
  String get planExpectedIncome => 'Expected income';

  @override
  String get planNothingBudgeted =>
      'Fill in your budget and the forecast appears here.';

  @override
  String planUntilPaycheck(String date) {
    return 'Until your $date paycheck';
  }

  @override
  String planLowestToday(String amount) {
    return 'Lowest $amount, today';
  }

  @override
  String planChartPay(String amount) {
    return '+$amount pay';
  }

  @override
  String planLowestAfterPay(String amount, String date) {
    return 'Lowest $amount on $date, after payday';
  }

  @override
  String get planNoBillsOrIncome => 'No bills or income in the next 30 days';

  @override
  String planNoBillsBefore(String date) {
    return 'No bills through $date';
  }

  @override
  String planInBefore(String amount, String date) {
    return '+$amount in through $date';
  }

  @override
  String planBillsBefore(int count, String amount, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bills',
      one: '1 bill',
    );
    return '$_temp0 · $amount through $date';
  }

  @override
  String planBillsBeforeIn(
    int count,
    String amount,
    String date,
    String inAmount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bills',
      one: '1 bill',
    );
    return '$_temp0 · $amount through $date · +$inAmount in';
  }

  @override
  String get planNext30Days => 'Next 30 days';

  @override
  String planNextDays(int count) {
    return 'Next $count days';
  }

  @override
  String get planNext6Months => 'Next 6 months';

  @override
  String get planNextYear => 'Next 12 months';

  @override
  String get planSpanTip => 'How far ahead the forecast looks';

  @override
  String get planAddPay => ' · no payday ahead · Add your pay →';

  @override
  String planUntilDate(String date) {
    return 'Through $date';
  }

  @override
  String get planBalanceAfter => 'Balance after';

  @override
  String get planOwedAfter => 'Owed after';

  @override
  String planTransferTo(String account) {
    return 'To $account';
  }

  @override
  String planTransferFrom(String account) {
    return 'From $account';
  }

  @override
  String planAtLeastEstimate(String category) {
    return '$category · at least, an estimate';
  }

  @override
  String get planBudget => 'Budget';

  @override
  String get planAddCategory => 'Add category';

  @override
  String get setupAddPayTip =>
      'Set up a paycheck: how much, how often, and the account it goes into';

  @override
  String planIncomeExpected(String received, String expected) {
    return '$received received of $expected expected this period';
  }

  @override
  String get planIncomeTab => 'Income';

  @override
  String planPayInto(String amounts, String account) {
    return '$amounts · into $account';
  }

  @override
  String planPayIntoNext(String amounts, String account, String date) {
    return '$amounts · into $account · next $date';
  }

  @override
  String get planSpending => 'Spending';

  @override
  String planShowArchived(int count) {
    return 'Show archived ($count)';
  }

  @override
  String planHideArchived(int count) {
    return 'Hide archived ($count)';
  }

  @override
  String get planShowInMenus => 'Show in menus';

  @override
  String get planPaydayNoRegular => 'No regular pay';

  @override
  String get planPaydayNotSetUp => 'Pay not set up';

  @override
  String planMorePay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count more pays',
      one: '+1 more pay',
    );
    return ' · $_temp0';
  }

  @override
  String get planRaiseSplit =>
      'Your last 6 pays were each more than 5% over the estimate · raise it?';

  @override
  String planRaiseLowest(String amount) {
    return 'Your lowest of the last 6 was $amount · raise the estimate?';
  }

  @override
  String planLastTwoLess(String amount) {
    return 'Your last 2 pays were $amount, less than planned · change the amount?';
  }

  @override
  String planLastTwoMore(String amount) {
    return 'Your last 2 pays were $amount · change the amount?';
  }

  @override
  String planPaydayPay(String pay) {
    return 'Pay: $pay';
  }

  @override
  String planPaydayPayNext(String pay, String date) {
    return 'Pay: $pay · next $date';
  }

  @override
  String get planNoRows => 'no rows';

  @override
  String planUsageRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$_temp0';
  }

  @override
  String planUsageRowsLast(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$_temp0 · last $date';
  }

  @override
  String planUsageScheduled(int count) {
    return '$count scheduled';
  }

  @override
  String get planShowTheseRows => 'Show these rows';

  @override
  String get planArchive => 'Archive';

  @override
  String get planDeleteMenu => 'Delete…';

  @override
  String get planCategoryName => 'Category name';

  @override
  String get planCancel => 'Cancel';

  @override
  String get planAdd => 'Add';

  @override
  String get planAddAnother => 'Add another';

  @override
  String planNewAdded(String names) {
    return 'Added: $names';
  }

  @override
  String get planEnterName => 'Enter a name';

  @override
  String planNameIsCategory(String name) {
    return '$name is already a category. Add opens it.';
  }

  @override
  String planNameIsCategoryInRow(String name) {
    return '$name is already a category. Add puts it in this row.';
  }

  @override
  String planNameArchived(String name) {
    return '$name is archived. Add brings it back.';
  }

  @override
  String planNameIsAccount(String name) {
    return 'An account is already called $name. Give the category another name.';
  }

  @override
  String get planNothingFiled => 'Nothing is filed under it yet.';

  @override
  String planRowsFiled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows are filed under it. They move to:',
      one: '1 row is filed under it. It moves to:',
    );
    return '$_temp0';
  }

  @override
  String planRowsFiledScheduled(int count, int scheduled) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count rows are filed under it, $scheduled of them scheduled. They move to:',
      one:
          '1 row is filed under it, $scheduled of them scheduled. It moves to:',
    );
    return '$_temp0';
  }

  @override
  String planIntoIncome(String name) {
    return '$name is income: money in these rows will count as income, and money out will take away from it.';
  }

  @override
  String planIntoIncomeScheduled(String name) {
    return '$name is income: money in these rows will count as income, money out will take away from it, and scheduled money in can end a forecast.';
  }

  @override
  String planMergeTitle(String name, String into) {
    return 'Merge $name into $into?';
  }

  @override
  String planDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get planNoOtherCategory =>
      'There’s no other category to move them to. Add one first.';

  @override
  String get planPickCategory => 'Pick a category';

  @override
  String planDeleteButton(String name) {
    return 'Delete $name';
  }

  @override
  String planMergeButton(String into) {
    return 'Merge into $into';
  }

  @override
  String planMoveAndDelete(String into) {
    return 'Move to $into and delete';
  }

  @override
  String get planSavings => 'Savings';

  @override
  String get planAllStepsDone => 'Every step is done';

  @override
  String get planOneStepAtATime => 'Getting prepared, one step at a time';

  @override
  String get planStepOneMonth => 'Build a safety net';

  @override
  String get planStepConsumerDebt => 'Eliminate debt';

  @override
  String get planStepMoreMonths => 'Build three to six months of savings';

  @override
  String get planStepFuture => 'Save for the future';

  @override
  String get planStepRetirement => 'Saving for retirement';

  @override
  String get planStepLongLoans => 'Paying off the mortgage';

  @override
  String get planNow => 'Now';

  @override
  String get planSetAside => 'Skipped for now';

  @override
  String get planSetAsideState => 'set aside';

  @override
  String planSetAsideUndo(String step) {
    return '“$step” skipped for now';
  }

  @override
  String planBackInStepsUndo(String step) {
    return '“$step” back in the steps';
  }

  @override
  String get planMonthUnknown =>
      'A month of your expenses isn’t known yet. It comes from your budget once you fill that in, or you can type it.';

  @override
  String planMonthNoSpending(int days) {
    return 'There’s no spending in the last $days days. Type what you spend in a month.';
  }

  @override
  String planMonthBudget(String amount) {
    return 'A month of expenses: $amount, from your budget';
  }

  @override
  String planMonthTyped(String amount) {
    return 'A month of expenses: $amount, as you typed it';
  }

  @override
  String planMonthAverage3(String amount, String loans) {
    String _temp0 = intl.Intl.selectLogic(loans, {
      'yes': ', loan payments included',
      'other': '',
    });
    return 'A month of expenses: $amount, the average of the last 3 months$_temp0';
  }

  @override
  String planMonthAverageDays(String amount, int days, String loans) {
    String _temp0 = intl.Intl.selectLogic(loans, {
      'yes': ', loan payments included',
      'other': '',
    });
    return 'A month of expenses: $amount, the average of the last $days days$_temp0';
  }

  @override
  String planFundOf(String fund, String target) {
    return '$fund of $target';
  }

  @override
  String planFundOfToGo(String fund, String target, String left) {
    return '$fund of $target · $left to go';
  }

  @override
  String planWhichAccount(String category) {
    return 'Your safety net is the $category category in your budget: money you assign to it and don’t spend. A separate savings account is the best place to keep it; until you have one, it can sit in the account you spend from.';
  }

  @override
  String get planFundCategoryName => 'Safety net';

  @override
  String planFundWhere(String there, String names, String move) {
    return '$there in $names · $move still to move there';
  }

  @override
  String planFundAllIn(String names) {
    return 'All of it is in $names';
  }

  @override
  String planFundSetPaidFrom(String category) {
    return 'Keeping it in a savings account? On the Budget page, open $category’s Edit and set Paid from to that account. This step then shows how much you’ve moved there.';
  }

  @override
  String planFundNotAssigned(String amount) {
    return '$amount in your budget isn’t assigned to a category yet.';
  }

  @override
  String get planSaved => 'Saved';

  @override
  String get planKeepReachable =>
      'Keep it where you can reach it. If you use it, fill it back up before anything else.';

  @override
  String planMinimumsOn(String names) {
    return 'Until it’s full, pay only the minimums on $names.';
  }

  @override
  String get planEnoughForJobLoss =>
      'Enough to get through losing a job or a long illness.';

  @override
  String get planRetirementYes => 'You’re putting money into it';

  @override
  String get planRetirementWhat =>
      'Are you putting money into a retirement plan, from your pay or on your own?';

  @override
  String get planEmployerMatch =>
      'If your employer matches what you put in, put in at least enough to get all of it.';

  @override
  String get planIAm => 'I am';

  @override
  String planAnswerYesUndo(String step) {
    return '$step: yes';
  }

  @override
  String planAnswerNotYetUndo(String step) {
    return '$step: not yet';
  }

  @override
  String get planNoCardsOwing => 'No credit cards or loans owing';

  @override
  String planAmountOwed(String amount) {
    return '$amount owed';
  }

  @override
  String get planPayExtraGuide =>
      'Pay the minimum on each, and everything extra on the first one in the list. When it’s paid off, put its payment toward the next.';

  @override
  String get planLongNone => 'You have none';

  @override
  String get planLongAsk => 'Do you have a mortgage?';

  @override
  String get planLongMarkThere =>
      'If a loan under Eliminate debt is the mortgage, mark it there.';

  @override
  String get planIHaveNone => 'I have none';

  @override
  String get planPayingExtraOnThem => 'I\'m paying extra on it';

  @override
  String get planNotYet => 'Not yet';

  @override
  String get planNoLongLoansUndo => 'No mortgage';

  @override
  String get planPayingExtraUndo => 'Paying extra on the mortgage';

  @override
  String get planLoansNotYetUndo => 'Mortgage: not paying extra yet';

  @override
  String get planNotPayingExtraUndo => 'Not paying extra on the mortgage';

  @override
  String get planPaidOff => 'Paid off';

  @override
  String planAmountLeft(String amount) {
    return '$amount left';
  }

  @override
  String get planPayingExtra => 'Paying extra';

  @override
  String planNamesAnd(String first, String last) {
    return '$first and $last';
  }

  @override
  String get planMonthBackToAverage => 'Your own month of expenses taken off';

  @override
  String planMonthSet(String amount) {
    return 'A month of expenses: $amount';
  }

  @override
  String get planTypeMonth => 'Type a month of expenses';

  @override
  String get planChangeMonth => 'Change the amount';

  @override
  String get planTypeOwnMonth => 'Type your own amount';

  @override
  String get planMonthHint => 'A month of expenses';

  @override
  String get planSave => 'Save';

  @override
  String get planEmptyToAverage =>
      'Clear the field to use your budget or your average spending';

  @override
  String planMonthsChoice(int count) {
    return '$count months';
  }

  @override
  String planAimingFor(int count) {
    return 'Aiming for $count months';
  }

  @override
  String get planRoleMortgage => 'Mortgage';

  @override
  String get planRolePaidMonthly => 'Paid in full every month';

  @override
  String get planRoleConsumer => 'Debt to pay off';

  @override
  String planCountsAsMortgage(String account) {
    return '$account counts as mortgage';
  }

  @override
  String planCountsAsPaidMonthly(String account) {
    return '$account counts as paid in full every month';
  }

  @override
  String planCountsAsConsumer(String account) {
    return '$account counts as debt to pay off';
  }

  @override
  String get planNothingOwed => 'nothing owed';

  @override
  String planPayingExtraOn(String account) {
    return 'Paying extra on $account';
  }

  @override
  String get planPayExtraOnThis => 'Pay extra on this one';

  @override
  String get planPayExtraHere => 'Pay extra here';

  @override
  String get planRateAdd => 'Add interest rate';

  @override
  String planRateMonthly(String rate) {
    return '$rate% a month';
  }

  @override
  String planRateYearly(String rate) {
    return '$rate% a year';
  }

  @override
  String get planRateTip =>
      'Step 2 uses this rate for the interest each debt costs a month, and for when it’s all paid off.';

  @override
  String get planRatePerMonth => 'a month';

  @override
  String get planRatePerYear => 'a year';

  @override
  String planInterestAMonth(String amount) {
    return 'about $amount a month in interest';
  }

  @override
  String planRateSet(String name, String rate) {
    return 'Interest rate for $name: $rate';
  }

  @override
  String planRateRemoved(String name) {
    return 'Interest rate for $name taken off';
  }

  @override
  String get planRateEmptyToRemove => 'Clear the field to take the rate off';

  @override
  String planRateLooksYearly(String rate, String year) {
    return '$rate% a month is $year% a year. If your bank’s $rate% is a year’s rate, pick a year.';
  }

  @override
  String planRateLooksMonthly(String rate, String month) {
    return '$rate% a year is $month% a month. If your bank’s $rate% is a month’s rate, pick a month.';
  }

  @override
  String get setupRate => 'Interest rate';

  @override
  String get setupRateHint =>
      'Step 2 of Savings uses it for the interest this debt costs a month, and for when it’s paid off.';

  @override
  String planCarried(String date) {
    return 'What it owed five weeks ago isn’t paid off: a balance has carried since $date. It’s left out of the debt to pay off only because it’s marked paid in full every month.';
  }

  @override
  String get planLooksPaidInFull =>
      'What it owed five weeks ago is paid off. If you pay it in full every month, mark it “Paid in full every month”.';

  @override
  String get planBringBack => 'Bring it back';

  @override
  String get planSetStepAside => 'Skip this step for now';

  @override
  String get rowsNothingScheduled => 'Nothing scheduled';

  @override
  String rowsNextOfScheduled(int count) {
    return 'next of $count scheduled';
  }

  @override
  String rowsMoreOverdue(int count) {
    return '$count more overdue';
  }

  @override
  String get rowsScheduledOnly => 'scheduled';

  @override
  String get rowsNoTransactions => 'No transactions';

  @override
  String rowsNothingMatches(String search) {
    return 'Nothing matches “$search”';
  }

  @override
  String rowsNotReconciledThrough(String date) {
    return 'Not reconciled, through $date';
  }

  @override
  String get rowsColumnDate => 'Date';

  @override
  String get rowsColumnPayee => 'Payee';

  @override
  String get rowsColumnCategory => 'Category';

  @override
  String get rowsColumnAmount => 'Amount';

  @override
  String get rowsColumnBalance => 'Balance';

  @override
  String get rowsColumnOwed => 'Owed';

  @override
  String get rowsColumnClearedBalance => 'Cleared balance';

  @override
  String get rowsColumnAccount => 'Account';

  @override
  String get rowsTabAll => 'All';

  @override
  String get rowsTabUncleared => 'Uncleared';

  @override
  String get rowsTabScheduled => 'Scheduled';

  @override
  String ledgerFiledUnder(Object category) {
    return 'Filed under $category';
  }

  @override
  String ledgerAlwaysFile(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remember this for next time, and file $count more rows now',
      one: 'Remember this for next time, and file 1 more row now',
      zero: 'Remember this for next time',
    );
    return '$_temp0';
  }

  @override
  String ledgerRememberedBefore(String category) {
    return 'it was $category before';
  }

  @override
  String ledgerAlwaysFiled(int count, Object category) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$category remembered for next time · $count more rows filed',
      one: '$category remembered for next time · 1 more row filed',
      zero: '$category remembered for next time',
    );
    return '$_temp0';
  }

  @override
  String rowsIncomeFrom(Object pay) {
    return 'Income · $pay';
  }

  @override
  String get rowsIncomePaycheck => 'Income · paycheck';

  @override
  String get rowsTabUncategorized => 'Not categorized';

  @override
  String get rowsEdit => 'Edit';

  @override
  String get rowsCategorize => 'Categorize';

  @override
  String get rowsMarkCleared => 'Mark cleared';

  @override
  String get rowsMarkUncleared => 'Mark uncleared';

  @override
  String get rowsMoveTo => 'Move to';

  @override
  String get rowsDelete => 'Delete';

  @override
  String get rowsReconciledLocked => 'Reconciled · date and amount locked';

  @override
  String rowsReconciledOnLocked(String date) {
    return 'Reconciled on $date · date and amount locked';
  }

  @override
  String get rowsUndoThisReconcile => 'Undo this reconcile';

  @override
  String rowsReconciledOnCanChange(String date) {
    return 'Reconciled on $date · its category, payee and memo can still change';
  }

  @override
  String rowsReconciledOnCanChangeTransfer(String date) {
    return 'Reconciled on $date · its payee and memo can still change';
  }

  @override
  String get rowsChangeLockedAmount => 'Change the amount…';

  @override
  String rowsTakesBackReconciles(int count, String dates) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Saving takes back $count reconciles: $dates. Then reconcile each statement again.',
      one:
          'Saving takes back the reconcile of $dates. Then reconcile that statement again.',
    );
    return '$_temp0';
  }

  @override
  String ledgerReconcilesTakenBack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reconciles taken back',
      one: '1 reconcile taken back',
    );
    return '$_temp0';
  }

  @override
  String rowsReconciledInLocked(String account) {
    return 'Reconciled in $account · date and amount locked';
  }

  @override
  String rowsStatusTip(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'uncleared': 'Uncleared — the bank hasn’t cleared it yet, even if it shows there as pending. Click once it clears.',
      'cleared': 'Cleared — the bank has cleared it. Click to mark uncleared.',
      'other': 'Reconciled — matches a statement, so its date and amount are locked.',
    });
    return '$_temp0';
  }

  @override
  String rowsStatusTipIn(String account, String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'uncleared':
          'In $account: Uncleared — the bank hasn’t cleared it yet, even if it shows there as pending. Click once it clears.',
      'cleared':
          'In $account: Cleared — the bank has cleared it. Click to mark uncleared.',
      'other':
          'In $account: Reconciled — matches a statement, so its date and amount are locked.',
    });
    return '$_temp0';
  }

  @override
  String get rowsTransferToBefore => 'To';

  @override
  String get rowsTransferToAfter => '';

  @override
  String get rowsTransferFromBefore => 'From';

  @override
  String get rowsTransferFromAfter => '';

  @override
  String rowsScheduledTransferTo(String account) {
    return 'To $account';
  }

  @override
  String rowsScheduledTransferFrom(String account) {
    return 'From $account';
  }

  @override
  String get rowsScheduledTip =>
      'Scheduled — not in any balance until confirmed';

  @override
  String get rowsConfirm => 'Confirm';

  @override
  String rowsNewCategoryOption(String name) {
    return '+ New category “$name”';
  }

  @override
  String rowsDidYouMeanTransfer(String account) {
    return 'Did you mean “→ $account”?';
  }

  @override
  String rowsNotACategoryPickOne(String typed, String first) {
    return '“$typed” isn’t a category · pick $first, or + New category';
  }

  @override
  String rowsNotACategoryPickTwo(String typed, String first, String second) {
    return '“$typed” isn’t a category · pick $first or $second, or + New category';
  }

  @override
  String get rowsNewCategoryNote => 'new category';

  @override
  String rowsTransferFromTo(String from, String to) {
    return 'From $from to $to';
  }

  @override
  String rowsTransferAmountFromTo(String amount, String from, String to) {
    return '$amount from $from to $to';
  }

  @override
  String get rowsErrorDate => 'Enter the date like 2026.09.16';

  @override
  String get rowsErrorSameAccount => 'Can’t transfer to the same account';

  @override
  String rowsErrorNoAccount(String name) {
    return 'No account “$name”';
  }

  @override
  String rowsErrorAmount(String typed) {
    return '“$typed” isn’t an amount';
  }

  @override
  String get rowsRemember => 'Remember this category for this payee';

  @override
  String get rowsSave => 'Save';

  @override
  String get rowsAdd => 'Add';

  @override
  String rowsSum(String sum) {
    return '= $sum';
  }

  @override
  String rowsSumWithNote(String sum, String note) {
    return '= $sum · $note';
  }

  @override
  String rowsNeeds(String field) {
    String _temp0 = intl.Intl.selectLogic(field, {
      'when': 'needs date',
      'account': 'needs account',
      'payee': 'needs payee',
      'category': 'needs category',
      'other': 'needs amount',
    });
    return '$_temp0';
  }

  @override
  String rowsEnterMissing(String field) {
    String _temp0 = intl.Intl.selectLogic(field, {
      'when': 'Enter a date',
      'account': 'Pick an account',
      'payee': 'Enter a payee',
      'category': 'Pick a category',
      'other': 'Enter an amount',
    });
    return '$_temp0';
  }

  @override
  String rowsNeedsMore(int count) {
    return 'needs $count more';
  }

  @override
  String get rowsCancelEdit => 'Cancel';

  @override
  String get rowsNewCategoryBlank => 'New category';

  @override
  String get rowsSplitOption => 'Split';

  @override
  String rowsSplitTitle(String payee, String amount) {
    return '$payee, $amount';
  }

  @override
  String rowsSplitLeft(String amount) {
    return '$amount left';
  }

  @override
  String rowsSplitTooMuch(String amount) {
    return '$amount too much';
  }

  @override
  String rowsSplitInAll(String amount) {
    return '$amount in all';
  }

  @override
  String get rowsSplitIsOut => 'The total is money out.';

  @override
  String get rowsSplitIsIn => 'The total is money in.';

  @override
  String get rowsSplitMakeIn => 'Change to money in';

  @override
  String get rowsSplitMakeOut => 'Change to money out';

  @override
  String get rowsSplitEven =>
      'The lines even out, so the account’s balance doesn’t change.';

  @override
  String get rowsSplitAnother => '+ Another category';

  @override
  String get rowsSplitRemove => 'Take this category off';

  @override
  String get rowsSplitDone => 'Done';

  @override
  String rowsErrorSplitLeft(String amount) {
    return 'Place the last $amount';
  }

  @override
  String rowsErrorSplitTooMuch(String amount) {
    return 'The lines are $amount more than the total';
  }

  @override
  String rowsErrorSplitNoCategory(String amount) {
    return 'Pick a category for $amount';
  }

  @override
  String rowsErrorSplitUnknown(String name) {
    return 'There’s no category “$name”';
  }

  @override
  String rowsErrorSplitTwice(String name) {
    return '“$name” is already on another line';
  }

  @override
  String get phoneSplitTitle => 'Split';

  @override
  String phoneSplitToPlace(String amount) {
    return '$amount to place';
  }

  @override
  String phoneDeleteCategoryWhole(int count, String name, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Delete $name and the $count entries that use it ($amount in all, other categories’ shares included)?',
      one:
          'Delete $name and the 1 entry that uses it ($amount in all, other categories’ shares included)?',
    );
    return '$_temp0';
  }

  @override
  String get phoneWaitingCategoryGone =>
      'A category in it was deleted on your computer. That part will come in as Not categorized.';

  @override
  String get phoneSplitReturned => 'Returned';

  @override
  String get phoneSplitSpent => 'Spent';

  @override
  String get phoneFixing => 'Changing an entry that’s waiting';

  @override
  String get phoneFixingTaken =>
      'Your computer has taken this entry in. Save will add it as a new one.';

  @override
  String get phoneSavedAsNew =>
      'Your computer had already taken in the first one, so this is saved as a new entry. Fix or delete the first one on your computer.';

  @override
  String get phoneOpenWaiting =>
      'Open this entry? What you’ve typed on the entry screen will be cleared.';

  @override
  String get phoneOpen => 'Open';

  @override
  String get ledgerDbSplitDoesntAddUp =>
      'The split’s lines don’t add up to its amount';

  @override
  String get rowsReconciledTip =>
      'Reconciled · this matches a bank statement, so it can’t change';

  @override
  String get rowsOpeningBalanceTip =>
      'An opening balance belongs to its account';

  @override
  String get rowsAdjustmentTip => 'An adjustment belongs to its account';

  @override
  String get rowsOtherAccountDeleted => 'The other account is deleted';

  @override
  String get rowsOtherAccountArchived => 'The other account is archived';

  @override
  String get rowsHintPayee => 'Payee';

  @override
  String get rowsHintNewPayee => 'New transaction — payee';

  @override
  String get rowsHintMemo => 'Memo';

  @override
  String get rowsHintCategory => 'Category';

  @override
  String get rowsHintDate => 'Date';

  @override
  String get rowsHintAccount => 'Account';

  @override
  String rowsLessThanPlanned(String amount) {
    return '$amount less than planned:';
  }

  @override
  String rowsStillOwedDue(String date) {
    return 'Still owed, due $date';
  }

  @override
  String get rowsPaidInFull => 'Paid in full';

  @override
  String get rowsTurnItAround => 'Turn it around';

  @override
  String get rowsSwap => 'Swap';

  @override
  String get rowsPreviousMonth => 'Previous month';

  @override
  String get rowsNextMonth => 'Next month';

  @override
  String get rowsWeekdayInitials => 'Mo|Tu|We|Th|Fr|Sa|Su';

  @override
  String get rowsAfterTodayScheduled => 'After today · it will be scheduled';

  @override
  String rowsOrPressKey(String key) {
    return 'Or press $key in any field';
  }

  @override
  String get rowsReconcileTitle => 'Reconcile';

  @override
  String get rowsStatementDate => 'Statement date';

  @override
  String get rowsBankSaysYouOwe => 'Bank says you owe';

  @override
  String get rowsBankBalance => 'Bank balance';

  @override
  String get rowsNotAvailableBalance => 'Not the “available” balance';

  @override
  String get rowsClearedHere => 'Cleared here';

  @override
  String get rowsOffBy => 'Off by';

  @override
  String get rowsMatches => 'Matches';

  @override
  String get rowsBankIsLower => 'Bank is lower';

  @override
  String get rowsBankIsHigher => 'Bank is higher';

  @override
  String get rowsBankSaysOweLess => 'Bank says you owe less';

  @override
  String get rowsBankSaysOweMore => 'Bank says you owe more';

  @override
  String get rowsHintClearRows => 'Clear the rows your bank shows';

  @override
  String rowsHintNotCleared(String payee, String date, String amount) {
    return '$payee on $date is $amount and isn’t cleared';
  }

  @override
  String rowsHintDatedAfter(String payee, String date, String amount) {
    return '$payee is $amount but dated $date, after the statement';
  }

  @override
  String rowsHintClearedEarly(String payee, String date, String amount) {
    return '$payee on $date is $amount and cleared here · not at the bank yet?';
  }

  @override
  String get rowsCancel => 'Cancel';

  @override
  String rowsAdjustUpAndLock(String amount) {
    return 'Add $amount to the balance and lock';
  }

  @override
  String rowsAdjustDownAndLock(String amount) {
    return 'Take $amount off the balance and lock';
  }

  @override
  String get rowsMarkReconciled => 'Mark reconciled';

  @override
  String rowsLockTransactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Lock $count transactions',
      one: 'Lock 1 transaction',
    );
    return '$_temp0';
  }

  @override
  String setupOwedStill(String amount) {
    return 'You still owe $amount on it.';
  }

  @override
  String setupInCredit(String amount) {
    return 'It’s $amount in credit: the bank owes you.';
  }

  @override
  String setupStillIn(String amount) {
    return '$amount is still in it.';
  }

  @override
  String setupOverdrawn(String amount) {
    return 'It’s $amount overdrawn.';
  }

  @override
  String get setupAddAccount => 'Add account';

  @override
  String get setupNewAccount => 'New account';

  @override
  String get setupName => 'Name';

  @override
  String get setupKind => 'Type';

  @override
  String get setupKindBank => 'Bank account';

  @override
  String get setupKindCash => 'Cash';

  @override
  String get setupKindCashHint =>
      'Cash you hold: a wallet, a tin at home. There’s no statement to check it against, so it’s yours to keep true — type what you spend.';

  @override
  String get setupKindOwed => 'Credit card or loan';

  @override
  String get setupKindOwedHint =>
      'A credit card, a loan or Storepay: shows what you owe, as a positive amount, the way the bank does.';

  @override
  String get setupKindBankHint => 'Checking or savings, at a bank.';

  @override
  String get setupCancel => 'Cancel';

  @override
  String get setupStartOwedToday => 'What do you owe on it today?';

  @override
  String get setupStartInToday => 'What’s in this account today?';

  @override
  String setupStartOwedOn(String date) {
    return 'What did you owe on it on $date?';
  }

  @override
  String setupStartInOn(String date) {
    return 'What was in it on $date?';
  }

  @override
  String get setupYouOwe => 'You owe';

  @override
  String get setupBalance => 'Balance';

  @override
  String get setupOn => 'On';

  @override
  String setupCantRead(String text) {
    return '“$text” isn’t an amount';
  }

  @override
  String setupDateShouldLook(String example) {
    return 'Enter the date like $example';
  }

  @override
  String setupStartOwedHint(Object zero) {
    return 'What you’ve used, not the available limit · empty starts at $zero';
  }

  @override
  String setupStartBankHint(Object zero) {
    return 'From the bank app, a statement or what you count, not the “available” balance · empty starts at $zero';
  }

  @override
  String get setupStartImport => 'Or import a file from your bank';

  @override
  String get setupStartAccount => 'Start account';

  @override
  String get setupRename => 'Rename';

  @override
  String get setupToBank => 'Change to bank account';

  @override
  String get setupToOwed => 'Change to credit card or loan';

  @override
  String get setupArchiveMenu => 'Archive…';

  @override
  String get setupDeleteMenu => 'Delete…';

  @override
  String get setupClickToRename => 'Click to rename';

  @override
  String setupArchiveBalance(String balance) {
    return '$balance It stays in net worth, but the account won’t be in the sidebar.';
  }

  @override
  String setupArchiveScheduled(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scheduled rows ($list) won’t show in any forecast.',
      one: '1 scheduled row ($list) won’t show in any forecast.',
    );
    return '$_temp0';
  }

  @override
  String setupArchiveTransfers(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count scheduled transfers stay on the other account’s forecast ($list). Delete them there if cancelled.',
      one:
          '1 scheduled transfer stays on the other account’s forecast ($list). Delete it there if cancelled.',
    );
    return '$_temp0';
  }

  @override
  String get setupDeleteNoRows =>
      'This deletes the account. It has no rows of its own.';

  @override
  String setupDeleteRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'This deletes the account and its $count rows.',
      one: 'This deletes the account and its 1 row.',
    );
    return '$_temp0';
  }

  @override
  String setupDeleteRowsReconciled(int count, int reconciled) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'This deletes the account and its $count rows, $reconciled of them reconciled.',
      one:
          'This deletes the account and its 1 row, $reconciled of them reconciled.',
    );
    return '$_temp0';
  }

  @override
  String setupWorthDown(String amount) {
    return 'Net worth goes down by $amount.';
  }

  @override
  String setupWorthUp(String amount) {
    return 'Net worth goes up by $amount.';
  }

  @override
  String setupWorthUpOwed(String amount) {
    return 'Net worth goes up by $amount, since what you owe on it is no longer counted.';
  }

  @override
  String setupDeletePending(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count are still scheduled ($list). Confirmed later, they move money from an account that no longer exists; delete them there if cancelled.',
      one:
          'One is still scheduled ($list). Confirmed later, it moves money from an account that no longer exists; delete it there if cancelled.',
    );
    return '$_temp0';
  }

  @override
  String setupKeptOne(int count, String other, String label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Its $count transfers with $other stay on $other as “$label”.',
      one: 'Its 1 transfer with $other stay on $other as “$label”.',
    );
    return '$_temp0';
  }

  @override
  String setupKeptMany(String label, String list) {
    return 'Its transfers stay on the other accounts as “$label”: $list.';
  }

  @override
  String setupKeptOn(int count, String account) {
    return '$count on $account';
  }

  @override
  String get setupArchived => 'Archived accounts';

  @override
  String setupAmountOwed(String amount) {
    return '$amount owed';
  }

  @override
  String get setupShowInSidebar => 'Show in sidebar';

  @override
  String get setupAllAccounts => 'All accounts';

  @override
  String get setupShowEveryRow => 'Show every row · Esc';

  @override
  String get setupAmountMissing => 'Type how much you’re paid';

  @override
  String setupAmountMissingOn(String day) {
    return 'Type how much you’re paid on the $day';
  }

  @override
  String get setupAmountMissingFirst =>
      'Type how much you’re paid on the first payday';

  @override
  String get setupAmountMissingSecond =>
      'Type how much you’re paid on the second payday';

  @override
  String setupOnDay(String day) {
    return 'On the $day';
  }

  @override
  String setupAtLeastOnDay(String day) {
    return 'At least, on the $day';
  }

  @override
  String get setupOnFirst => 'On the first payday';

  @override
  String get setupOnSecond => 'On the second payday';

  @override
  String get setupAtLeastOnFirst => 'At least, on the first payday';

  @override
  String get setupAtLeastOnSecond => 'At least, on the second payday';

  @override
  String get setupWhichDay => 'Which day of the month?';

  @override
  String get setupWhichTwoDays => 'Which two days of the month?';

  @override
  String get setupTwoDifferentDays => 'Two different days of the month';

  @override
  String get setupHowManyWeeks => 'Every how many weeks?';

  @override
  String setupWhenPayday(String example) {
    return 'When is a payday? ($example)';
  }

  @override
  String get setupAddYourPay => 'Add your pay';

  @override
  String get setupYourPay => 'Your pay';

  @override
  String get setupPaidInto => 'Paid into';

  @override
  String get setupFrom => 'From';

  @override
  String get setupEmployerHint => 'Employer (optional)';

  @override
  String get setupNameHint => 'Jenny, or Jeff’s job (optional)';

  @override
  String get setupPayIs => 'Pay is';

  @override
  String get setupPaySame => 'About the same each time';

  @override
  String get setupPayVaries => 'It varies';

  @override
  String get setupVariesHint =>
      'Hourly, shifts, overtime: it changes each time. Leave bonuses out; they aren’t every payday.';

  @override
  String get setupExpectAtLeast => 'Expect at least';

  @override
  String get setupEachPayday => 'Each payday';

  @override
  String get setupSameEachPaycheck => 'The same each paycheck';

  @override
  String get setupDifferentEachPaycheck => 'A different amount each paycheck';

  @override
  String setupLastPaycheck(String amount) {
    return 'Your last paycheck: $amount';
  }

  @override
  String setupLastPaychecks(int count, String lowest, String highest) {
    return 'Your last $count: lowest $lowest · highest $highest';
  }

  @override
  String get setupLowEndSafer =>
      'The forecast counts on this, so the low end is safer: finding more on payday is better than finding less.';

  @override
  String setupHigherThan(int above, int count) {
    return 'Higher than $above of your last $count paychecks: the forecast may look better than it’ll be.';
  }

  @override
  String get setupWhen => 'When';

  @override
  String get setupMonthly => 'Monthly';

  @override
  String get setupTwiceMonthly => 'Twice a month';

  @override
  String get setupEveryFewWeeks => 'Every few weeks';

  @override
  String setupOnDayField(String field) {
    return 'On the $field';
  }

  @override
  String setupOnDaysField(String first, String second) {
    return 'On the $first  and the $second';
  }

  @override
  String setupEveryWeeksField(int count, String weeks, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $weeks weeks, from $date',
      one: 'Every $weeks week, from $date',
    );
    return '$_temp0';
  }

  @override
  String get setupDaysMeet =>
      'In shorter months both days land on the last day: one payday that month, not two.';

  @override
  String get setupOnWeekend => 'On a weekend';

  @override
  String get setupFridayBefore => 'Friday before';

  @override
  String get setupMondayAfter => 'Monday after';

  @override
  String get setupKeepTheDay => 'Keep the day';

  @override
  String get setupMonth => 'Month';

  @override
  String setupPaydaysAYear(int count) {
    return '$count paydays a year: two months a year have three.';
  }

  @override
  String setupNextPayday(String date, String amount) {
    return 'Next payday $date · $amount';
  }

  @override
  String setupNextPaydayOrMore(String date, String amount) {
    return 'Next payday $date · $amount or more';
  }

  @override
  String setupNextPaydayMonthly(String date, String amount, String perMonth) {
    return 'Next payday $date · $amount · about $perMonth a month';
  }

  @override
  String setupNextPaydayOrMoreMonthly(
    String date,
    String amount,
    String perMonth,
  ) {
    return 'Next payday $date · $amount or more · about $perMonth a month';
  }

  @override
  String get setupNoRegularPay => 'I don’t have regular pay';

  @override
  String get setupStopPay => 'Stop scheduling pay';

  @override
  String get stopPayTitle => 'Stop this pay?';

  @override
  String stopPayPerIt(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories are budgeted per this pay: $names',
      one: '1 category is budgeted per this pay: $names',
    );
    return '$_temp0';
  }

  @override
  String get stopPayFromNow => 'From now, budget them';

  @override
  String stopPayBillsMonthly(String names) {
    return 'A bill every payday comes every month from its next payday: $names.';
  }

  @override
  String get setupSavePay => 'Save pay';

  @override
  String setupNameArchived(String name) {
    return '$name (archived · no paydays until it’s back)';
  }

  @override
  String setupCategoryInto(String category, String account) {
    return '$category into $account';
  }

  @override
  String get setupPay => 'Pay';

  @override
  String setupPayLine(String category, String amounts, String account) {
    return '$category · $amounts · into $account';
  }

  @override
  String get setupEdit => 'Edit';

  @override
  String get setupSaidNoPay =>
      'You said you don’t have regular pay, so the forecast doesn’t ask for it.';

  @override
  String get setupAskAgain => 'Ask me again';

  @override
  String get setupAddOtherPay => 'Add other pay';

  @override
  String get startKeyFileName => 'BetterBudget recovery key.txt';

  @override
  String get startSave => 'Save';

  @override
  String startKeyFileText(String key, String date) {
    return 'BetterBudget recovery key\n\n$key\n\nMade $date.\n\nIt opens your BetterBudget ledger and its backups on another computer, or on a phone that records spending. BetterBudget doesn’t keep a copy, and it can’t be replaced: without it, the ledger can’t be opened anywhere else.\n\nKeep it somewhere safe, away from this computer, where the other person who manages the money can find it. Don’t keep this file in the same folder as your backups.\n';
  }

  @override
  String get startKeyTitle => 'Your recovery key';

  @override
  String get startKeyIntro =>
      'BetterBudget encrypts your ledger and its backups. This key opens them on another computer, and on each phone that records spending. This is the only time it’s shown: BetterBudget doesn’t keep a copy, and it can’t be replaced.';

  @override
  String get startKeyWhere =>
      'Keep it away from this computer, where the other person who manages the money can find it: printed with your important papers, or on another drive.';

  @override
  String get startSaveEllipsis => 'Save…';

  @override
  String get startSaved => 'Saved';

  @override
  String get startCopy => 'Copy';

  @override
  String get startCopied => 'Copied';

  @override
  String get startOldCopies =>
      'Copies you saved elsewhere with Back up to… before today aren’t encrypted. Replace them with a new Back up to….';

  @override
  String get startCopiedWarning =>
      'Copied · paste it somewhere off this computer before you continue. The clipboard is cleared in a minute.';

  @override
  String get startNotKeptWarning =>
      'If you continue without saving or copying it, it’s gone: BetterBudget can’t show it again, and if this computer is lost, your ledger and its backups can’t be opened.';

  @override
  String get startContinue => 'Continue';

  @override
  String get startEnterTitle => 'Enter your recovery key';

  @override
  String get startNewLedgerInstead => 'Start a new ledger instead…';

  @override
  String get startSetAsideTitle => 'Start a new ledger?';

  @override
  String startSetAsideBodyNamed(String name) {
    return 'The ledger already on this computer can only be opened with its own recovery key. It won’t be deleted: it’s moved aside as $name, in BetterBudget’s folder, so you can open it later if you find its key.';
  }

  @override
  String get startSetAsideBody =>
      'The ledger already on this computer can only be opened with its own recovery key. It won’t be deleted: it’s moved aside, in BetterBudget’s folder, so you can open it later if you find its key.';

  @override
  String get startCancel => 'Cancel';

  @override
  String get startSetAsideConfirm => 'Move it aside and start new';

  @override
  String get startCheckTitle => 'Check your recovery key';

  @override
  String get startCheckBody =>
      'Type the key you saved. BetterBudget checks whether it opens this ledger. It never shows the key.';

  @override
  String get startCheckAction => 'Check';

  @override
  String get startCheckNo => 'No · this key doesn’t open this ledger';

  @override
  String get startCheckYes => 'Yes · this key opens this ledger';

  @override
  String get startBackupKeyTitle => 'This backup has its own key';

  @override
  String get startBackupKeyBody =>
      'It isn’t encrypted with this ledger’s key. It may be from another ledger: type that ledger’s recovery key to restore it. Your own key doesn’t change.';

  @override
  String get startBackupKeyAction => 'Open backup';

  @override
  String get startClose => 'Close';

  @override
  String get startKeyCyrillic =>
      'Your keyboard is typing Cyrillic · switch to ABC to type the key';

  @override
  String startKeyLength(int typed, int total) {
    return '$typed of $total characters';
  }

  @override
  String get startKeyChecksum =>
      'A character is wrong · check the key against your copy';

  @override
  String get startEntryKeptKeyWrong =>
      'The key kept on this computer doesn’t open the ledger here. Type the ledger’s recovery key to open it.';

  @override
  String get startEntryLedgerHere =>
      'There’s a ledger on this computer. Type its recovery key to open it.';

  @override
  String get startEntryLedgerHereEveryLaunch =>
      'This computer has no keychain BetterBudget can use, so it asks for your recovery key each time it opens. There’s a ledger on this computer. Type its recovery key to open it.';

  @override
  String get startKeyWrongHere =>
      'That key doesn’t open the ledger on this computer';

  @override
  String startCouldntKeepKey(String error) {
    return 'Couldn’t keep the key on this computer · $error';
  }

  @override
  String get startCouldntKeepKeyNothingEncrypted =>
      'Couldn’t keep the key on this computer';

  @override
  String get startNothingEncrypted => 'Nothing was encrypted.';

  @override
  String get startCouldntOpen => 'Couldn’t open your ledger';

  @override
  String get startCouldntReadKey =>
      'Couldn’t read the key kept on this computer';

  @override
  String get startLedgerNotTouched => 'Your ledger hasn’t been touched.';

  @override
  String get startTryAgain => 'Try again';

  @override
  String get startShowDetails => 'Show details';

  @override
  String startCopiesFailed(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count old copies couldn’t be encrypted and are still readable: $names',
      one: '1 old copy couldn’t be encrypted and is still readable: $names',
    );
    return '$_temp0';
  }

  @override
  String startCopiesEncrypted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encrypted $count old copies of your ledger',
      one: 'Encrypted 1 old copy of your ledger',
    );
    return '$_temp0';
  }

  @override
  String startEncryptedCopyFailed(String name) {
    return 'The encrypted copy of $name didn’t check out';
  }

  @override
  String get startRestoreNothingInto => 'Nothing to restore into';

  @override
  String get startRestoreNewer =>
      'That backup is from a newer BetterBudget · update the app first';

  @override
  String get startRestoreNotABackup => 'That file isn’t a BetterBudget backup';

  @override
  String get startRestoreNeedsKey =>
      'That backup can’t be opened with this ledger’s key · it may be from another ledger, or damaged';

  @override
  String get startRestoreWrongKey =>
      'That key doesn’t open this backup · it may be from another ledger, or damaged';

  @override
  String get startRestoreDamaged => 'That backup is damaged';

  @override
  String get startRestoreNoAccounts => 'That backup has no accounts in it';

  @override
  String get startUncleared => 'Uncleared';

  @override
  String get startCleared => 'Cleared';

  @override
  String get startReconciled => 'Reconciled';

  @override
  String get startOpeningBalance => 'Opening balance';

  @override
  String get startOpeningBalances => 'Opening balance';

  @override
  String get startBalanceAdjustments => 'Balance adjustments';

  @override
  String get startReconcileAdjustment => 'Reconcile adjustment';

  @override
  String get startTransfer => 'Transfer';

  @override
  String startSplitCategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories',
      one: '1 category',
    );
    return '$_temp0';
  }

  @override
  String startDeletedAccount(String name) {
    return '$name (deleted)';
  }

  @override
  String startStaleNote(int days) {
    return 'not cleared for $days days';
  }

  @override
  String startNotOnStatement(String date) {
    return 'not on the $date statement';
  }

  @override
  String get startDueYesterday => 'due yesterday';

  @override
  String startDueDaysAgo(int days) {
    return 'due $days days ago';
  }

  @override
  String startDayOn(String ordinal, int day, String isTwo) {
    return '$ordinal';
  }

  @override
  String startPayMonthly(String day) {
    return 'monthly on the $day';
  }

  @override
  String startPayTwiceMonthly(String first, String second, int firstDay) {
    return 'on the $first and $second';
  }

  @override
  String get startPayEveryWeek => 'every week';

  @override
  String startPayEveryWeeks(int weeks) {
    return 'every $weeks weeks';
  }

  @override
  String startPayAmountWhen(String amount, String when) {
    return '$amount $when';
  }

  @override
  String startPayAmountOrMoreWhen(String amount, String when) {
    return '$amount or more $when';
  }

  @override
  String startPayAmountDotWhen(String amount, String when) {
    return '$amount · $when';
  }

  @override
  String startPayAmountOrMoreDotWhen(String amount, String when) {
    return '$amount or more · $when';
  }

  @override
  String startPaySplit(
    String first,
    String firstDay,
    String second,
    String secondDay,
  ) {
    return '$first on the $firstDay and $second on the $secondDay';
  }

  @override
  String startPaySplitAtLeast(
    String first,
    String firstDay,
    String second,
    String secondDay,
  ) {
    return 'at least $first on the $firstDay and $second on the $secondDay';
  }

  @override
  String get startThisPayPeriod => 'This pay period';

  @override
  String get startThisMonth => 'This month';

  @override
  String get importButton => 'Import…';

  @override
  String importTitle(Object account) {
    return 'Import into $account';
  }

  @override
  String get importExcelFiles => 'Excel files';

  @override
  String get importTextFiles => 'Text files (CSV)';

  @override
  String get importOfxFiles => 'Bank downloads (OFX, QFX, QBO)';

  @override
  String importCouldntRead(Object file) {
    return 'Couldn’t read $file. BetterBudget reads Excel (.xls, .xlsx), CSV and OFX files.';
  }

  @override
  String importCouldntReadDamaged(Object file) {
    return 'Couldn’t read $file. The file may be damaged; download it from your bank again.';
  }

  @override
  String importNoDates(Object file) {
    return '$file has no rows with a date in them.';
  }

  @override
  String get importSavedColumns =>
      'Read with the columns you set for this account last time.';

  @override
  String get importChangeColumns => 'Change columns';

  @override
  String get importColumnsHint =>
      'Choose what each column holds. The app filled in its best guess; check the date and the amount.';

  @override
  String get importRoleIgnore => 'Not used';

  @override
  String get importRoleDate => 'Date';

  @override
  String get importRoleAmount => 'Amount (+ in, − out)';

  @override
  String get importRoleIn => 'Money in';

  @override
  String get importRoleOut => 'Money out';

  @override
  String get importRolePayee => 'Payee';

  @override
  String get importRoleMemo => 'Memo';

  @override
  String get importRoleBalance => 'Bank’s balance';

  @override
  String get importNeedDateAmount =>
      'Choose the date column and the amount (or money in and money out).';

  @override
  String get importDateOrder => 'Dates in this file:';

  @override
  String importDayFirst(Object date) {
    return 'Day first: $date';
  }

  @override
  String importMonthFirst(Object date) {
    return 'Month first: $date';
  }

  @override
  String get importSignLabel => 'In the amount column:';

  @override
  String get importMinusOut => 'minus is money out';

  @override
  String get importPlusOut => 'plus is money out';

  @override
  String importCountNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new rows',
      one: '1 new row',
    );
    return '$_temp0';
  }

  @override
  String importCountMatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count match rows you typed, which become cleared',
      one: '1 matches a row you typed, which becomes cleared',
    );
    return '$_temp0';
  }

  @override
  String importCountAlready(int count) {
    return '$count already in the ledger';
  }

  @override
  String importBalanceOk(Object opening, Object closing) {
    return 'The bank’s running balance adds up on every row, $opening to $closing.';
  }

  @override
  String importBalanceOff(int row, Object found, Object expected) {
    return 'Row $row of the file: the bank’s balance is $found, but the amounts before it come to $expected. A column may be set wrong. You can still import.';
  }

  @override
  String importBalanceOffCount(int count) {
    return '$count rows don’t add up in all.';
  }

  @override
  String importClearedMatches(Object amount) {
    return 'After this, the cleared balance matches the bank: $amount.';
  }

  @override
  String importClearedDiffers(Object ours, Object bank, Object diff) {
    return 'After this, the cleared balance is $ours; the bank’s file ends at $bank, $diff apart. Rows from before this file, or ones not cleared, can make the difference.';
  }

  @override
  String importClearedMatchesOn(Object amount, Object date) {
    return 'After this, the cleared balance matches the bank’s on $date: $amount.';
  }

  @override
  String importClearedDiffersOn(
    Object ours,
    Object bank,
    Object date,
    Object diff,
  ) {
    return 'After this, the cleared balance is $ours; the bank’s was $bank on $date, $diff apart. Rows after that day, rows from before this file, or ones not cleared, can make the difference.';
  }

  @override
  String get importFateRepeat => 'Already in · same day and amount';

  @override
  String importRepeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count rows have the day and amount of rows already imported from another kind of file, so they’re left out. Click a row’s tag to bring it in.',
      one: '1 row has the day and amount of a row already imported from another kind of file, so it’s left out. Click its tag to bring it in.',
    );
    return '$_temp0';
  }

  @override
  String importStartsEnds(Object start, Object from, Object end, Object to) {
    return 'This file starts at $start on $from and ends at $end on $to. The account starts from it.';
  }

  @override
  String importStartsEndsOwed(
    Object start,
    Object from,
    Object end,
    Object to,
  ) {
    return 'This file starts with $start owed on $from and ends with $end owed on $to. The account starts from it.';
  }

  @override
  String get importStartFrom => 'Start from';

  @override
  String get importWholeFile => 'The whole file';

  @override
  String importEarlierLeftOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count earlier rows in this file are left out',
      one: '1 earlier row in this file is left out',
    );
    return '$_temp0';
  }

  @override
  String importStartsOn(Object from, Object start, Object end, Object to) {
    return 'The account starts on $from at $start. The file ends at $end on $to.';
  }

  @override
  String importStartsOnOwed(Object from, Object start, Object end, Object to) {
    return 'The account starts on $from with $start owed. The file ends with $end owed on $to.';
  }

  @override
  String importNoBalance(Object question) {
    return 'This file doesn’t give a balance. $question';
  }

  @override
  String importNoBalanceHint(Object zero) {
    return 'Empty starts the account at $zero before the file’s first row';
  }

  @override
  String get importFateNew => 'New';

  @override
  String importFateMatch(Object payee, Object date) {
    return 'Matches $payee, $date';
  }

  @override
  String get importFateAlready => 'Already in';

  @override
  String importDo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $count rows',
      one: 'Import 1 row',
    );
    return '$_temp0';
  }

  @override
  String get importNothingNew => 'Nothing new in this file';

  @override
  String get importCancel => 'Cancel';

  @override
  String importDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count rows',
      one: 'Imported 1 row',
    );
    return '$_temp0';
  }

  @override
  String importMatchedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count typed rows now cleared',
      one: '1 typed row now cleared',
    );
    return '$_temp0';
  }

  @override
  String importUncategorizedToast(int count, Object name) {
    return '$count in “$name”';
  }

  @override
  String get importUncategorized => 'Not categorized';

  @override
  String get importCouldntImportRows => 'Couldn’t import those rows';

  @override
  String importCouldntImport(Object problem) {
    return 'Couldn’t import: $problem';
  }

  @override
  String importDoClear(int count, int cleared) {
    return 'Import $count rows · clear $cleared';
  }

  @override
  String importDoOnlyClear(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Clear $count typed rows',
      one: 'Clear 1 typed row',
    );
    return '$_temp0';
  }

  @override
  String importCountNoDate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines without a date (headings, totals) left out',
      one: '1 line without a date (a heading or total) left out',
    );
    return '$_temp0';
  }

  @override
  String importNoAmountRows(int count, Object rows) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Rows $rows of the file have a date but no amount this can read, so they’re left out.',
      one:
          'Row $rows of the file has a date but no amount this can read, so it’s left out.',
    );
    return '$_temp0';
  }

  @override
  String importCountLeftOut(int count) {
    return '$count left out by you';
  }

  @override
  String get importTagHint =>
      'Click a row’s New or Matches to add it as its own row or leave it out.';

  @override
  String importFateMatchDate(Object date) {
    return 'Matches your row of $date';
  }

  @override
  String get importFateLeftOut => 'Left out';

  @override
  String importOverlap(Object from, Object to, int count) {
    return 'The new rows fall between $from and $to, where this account already has $count imported rows. If this file repeats an earlier one in another form, they’re duplicates.';
  }

  @override
  String get importLeaveNewOut => 'Leave the new rows out';

  @override
  String importMaybeSame(
    String payee,
    String typed,
    String typedDate,
    String bank,
    String bankDate,
  ) {
    return 'You typed $payee $typed on $typedDate. The bank has $bank on $bankDate.';
  }

  @override
  String importSamePurchase(String amount) {
    return 'Same purchase: take the bank’s $amount';
  }

  @override
  String importFateTakesAmount(String amount) {
    return 'takes $amount';
  }

  @override
  String importUnmatched(int count, Object from, Object to, Object list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count rows you typed between $from and $to aren’t in this file: $list. They stay not cleared.',
      one:
          '1 row you typed between $from and $to isn’t in this file: $list. It stays not cleared.',
    );
    return '$_temp0';
  }

  @override
  String importUnmatchedItem(Object payee, Object amount, Object date) {
    return '$payee $amount on $date';
  }

  @override
  String importUnmatchedMore(int count) {
    return '$count more';
  }

  @override
  String rowsLeftOther(Object account) {
    return 'Sent from $account:';
  }

  @override
  String rowsArrivesOther(Object account) {
    return 'Arrives in $account:';
  }

  @override
  String rowsErrorLeftOther(Object account) {
    return 'Enter the amount sent from $account';
  }

  @override
  String rowsErrorArrivesOther(Object account) {
    return 'Enter the amount arriving in $account';
  }

  @override
  String rowsRatePer(String rate, String one) {
    return '$rate per $one';
  }

  @override
  String get ledgerDbOtherCurrency => 'That account is in another currency';

  @override
  String get ledgerDbNeedsOtherAmount =>
      'Accounts in two currencies need a transfer with both amounts';

  @override
  String get setupCurrency => 'Currency';

  @override
  String get setupCurrencyHint =>
      'Every amount in this account is in it, and it can’t be changed later yet. Net worth shows each currency on its own line.';

  @override
  String rowsExchangeNote(
    Object account,
    Object amount,
    Object rate,
    String one,
  ) {
    return '$account: $amount · $rate per $one';
  }

  @override
  String savingsOtherHeld(String account, String amount) {
    return '$account $amount';
  }

  @override
  String savingsOtherOwed(String account, String amount) {
    return '$account $amount owed';
  }

  @override
  String savingsOnlyOne(String accounts, String currency) {
    return 'Not counted here yet: $accounts. Savings counts one currency for now: $currency.';
  }

  @override
  String importFileIn(
    String fileCurrency,
    String account,
    String accountCurrency,
    String example,
    String asIs,
  ) {
    return 'This file looks like it’s in $fileCurrency, and $account is in $accountCurrency. Amounts come in as they are: $example would become $asIs.';
  }

  @override
  String get ledgerNewerLedger =>
      'it was saved by a newer version of BetterBudget. Open it with that version; nothing here was changed.';

  @override
  String importBeforeOpening(int count, Object amount, Object date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count rows are dated on or before this account’s opening balance ($amount on $date), which already counts them.',
      one:
          '1 row is dated on or before this account’s opening balance ($amount on $date), which already counts it.',
    );
    return '$_temp0';
  }

  @override
  String importBeforeOpeningLocked(int count, Object amount, Object date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count rows are dated on or before this account’s opening balance ($amount on $date), which already counts them. The opening balance is reconciled, so it stays; imported, they count twice.',
      one:
          '1 row is dated on or before this account’s opening balance ($amount on $date), which already counts it. The opening balance is reconciled, so it stays; imported, the row counts twice.',
    );
    return '$_temp0';
  }

  @override
  String importMoveOpening(Object date, Object amount) {
    return 'Move the opening balance to $date at $amount';
  }

  @override
  String get importKeepOpening => 'Leave it (those rows count twice)';

  @override
  String get importLeaveBeforeOut => 'Leave those rows out';

  @override
  String importFateRedated(Object date) {
    return 'dated $date, the bank’s';
  }

  @override
  String importOpeningMovedToast(Object date, Object amount) {
    return 'opening balance now $amount on $date';
  }

  @override
  String get planAssigned => 'Assigned';

  @override
  String get planSpent => 'Spent';

  @override
  String get planLeft => 'Left';

  @override
  String planFromBefore(String amount) {
    return '$amount from before';
  }

  @override
  String get planPayPeriod => 'Pay period';

  @override
  String get planViewMonth => 'Month';

  @override
  String get planViewTip => 'View by month, or by one pay’s periods';

  @override
  String planPeriodTitle(String name, String start, String end) {
    return '$name · $start–$end';
  }

  @override
  String get planPeriodPrev => 'Previous period';

  @override
  String get planPeriodNext => 'Next period';

  @override
  String get planBackToToday => 'Back to today';

  @override
  String get planAssignTip =>
      'Click to type how much to assign · Tab for the next';

  @override
  String planAssignUndo(String amount, String category) {
    return 'Assign $amount to $category';
  }

  @override
  String planShowAllRows(String usage) {
    return '$usage · show them';
  }

  @override
  String planStartOffer(String amount, String count) {
    return '$amount was spent in $count categories before anything was assigned. It counts against them this period.';
  }

  @override
  String planStartLater(String date) {
    return 'Start the budget on $date instead';
  }

  @override
  String get planStartKeep => 'Keep it as it is';

  @override
  String planStartLaterUndo(String date) {
    return 'Start the budget on $date';
  }

  @override
  String planMoneyBack(String amount, String category) {
    return '$amount assigned to $category goes back to not assigned';
  }

  @override
  String get setupLoanPaidFrom => 'Payments come out of';

  @override
  String get setupLoanNoCategory => 'No category';

  @override
  String setupLoanPaidFromUndo(String loan, String category) {
    return '$loan paid from $category';
  }

  @override
  String setupLoanNoCategoryUndo(String loan) {
    return '$loan paid from no category';
  }

  @override
  String get appearanceColorsTitle => 'Colors';

  @override
  String appearanceColorsUndoLabel(String name) {
    return 'Colors: $name';
  }

  @override
  String get schemeBetterBudget => 'BetterBudget';

  @override
  String get schemeGroupMonochromatic => 'Monochromatic';

  @override
  String get schemeGroupRomantic => 'Romantic';

  @override
  String get schemeGroupPlayful => 'Playful';

  @override
  String get schemeGroupVibrant => 'Vibrant';

  @override
  String get schemeGroupNeutral => 'Neutral';

  @override
  String get schemeGroupTranquil => 'Tranquil';

  @override
  String get schemeGroupSeasonal => 'Seasonal';

  @override
  String get schemeStormyMorning => 'Stormy morning';

  @override
  String get schemeMossyHollow => 'Mossy hollow';

  @override
  String get schemeBlueEclipse => 'Blue eclipse';

  @override
  String get schemeLushForest => 'Lush forest';

  @override
  String get schemeGreenJuice => 'Green juice';

  @override
  String get schemeChiliSpice => 'Chili spice';

  @override
  String get schemeChocolateTruffle => 'Chocolate truffle';

  @override
  String get schemeInkWash => 'Ink wash';

  @override
  String get schemeGoldenTaupe => 'Golden taupe';

  @override
  String get schemeWisteriaBloom => 'Wisteria bloom';

  @override
  String get schemeBurntSienna => 'Burnt sienna';

  @override
  String get schemeBloomingRomance => 'Blooming romance';

  @override
  String get schemeDesertDusk => 'Desert dusk';

  @override
  String get schemeLavenderFields => 'Lavender fields';

  @override
  String get schemeHydrangea => 'Hydrangea';

  @override
  String get schemeCactusFlower => 'Cactus flower';

  @override
  String get schemeWildflowers => 'Wildflowers';

  @override
  String get schemeCountryGarden => 'Country garden';

  @override
  String get schemeLotusGarden => 'Lotus garden';

  @override
  String get schemeIrisGarden => 'Iris garden';

  @override
  String get schemeFreshPeach => 'Fresh peach';

  @override
  String get schemeGoldenHour => 'Golden hour';

  @override
  String get schemeSpicedChai => 'Spiced chai';

  @override
  String get schemeCherryBlossom => 'Cherry blossom';

  @override
  String get schemeEveningRose => 'Evening rose';

  @override
  String get schemePastelGarden => 'Pastel garden';

  @override
  String get schemeTuscanSunset => 'Tuscan sunset';

  @override
  String get schemeZestyLemon => 'Zesty lemon';

  @override
  String get schemeCaliforniaBeaches => 'California beaches';

  @override
  String get schemeFreshlySqueezed => 'Freshly squeezed';

  @override
  String get schemePistachioDream => 'Pistachio dream';

  @override
  String get schemeMangoPopsicle => 'Mango popsicle';

  @override
  String get schemeGuava => 'Guava';

  @override
  String get schemeGlowingHorizon => 'Glowing horizon';

  @override
  String get schemeSunnyDay => 'Sunny day';

  @override
  String get schemeRetroSunset => 'Retro sunset';

  @override
  String get schemeBubblegumPop => 'Bubblegum pop';

  @override
  String get schemeCottonCandySkies => 'Cotton candy skies';

  @override
  String get schemeElectricKiwi => 'Electric kiwi';

  @override
  String get schemeWatermelonSplash => 'Watermelon splash';

  @override
  String get schemeAlchemicalReaction => 'Alchemical reaction';

  @override
  String get schemeElectropop => 'Electropop';

  @override
  String get schemeCoolRevival => 'Cool revival';

  @override
  String get schemeNeonJungle => 'Neon jungle';

  @override
  String get schemeSharpEdge => 'Sharp edge';

  @override
  String get schemeElectricFusion => 'Electric fusion';

  @override
  String get schemeFireworks => 'Fireworks';

  @override
  String get schemeSpaceBerries => 'Space berries';

  @override
  String get schemePopArt => 'Pop art';

  @override
  String get schemeUrbanGraffiti => 'Urban graffiti';

  @override
  String get schemeNeonNoir => 'Neon noir';

  @override
  String get schemeTropicalPunch => 'Tropical punch';

  @override
  String get schemeCobaltSky => 'Cobalt sky';

  @override
  String get schemeTechnicolorDream => 'Technicolor dream';

  @override
  String get schemeJewelBox => 'Jewel box';

  @override
  String get schemeSaltAndPepper => 'Salt and pepper';

  @override
  String get schemeQuiteClear => 'Quite clear';

  @override
  String get schemeGothicNoir => 'Gothic noir';

  @override
  String get schemeYachtClub => 'Yacht club';

  @override
  String get schemeQuietLuxury => 'Quiet luxury';

  @override
  String get schemeNightSands => 'Night sands';

  @override
  String get schemeHarborHaze => 'Harbor haze';

  @override
  String get schemeOldPhotograph => 'Old photograph';

  @override
  String get schemeCappuccino => 'Cappuccino';

  @override
  String get schemeBreakfastTea => 'Breakfast tea';

  @override
  String get schemeCozyCampfire => 'Cozy campfire';

  @override
  String get schemeStonePath => 'Stone path';

  @override
  String get schemeDesertMirage => 'Desert mirage';

  @override
  String get schemeHoneycomb => 'Honeycomb';

  @override
  String get schemeUrbanLoft => 'Urban loft';

  @override
  String get schemeSpicedMocha => 'Spiced mocha';

  @override
  String get schemeCharmingSeaside => 'Charming seaside';

  @override
  String get schemeCalmBlue => 'Calm blue';

  @override
  String get schemeBeachfrontViews => 'Beachfront views';

  @override
  String get schemeUnderTheMoonlight => 'Under the moonlight';

  @override
  String get schemeLavenderLullaby => 'Lavender lullaby';

  @override
  String get schemeMintyFresh => 'Minty fresh';

  @override
  String get schemeRetroCalm => 'Retro calm';

  @override
  String get schemeSiltstone => 'Siltstone';

  @override
  String get schemeEmeraldOdyssey => 'Emerald odyssey';

  @override
  String get schemeOceanTide => 'Ocean tide';

  @override
  String get schemePeachSkyline => 'Peach skyline';

  @override
  String get schemeMountainMist => 'Mountain mist';

  @override
  String get schemeMorningDew => 'Morning dew';

  @override
  String get schemeFrozenLake => 'Frozen lake';

  @override
  String get schemeOliveGrove => 'Olive grove';

  @override
  String get schemeCoastalMorning => 'Coastal morning';

  @override
  String get schemeEucalyptusGrove => 'Eucalyptus grove';

  @override
  String get schemeSoftSpring => 'Soft spring';

  @override
  String get schemeAutumnLeaves => 'Autumn leaves';

  @override
  String get schemeWinterChill => 'Winter chill';

  @override
  String get schemeSpringEnergy => 'Spring energy';

  @override
  String get schemePumpkinSpiceSeason => 'Pumpkin spice season';

  @override
  String get schemeIslandOasis => 'Island oasis';

  @override
  String get schemeAutumnOrchard => 'Autumn orchard';

  @override
  String get schemeTropicalRainforest => 'Tropical rainforest';

  @override
  String get schemeWildflowerMeadow => 'Wildflower meadow';

  @override
  String get schemeHarvestMoon => 'Harvest moon';

  @override
  String get schemeWinterBerry => 'Winter berry';

  @override
  String get schemeSummerBreeze => 'Summer breeze';

  @override
  String appearanceColorsShowAll(int count) {
    return 'See all $count colors';
  }

  @override
  String get appearanceColorsHide => 'Hide the colors';

  @override
  String planRepeatMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count months',
      one: 'Every month',
    );
    return '$_temp0';
  }

  @override
  String planRepeatYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count years',
      one: 'Every year',
    );
    return '$_temp0';
  }

  @override
  String planEachMonth(String amount) {
    return '$amount a month';
  }

  @override
  String planEachPay(String amount) {
    return '$amount each pay period';
  }

  @override
  String planThisMonth(String amount) {
    return '$amount this month';
  }

  @override
  String planThisPay(String amount) {
    return '$amount this pay period';
  }

  @override
  String planPaidFromArchived(String account) {
    return '$account is archived, so this bill isn’t in any forecast';
  }

  @override
  String planEachPayOf(String amount, String name) {
    return '$amount each pay period · $name';
  }

  @override
  String planAboutThisMonth(String amount) {
    return 'about $amount this month';
  }

  @override
  String planAboutThisPay(String amount) {
    return 'about $amount this pay period';
  }

  @override
  String planStillFor(String amount, String start, String end) {
    return '$amount still to assign for $start–$end';
  }

  @override
  String planPlusNext(String amount) {
    return 'plus about $amount toward the next';
  }

  @override
  String get planNoCarry => 'what’s left goes back to not assigned';

  @override
  String planWentBack(String amount) {
    return '$amount left last month went back to not assigned';
  }

  @override
  String planDue(String amount, String date) {
    return '$amount due $date';
  }

  @override
  String planWasDue(String amount, String date) {
    return '$amount was due $date';
  }

  @override
  String planBy(String amount, String date) {
    return '$amount by $date';
  }

  @override
  String planPaidOn(String date) {
    return 'paid $date';
  }

  @override
  String planUsedOf(String used, String had) {
    return '$used of $had used';
  }

  @override
  String planUsedNone(String amount) {
    return '$amount overspent, with nothing assigned';
  }

  @override
  String planUsedOver(String amount) {
    return '$amount overspent';
  }

  @override
  String get planTotal => 'Total';

  @override
  String get planOnTrack => 'on track';

  @override
  String planShort(String amount) {
    return '$amount short';
  }

  @override
  String planAssignThis(String amount) {
    return 'Assign $amount';
  }

  @override
  String get planEditTip => 'Click to change the plan';

  @override
  String planFill(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Assign what’s planned · $amount in $count categories',
      one: 'Assign what’s planned · $amount in 1 category',
    );
    return '$_temp0';
  }

  @override
  String planFillOver(String amount) {
    return 'That’s $amount more than you have';
  }

  @override
  String get planKeyBank => 'Bank';

  @override
  String get planKeyCash => 'Cash';

  @override
  String get planKeyCashBank => 'Cash & bank';

  @override
  String get planKeyAssigned => 'In categories';

  @override
  String get planKeyNotAssigned => 'Not assigned';

  @override
  String get planKeyOverspent => 'Overspent';

  @override
  String get planKeyNotBegun =>
      'Spending counts against a category once you assign money to it.';

  @override
  String planBeganMovedBack(String date) {
    return 'the budget now begins $date, so spending from then on counts against its categories';
  }

  @override
  String planAssignedTo(String amount, String category) {
    return 'Assigned $amount to $category';
  }

  @override
  String planKeyBeganInside(String date) {
    return 'Spending before $date, when the budget began, isn\'t counted against its categories.';
  }

  @override
  String get planMoveChooseCategory => 'Choose a category';

  @override
  String get planMoveNothingFrom =>
      'No other category in this currency has money to move, and none is unassigned.';

  @override
  String get planKeyAsOfToday => 'As of today';

  @override
  String get planKeyOver => 'Assigned too much';

  @override
  String planFilled(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Assigned $amount to $count categories',
      one: 'Assigned $amount to 1 category',
    );
    return '$_temp0';
  }

  @override
  String planSetUndo(String category) {
    return 'Plan for $category';
  }

  @override
  String planRemoveUndo(String category) {
    return 'Remove the plan for $category';
  }

  @override
  String planWentBackPay(String amount) {
    return '$amount left last pay period went back to not assigned';
  }

  @override
  String planWentBackOn(String amount, String date) {
    return '$amount went back to not assigned on $date';
  }

  @override
  String planReturns(String amount, String category) {
    return '$amount that went back returns to $category, so not assigned goes down by that much';
  }

  @override
  String get planMoneyCurrency => 'Currency';

  @override
  String planOnlyFromOne(String account) {
    return 'only from $account';
  }

  @override
  String planOnlyFromSome(int count, int total) {
    return 'only from $count of $total accounts';
  }

  @override
  String planMoneyUndo(String category) {
    return 'Accounts for $category';
  }

  @override
  String planMoneyCurrencyUndo(String category, String symbol) {
    return '$category is now in $symbol';
  }

  @override
  String planMoneyChange(String amount) {
    return 'Changing the currency sends the $amount assigned to it back to not assigned and removes its plan';
  }

  @override
  String planMoneyChangeAmount(String amount) {
    return 'Changing the currency sends the $amount assigned to it back to not assigned';
  }

  @override
  String get planMoneyChangePlan => 'Changing the currency removes its plan';

  @override
  String planMoneyRestOne(
    String held,
    String account,
    String category,
    String rest,
  ) {
    return '$held of what’s in $account is for $category. The other $rest there can still be assigned to any category.';
  }

  @override
  String planMoneyRestSome(String held, String category, String rest) {
    return '$held of what’s in these accounts is for $category. The other $rest there can still be assigned to any category.';
  }

  @override
  String get planFromNone => 'no account checked';

  @override
  String planOtherRows(int count, String amount, String symbol, String other) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$amount in $count rows isn’t counted here (this category is in $symbol); it came out of $other not assigned',
      one:
          '$amount in 1 row isn’t counted here (this category is in $symbol); it came out of $other not assigned',
    );
    return '$_temp0';
  }

  @override
  String planOffAccount(String amount, String account) {
    return '$amount paid from $account, which this category doesn’t use';
  }

  @override
  String planOffAccounts(String amount, int count) {
    return '$amount paid from $count accounts this category doesn’t use';
  }

  @override
  String planBackingOne(String held, String account, String have) {
    return '$held left here, but $account holds $have';
  }

  @override
  String planBackingSome(String held, String have) {
    return '$held left here, but its accounts hold $have';
  }

  @override
  String planBackingShared(String held, int count, String have) {
    return '$held left in $count categories kept in the same accounts, which hold $have';
  }

  @override
  String get planEdit => 'Edit';

  @override
  String get planEditName => 'Name';

  @override
  String planFundOverAssigned(String amount) {
    return 'Your budget has assigned $amount more than you have.';
  }

  @override
  String planMonthOutgrown(String amount) {
    return 'Your budget now holds $amount a month.';
  }

  @override
  String get planMonthWrong => 'Type an amount, like 2,000,000.';

  @override
  String get planRateWrong => 'Type a rate, like 2 or 2.5.';

  @override
  String get planNotPayingExtraYet => 'Not paying extra yet';

  @override
  String planFundAssign(String amount, String category) {
    return 'Assign $amount to $category';
  }

  @override
  String get planInMonthQ => 'In a month of expenses?';

  @override
  String get planInMonthYesMeans =>
      'Savings counts it in the month your safety net covers.';

  @override
  String get planInMonthNoMeans =>
      'Left out, like a card\'s payment when what\'s bought on the card is in its own categories.';

  @override
  String get planDueDateQ => 'Is there a due date?';

  @override
  String get planDueNoMeans =>
      'An amount you spend as the month goes, like groceries.';

  @override
  String get planDueNoMeansPay =>
      'An amount you spend as the pay period goes, like groceries.';

  @override
  String get planDueYesMeans =>
      'An amount to have ready by a date, like rent or insurance.';

  @override
  String get planNo => 'No';

  @override
  String get planYes => 'Yes';

  @override
  String get planSetAsideMonth => 'Set aside each month';

  @override
  String get planSetAsidePay => 'Set aside each pay period';

  @override
  String get planNothingSet => 'nothing set';

  @override
  String get planEmptyHint =>
      'Leave it empty and you choose each month how much to assign.';

  @override
  String get planEmptyHintPay =>
      'Leave it empty and you choose each pay period how much to assign.';

  @override
  String get planLeftMonthEnd => 'What’s left at month’s end';

  @override
  String get planLeftPeriodEnd => 'What’s left at the period’s end';

  @override
  String get planStaysHere => 'Stays here';

  @override
  String get planGoesBack => 'Goes back to not assigned';

  @override
  String get planStopAt => 'Up to';

  @override
  String get planNoLimit => 'no limit';

  @override
  String get planStopAtHint =>
      'Once it holds this much, the plan stops adding to it.';

  @override
  String get planAmountDue => 'Amount due';

  @override
  String get planLabelDueDate => 'Due';

  @override
  String get planHowOften => 'How often';

  @override
  String get planOnce => 'Once';

  @override
  String planRepeatDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count days',
      one: 'Every day',
    );
    return '$_temp0';
  }

  @override
  String planRepeatWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count weeks',
      one: 'Every week',
    );
    return '$_temp0';
  }

  @override
  String get planEveryPayday => 'Every payday';

  @override
  String planEveryPaydayOf(String name) {
    return 'Every payday · $name';
  }

  @override
  String get planEveryPayPeriod => 'Every pay period';

  @override
  String planEveryPayPeriodOf(String name) {
    return 'Every pay period · $name';
  }

  @override
  String get planEveryCustom => 'Custom…';

  @override
  String get planCustomOn => 'Custom';

  @override
  String get planRepeatEvery => 'Repeat every';

  @override
  String get planOnWeekdays => 'On';

  @override
  String get planWeekdaysHint =>
      'Pick the days. With none picked, it’s the due date’s weekday.';

  @override
  String get planOnLabel => 'On';

  @override
  String get planDayOfMonth => 'Day of the month';

  @override
  String get planAWeekday => 'A weekday';

  @override
  String get planNthFirst => 'first';

  @override
  String get planNthSecond => 'second';

  @override
  String get planNthThird => 'third';

  @override
  String get planNthFourth => 'fourth';

  @override
  String get planNthLast => 'last';

  @override
  String get planWeekdayNames =>
      'Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday';

  @override
  String get planEnds => 'Ends';

  @override
  String get planEndsNever => 'Never';

  @override
  String get planEndsOn => 'On a date';

  @override
  String get planEndsAfter => 'After';

  @override
  String get planEndsTimes => 'times';

  @override
  String get planEndDateHint => 'YYYY.MM.DD';

  @override
  String planEnded(String amount, String date) {
    return '$amount · ended $date';
  }

  @override
  String get planOnDates => 'On these dates…';

  @override
  String get planUnitDays => 'days';

  @override
  String get planUnitWeeks => 'weeks';

  @override
  String get planUnitMonths => 'months';

  @override
  String get planUnitYears => 'years';

  @override
  String get planDatesLabel => 'Dates';

  @override
  String get planDatesHint => '04.15, 06.15, 09.15, 01.15';

  @override
  String planDatesAYear(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dates a year',
      one: '1 date a year',
      zero: 'On these dates',
    );
    return '$_temp0';
  }

  @override
  String get planDaysAfterPay => 'days after payday';

  @override
  String get planOnPayday => 'on payday';

  @override
  String get planWeekendKeep => 'On the day';

  @override
  String get planWeekendBefore => 'Before a weekend';

  @override
  String get planWeekendAfter => 'After a weekend';

  @override
  String planPaidFromHint(String account, String date) {
    return 'The bill shows in $account’s forecast on $date. When it’s paid, you confirm it there.';
  }

  @override
  String planPaidFromHintNone(String account) {
    return 'Enter the date and the bill shows in $account’s forecast.';
  }

  @override
  String get planEnterAmountDate => 'Enter the amount and the date';

  @override
  String get planNothingMore => 'nothing more to set aside';

  @override
  String get planRowWillRead => 'The row will read';

  @override
  String get planLabelPaidFrom => 'Paid from';

  @override
  String planUpTo(String amount) {
    return 'up to $amount';
  }

  @override
  String planSetAsideAmount(String amount) {
    return '$amount set aside';
  }

  @override
  String planEditedUndo(String category) {
    return 'Changes to $category';
  }

  @override
  String get planAccountsAll => 'All accounts';

  @override
  String get planAccountsNone => 'No accounts';

  @override
  String planAccountsSome(int count, int total) {
    return '$count of $total accounts';
  }

  @override
  String get setupCurrencySearch => 'Search currencies';

  @override
  String get setupCurrencyNoMatch => 'No currency by that name';

  @override
  String get ledgerIncome => 'Income';

  @override
  String payStopped(String name) {
    return '$name (stopped)';
  }

  @override
  String planIncomeLine(String amounts) {
    return 'Income: $amounts';
  }

  @override
  String get rowsNewCategoryRefundNote =>
      'new category · money in counts as a refund to it; for pay, pick Income';

  @override
  String ledgerPayReplaced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'replaced $count incomes you scheduled by hand',
      one: 'replaced the income you scheduled by hand',
    );
    return '$_temp0';
  }

  @override
  String get setupYourAccounts => 'Your accounts';

  @override
  String get setupAddTracked => 'Add the accounts you want to track.';

  @override
  String get setupNeverConnects =>
      'BetterBudget never connects to your bank. You type in what your bank app shows.';

  @override
  String get setupBalancesAsOf => 'Balances as of';

  @override
  String get setupDateChanged => 'Balances date changed';

  @override
  String get setupOwedTodayHint =>
      'A charge from today that the bank hasn’t shown yet isn’t in this figure.';

  @override
  String get setupEverydayQ => 'How do you pay for everyday things?';

  @override
  String get setupEverydayBank => 'From the bank (card, QR or transfer)';

  @override
  String get setupEverydayBoth => 'Both';

  @override
  String get setupNoCashWarning =>
      'You have no Cash account. Money you take out of an ATM will read as spent the day you take it out, and the cash in your wallet won’t be counted.';

  @override
  String get setupAddCashAccount => 'Add a Cash account';

  @override
  String get setupOpenLedger => 'Open my ledger';

  @override
  String setupRemoveAccount(String name) {
    return 'Remove $name';
  }

  @override
  String get setupEverydayCash => 'Cash';

  @override
  String setupStartCashHint(String zero) {
    return 'Count what’s in your wallet now · empty starts at $zero';
  }

  @override
  String get setupFinished => 'Setup finished';

  @override
  String get setupStepAccounts => 'Accounts';

  @override
  String get setupStepPay => 'Pay';

  @override
  String get setupContinue => 'Continue';

  @override
  String get setupBack => 'Back';

  @override
  String get setupPayArrives =>
      'The amount that lands in the account, not your salary before tax. A loan payment the bank takes afterwards is a bill.';

  @override
  String get setupPayNeedsAccount =>
      'Pay goes into a bank account or Cash. Add one on Accounts to set up your pay.';

  @override
  String get setupNoRegularPayLine => 'No regular pay';

  @override
  String phoneLeftIn(String month) {
    return 'Left in $month';
  }

  @override
  String phoneFromMacToday(String time) {
    return 'From your computer today $time';
  }

  @override
  String phoneFromMacOn(String date, String time) {
    return 'From your computer $date $time';
  }

  @override
  String phoneWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count of your entries are waiting for your computer',
      one: '1 of your entries is waiting for your computer',
    );
    return '$_temp0';
  }

  @override
  String get phoneWaitingTitle => 'Waiting for your computer';

  @override
  String phoneOwed(String amount) {
    return 'Owed $amount';
  }

  @override
  String phoneLeftNow(String left) {
    return '$left left now';
  }

  @override
  String phoneLeftAfter(String left, String after) {
    return '$left left now · $after after this';
  }

  @override
  String get phoneEnterAmount => 'Enter an amount';

  @override
  String get phoneEnterPayee => 'Enter a payee';

  @override
  String get phoneDeleteDigit => 'Delete the last digit';

  @override
  String get ledgerFolderLabel => 'Stored in';

  @override
  String get ledgerFolderChoose => 'Move my ledger to a folder…';

  @override
  String get ledgerFolderPickButton => 'Move It Here';

  @override
  String get ledgerFolderNote =>
      'Move it to a folder that Google Drive, OneDrive, Box or Dropbox keeps on this computer, and your ledger is stored there, encrypted, and saved again after each change.';

  @override
  String ledgerFolderCopied(String folder, String when) {
    return '$folder · $when';
  }

  @override
  String ledgerFolderFailing(String folder, String when) {
    return '$folder · couldn’t copy · the last one is from $when';
  }

  @override
  String ledgerFolderFailingNone(String folder) {
    return '$folder · couldn’t copy';
  }

  @override
  String get ledgerFolderChange => 'Move to another folder…';

  @override
  String get ledgerFolderStop => 'Move it back to this computer';

  @override
  String ledgerFolderKept(String folder) {
    return 'Your ledger was moved to $folder';
  }

  @override
  String ledgerFolderStopped(String folder) {
    return 'Your ledger is back on this computer · the file in $folder stays there';
  }

  @override
  String get ledgerFolderCouldnt => 'Couldn’t move it to that folder';

  @override
  String get ledgerFolderHere => 'This computer';

  @override
  String get phoneKeyTitle => 'Enter your recovery key';

  @override
  String get phoneKeyBody =>
      'The 25 characters you were shown when your ledger was set up on your computer. This phone needs them once, to read your ledger.';

  @override
  String get phoneFolderTitle => 'Where is your ledger?';

  @override
  String get phoneFolderBody =>
      'Choose the folder your ledger was moved to on your computer. In Settings there, the line “Stored in” names it.';

  @override
  String get phoneFolderChoose => 'Choose the folder';

  @override
  String get phoneNoLedger => 'There is no ledger in that folder';

  @override
  String phoneNoLedgerBody(String file) {
    return 'The folder should hold a file named $file. It can take a minute to arrive after your computer saves it.';
  }

  @override
  String get phoneKeyDoesntOpen =>
      'That recovery key doesn’t open the ledger in this folder';

  @override
  String get phoneEnterKeyAgain => 'Enter the key again';

  @override
  String get phoneCantRead => 'The ledger in this folder couldn’t be read';

  @override
  String get phoneCantReadBody =>
      'It may have been saved by a newer BetterBudget than the one on this phone.';

  @override
  String get phoneTryAgain => 'Try again';

  @override
  String get phoneChooseAnother => 'Choose another folder';

  @override
  String get ledgerFolderAlert => 'Your ledger couldn’t be saved to its folder';

  @override
  String phoneLeftUntil(String date) {
    return 'Left until $date';
  }

  @override
  String phoneDue(String date) {
    return 'Due $date';
  }

  @override
  String phoneOverNow(String over) {
    return 'Overspent by $over';
  }

  @override
  String phoneOverAfter(String left, String over) {
    return '$left left now · overspent by $over after this';
  }

  @override
  String phoneOverBoth(String over, String after) {
    return 'Overspent by $over · by $after after this';
  }

  @override
  String get phoneChooseAccount => 'Choose an account';

  @override
  String get phoneMoveToAccount => 'Move to an account';

  @override
  String phoneTransferTo(String account) {
    return '→ $account';
  }

  @override
  String get phoneFrom => 'From';

  @override
  String phoneTransferAfter(String account, String amount) {
    return '$account · $amount after this';
  }

  @override
  String phoneTransferOwedAfter(String account, String amount) {
    return '$account · $amount owed after this';
  }

  @override
  String phoneSavedTransfer(String from, String to, String amount) {
    return 'Saved · $from → $to $amount';
  }

  @override
  String phoneTransferNow(String account, String amount) {
    return '$account · $amount now';
  }

  @override
  String phoneTransferOwedNow(String account, String amount) {
    return '$account · $amount owed now';
  }

  @override
  String phoneTransferTitle(String from, String to) {
    return '$from → $to';
  }

  @override
  String phoneInCredit(String amount) {
    return '$amount in credit';
  }

  @override
  String get phoneBills => 'Bills';

  @override
  String get phoneNewCategory => '+ New category';

  @override
  String get phoneNewCategoryTitle => 'New category';

  @override
  String get phoneChooseCategory => 'Choose a category';

  @override
  String get phoneNothingAssigned => 'Nothing assigned yet';

  @override
  String phoneSaved(String payee, String amount) {
    return 'Saved · $payee $amount';
  }

  @override
  String phoneWaitingCategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new categories are waiting for your computer',
      one: '1 new category is waiting for your computer',
    );
    return '$_temp0';
  }

  @override
  String phoneWaitingBoth(int entries, int categories) {
    String _temp0 = intl.Intl.pluralLogic(
      entries,
      locale: localeName,
      other: '$entries of your entries',
      one: '1 of your entries',
    );
    String _temp1 = intl.Intl.pluralLogic(
      categories,
      locale: localeName,
      other: '$categories new categories',
      one: '1 new category',
    );
    return '$_temp0 and $_temp1 are waiting for your computer';
  }

  @override
  String phoneDeleteCategory(int count, String name, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $name and the $count entries in it ($amount)?',
      one: 'Delete $name and the 1 entry in it ($amount)?',
    );
    return '$_temp0';
  }

  @override
  String get phoneClear => 'Clear';

  @override
  String phoneSavedLeft(String category, String left) {
    return '$category · $left left';
  }

  @override
  String phoneSavedOver(String category, String over) {
    return '$category · overspent by $over';
  }

  @override
  String phoneSavedNothingAssigned(String category) {
    return '$category · nothing assigned yet';
  }

  @override
  String ledgerFromPhone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions from your phone',
      one: '1 transaction from your phone',
    );
    return '$_temp0';
  }

  @override
  String ledgerCategoryFromPhone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new categories from your phone',
      one: '1 new category from your phone',
    );
    return '$_temp0';
  }

  @override
  String ledgerEditCategory(String name) {
    return 'Edit $name';
  }

  @override
  String phoneOverThenLeft(String over, String after) {
    return 'Overspent by $over · $after left after this';
  }

  @override
  String get phoneToMoneyIn => 'Change to money in';

  @override
  String get phoneIncomeNeedsMoneyIn =>
      'To record income, tap +/− beside the amount first.';

  @override
  String get phoneToMoneyOut => 'Change to money out';

  @override
  String ledgerFolderOpenedFrom(String computer) {
    return 'Opened the ledger saved on $computer';
  }

  @override
  String get ledgerFolderOpened =>
      'Opened the ledger saved on another computer';

  @override
  String ledgerCombinedFrom(int count, String computer) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions from $computer',
      one: '1 transaction from $computer',
    );
    return '$_temp0';
  }

  @override
  String ledgerCombinedMoreFrom(int count, String computer) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions and other changes from $computer',
      one: '1 transaction and other changes from $computer',
    );
    return '$_temp0';
  }

  @override
  String ledgerCombinedOtherFrom(String computer) {
    return 'Changes from $computer';
  }

  @override
  String ledgerCombined(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions from another computer',
      one: '1 transaction from another computer',
    );
    return '$_temp0';
  }

  @override
  String ledgerCombinedMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions and other changes from another computer',
      one: '1 transaction and other changes from another computer',
    );
    return '$_temp0';
  }

  @override
  String get ledgerCombinedOther => 'Changes from another computer';

  @override
  String ledgerCombinedAlike(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count look the same as ones already here',
      one: '1 looks the same as one already here',
    );
    return '$_temp0';
  }

  @override
  String ledgerCombinedOverAssigned(String amount) {
    return '$amount more is assigned than you have';
  }

  @override
  String ledgerFolderCouldntOpen(String folder) {
    return 'Couldn’t open the ledger in $folder · nothing was changed';
  }

  @override
  String ledgerFolderArriving(String folder) {
    return '$folder · the ledger there can’t be read yet';
  }

  @override
  String ledgerFolderNewerAppLine(String folder) {
    return '$folder · saved by a newer version of BetterBudget · update BetterBudget on this computer';
  }

  @override
  String ledgerFolderApart(String folder) {
    return '$folder · changed on another computer too · this computer’s changes aren’t in the folder';
  }

  @override
  String get ledgerFolderChooseWhich => 'Choose which to keep…';

  @override
  String get ledgerFolderApartAlert =>
      'Your ledger was changed on two computers';

  @override
  String get ledgerTwoTitle => 'Your ledger was changed on two computers';

  @override
  String get ledgerTwoTitleFolder => 'This folder already has a ledger';

  @override
  String ledgerTwoBody(String folder) {
    return 'The ledger in $folder has changes that aren’t on this computer, and this computer has changes that aren’t in the folder. BetterBudget can’t put these two together, so choose which one to keep. The other is saved first, and Restore from… in Settings brings it back. Until you choose, this computer’s changes and your phone’s entries stay out of the folder.';
  }

  @override
  String get ledgerTwoInFolder => 'In the folder';

  @override
  String get ledgerTwoHere => 'On this computer';

  @override
  String ledgerTwoSavedOn(String computer, String when) {
    return 'Saved on $computer · $when';
  }

  @override
  String ledgerTwoSavedWhen(String when) {
    return 'Saved on another computer · $when';
  }

  @override
  String get ledgerTwoNotNow => 'Not now';

  @override
  String get ledgerTwoUseMine => 'Keep this computer’s ledger';

  @override
  String get ledgerTwoUseFolder => 'Keep the folder’s ledger';

  @override
  String ledgerFolderKeptMine(String folder) {
    return 'This computer’s ledger is now in $folder · the one that was there is saved in Backups';
  }

  @override
  String get ledgerFolderUnreadableTitle =>
      'The ledger in this folder can’t be opened';

  @override
  String ledgerFolderUnreadableBody(String folder) {
    return '$folder holds a ledger that this computer can’t open. It may be another ledger, or one that is still arriving.';
  }

  @override
  String get ledgerFolderUnreadableKept =>
      'If you replace it, it is saved on this computer first, and Restore from… opens it with its own recovery key.';

  @override
  String get ledgerFolderReplace => 'Replace it';

  @override
  String get ledgerFolderNewerApp =>
      'The ledger in that folder was saved by a newer version of BetterBudget · update BetterBudget on this computer first';

  @override
  String ledgerRestoreKeepOnFolder(String folder) {
    return 'Share the ledger in $folder';
  }

  @override
  String ledgerRestoreKeepOnFolderNote(String folder) {
    return 'What you change here goes to $folder, and what is changed on another computer comes here.';
  }

  @override
  String get ledgerUseThisFolder => 'Use This Folder';

  @override
  String ledgerRestoredOnFolder(String folder) {
    return 'This computer is now on the ledger in $folder';
  }

  @override
  String ledgerRestoredNotOnFolder(String folder) {
    return 'Your ledger is here, but this computer isn’t on $folder · in Settings, use Move my ledger to a folder…';
  }

  @override
  String ledgerRestoreNotKeptNote(String folder) {
    return 'This computer gets its own copy. What you change here won’t reach $folder.';
  }

  @override
  String get ledgerRestoreMacAsks =>
      'Your Mac asks for the folder next: press Use This Folder.';

  @override
  String get ledgerBringLedgerTitle => 'Bring this ledger here?';

  @override
  String get ledgerLastChanged => 'Last changed';

  @override
  String get ledgerBringLedgerNote =>
      'Everything here is replaced by this ledger. What you have now is saved first, and Undo brings it back.';

  @override
  String get startWhereTitle => 'Where is your ledger?';

  @override
  String get startWhereFolder => 'In a folder, such as Google Drive';

  @override
  String get startWhereFolderNote =>
      'This computer shares the ledger that is there.';

  @override
  String get startWhereBackup => 'In a backup';

  @override
  String get startWhereBackupNote =>
      'A copy you saved with Back up to… in Settings.';

  @override
  String ledgerFolderWrongKey(String folder) {
    return 'Your recovery key doesn’t open the ledger in $folder';
  }

  @override
  String ledgerFolderNoLedger(String folder) {
    return 'There’s no ledger in $folder · choose the folder that holds Ledger.betterbudget. If it is still copying to this computer, try again in a minute.';
  }

  @override
  String get startHowTitle => 'How do you want to start?';

  @override
  String get startFresh => 'Start fresh';

  @override
  String get startFreshNote => 'My household is new to BetterBudget.';

  @override
  String get startRestore => 'Restore from backup';

  @override
  String get startRestoreNote =>
      'I have a backup file, saved with Back up to… in Settings. This computer gets its own copy.';

  @override
  String get startOpen => 'Open ledger';

  @override
  String get startOpenNote =>
      'My household already uses BetterBudget on another computer, and the ledger is in a folder, such as Google Drive. This computer shares it.';

  @override
  String get startKeyLabel => 'Recovery key';

  @override
  String get startChooseFolder => 'Choose the folder…';

  @override
  String get startChooseBackup => 'Choose the backup…';

  @override
  String get startKeyHint =>
      'It was shown when BetterBudget was first set up, and is in “BetterBudget recovery key.txt” if it was saved.';

  @override
  String startKeyWrongFolder(String folder) {
    return 'That key doesn’t open the ledger in $folder. If the folder is still copying to this computer, try again in a minute.';
  }

  @override
  String get ledgerSectionPayees => 'Payees';

  @override
  String get payeesColumnPayee => 'Payee';

  @override
  String get payeesColumnAccounts => 'Accounts';

  @override
  String get payeesDelete => 'Delete';

  @override
  String payeesDeletedMessage(String category) {
    return 'Deleted · $category no longer remembered for next time';
  }

  @override
  String get payeesAdd => 'Add a payee';

  @override
  String get payeesWordsLabel => 'Payee, or a word in it';

  @override
  String get payeesWhere => 'Where to look';

  @override
  String get payeesAtStart => 'At the start of the payee';

  @override
  String get payeesAnywhere => 'Anywhere in the payee or memo';

  @override
  String payeesStartsWith(String name) {
    return 'starts with «$name»';
  }

  @override
  String payeesHasAnywhere(String name) {
    return 'has «$name» anywhere';
  }

  @override
  String payeesFitsStarts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows start with this',
      one: '1 row starts with this',
      zero: 'No row starts with this yet',
    );
    return '$_temp0';
  }

  @override
  String payeesFitsAnywhere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows have this',
      one: '1 row has this',
      zero: 'No row has this yet',
    );
    return '$_temp0';
  }

  @override
  String payeesWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count still in Not categorized',
      one: '1 still in Not categorized',
    );
    return '$_temp0';
  }

  @override
  String payeesElsewhere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count in another category',
      one: '1 in another category',
    );
    return '$_temp0';
  }

  @override
  String get payeesHowRowReads => 'Rows like this will read';

  @override
  String get payeesNeedsWords => 'Type a payee, or a word in it';

  @override
  String get payeesNeedsCategory => 'Pick a category';

  @override
  String get payeesNeedsAccount => 'Pick an account';

  @override
  String get payeesEmpty =>
      'Nothing remembered yet. When you pick a row\'s category in the Ledger, tick “Remember this category for this payee” under it, or add a payee here.';

  @override
  String get payeesColumnFiled => 'Category';

  @override
  String get payeesDeleted => 'Deleted';

  @override
  String payeesFiled(int count, String category) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows filed under $category',
      one: '1 row filed under $category',
    );
    return '$_temp0';
  }

  @override
  String payeesFileWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'File the $count still in Not categorized',
      one: 'File the 1 still in Not categorized',
    );
    return '$_temp0';
  }

  @override
  String payeesAlreadyListed(String payee, String category) {
    return '«$payee» is already in the list, with $category';
  }

  @override
  String payeesAlreadyIn(int count, String category) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count already in $category',
      one: '1 already in $category',
    );
    return '$_temp0';
  }

  @override
  String payeesAnywhereWould(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count have it elsewhere in the payee or memo',
      one: '1 has it elsewhere in the payee or memo',
    );
    return '$_temp0';
  }

  @override
  String payeesCategoryArchived(String category) {
    return '$category (archived: rows wait in Not categorized)';
  }

  @override
  String get payeesNoAccount => 'No account';

  @override
  String payeesWaitingStay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more in Not categorized stay there',
      one: '1 more in Not categorized stays there',
    );
    return '$_temp0';
  }

  @override
  String get payeesWhatLinesDo =>
      'A payee here fills its category when a row is typed with it, and files rows of it brought in from a bank file. Rows already in the ledger stay where they are.';

  @override
  String get payeesCategoryGone => 'A deleted category';

  @override
  String get ledgerRowsThisComputer => 'This computer';

  @override
  String get ledgerRowsOtherComputer => 'The other computer';

  @override
  String get ledgerRowsOtherComputerInSentence => 'the other computer';

  @override
  String get ledgerRowsKeepHere => 'Keep this computer’s';

  @override
  String ledgerRowsKeepTheirs(String computer) {
    return 'Keep $computer’s';
  }

  @override
  String ledgerRowsKeepDeletedTheirs(String computer) {
    return 'Keep it deleted ($computer’s)';
  }

  @override
  String get ledgerRowsKeepNeither => 'Neither: as it was';

  @override
  String ledgerRowsAssigned(String category, String date) {
    return '$category · Assigned, period starting $date';
  }

  @override
  String get ledgerRowsDeleted => 'Deleted';

  @override
  String get ledgerRowsNoPayee => 'No payee';

  @override
  String ledgerRowsAsItWas(String what) {
    return 'As it was: $what';
  }

  @override
  String get ledgerBothDeleteAnyway => 'Delete it anyway';

  @override
  String ledgerRowsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things were changed on both computers',
      one: 'One thing was changed on both computers',
    );
    return '$_temp0';
  }

  @override
  String get ledgerRowsBody =>
      'Choose which to keep for each. Everything else comes in with your choices. The one you don’t keep is saved in Backups. Until you choose, this computer’s changes and your phone’s entries stay out of the folder.';

  @override
  String get ledgerRowsSave => 'Save my choices';

  @override
  String ledgerCombinedPayeeFrom(String payee, String computer) {
    return '$payee from $computer';
  }

  @override
  String ledgerCombinedPayeeMoreFrom(String payee, int count, String computer) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$payee and $count changes from $computer',
      one: '$payee and 1 change from $computer',
    );
    return '$_temp0';
  }

  @override
  String ledgerCombinedPayee(String payee) {
    return '$payee from the other computer';
  }

  @override
  String ledgerCombinedPayeeMore(String payee, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$payee and $count changes from the other computer',
      one: '$payee and 1 change from the other computer',
    );
    return '$_temp0';
  }

  @override
  String get rowsColumnSource => 'Source';

  @override
  String sourceTypedOn(String computer) {
    return 'Entered on $computer';
  }

  @override
  String get sourceTyped => 'Entered';

  @override
  String sourceImportedOn(String computer) {
    return 'Imported on $computer';
  }

  @override
  String get sourceImported => 'Imported';

  @override
  String sourcePhone(String phone) {
    return 'From $phone';
  }

  @override
  String get sourceYourPhone => 'From your phone';

  @override
  String sourcePhoneId(String id) {
    return 'From phone $id';
  }

  @override
  String get sourceScheduled => 'Scheduled';

  @override
  String get settingsRegisterTitle => 'Register';

  @override
  String get settingsSourceColumn => 'Show where each transaction came from';

  @override
  String get settingsPhonesTitle => 'Your phones';

  @override
  String settingsPhoneName(String id) {
    return 'Name for phone $id';
  }

  @override
  String get settingsPhoneNameHint => 'For example, Pixel';

  @override
  String get sourceTypedHere => 'Entered locally';

  @override
  String get sourceImportedHere => 'Imported locally';

  @override
  String get sourceTypedElsewhere => 'Entered on another computer';

  @override
  String get sourceImportedElsewhere => 'Imported on another computer';

  @override
  String get settingsComputersTitle => 'Your computers';

  @override
  String get settingsComputerThis => 'Name for this computer';

  @override
  String settingsComputerName(String id) {
    return 'Name for computer $id';
  }

  @override
  String rowsPaidOnAsk(String date, String payee, String amount) {
    return 'Paid on $date? $payee, $amount';
  }

  @override
  String rowsPaidOnAskFrom(
    String date,
    String payee,
    String amount,
    String account,
  ) {
    return 'Paid on $date? $payee, $amount, from $account';
  }

  @override
  String get rowsPaidYes => 'Yes';

  @override
  String get rowsPaidNo => 'No';

  @override
  String get rowsNotThisBill => 'Not this bill';

  @override
  String get rowsNoBillThisTime => 'No bill this time';

  @override
  String billAskTitle(String name) {
    return 'Did this pay the $name bill?';
  }

  @override
  String billAskPaidFrom(
    String payee,
    String amount,
    String account,
    String date,
  ) {
    return 'You paid $payee $amount from $account on $date.';
  }

  @override
  String billAskPaid(String payee, String amount, String date) {
    return 'You paid $payee $amount on $date.';
  }

  @override
  String billAskBill(String amount, String date) {
    return 'The bill is $amount, due $date.';
  }

  @override
  String billAskMore(String more, String category) {
    return 'That\'s $more more than the bill. All of it comes out of $category.';
  }

  @override
  String get billAskYes => 'Yes, it\'s paid';

  @override
  String get billAskNo => 'No, something else';

  @override
  String billRestTitle(String rest) {
    return 'Is $rest still to pay?';
  }

  @override
  String billRestPaid(String amount, String bill, String name) {
    return 'You paid $amount of the $bill $name bill.';
  }

  @override
  String billRestYes(String date) {
    return 'Yes, pay the rest by $date';
  }

  @override
  String get billRestNo => 'No, the bill is paid';

  @override
  String billSeveralTitle(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Did this pay $count $name bills?',
    );
    return '$_temp0';
  }

  @override
  String billSeveralPaid(String amount, String date) {
    return 'You paid $amount on $date.';
  }

  @override
  String billSeveralBills2(String first, String second, String each) {
    return 'The bills due $first and $second are $each each.';
  }

  @override
  String billSeveralBills3(
    String first,
    String second,
    String third,
    String each,
  ) {
    return 'The bills due $first, $second and $third are $each each.';
  }

  @override
  String billSeveralYes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Yes, all $count bills',
      two: 'Yes, both bills',
    );
    return '$_temp0';
  }

  @override
  String get billSeveralOne => 'Only one bill';

  @override
  String ledgerBillPaidNext(String name, String date) {
    return '$name bill paid. Next due $date.';
  }

  @override
  String ledgerBillPaidOnly(String name) {
    return '$name bill paid.';
  }

  @override
  String ledgerBillsPaidNext(int count, String name, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count $name bills paid. Next due $date.',
    );
    return '$_temp0';
  }

  @override
  String ledgerBillRest(String name, String rest, String date) {
    return '$name bill: $rest still to pay, due $date.';
  }

  @override
  String ledgerNotTheBill(String name, String date) {
    return 'Not the $name bill. It\'s still due $date.';
  }

  @override
  String ledgerNoBill(String name, String date, String amount, String next) {
    return 'No $name bill on $date. Its $amount stays for the one due $next.';
  }

  @override
  String ledgerNoBillLast(String name, String date) {
    return 'No $name bill on $date.';
  }

  @override
  String ledgerBillsPaidCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bills paid.',
      one: '1 bill paid.',
    );
    return '$_temp0';
  }

  @override
  String ledgerBillsToCheck(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bills to check.',
      one: '1 bill to check.',
    );
    return '$_temp0';
  }

  @override
  String forecastMaybePaid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count bills may already be paid. They\'re counted until you say yes.',
      one: 'A bill may already be paid. It\'s counted until you say yes.',
    );
    return '$_temp0';
  }

  @override
  String get planMoveFrom => 'From';

  @override
  String get planMoveTo => 'To';

  @override
  String get planMoveAmount => 'Amount';

  @override
  String get planMoveChoose => 'Choose a category';

  @override
  String planMoveLeft(String amount) {
    return '$amount left';
  }

  @override
  String planMoveOverspent(String amount) {
    return '$amount overspent';
  }

  @override
  String get planMoveButton => 'Move';

  @override
  String get planMoveEnterAmount => 'Enter an amount';

  @override
  String planMoveWarn(String category, String left, String short) {
    return '$category has $left left. After this, it will be $short overspent.';
  }

  @override
  String planMoveWarnOver(String category, String over, String short) {
    return '$category is $over overspent. After this, it will be $short overspent.';
  }

  @override
  String planMoveWarnNotAssigned(String amount, String over) {
    return 'Only $amount is not assigned. After this, you will have assigned $over too much.';
  }

  @override
  String planMoved(String amount, String from, String to) {
    return 'Moved $amount from $from to $to';
  }

  @override
  String planMoveUndo(String amount, String from, String to) {
    return 'Move $amount from $from to $to';
  }

  @override
  String planMovedMore(String amount, String category) {
    return 'Assigned $amount more to $category';
  }

  @override
  String planMovedBack(String amount, String category) {
    return 'Moved $amount from $category back to not assigned';
  }

  @override
  String planMoveBackUndo(String amount, String category) {
    return 'Move $amount from $category back to not assigned';
  }

  @override
  String get planMoveOutTip => 'Click to move this money to another category';

  @override
  String get planMoveInTip => 'Click to move money in from another category';

  @override
  String get planMoveMoney => 'Move money';

  @override
  String get planMoveSwap => 'Swap';

  @override
  String get planMoveSwapTip => 'Move money the other way';

  @override
  String planOnceMonth(String month) {
    return 'Just for $month';
  }

  @override
  String planOncePay(String date) {
    return 'Just for the pay period from $date';
  }

  @override
  String planSkipMonth(String month) {
    return 'Skip $month';
  }

  @override
  String get planSkipPay => 'Skip this pay period';

  @override
  String planOnceBackMonth(String amount, String next) {
    return 'Back to $amount in $next.';
  }

  @override
  String planOnceSkippedMonth(String month, String amount, String next) {
    return 'Nothing set aside in $month. Back to $amount in $next.';
  }

  @override
  String planOnceBackPay(String amount, String date) {
    return 'Back to $amount from $date.';
  }

  @override
  String planOnceSkippedPay(String amount, String date) {
    return 'Nothing set aside that pay period. Back to $amount from $date.';
  }

  @override
  String planOnceMonthLine(String amount, String month, String usual) {
    return '$amount in $month only, then $usual a month';
  }

  @override
  String planOncePayLine(String amount, String usual) {
    return '$amount this pay period only, then $usual each pay period';
  }

  @override
  String planSkippedMonth(String month, String usual) {
    return 'Skipped in $month, then $usual a month';
  }

  @override
  String planSkippedPay(String usual) {
    return 'Skipped this pay period, then $usual each pay period';
  }

  @override
  String get planGroup => 'Group';

  @override
  String get planNewGroup => 'New group…';

  @override
  String get planNoGroup => 'No group';

  @override
  String get planGroupName => 'Group name';

  @override
  String get planNote => 'Note';

  @override
  String planClearMonth(String month) {
    return 'Clear $month’s Assigned';
  }

  @override
  String get planClearPay => 'Clear this pay period’s Assigned';

  @override
  String planClearMonthTitle(String month) {
    return 'Clear $month’s Assigned?';
  }

  @override
  String get planClearPayTitle => 'Clear this pay period’s Assigned?';

  @override
  String planClearBody(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$amount comes out of $count categories.',
      one: '$amount comes out of 1 category.',
    );
    return '$_temp0';
  }

  @override
  String planClearShortMonth(String month) {
    return 'What’s spent stays spent, so these end $month short:';
  }

  @override
  String get planClearShortPay =>
      'What’s spent stays spent, so these end this pay period short:';

  @override
  String planClearMore(int count) {
    return 'and $count more';
  }

  @override
  String get planClear => 'Clear';

  @override
  String planClearedMonth(String month, String amount) {
    return 'Cleared $month’s Assigned · $amount';
  }

  @override
  String planClearedPay(String amount) {
    return 'Cleared this pay period’s Assigned · $amount';
  }

  @override
  String planOnceCappedMonth(String cap, String month, String amount) {
    return 'Up to $cap holds $month to $amount.';
  }

  @override
  String planOnceCappedPay(String cap, String amount) {
    return 'Up to $cap holds that pay period to $amount.';
  }

  @override
  String planOnceUsual(String amount) {
    return 'Use $amount';
  }

  @override
  String get planClearBack => 'It all goes back to Not assigned.';

  @override
  String planClearPart(String freed, String covering) {
    return 'Not assigned goes up $freed; $covering was covering what was already spent.';
  }

  @override
  String planClearLaterMonth(String month, String amount) {
    return 'What carried into $month goes too: its categories end $month with $amount less.';
  }

  @override
  String planClearLaterPay(String amount) {
    return 'What carried into this pay period goes too: its categories end it with $amount less.';
  }

  @override
  String planClearFromTo(String before, String after) {
    return '$before → $after';
  }

  @override
  String get planClearBills => 'These bills lose what was set aside for them:';

  @override
  String planClearSafetyNet(String amount) {
    return 'The Safety net keeps its $amount.';
  }

  @override
  String planClearMonthIn(String month, String code) {
    return 'Clear $month’s Assigned in $code';
  }

  @override
  String planClearPayIn(String code) {
    return 'Clear this pay period’s Assigned in $code';
  }

  @override
  String get phoneDemoNote =>
      'Made-up figures for a look around. Nothing here is saved.';

  @override
  String planDebtsPaidOff(int paid, int all, String left) {
    return '$paid of $all debts paid off · $left to go';
  }

  @override
  String planPaidOffOf(String paid, String most) {
    return '$paid of $most paid off';
  }

  @override
  String get planPayAdd => 'Add what you pay a month';

  @override
  String planPays(String amount) {
    return 'Pays $amount a month';
  }

  @override
  String planPaysFrom(String amount, String category) {
    return 'Pays $amount a month, from $category';
  }

  @override
  String planPayLately(String amount) {
    return 'Lately about $amount a month went into it.';
  }

  @override
  String planPayUse(String amount) {
    return 'Use $amount';
  }

  @override
  String get planPayEmptyToRemove => 'Leave it empty to remove it.';

  @override
  String get planPayWrong => 'Type an amount, like 150,000.';

  @override
  String planPaySet(String name, String amount) {
    return '$name pays $amount a month';
  }

  @override
  String planPayRemoved(String name) {
    return 'Monthly payment taken off $name';
  }

  @override
  String planPayOnlyInterest(String amount) {
    return '$amount a month only covers its interest.';
  }

  @override
  String get planExtraLabel => 'Extra each month, on top of the payments';

  @override
  String get planExtraNone => 'None';

  @override
  String get planExtraEmptyToRemove => 'Leave it empty for none.';

  @override
  String planExtraSet(String amount) {
    return 'Extra each month: $amount';
  }

  @override
  String get planExtraRemoved => 'No extra each month';

  @override
  String planPlanNeedsPay(String names) {
    return 'To see when it’s all paid off, add what you pay a month on $names.';
  }

  @override
  String get planMethodSmallest => 'Smallest first';

  @override
  String get planMethodRate => 'Highest rate first';

  @override
  String get planMethodSmallestUndo => 'Paying off smallest first';

  @override
  String get planMethodRateUndo => 'Paying off highest rate first';

  @override
  String planPlanDone(String month) {
    return 'Everything paid off in $month';
  }

  @override
  String planPlanInterest(String amount) {
    return 'About $amount in interest';
  }

  @override
  String planPlanFirst(String name, String month) {
    return 'First paid off: $name, $month';
  }

  @override
  String get planPlanNever => 'Not paid off within 30 years at these payments';

  @override
  String planPlanOne(String month, String amount) {
    return 'Everything paid off in $month, with about $amount in interest.';
  }

  @override
  String planPlanOneNoInterest(String month) {
    return 'Everything paid off in $month.';
  }

  @override
  String get planPlanNeedRates =>
      'Add each debt’s rate to compare paying the highest rate first.';

  @override
  String planPlanPicked(String name) {
    return 'You picked $name to pay extra on first, so neither way is marked. Click one to follow it instead.';
  }

  @override
  String planPlanNoRate(String names) {
    return 'No rate on $names, so the dates may come too early.';
  }

  @override
  String get planPlanAssume =>
      'If you keep paying these amounts and add nothing new to the cards.';

  @override
  String planRateSaves(String amount) {
    return 'Highest rate first saves about $amount in interest.';
  }

  @override
  String planSmallestSaves(String amount) {
    return 'Smallest first saves about $amount in interest.';
  }

  @override
  String get planBothEndSame => 'Both end the same month.';

  @override
  String planRateEndsSooner(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: 'a month',
    );
    return 'Highest rate first ends $_temp0 sooner.';
  }

  @override
  String planSmallestEndsSooner(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: 'a month',
    );
    return 'Smallest first ends $_temp0 sooner.';
  }

  @override
  String planSmallestFirstSooner(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: 'a month',
    );
    return 'Smallest first clears your first debt $_temp0 sooner.';
  }

  @override
  String planRateFirstSooner(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: 'a month',
    );
    return 'Highest rate first clears your first debt $_temp0 sooner.';
  }

  @override
  String planPayOnlyInterestNext(String amount) {
    return '$amount a month only covers its interest. It goes down once another debt’s payment moves to it.';
  }

  @override
  String planPayBelowInterest(String amount) {
    return '$amount a month is less than its interest, so what it owes grows.';
  }

  @override
  String planPayBelowInterestNext(String amount) {
    return '$amount a month is less than its interest, so what it owes grows until another debt’s payment moves to it.';
  }

  @override
  String get planOnlyRateEnds =>
      'Only highest rate first pays it all off within 30 years.';

  @override
  String get planOnlySmallestEnds =>
      'Only smallest first pays it all off within 30 years.';

  @override
  String planPlanCharged(String amount, String name) {
    return '$amount went on $name in the last three months. These dates count none of it.';
  }

  @override
  String get planPlanNetFirst =>
      'Your safety net comes first. Until it’s full, the extra waits, so these dates come later than shown.';

  @override
  String planPlanExtraTo(String name) {
    return 'The extra goes to $name first.';
  }
}
