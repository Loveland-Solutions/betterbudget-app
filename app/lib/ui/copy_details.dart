// Copy, beside a failure's opened Details (#293): what went wrong, on the
// clipboard, for the person to paste into lls.mn's form (#92) themselves.
// They've seen it first, so nothing new leaves the app with the link.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'language.dart';
import 'theme.dart';

/// What Copy puts on the clipboard: the line the person saw, then the
/// technical reason behind Details.
String failureReport(String message, String details) => '$message\n\n$details';

/// A quiet Copy that says Copied for a moment once it has. No popup: those
/// are for saved changes.
class CopyDetails extends StatefulWidget {
  const CopyDetails({super.key, required this.text, required this.color});
  final String text;
  final Color color;

  @override
  State<CopyDetails> createState() => _CopyDetailsState();
}

class _CopyDetailsState extends State<CopyDetails> {
  bool _copied = false;
  Timer? _back;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    _back?.cancel();
    setState(() => _copied = true);
    _back = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _back?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextButton(
    key: const ValueKey('copy-details'),
    onPressed: _copy,
    style: TextButton.styleFrom(
      foregroundColor: widget.color,
      // A Mac draws buttons 8 shorter otherwise.
      visualDensity: VisualDensity.standard,
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(
      _copied ? context.t.detailsCopied : context.t.detailsCopy,
      style: onest(13, weight: 600, color: widget.color),
    ),
  );
}
