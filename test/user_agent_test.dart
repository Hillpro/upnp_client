import 'dart:io';

import 'package:test/test.dart';
import 'package:upnp_client/src/utils/user_agent.dart';

/// RFC 2616 §3.8: `product = token ["/" product-version]`, and §2.2 bars the
/// separators from a token, so no space, quote, slash or parenthesis.
final productTokenPattern = RegExp(r'^[\w.+-]+(/[\w.+-]+)?$');

void main() {
  group('productToken', () {
    test('collapses the version string Windows reports', () {
      expect(
        productToken('"Windows 11 Home" 10.0 (Build 26200)'),
        'Windows-11-Home-10.0-Build-26200',
      );
    });

    test('collapses the version string Linux reports', () {
      expect(
        productToken(
          'Linux 5.11.0-1018-gcp #20~20.04.2-Ubuntu SMP Fri Sep 3 '
          '01:01:37 UTC 2021',
        ),
        'Linux-5.11.0-1018-gcp-20-20.04.2-Ubuntu-SMP-Fri-Sep-3-01-01-37-'
        'UTC-2021',
      );
    });

    test('leaves an already legal token alone', () {
      expect(productToken('3.8.0'), '3.8.0');
    });

    test('falls back when no legal character is left', () {
      expect(productToken(''), 'unknown');
      expect(productToken('()  ""'), 'unknown');
    });
  });

  group('userAgent', () {
    test(
      'is the three product tokens UDA 1.1 §1.3.2 requires, and no more',
      () {
        final tokens = userAgent.split(' ');

        expect(tokens, hasLength(3));
        expect(tokens[0], matches(RegExp(r'^[\w.+-]+/[\w.+-]+$')));
        expect(tokens[1], 'UPnP/1.1');
        expect(tokens[2], 'upnp_client/$packageVersion');
      },
    );

    test('holds nothing that would end a token early', () {
      for (final token in userAgent.split(' ')) {
        expect(token, matches(productTokenPattern), reason: 'in "$userAgent"');
      }
    });

    test('holds no CR or LF, which would forge a header', () {
      expect(userAgent, isNot(contains('\r')));
      expect(userAgent, isNot(contains('\n')));
    });
  });

  test('packageVersion matches pubspec.yaml', () {
    // `dart test` runs from the package root.
    final version = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((line) => line.startsWith('version:'))
        .split(':')
        .last
        .trim();

    expect(packageVersion, version);
  });
}
