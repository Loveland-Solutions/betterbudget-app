import 'dart:convert';
import 'dart:io';

import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:sqlite3/common.dart' show SqliteException;

import 'database.dart' show DbException;
import 'encryption.dart' show CipherException;
import 'report_problem.dart';

/// One problem the app ran into: when, the line the person saw, the
/// technical reason behind Details, and the app's version then.
@immutable
class Problem {
  const Problem({
    required this.at,
    required this.message,
    required this.reason,
    required this.version,
  });
  final DateTime at;
  final String message;
  final String reason;
  final String version;

  Map<String, Object> toJson() => {
    'at': at.toIso8601String(),
    'message': message,
    'reason': reason,
    'version': version,
  };

  static Problem? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = DateTime.tryParse('${json['at']}');
    final message = json['message'], reason = json['reason'];
    if (at == null || message is! String || reason is! String) return null;
    return Problem(
      at: at,
      message: message,
      reason: reason,
      version: json['version'] is String ? json['version'] as String : '',
    );
  }
}

/// What of a technical reason is kept. The record isn't encrypted (it must
/// be read when the ledger won't open), so no amounts go in (owner,
/// 2026-10-27): only errors that carry words, codes and paths keep their
/// text, a database error without the statement and values that follow
/// "Causing statement", and every other only its type, as the failed-start
/// screen's Details do. An app error can name an amount ("Off by 12500"), a
/// plan's text or a bank file's line. A [String] is a reason the caller has
/// already made safe (the failed-start screen's).
String keptReason(Object error) {
  // The ledger's database runs apart from the screen and hands its errors
  // back wrapped.
  if (error is DriftRemoteException) return keptReason(error.remoteCause);
  final text = switch (error) {
    String() ||
    PlatformException() ||
    MissingPluginException() ||
    FileSystemException() ||
    CipherException() ||
    SqliteException() ||
    DbException() => '$error',
    _ => '${error.runtimeType}',
  };
  var kept = text.trim().split('\n').first;
  final at = kept.indexOf('Causing statement');
  if (at >= 0) kept = kept.substring(0, at);
  kept = kept.trim();
  if (kept.endsWith(',')) kept = kept.substring(0, kept.length - 1);
  return kept.length > 400 ? '${kept.substring(0, 400)}…' : kept;
}

/// Recent problems (#294): kept on this device only, never sent, in a plain
/// file beside the app's others so it can be read when the ledger can't.
/// The newest [keep], none older than [days] days. Shown in Settings on a
/// computer and at the foot of Budget on a phone, with Copy all, for the
/// person to paste into Send feedback…'s form. What it holds is said in
/// PRIVACY.md, section 3; change neither without the other.
class ProblemLog extends ChangeNotifier {
  ProblemLog(this.file, {this.now = DateTime.now, this.version = appVersion}) {
    _all = _read();
    // One older than [days] goes from the file too, not only from sight.
    final kept = _kept(_all);
    if (kept.length < _all.length) {
      _all = kept;
      _write();
    }
  }

  static const keep = 100;
  static const days = 90;

  final File file;
  final DateTime Function() now;
  final Future<String> Function() version;
  late List<Problem> _all;

  /// Newest first.
  List<Problem> get recent {
    final since = now().subtract(const Duration(days: days));
    return [
      for (final p in _all.reversed)
        if (p.at.isAfter(since)) p,
    ];
  }

  List<Problem> _read() {
    try {
      if (!file.existsSync()) return [];
      return [
        for (final line in file.readAsLinesSync())
          if (line.trim().isNotEmpty) ?Problem.fromJson(_decode(line)),
      ];
    } on Object catch (e) {
      debugPrint('Reading the record of problems failed: $e');
      return [];
    }
  }

  static Object? _decode(String line) {
    try {
      return jsonDecode(line);
    } on FormatException {
      return null;
    }
  }

  /// Adds one; never throws, since it is called while something already
  /// went wrong.
  Future<void> record(String message, Object reason) async {
    final problem = Problem(
      at: now(),
      message: message,
      reason: keptReason(reason),
      version: await version(),
    );
    _all = _kept([..._all, problem]);
    _write();
    notifyListeners();
  }

  /// The newest [keep], none older than [days] days, oldest first.
  List<Problem> _kept(List<Problem> all) {
    final since = now().subtract(const Duration(days: days));
    final kept = [
      for (final p in all)
        if (p.at.isAfter(since)) p,
    ];
    return kept.length > keep ? kept.sublist(kept.length - keep) : kept;
  }

  void _write() {
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        _all.map((p) => '${jsonEncode(p.toJson())}\n').join(),
      );
    } on Object catch (e) {
      debugPrint('Keeping the record of problems failed: $e');
    }
  }
}

/// How much of lls.mn's form Copy all may fill: the message box takes 5,000
/// characters, and the person needs room to say what they were doing.
const copyAllRoom = 3500;

/// The problems Copy all takes: the newest that fit in [copyAllRoom], and
/// always the newest one.
List<Problem> problemsToCopy(List<Problem> newestFirst) {
  final taken = <Problem>[];
  var used = 0;
  for (final p in newestFirst) {
    final size = _one(p).length + 2;
    if (taken.isNotEmpty && used + size > copyAllRoom) break;
    taken.add(p);
    used += size;
  }
  return taken;
}

/// What Copy all puts on the clipboard: each problem, newest first, with its
/// time and version, a blank line between.
String problemsReport(List<Problem> problems) =>
    problems.map(_one).join('\n\n');

String _one(Problem p) => [
  '${_stamp(p.at)}${p.version.isEmpty ? '' : ' · ${p.version}'}',
  p.message,
  if (p.reason.isNotEmpty) p.reason,
].join('\n');

String _stamp(DateTime at) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${at.year}-${two(at.month)}-${two(at.day)} '
      '${two(at.hour)}:${two(at.minute)}';
}
