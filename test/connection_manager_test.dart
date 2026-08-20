import 'package:test/test.dart';
import 'package:upnp_client/upnp_client.dart';

void main() {
  group('ProtocolInfo.fromString', () {
    test('parses the four fields', () {
      final p = ProtocolInfo.fromString('http-get:*:audio/mpeg:*');
      expect(p.protocol, 'http-get');
      expect(p.network, '*');
      expect(p.contentFormat, 'audio/mpeg');
      expect(p.additionalInfo, '*');
    });

    test('keeps colons inside additionalInfo', () {
      // Regression: splitting on ':' and demanding exactly 4 parts threw on
      // real DLNA strings, where DLNA.ORG_OP carries a colon.
      final p = ProtocolInfo.fromString(
        'http-get:*:audio/mpeg:DLNA.ORG_PN=MP3;DLNA.ORG_OP=01:01',
      );
      expect(p.contentFormat, 'audio/mpeg');
      expect(p.additionalInfo, 'DLNA.ORG_PN=MP3;DLNA.ORG_OP=01:01');
    });

    test('round-trips through toString', () {
      const raw = 'http-get:*:video/mp4:DLNA.ORG_OP=01:01';
      expect(ProtocolInfo.fromString(raw).toString(), raw);
    });

    test('throws when there are fewer than four fields', () {
      expect(
        () => ProtocolInfo.fromString('http-get:*:audio/mpeg'),
        throwsA(isA<ArgumentError>()),
      );
      expect(() => ProtocolInfo.fromString(''), throwsA(isA<ArgumentError>()));
    });
  });
}
