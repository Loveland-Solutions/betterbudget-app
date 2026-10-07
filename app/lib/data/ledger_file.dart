// What the ledger's files are called. Every file this app writes a ledger into
// ends in `.betterbudget` (owner, 2026-10-07: not `.sqlite`, and all of them or
// none): the file it works in, the daily copies, "Back up to…" files, the
// copies made around a restore or an upgrade, and the ledger in a cloud folder.
// Files made under the earlier names are still found, opened and cleared away;
// only the file the app works in is renamed, once, by [ledgerFileIn].
import 'dart:io';

/// The end of every ledger file's name, without the point.
const ledgerExtension = 'betterbudget';

/// What ledger files ended in until 2026-10-07.
const earlierLedgerExtension = 'sqlite';

/// The file the app works in, in its own folder.
const ledgerFileName = 'Ledger.$ledgerExtension';

/// That file's name until 2026-10-07.
const earlierLedgerFileName = 'betterbudget.$earlierLedgerExtension';

/// [name] without `.betterbudget` or `.sqlite` on the end.
String withoutLedgerExtension(String name) {
  for (final ext in const [ledgerExtension, earlierLedgerExtension]) {
    if (name.endsWith('.$ext')) {
      return name.substring(0, name.length - ext.length - 1);
    }
  }
  return name;
}

/// The ledger in [dir], which may not exist yet. A ledger still under its
/// earlier name is given the new one first: the same file, renamed, nothing
/// in it read or written. Call it before anything opens the ledger.
///
/// SQLite keeps changes not yet folded into the file in a `-wal` beside it,
/// found by name, so that goes first and the ledger last: stopped at any
/// point, the next launch finds the earlier name still there and carries on.
/// The `-shm` beside them is an index SQLite makes again when it's missing.
Future<File> ledgerFileIn(Directory dir) async {
  final file = File('${dir.path}/$ledgerFileName');
  final earlier = File('${dir.path}/$earlierLedgerFileName');
  // Both there can't come from this rename; the new name is the ledger and
  // the earlier file is left alone for a person to look at.
  if (!earlier.existsSync() || file.existsSync()) return file;
  final wal = File('${earlier.path}-wal');
  if (wal.existsSync()) await wal.rename('${file.path}-wal');
  final shm = File('${earlier.path}-shm');
  if (shm.existsSync()) await shm.delete();
  await earlier.rename(file.path);
  return file;
}
