// The phone screens on invented figures, to look at them on a real phone before
// the Mac can send a snapshot (ADR 0005). Built on its own with
// `flutter build apk --debug -t lib/phone_preview.dart`; `main.dart` doesn't use it.
// Entries saved here live only until the app is closed.
import 'package:flutter/material.dart';

import 'domain/phone.dart';
import 'ui/phone/phone_app.dart';

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

void main() {
  usePhoneColors();
  final now = DateTime.now();
  runApp(
    PhoneApp(
      store: PhoneStore(
        previewSnapshot(DateTime(now.year, now.month, now.day, 8, 10)),
      ),
    ),
  );
}
