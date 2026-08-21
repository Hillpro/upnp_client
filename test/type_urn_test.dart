import 'package:test/test.dart';
import 'package:upnp_client/src/types/type_urn.dart';

void main() {
  group('baseTypeUrn', () {
    test('strips the trailing version, keeping the colon', () {
      expect(
        baseTypeUrn('urn:schemas-upnp-org:service:AVTransport:1'),
        'urn:schemas-upnp-org:service:AVTransport:',
      );
      expect(
        baseTypeUrn('urn:schemas-upnp-org:device:MediaRenderer:23'),
        'urn:schemas-upnp-org:device:MediaRenderer:',
      );
    });

    test('strips only the trailing version segment', () {
      // The pattern is anchored to the end, so digits inside a type name
      // survive and only the version is removed.
      expect(
        baseTypeUrn('urn:schemas-upnp-org:service:WANIPConnection2:1'),
        'urn:schemas-upnp-org:service:WANIPConnection2:',
      );
    });

    test('passes through a URN with no version', () {
      expect(
        baseTypeUrn('urn:acme-example:service:Thing'),
        'urn:acme-example:service:Thing',
      );
    });

    test('passes through null', () => expect(baseTypeUrn(null), isNull));
  });
}
