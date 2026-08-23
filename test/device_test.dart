import 'package:test/test.dart';
import 'package:upnp_client/upnp_client.dart';
import 'package:xml/xml.dart';

import 'fixtures.dart';

Device parseDevice({String? url, String? urlBase}) {
  final root = XmlDocument.parse(deviceDescriptionXml).rootElement;
  return Device.fromXmlTyped(
    root.getElement('device')!,
    url,
    urlBase ?? root.getElement('URLBase')?.innerText,
  );
}

/// Builds a device with an optional raw UDN and location url.
Device udnDevice(String? udn, String? url) => Device.fromXml(
  XmlDocument.parse(
    udn == null
        ? '<device><friendlyName>x</friendlyName></device>'
        : '<device><UDN>$udn</UDN></device>',
  ).rootElement,
  url,
);

/// A three-level tree of unrecognised device types where only the leaf, two
/// `deviceList` levels down, carries a service. Deliberately not a real
/// profile: it pins [Device.findService] for any nesting, whatever the
/// deviceType. `igdDescriptionXml` covers the typed gateway tiers.
Device nestedDevice() => Device.fromXml(
  XmlDocument.parse('''
<device>
  <deviceType>urn:acme-example:device:Outer:1</deviceType>
  <UDN>uuid:root</UDN>
  <deviceList>
    <device>
      <deviceType>urn:acme-example:device:Middle:1</deviceType>
      <UDN>uuid:wan</UDN>
      <deviceList>
        <device>
          <deviceType>urn:acme-example:device:Inner:1</deviceType>
          <UDN>uuid:wanconn</UDN>
          <serviceList>
            <service>
              <serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
              <serviceId>urn:upnp-org:serviceId:RenderingControl</serviceId>
              <SCPDURL>deep.xml</SCPDURL>
              <controlURL>deep/control</controlURL>
              <eventSubURL>deep/event</eventSubURL>
            </service>
          </serviceList>
        </device>
      </deviceList>
    </device>
  </deviceList>
</device>
''').rootElement,
  'http://gw/desc.xml',
);

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

    // UDA 1.1 §3.2.1 - element names are case sensitive, and these two carry
    // an uppercase URL in every UDA version. Reading them as `manufacturerUrl`
    // and `modelUrl` left both permanently null against real devices, which
    // went unnoticed because the fixture had the same misspelling and no test
    // asserted the fields.
    test('parses the URL metadata, which the spec spells with URL', () {
      final d = parseDevice().description!;
      expect(d.manufacturerUrl, 'http://acme.example');
      expect(d.modelUrl, 'http://acme.example/s1');
    });

    test('ignores lowercase-url spellings no UPnP version defines', () {
      final xml = XmlDocument.parse('''
<device>
  <manufacturerUrl>http://wrong.example</manufacturerUrl>
  <modelUrl>http://wrong.example/m</modelUrl>
</device>''').rootElement;
      final d = DeviceDescription.fromXml(xml);
      expect(d.manufacturerUrl, isNull);
      expect(d.modelUrl, isNull);
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

  group('serviceOfType', () {
    test('finds a service by its UPnP type', () {
      final device = parseDevice();
      expect(
        device.serviceOfType(UpnpServiceType.avTransport)!.url,
        'AVTransport.xml',
      );
    });

    test('matches regardless of the version the device declares', () {
      // The fixture advertises ConnectionManager:2.
      final device = parseDevice();
      expect(
        device.serviceOfType(UpnpServiceType.connectionManager),
        isNotNull,
      );
    });

    test('returns null when the device advertises no such service', () {
      expect(
        parseDevice().serviceOfType(UpnpServiceType.contentDirectory),
        isNull,
      );
    });

    test('is scoped to the receiving device, not its subtree', () {
      // Both the root and the embedded device carry an AVTransport; each must
      // report its own.
      final device = parseDevice();
      expect(
        device.serviceOfType(UpnpServiceType.avTransport)!.url,
        'AVTransport.xml',
      );
      expect(
        device.devices.single.serviceOfType(UpnpServiceType.avTransport)!.url,
        'embedded/AVTransport.xml',
      );
      expect(
        nestedDevice().serviceOfType(UpnpServiceType.renderingControl),
        isNull,
        reason: 'the match is two deviceList levels down',
      );
    });
  });

  group('service tree lookup', () {
    test('allServices walks the whole subtree, root services first', () {
      final device = parseDevice();
      expect(device.services, hasLength(4));
      expect(
        device.allServices,
        hasLength(5),
        reason: "4 on the root device, 1 on the embedded one",
      );
      expect(
        device.allServices.take(4),
        containsAll(device.services),
        reason: 'depth first: own services precede embedded ones',
      );
      expect(device.allServices.last, device.devices.single.services.single);
    });

    test('findService reaches a service two deviceList levels down', () {
      // The lookup the AV accessors cannot do: nothing on the root device.
      final gateway = nestedDevice();
      expect(gateway.services, isEmpty);
      expect(gateway.findService<RenderingControlService>(), isNotNull);
      expect(gateway.findService<RenderingControlService>()!.url, 'deep.xml');
    });

    test('findService returns the shallowest match', () {
      final device = parseDevice();
      expect(
        device.findService<AvTransportService>()!.url,
        'AVTransport.xml',
        reason: 'the root service, not the embedded one',
      );
    });

    test('findService returns null when the subtree has no such service', () {
      expect(nestedDevice().findService<AvTransportService>(), isNull);
    });

    test('findServices returns every match in the subtree', () {
      final urls = parseDevice().findServices<AvTransportService>().map(
        (service) => service.url,
      );
      expect(urls, ['AVTransport.xml', 'embedded/AVTransport.xml']);
    });

    test('findServices is empty rather than null when nothing matches', () {
      expect(nestedDevice().findServices<AvTransportService>(), isEmpty);
    });

    test('findService is the only lookup that leaves the device', () {
      // The profile accessors use singleOrNull on their own services, so
      // recursing would break them on any device that repeats a service type
      // in an embedded device - as the fixture does with AVTransport.
      final renderer = parseDevice() as MediaRenderer;
      expect(renderer.avTransport!.url, 'AVTransport.xml');
      expect(renderer.findServices<AvTransportService>(), hasLength(2));
    });
  });

  group('deprecated service accessors', () {
    // Kept so the typed-profile move is not a breaking change. They must stay
    // on Device, scoped to its own services, exactly as before.
    test('still resolve on a device built through the typed factory', () {
      final device = parseDevice();
      // ignore: deprecated_member_use_from_same_package
      expect(device.avTransportService(), isA<AvTransportService>());
      // ignore: deprecated_member_use_from_same_package
      expect(device.renderingControlService(), isA<RenderingControlService>());
      expect(
        // ignore: deprecated_member_use_from_same_package
        device.connectionManagerService(),
        isA<ConnectionManagerService>(),
      );
    });

    test('agree with the profile accessors that replace them', () {
      final renderer = parseDevice() as MediaRenderer;
      // ignore: deprecated_member_use_from_same_package
      expect(renderer.avTransportService(), renderer.avTransport);
      // ignore: deprecated_member_use_from_same_package
      expect(renderer.renderingControlService(), renderer.renderingControl);
      // ignore: deprecated_member_use_from_same_package
      expect(renderer.connectionManagerService(), renderer.connectionManager);
    });

    test('remain available on a plain Device, as before', () {
      // The embedded device is not a recognised profile, so it has no typed
      // accessors at all - the shim is the only way in for such callers.
      final embedded = parseDevice().devices.single;
      expect(embedded.runtimeType, Device);
      // ignore: deprecated_member_use_from_same_package
      expect(embedded.avTransportService()!.url, 'embedded/AVTransport.xml');
    });

    test('stay scoped to their own device', () {
      // ignore: deprecated_member_use_from_same_package
      expect(nestedDevice().avTransportService(), isNull);
    });
  });

  group('deprecated modelType', () {
    // No UPnP version defines a <modelType> element, so nothing a compliant
    // device sends can reach this field. Kept reading until removal so the
    // deprecation is not itself a breaking change.
    test('still parses an unqualified element, as before', () {
      final xml = XmlDocument.parse(
        '<device><modelType>off-spec value</modelType></device>',
      ).rootElement;
      // ignore: deprecated_member_use_from_same_package
      expect(DeviceDescription.fromXml(xml).modelType, 'off-spec value');
    });

    test('never sees the only form the schema would allow', () {
      // device-1-0.xsd admits vendor elements through
      // <xsd:any namespace="##other">, so a valid extension is qualified.
      final xml = XmlDocument.parse(
        '<device xmlns="urn:schemas-upnp-org:device-1-0" '
        'xmlns:v="http://vendor.example/ext">'
        '<v:modelType>vendor value</v:modelType></device>',
      ).rootElement;
      // ignore: deprecated_member_use_from_same_package
      expect(DeviceDescription.fromXml(xml).modelType, isNull);
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

    test('a device with a UDN never equals one without', () {
      // == used to fall through to the url when only one side had a UDN,
      // returning true while the hash codes differed.
      const url = 'http://192.168.1.50/d.xml';
      final withUdn = udnDevice('uuid:abc', url);
      final withoutUdn = udnDevice(null, url);
      expect(withUdn, isNot(withoutUdn));
      expect(
        [withoutUdn].contains(withUdn),
        {withoutUdn}.contains(withUdn),
        reason: 'List and Set must agree',
      );
    });

    test('a UDN is never confused with a url', () {
      // UDA 1.1 §1.1.4 requires control points to accept malformed UUIDs, so a
      // UDN may itself look like a url. The identity kinds must stay disjoint.
      const url = 'http://192.168.1.50/d.xml';
      expect(udnDevice(url, 'http://other/'), isNot(udnDevice(null, url)));
    });

    test('devices with neither UDN nor url are never equal', () {
      expect(udnDevice(null, null), isNot(udnDevice(null, null)));
    });

    test('== implies equal hashCodes across every identity combination', () {
      const a = 'http://a/', b = 'http://b/';
      final devices = [
        udnDevice('uuid:one', a),
        udnDevice('uuid:one', b),
        udnDevice('uuid:two', a),
        udnDevice(null, a),
        udnDevice(null, b),
        udnDevice(null, null),
      ];
      for (final x in devices) {
        for (final y in devices) {
          if (x == y) {
            expect(
              x.hashCode,
              y.hashCode,
              reason: 'equal devices must share a hashCode',
            );
          }
        }
      }
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
    expect(
      s,
      startsWith('MediaRenderer{'),
      reason: 'the runtime profile, not the base type',
    );
    expect(s, contains('Living Room'));
    expect(s, contains('services:'));
    expect(s, contains('devices:'));
  });
}
