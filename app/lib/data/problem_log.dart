import 'dart:convert';
import 'dart:io';

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
/// person to paste into Report a problem…'s form. What it holds is said in
/// PRIVACY.md, section 3; change neither without the other.
class ProblemLog extends ChangeNotifier {
  ProblemLog(this.file, {this.now = DateTime.now, this.version = appVersion}) {
    _all = _read();
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
    final since = now().subtract(const Duration(days: days));
    final kept = [
      for (final p in _all)
        if (p.at.isAfter(since)) p,
      problem,
    ];
    _all = kept.length > keep ? kept.sublist(kept.length - keep) : kept;
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        _all.map((p) => '${jsonEncode(p.toJson())}\n').join(),
      );
    } on Object catch (e) {
      debugPrint('Keeping a problem in the record failed: $e');
    }
    notifyListeners();
  }
}

/// What Copy all puts on the clipboard: each problem, newest first, with its
/// time and version, a blank line between.
String problemsReport(List<Problem> problems) => [
  for (final p in problems)
    [
      '${_stamp(p.at)}${p.version.isEmpty ? '' : ' · ${p.version}'}',
      p.message,
      if (p.reason.isNotEmpty) p.reason,
    ].join('\n'),
].join('\n\n');

String _stamp(DateTime at) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${at.year}-${two(at.month)}-${two(at.day)} '
      '${two(at.hour)}:${two(at.minute)}';
}
