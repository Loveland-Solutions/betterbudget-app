import 'ledger.dart';

/// The first half hour (ADR 0004, "Onboarding"): what the setup keeps in the
/// `Preferences` table while it's open, and when it shows.
abstract final class SetupKeys {
  /// The one day every balance typed in setup is as of, as a date key. Set
  /// when setup first opens, so it also says a setup is under way.
  static const date = 'setup.date';

  /// Set when setup is left for the ledger. It never opens again after.
  static const done = 'setup.done';

  /// The step setup is on, so a quit comes back to it: [stepPay], or unset
  /// for the accounts.
  static const step = 'setup.step';
  static const stepAccounts = 'accounts';
  static const stepPay = 'pay';

  /// Set to [backupOfferNo] once "Open your newest backup?" needn't be asked
  /// again: the recovery key was made here, or the answer was "Start empty".
  static const backupOffer = 'setup.backupOffer';
  static const backupOfferNo = 'no';

  /// The answer to "How do you pay for everyday things?".
  static const everyday = 'setup.everyday';
  static const everydayBank = 'bank';
  static const everydayCash = 'cash';
  static const everydayBoth = 'both';
}

/// Whether the ledger opens on setup: one that's under way, or a ledger that
/// has never had an account. A ledger that had accounts before setup existed
/// has neither key and never sees it, even with its last account deleted:
/// a deleted account is still in [LedgerData.accounts], and only starting a
/// new ledger takes them out.
bool inSetup(LedgerData data) =>
    data.prefs[SetupKeys.done] == null &&
    (data.prefs[SetupKeys.date] != null ||
        !data.accounts.values.any((a) => a.isBalanceSheet));

/// The day setup's balances are as of: the one stored, or [today].
DateTime setupDate(LedgerData data, DateTime today) =>
    switch (data.prefs[SetupKeys.date]) {
      final String key => parseDateKey(key),
      null => today,
    };
