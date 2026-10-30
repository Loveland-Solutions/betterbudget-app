import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Send feedback… (#92): lls.mn's contact form, opened in the browser with
/// the app's version and the system it runs on in the link, and nothing else:
/// never a figure from the ledger. The app makes no connection itself; the
/// browser opens the page, and nothing is sent until the person sends the
/// form. What the link carries is in PRIVACY.md, section 5, and in the
/// website's README, "BetterBudget reports"; change neither without the other.
Uri reportProblemLink({
  required String language,
  required String version,
  required String platform,
  required String os,
}) => Uri.https('lls.mn', '/${language == 'mn' ? 'mn' : 'en'}/contact/', {
  'from': 'betterbudget',
  'version': version,
  'platform': platform,
  'os': os,
});

/// The system's own version, the way a person would read it off their
/// device: `15.1` from the Mac's "Version 15.1 (Build 24B83)", `10.0.26100`
/// from Windows' `"Windows 10 Pro" 10.0 (Build 26100)` (Windows 11 calls
/// itself 10 there; the build tells them apart). Empty when it can't be read.
String systemVersion(String platform, String raw) {
  if (platform == 'windows') {
    final m = RegExp(r'(\d+\.\d+) \(Build (\d+)\)').firstMatch(raw);
    if (m != null) return '${m[1]}.${m[2]}';
  }
  return RegExp(r'\d+(\.\d+)*').firstMatch(raw)?[0] ?? '';
}

/// Android's own version (`15`), asked of the phone: Dart's
/// `operatingSystemVersion` there is the Linux kernel's.
const _system = MethodChannel('betterbudget/system');

/// The app's version (`0.55.0`); empty with no bundle to read (widget tests),
/// which the website takes as an ordinary message.
Future<String> appVersion() async {
  try {
    return (await PackageInfo.fromPlatform()).version;
  } on Exception {
    return '';
  }
}

/// Opens the form in the browser. False when the system wouldn't open it.
Future<bool> openReportProblem({required String language}) async {
  final platform = Platform.operatingSystem;
  String raw;
  try {
    raw = Platform.isAndroid
        ? await _system.invokeMethod<String>('release') ?? ''
        : Platform.operatingSystemVersion;
  } on Exception {
    raw = '';
  }
  final link = reportProblemLink(
    language: language,
    version: await appVersion(),
    platform: platform,
    os: systemVersion(platform, raw),
  );
  try {
    // Never the in-app web view: the person's own browser.
    return await launchUrl(link, mode: LaunchMode.externalApplication);
  } on PlatformException {
    return false;
  }
}
