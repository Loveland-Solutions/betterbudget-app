// Invented figures for the phone's screens: the preview build, and the demo
// key Google Play's reviewers type on the start screen (#100 follow-up; ADR
// 0005 "A demo key for Play's review"). Nothing about them is real.
import '../../domain/phone.dart';

/// Typed on the recovery key screen, opens the phone on [previewSnapshot]
/// with nothing read or saved. A real key never holds an O, so this can't
/// be anyone's.
const phoneDemoKey = 'DEMO-DEMO-DEMO-DEMO-DEMO';

/// Whether [typed] is [phoneDemoKey], however it was spaced or capitalised.
bool isPhoneDemoKey(String typed) =>
    typed.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '') ==
    phoneDemoKey.replaceAll('-', '');

/// The demo ledger's categories and accounts (`data/demo_seed.dart`), with
/// made-up amounts.
PhoneSnapshot previewSnapshot(DateTime madeAt) => PhoneSnapshot(
  madeAt: madeAt,
  payees: const [
    'Nomin',
    'E-Mart',
    'Good Price',
    'UB Cab',
    'Petrovis',
    'Modern Nomads',
    'Rosewood',
    'Unitel',
    'Zaisan Residence',
  ],
  // A pay into TDB, offered by name for money in (#187).
  pays: [PhonePay(id: phonePayId(1), accountId: 'tdb', name: 'Salary')],
  accounts: const [
    PhoneAccount(id: 'tdb', name: 'TDB Checking', balanceMinor: 243180000),
    PhoneAccount(id: 'cash', name: 'Cash wallet', balanceMinor: 8600000),
    PhoneAccount(
      id: 'visa',
      name: 'Golomt Visa',
      balanceMinor: 31200000,
      owes: true,
    ),
  ],
  categories: [
    const PhoneCategory(
      id: 'groceries',
      name: 'Groceries',
      leftMinor: 14800000,
      hadMinor: 90000000,
      paidFromId: 'tdb',
      recentPayees: ['Nomin', 'E-Mart', 'Good Price'],
    ),
    PhoneCategory(
      id: 'transport',
      name: 'Transport',
      leftMinor: 6150000,
      hadMinor: 20000000,
      paidFromId: 'cash',
      recentPayees: ['UB Cab', 'Petrovis'],
    ),
    PhoneCategory(
      id: 'eating-out',
      name: 'Eating out',
      leftMinor: -1840000,
      hadMinor: 8000000,
      paidFromId: 'visa',
      recentPayees: ['Modern Nomads', 'Rosewood'],
    ),
    PhoneCategory(
      id: 'phone',
      name: 'Phone & internet',
      leftMinor: 0,
      hadMinor: 6000000,
      paidFromId: 'tdb',
      recentPayees: ['Unitel'],
    ),
    PhoneCategory(
      id: 'rent',
      name: 'Rent',
      leftMinor: 180000000,
      paidFromId: 'tdb',
      recentPayees: const ['Zaisan Residence'],
      due: DateTime(madeAt.year, madeAt.month, 20),
    ),
    PhoneCategory(
      id: 'utilities',
      name: 'Utilities',
      leftMinor: 9600000,
      hadMinor: 12000000,
      paidFromId: 'tdb',
    ),
    PhoneCategory(
      id: 'clothing',
      name: 'Clothing',
      leftMinor: 8000000,
      hadMinor: 8000000,
    ),
  ],
);
