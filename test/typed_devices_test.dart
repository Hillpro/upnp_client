import 'package:test/test.dart';
import 'package:upnp_client/upnp_client.dart';
import 'package:xml/xml.dart';

import 'fixtures.dart';

Device parse(String xml) {
  final root = XmlDocument.parse(xml).rootElement;
  return Device.fromXmlTyped(root.getElement('device')!, 'http://host/d.xml');
}

/// A device description for a bare root device of [deviceType].
Device parseType(String deviceType) => Device.fromXmlTyped(
  XmlDocument.parse(
    '<device><deviceType>$deviceType</deviceType><UDN>uuid:x</UDN></device>',
  ).rootElement,
);

void main() {
  group('Device.fromXmlTyped', () {
    test('dispatches every modelled profile', () {
      expect(
        parseType('urn:schemas-upnp-org:device:InternetGatewayDevice:1'),
        isA<InternetGatewayDevice>(),
      );
      expect(
        parseType('urn:schemas-upnp-org:device:WANDevice:1'),
        isA<WanDevice>(),
      );
      expect(
        parseType('urn:schemas-upnp-org:device:WANConnectionDevice:1'),
        isA<WanConnectionDevice>(),
      );
      expect(
        parseType('urn:schemas-upnp-org:device:MediaRenderer:1'),
        isA<MediaRenderer>(),
      );
      expect(
        parseType('urn:schemas-upnp-org:device:MediaServer:1'),
        isA<MediaServer>(),
      );
    });

    test('matches independently of the profile version', () {
      // UDA 1.1 §1.3.2 - a v2 device must be usable as the v1 it extends.
      expect(
        parseType('urn:schemas-upnp-org:device:InternetGatewayDevice:2'),
        isA<InternetGatewayDevice>(),
      );
      expect(
        parseType('urn:schemas-upnp-org:device:MediaRenderer:3'),
        isA<MediaRenderer>(),
      );
    });

    test('falls back to a plain Device for an unknown profile', () {
      final device = parseType('urn:acme-example:device:Toaster:1');
      expect(device, isA<Device>());
      expect(device.runtimeType, Device);
    });

    test('falls back to a plain Device when deviceType is missing', () {
      final device = Device.fromXmlTyped(
        XmlDocument.parse('<device><UDN>uuid:x</UDN></device>').rootElement,
      );
      expect(device.runtimeType, Device);
    });

    test('rejects XML that is not a <device>', () {
      final root = XmlDocument.parse(igdDescriptionXml).rootElement;
      expect(() => Device.fromXmlTyped(root), throwsA(isA<Exception>()));
    });

    test('types embedded devices even when the parent is built untyped', () {
      // fromXml yields a plain root, but the tree beneath it is still typed.
      final root = XmlDocument.parse(igdDescriptionXml).rootElement;
      final untyped = Device.fromXml(root.getElement('device')!);
      expect(untyped.runtimeType, Device);
      expect(untyped.devices.single, isA<WanDevice>());
    });

    test('propagates urlBase through the typed tiers', () {
      final gateway = parse(igdDescriptionXml) as InternetGatewayDevice;
      final connectionDevice =
          gateway.wanDevices.single.connectionDevices.single;
      expect(connectionDevice.urlBase, 'http://host/d.xml');
    });
  });

  group('InternetGatewayDevice', () {
    late InternetGatewayDevice gateway;

    setUp(() => gateway = parse(igdDescriptionXml) as InternetGatewayDevice);

    test('exposes the tiers IGD:1 Table 1 requires', () {
      expect(gateway.wanDevices, hasLength(1));
      expect(gateway.wanDevices.single.connectionDevices, hasLength(1));
      expect(
        gateway.wanDevices.single.connectionDevices.single.connections,
        hasLength(1),
      );
    });

    test('exposes Layer3Forwarding on the root device', () {
      expect(gateway.layer3Forwarding, isNotNull);
      expect(
        gateway.layer3Forwarding!.type,
        'urn:schemas-upnp-org:service:Layer3Forwarding:1',
      );
    });

    test('exposes WANCommonInterfaceConfig on the WAN tier', () {
      final wan = gateway.wanDevices.single;
      expect(wan.wanCommonInterfaceConfig, isNotNull);
      expect(
        wan.wanCommonInterfaceConfig!.type,
        'urn:schemas-upnp-org:service:WANCommonInterfaceConfig:1',
      );
      expect(
        gateway.layer3Forwarding,
        isNot(wan.wanCommonInterfaceConfig),
        reason: 'each tier reports only its own services',
      );
    });

    test('connections walks the tiers rather than searching the tree', () {
      expect(gateway.connections, hasLength(1));
      expect(gateway.connections.single, isA<WanIpConnectionService>());
    });

    test('connections keeps the owning device reachable', () {
      // Layer3Forwarding's DefaultConnectionService identifies a service by
      // its WANConnectionDevice UDN plus service id, so both must survive.
      final connection = gateway.connections.single;
      expect(connection.id, 'urn:upnp-org:serviceId:WANIPConn1');
      expect(connection.device, isA<WanConnectionDevice>());
      expect(
        connection.device.description!.udn,
        'uuid:22222222-2222-2222-2222-222222222222',
      );
    });

    test('reports empty tiers rather than reaching past them', () {
      // A gateway that does not follow the template reads as empty here; the
      // service is still reachable through findService.
      final flat = Device.fromXmlTyped(
        XmlDocument.parse('''
<device>
  <deviceType>urn:schemas-upnp-org:device:InternetGatewayDevice:1</deviceType>
  <UDN>uuid:flat</UDN>
  <serviceList>
    <service>
      <serviceType>urn:schemas-upnp-org:service:WANIPConnection:1</serviceType>
      <serviceId>urn:upnp-org:serviceId:WANIPConn1</serviceId>
      <SCPDURL>s.xml</SCPDURL>
      <controlURL>c</controlURL>
      <eventSubURL>e</eventSubURL>
    </service>
  </serviceList>
</device>''').rootElement,
      );
      expect(flat, isA<InternetGatewayDevice>());
      expect(
        (flat as InternetGatewayDevice).connections,
        isEmpty,
        reason: 'the service is not where the template puts it',
      );
      expect(
        flat.findService<WanConnectionService>(),
        isNotNull,
        reason: 'the tolerant lookup still finds it',
      );
    });

    test('reports every instance when a tier repeats', () {
      // IGD:1 Table 1 allows several WANConnectionDevice instances per
      // WANDevice, each with its own connection services.
      const second = '''
          <device>
            <deviceType>urn:schemas-upnp-org:device:WANConnectionDevice:1</deviceType>
            <UDN>uuid:33333333-3333-3333-3333-333333333333</UDN>
            <serviceList>
              <service>
                <serviceType>urn:schemas-upnp-org:service:WANPPPConnection:1</serviceType>
                <serviceId>urn:upnp-org:serviceId:WANPPPConn1</serviceId>
                <SCPDURL>WANPPPConn.xml</SCPDURL>
                <controlURL>WANPPPConn/control</controlURL>
                <eventSubURL>WANPPPConn/event</eventSubURL>
              </service>
            </serviceList>
          </device>
        </deviceList>''';
      final twoLinks =
          parse(igdDescriptionXml.replaceFirst('</deviceList>', second))
              as InternetGatewayDevice;

      expect(twoLinks.wanDevices.single.connectionDevices, hasLength(2));
      expect(twoLinks.connections, hasLength(2));
      expect(twoLinks.connections.first, isA<WanIpConnectionService>());
      expect(twoLinks.connections.last, isA<WanPppConnectionService>());
      // Hoisted rather than inline: formatter versions disagree on whether to
      // hug a collection literal that is followed by another argument, so an
      // inline list here formats differently on different SDKs.
      const expectedUdns = [
        'uuid:22222222-2222-2222-2222-222222222222',
        'uuid:33333333-3333-3333-3333-333333333333',
      ];
      expect(
        twoLinks.connections.map((c) => c.device.description!.udn),
        expectedUdns,
        reason: 'each connection stays attributable to its own link',
      );
    });
  });

  group('MediaRenderer', () {
    late MediaRenderer renderer;

    setUp(() {
      final root = XmlDocument.parse(deviceDescriptionXml).rootElement;
      renderer =
          Device.fromXmlTyped(
                root.getElement('device')!,
                null,
                root.getElement('URLBase')?.innerText,
              )
              as MediaRenderer;
    });

    test('exposes the three AV services', () {
      expect(renderer.avTransport, isA<AvTransportService>());
      expect(renderer.renderingControl, isA<RenderingControlService>());
      expect(renderer.connectionManager, isA<ConnectionManagerService>());
    });

    test('reads only its own services, not the embedded device', () {
      expect(renderer.avTransport!.url, 'AVTransport.xml');
    });

    test('returns null for a service the renderer does not advertise', () {
      final bare = parseType('urn:schemas-upnp-org:device:MediaRenderer:1');
      expect((bare as MediaRenderer).avTransport, isNull);
      expect(bare.renderingControl, isNull);
    });
  });

  group('MediaServer', () {
    test('exposes ContentDirectory untyped and ConnectionManager typed', () {
      final server =
          Device.fromXmlTyped(
                XmlDocument.parse('''
<device>
  <deviceType>urn:schemas-upnp-org:device:MediaServer:1</deviceType>
  <UDN>uuid:server</UDN>
  <serviceList>
    <service>
      <serviceType>urn:schemas-upnp-org:service:ContentDirectory:1</serviceType>
      <serviceId>urn:upnp-org:serviceId:ContentDirectory</serviceId>
      <SCPDURL>cds.xml</SCPDURL>
      <controlURL>cds/control</controlURL>
      <eventSubURL>cds/event</eventSubURL>
    </service>
    <service>
      <serviceType>urn:schemas-upnp-org:service:ConnectionManager:1</serviceType>
      <serviceId>urn:upnp-org:serviceId:ConnectionManager</serviceId>
      <SCPDURL>cm.xml</SCPDURL>
      <controlURL>cm/control</controlURL>
      <eventSubURL>cm/event</eventSubURL>
    </service>
  </serviceList>
</device>''').rootElement,
              )
              as MediaServer;
      expect(server.contentDirectory, isNotNull);
      expect(
        server.contentDirectory!.id,
        'urn:upnp-org:serviceId:ContentDirectory',
      );
      expect(server.connectionManager, isA<ConnectionManagerService>());
      expect(
        server.avTransport,
        isNull,
        reason: 'AVTransport is conditional on the transfer protocol',
      );
    });
  });
}
