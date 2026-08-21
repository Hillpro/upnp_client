import 'package:test/test.dart';
import 'package:upnp_client/upnp_client.dart';

void main() {
  group('UpnpDeviceType', () {
    test('builds the URN the spec publishes', () {
      // Asserted against literals on purpose: deriving the expectation from
      // the enum would make a typo in the enum invisible.
      expect(
        UpnpDeviceType.internetGatewayDevice.urn(),
        'urn:schemas-upnp-org:device:InternetGatewayDevice:1',
      );
      expect(
        UpnpDeviceType.wanDevice.urn(),
        'urn:schemas-upnp-org:device:WANDevice:1',
      );
      expect(
        UpnpDeviceType.wanConnectionDevice.urn(),
        'urn:schemas-upnp-org:device:WANConnectionDevice:1',
      );
      expect(
        UpnpDeviceType.mediaRenderer.urn(),
        'urn:schemas-upnp-org:device:MediaRenderer:1',
      );
      expect(
        UpnpDeviceType.mediaServer.urn(),
        'urn:schemas-upnp-org:device:MediaServer:1',
      );
    });

    test('takes an explicit version', () {
      expect(
        UpnpDeviceType.internetGatewayDevice.urn(2),
        'urn:schemas-upnp-org:device:InternetGatewayDevice:2',
      );
    });

    test('baseUrn ends in a colon and carries no version', () {
      expect(
        UpnpDeviceType.mediaRenderer.baseUrn,
        'urn:schemas-upnp-org:device:MediaRenderer:',
      );
      for (final type in UpnpDeviceType.values) {
        expect(type.baseUrn, startsWith('urn:schemas-upnp-org:device:'));
        expect(type.baseUrn, endsWith(':'));
        expect(type.baseUrn, isNot(matches(RegExp(r'\d+:$'))));
      }
    });

    test('parses its own URN at any version', () {
      for (final type in UpnpDeviceType.values) {
        for (final version in [1, 2, 7]) {
          expect(
            UpnpDeviceType.tryParse(type.urn(version)),
            type,
            reason: '${type.typeName} v$version',
          );
        }
      }
    });

    test('returns null for an unknown or malformed type', () {
      expect(
        UpnpDeviceType.tryParse('urn:acme-example:device:Toaster:1'),
        isNull,
      );
      expect(
        UpnpDeviceType.tryParse('urn:schemas-upnp-org:device:LANDevice:1'),
        isNull,
        reason: 'a real type, but not one this package models',
      );
      expect(UpnpDeviceType.tryParse(''), isNull);
      expect(UpnpDeviceType.tryParse(null), isNull);
    });

    test('does not match a service URN of the same name', () {
      expect(
        UpnpDeviceType.tryParse('urn:schemas-upnp-org:service:MediaRenderer:1'),
        isNull,
      );
    });
  });

  group('UpnpServiceType', () {
    test('builds the URN the spec publishes', () {
      expect(
        UpnpServiceType.avTransport.urn(),
        'urn:schemas-upnp-org:service:AVTransport:1',
      );
      expect(
        UpnpServiceType.renderingControl.urn(),
        'urn:schemas-upnp-org:service:RenderingControl:1',
      );
      expect(
        UpnpServiceType.connectionManager.urn(),
        'urn:schemas-upnp-org:service:ConnectionManager:1',
      );
      expect(
        UpnpServiceType.contentDirectory.urn(),
        'urn:schemas-upnp-org:service:ContentDirectory:1',
      );
      expect(
        UpnpServiceType.layer3Forwarding.urn(),
        'urn:schemas-upnp-org:service:Layer3Forwarding:1',
      );
      expect(
        UpnpServiceType.wanCommonInterfaceConfig.urn(),
        'urn:schemas-upnp-org:service:WANCommonInterfaceConfig:1',
      );
      expect(
        UpnpServiceType.wanIpConnection.urn(),
        'urn:schemas-upnp-org:service:WANIPConnection:1',
      );
      expect(
        UpnpServiceType.wanPppConnection.urn(),
        'urn:schemas-upnp-org:service:WANPPPConnection:1',
      );
    });

    test('baseUrn ends in a colon and carries no version', () {
      for (final type in UpnpServiceType.values) {
        expect(type.baseUrn, startsWith('urn:schemas-upnp-org:service:'));
        expect(type.baseUrn, endsWith(':'));
        expect(type.baseUrn, isNot(matches(RegExp(r'\d+:$'))));
      }
    });

    test('parses its own URN at any version', () {
      for (final type in UpnpServiceType.values) {
        for (final version in [1, 2, 7]) {
          expect(
            UpnpServiceType.tryParse(type.urn(version)),
            type,
            reason: '${type.typeName} v$version',
          );
        }
      }
    });

    test('returns null for an unknown type', () {
      expect(
        UpnpServiceType.tryParse(
          'urn:schemas-upnp-org:service:SomethingElse:1',
        ),
        isNull,
      );
      expect(UpnpServiceType.tryParse(null), isNull);
    });

    test('every type name is distinct', () {
      final names = UpnpServiceType.values.map((t) => t.typeName).toSet();
      expect(names, hasLength(UpnpServiceType.values.length));
    });
  });
}
