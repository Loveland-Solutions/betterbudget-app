import 'dart:io';

import 'package:betterbudget/data/report_problem.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the link carries the version and system, in the app’s language', () {
    final link = reportProblemLink(
      language: 'mn',
      version: '0.53.0',
      platform: 'macos',
      os: '15.1',
    );
    expect(
      link.toString(),
      'https://lls.mn/mn/contact/?from=betterbudget&version=0.53.0'
      '&platform=macos&os=15.1',
    );
    expect(
      reportProblemLink(
        language: 'en',
        version: '0.53.0',
        platform: 'android',
        os: '',
      ).path,
      '/en/contact/',
    );
    // A language the website doesn't have gets the English page.
    expect(
      reportProblemLink(
        language: 'de',
        version: '0.53.0',
        platform: 'windows',
        os: '',
      ).path,
      '/en/contact/',
    );
  });

  test('the system’s version as a person reads it', () {
    expect(systemVersion('macos', 'Version 15.1 (Build 24B83)'), '15.1');
    expect(
      systemVersion('windows', '"Windows 10 Pro" 10.0 (Build 26100)'),
      '10.0.26100',
    );
    expect(systemVersion('android', '15'), '15');
    expect(systemVersion('macos', ''), '');
  });

  // The website reads a report only when these fit (lovelandsolutions-website,
  // src/betterbudget/report.ts); anything else sends an ordinary message.
  test('the app’s own version and every platform fit what lls.mn accepts', () {
    final version = RegExp(
      r'^version: (\S+?)(\+\d+)?$',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())![1]!;
    expect(
      version,
      matches(RegExp(r'^\d{1,4}\.\d{1,4}\.\d{1,4}(\+\d{1,9})?$')),
    );
    for (final platform in ['macos', 'windows', 'linux', 'android', 'ios']) {
      final link = reportProblemLink(
        language: 'en',
        version: version,
        platform: platform,
        os: systemVersion(platform, 'Version 15.1 (Build 24B83)'),
      );
      expect(link.queryParameters['os'], matches(RegExp(r'^[\d.]{0,60}$')));
    }
  });
}
