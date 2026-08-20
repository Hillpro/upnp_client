import 'package:test/test.dart';
import 'package:upnp_client/upnp_client.dart';
import 'package:xml/xml.dart';

import 'fixtures.dart';

Device parseDevice({String? url, String? urlBase}) {
  final root = XmlDocument.parse(deviceDescriptionXml).rootElement;
  return Device.fromXml(
    root.getElement('device')!,
    url,
    urlBase ?? root.getElement('URLBase')?.innerText,
  );
}

void main() {
  group('Device.fromXml', () {
    test('rejects XML that is not a <device>', () {
      final root = XmlDocument.parse(deviceDescriptionXml).rootElement;
      expect(() => Device.fromXml(root), throwsA(isA<Exception>()));
    });

    test('parses the description metadata', () {
      final d = parseDevice().description!;
      expect(d.deviceType, 'urn:schemas-upnp-org:device:MediaRenderer:1');
      expect(d.friendlyName, 'Living Room');
      expect(d.manufacturer, 'Acme');
      expect(d.modelName, 'Speaker');
      expect(d.modelNumber, 'S-1');
      expect(d.serialNumber, 'SN123');
      expect(d.upc, '012345678905');
      expect(d.udn, 'uuid:11111111-2222-3333-4444-555555555555');
    });

    test('strips the uuid: prefix from the UDN', () {
      expect(
        parseDevice().description!.uuid,
        '11111111-2222-3333-4444-555555555555',
      );
    });

    test('falls back to the raw UDN when the uuid: prefix is missing', () {
      final xml = XmlDocument.parse(
        '<device><UDN>no-prefix-here</UDN></device>',
      ).rootElement;
      expect(DeviceDescription.fromXml(xml).uuid, 'no-prefix-here');
    });

    test('parses icons', () {
      final icons = parseDevice().description!.icons;
      expect(icons, hasLength(1));
      expect(icons.single.mimetype, 'image/png');
      expect(icons.single.width, 48);
      expect(icons.single.height, 48);
      expect(icons.single.depth, 24);
      expect(icons.single.url, '/icon48.png');
    });

    test('parses services and embedded devices', () {
      final device = parseDevice();
      expect(device.services, hasLength(4));
      expect(device.devices, hasLength(1));
      expect(device.devices.single.description!.friendlyName, 'Embedded');
      expect(device.devices.single.services, hasLength(1));
    });

    test('propagates urlBase to embedded devices', () {
      final device = parseDevice();
      expect(device.urlBase, 'http://192.168.1.50:8080/base/');
      expect(device.devices.single.urlBase, device.urlBase);
    });

    test('falls back to the LOCATION url when URLBase is absent', () {
      final root = XmlDocument.parse(deviceDescriptionXml).rootElement;
      final device = Device.fromXml(
        root.getElement('device')!,
        'http://host/desc.xml',
      );
      expect(device.urlBase, 'http://host/desc.xml');
      expect(
        device.devices.single.urlBase,
        'http://host/desc.xml',
        reason: 'embedded devices inherit the resolved base',
      );
    });
  });

  group('typed service accessors', () {
    test('return the matching typed service', () {
      final device = parseDevice();
      expect(device.avTransportService(), isA<AvTransportService>());
      expect(device.renderingControlService(), isA<RenderingControlService>());
      expect(
        device.connectionManagerService(),
        isA<ConnectionManagerService>(),
      );
    });
  });

  group('equality', () {
    test('two devices with the same UUID are equal', () {
      expect(parseDevice(url: 'http://a/'), parseDevice(url: 'http://b/'));
      expect(
        parseDevice(url: 'http://a/').hashCode,
        parseDevice(url: 'http://b/').hashCode,
      );
    });

    test('UUID-less devices fall back to the location url', () {
      Device bare(String? url) => Device.fromXml(
        XmlDocument.parse(
          '<device><friendlyName>x</friendlyName></device>',
        ).rootElement,
        url,
      );
      expect(bare('http://a/'), bare('http://a/'));
      expect(bare('http://a/').hashCode, bare('http://a/').hashCode);
      expect(bare('http://a/'), isNot(bare('http://b/')));
    });

    test('a device is never equal to a non-device', () {
      expect(parseDevice(), isNot(equals('not a device')));
    });

    test('deduplicates in a Set, as getDevices relies on', () {
      expect({
        parseDevice(url: 'http://a/'),
        parseDevice(url: 'http://b/'),
      }, hasLength(1));
    });
  });

  test('toString includes the type and nested children', () {
    final s = parseDevice().toString();
    expect(s, startsWith('Device{'));
    expect(s, contains('Living Room'));
    expect(s, contains('services:'));
    expect(s, contains('devices:'));
  });
}
