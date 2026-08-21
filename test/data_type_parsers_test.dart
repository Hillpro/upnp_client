import 'dart:convert';

import 'package:test/test.dart';
import 'package:upnp_client/src/types/data_type.dart';
import 'package:upnp_client/src/types/data_type_parsers.dart';

void main() {
  group('parseUpnpSeconds', () {
    test('reads a seconds count as a Duration', () {
      expect(parseUpnpSeconds('0'), Duration.zero);
      expect(parseUpnpSeconds('3661'), const Duration(seconds: 3661));
    });

    test('is null for a missing or non-integer value', () {
      expect(parseUpnpSeconds(null), isNull);
      expect(parseUpnpSeconds(''), isNull);
      expect(parseUpnpSeconds('1.5'), isNull);
      expect(parseUpnpSeconds('soon'), isNull);
    });

    test('distinguishes zero from absent', () {
      // A permanent port mapping reports 0; both must not read alike.
      expect(parseUpnpSeconds('0'), isNotNull);
      expect(parseUpnpSeconds(null), isNull);
    });
  });

  group('parseUpnpBool', () {
    test('accepts the canonical UDA 1.1 value', () {
      expect(parseUpnpBool('1'), isTrue);
      expect(parseUpnpBool('0'), isFalse);
    });

    test('accepts the deprecated UDA 1.0 spellings', () {
      expect(parseUpnpBool('true'), isTrue);
      expect(parseUpnpBool('yes'), isTrue);
      expect(parseUpnpBool('false'), isFalse);
      expect(parseUpnpBool('no'), isFalse);
    });

    test('is false for null and unknown values', () {
      expect(parseUpnpBool(null), isFalse);
      expect(parseUpnpBool(''), isFalse);
      expect(
        parseUpnpBool('TRUE'),
        isFalse,
        reason: 'values are case sensitive',
      );
    });
  });

  group('parseUpnpTime', () {
    test('parses HH:MM:SS', () {
      expect(
        parseUpnpTime('01:02:03'),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
    });

    test('parses HH:MM without seconds', () {
      expect(parseUpnpTime('04:05'), const Duration(hours: 4, minutes: 5));
    });

    test('parses a fractional part as milliseconds', () {
      expect(
        parseUpnpTime('00:00:01.5'),
        const Duration(seconds: 1, milliseconds: 500),
      );
      expect(
        parseUpnpTime('00:00:01.25'),
        const Duration(seconds: 1, milliseconds: 250),
      );
    });

    test('strips the timezone suffix', () {
      const expected = Duration(hours: 12, minutes: 30);
      expect(parseUpnpTime('12:30:00Z'), expected);
      expect(parseUpnpTime('12:30:00+02:00'), expected);
      expect(parseUpnpTime('12:30:00-05:00'), expected);
    });

    test('returns null on malformed input', () {
      expect(parseUpnpTime(null), isNull);
      expect(parseUpnpTime(''), isNull);
      expect(parseUpnpTime('12'), isNull);
      expect(parseUpnpTime('aa:bb:cc'), isNull);
    });
  });

  group('parseUpnpBase64', () {
    test('decodes a plain value', () {
      expect(parseUpnpBase64(base64.encode([1, 2, 3])), [1, 2, 3]);
    });

    test('tolerates the CRLF line breaks MIME base64 inserts', () {
      final payload = List<int>.generate(120, (i) => i);
      final wrapped = RegExp(
        '.{1,76}',
      ).allMatches(base64.encode(payload)).map((m) => m[0]).join('\r\n');
      expect(parseUpnpBase64(wrapped), payload);
    });

    test('returns null on invalid input', () {
      expect(parseUpnpBase64(null), isNull);
      expect(parseUpnpBase64('!!!not base64!!!'), isNull);
    });
  });

  group('parseUpnpHex', () {
    test('decodes hex octets in either case', () {
      expect(parseUpnpHex('00FF10'), [0, 255, 16]);
      expect(parseUpnpHex('00ff10'), [0, 255, 16]);
    });

    test('ignores whitespace', () {
      expect(parseUpnpHex('00 FF\n10'), [0, 255, 16]);
    });

    test('returns null on odd length, empty or non-hex input', () {
      expect(parseUpnpHex(null), isNull);
      expect(parseUpnpHex(''), isNull);
      expect(parseUpnpHex('ABC'), isNull);
      expect(parseUpnpHex('ZZ'), isNull);
    });
  });

  group('DataType', () {
    test('wire values match UDA 1.1 Table 2-5', () {
      // Regression: fixed_14_4 was 'float.14.4', so it never matched.
      expect(DataType.fixed_14_4.value, 'fixed.14.4');
      expect(DataType.bin_base64.value, 'bin.base64');
      expect(DataType.bin_hex.value, 'bin.hex');
      expect(DataType.dateTime_tz.value, 'dateTime.tz');
      expect(DataType.time_tz.value, 'time.tz');
    });

    test('every value is distinct', () {
      final values = DataType.values.map((d) => d.value).toList();
      expect(values.toSet().length, values.length);
    });
  });
}
