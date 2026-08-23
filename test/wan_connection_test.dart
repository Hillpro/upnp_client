// Blanket suppression, tests only: this file reads XML through xml's
// deprecated `namespace` argument (see pubspec.yaml). Safe to widen here
// because it cannot hide this package's own deprecations, which report under
// the separate `deprecated_member_use_from_same_package` name. lib/ keeps
// line-level ignores, where an unrelated deprecation must still surface.
// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:upnp_client/upnp_client.dart';
import 'package:xml/xml.dart';

import 'fixtures.dart';

const _soapNs = 'http://schemas.xmlsoap.org/soap/envelope/';
const _igdNs = 'urn:schemas-upnp-org:service:WANIPConnection:1';

/// A single reply from the fake gateway.
typedef Reply = ({int status, String body});

/// Builds a device description whose only connection service has [serviceType].
String gatewayWith(String serviceType) => igdDescriptionXml.replaceFirst(
  'urn:schemas-upnp-org:service:WANIPConnection:1',
  serviceType,
);

void main() {
  late HttpServer server;
  late List<String> bodies;
  late List<String?> soapActions;
  late List<String> paths;
  late void Function(HttpRequest) respond;
  late Device gateway;

  /// Parses the device description against the fake server's address.
  Device parseGateway([String? xml]) {
    final base = 'http://${server.address.address}:${server.port}/gw/';
    final root = XmlDocument.parse(xml ?? igdDescriptionXml).rootElement;
    return Device.fromXml(root.getElement('device')!, base, base);
  }

  setUp(() async {
    bodies = [];
    soapActions = [];
    paths = [];
    respond = (r) => r.response.close();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      bodies.add(await utf8.decoder.bind(request).join());
      soapActions.add(request.headers.value('soapaction'));
      paths.add(request.uri.path);
      respond(request);
    });
    gateway = parseGateway();
  });

  tearDown(() => server.close(force: true));

  String soapResponse(String inner) =>
      '''
<?xml version="1.0"?>
<s:Envelope xmlns:s="$_soapNs" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>$inner</s:Body>
</s:Envelope>''';

  /// A SOAP fault carrying [errorCode], as a gateway returns with HTTP 500.
  String soapFault(int errorCode) =>
      '''
<?xml version="1.0"?>
<s:Envelope xmlns:s="$_soapNs" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <s:Fault>
      <faultcode>s:Client</faultcode>
      <faultstring>UPnPError</faultstring>
      <detail>
        <UPnPError xmlns="urn:schemas-upnp-org:control-1-0">
          <errorCode>$errorCode</errorCode>
          <errorDescription>Error $errorCode</errorDescription>
        </UPnPError>
      </detail>
    </s:Fault>
  </s:Body>
</s:Envelope>''';

  /// Replies to the nth request with whatever [reply] returns for n.
  void replyByIndex(Reply Function(int index) reply) {
    var index = 0;
    respond = (r) {
      final response = reply(index++);
      r.response.statusCode = response.status;
      r.response.headers.contentType = ContentType.parse('text/xml');
      r.response.write(response.body);
      r.response.close();
    };
  }

  void reply(int status, String body) =>
      replyByIndex((_) => (status: status, body: body));

  /// An empty success response for an action with no `out` arguments.
  void replyEmpty(String action) =>
      reply(200, soapResponse('<u:${action}Response xmlns:u="$_igdNs"/>'));

  Reply entry({
    String remoteHost = '',
    String externalPort = '8080',
    String protocol = 'TCP',
    String internalPort = '9090',
    String internalClient = '192.168.1.10',
    String enabled = '1',
    String description = 'mapping',
    String lease = '0',
  }) => (
    status: 200,
    body: soapResponse('''
<u:GetGenericPortMappingEntryResponse xmlns:u="$_igdNs">
  <NewRemoteHost>$remoteHost</NewRemoteHost>
  <NewExternalPort>$externalPort</NewExternalPort>
  <NewProtocol>$protocol</NewProtocol>
  <NewInternalPort>$internalPort</NewInternalPort>
  <NewInternalClient>$internalClient</NewInternalClient>
  <NewEnabled>$enabled</NewEnabled>
  <NewPortMappingDescription>$description</NewPortMappingDescription>
  <NewLeaseDuration>$lease</NewLeaseDuration>
</u:GetGenericPortMappingEntryResponse>'''),
  );

  /// The action element of the nth captured request.
  XmlElement sentAction(int index) => XmlDocument.parse(
    bodies[index],
  ).rootElement.getElement('Body', namespace: _soapNs)!.childElements.single;

  WanConnectionService connection() =>
      gateway.findService<WanConnectionService>()!;

  group('service typing', () {
    test('WANIPConnection maps to the typed subclass', () {
      expect(connection(), isA<WanIpConnectionService>());
    });

    test('the connection service is not on the root device', () {
      // IGD:1 §2.2 nests it under WANDevice then WANConnectionDevice, so the
      // root-scoped accessors cannot reach it.
      expect(
        gateway.services.whereType<WanConnectionService>(),
        isEmpty,
        reason: 'only Layer3Forwarding sits on the root device',
      );
      expect(gateway.findService<WanConnectionService>(), isNotNull);
    });

    test('WANPPPConnection maps to the PPP subclass', () {
      gateway = parseGateway(
        gatewayWith('urn:schemas-upnp-org:service:WANPPPConnection:1'),
      );
      expect(connection(), isA<WanPppConnectionService>());
    });

    test('both connection services share the base type', () {
      final ppp = parseGateway(
        gatewayWith('urn:schemas-upnp-org:service:WANPPPConnection:1'),
      ).findService<WanConnectionService>();
      expect(ppp, isA<WanConnectionService>());
      expect(connection(), isA<WanConnectionService>());
    });

    test('a v2 gateway maps to the same type', () {
      // Service types match version-independently, so IGD:2 devices land here.
      gateway = parseGateway(
        gatewayWith('urn:schemas-upnp-org:service:WANIPConnection:2'),
      );
      expect(connection(), isA<WanIpConnectionService>());
    });
  });

  group('PortMappingProtocol', () {
    test('serialises uppercase, as the allowedValueList requires', () {
      // Table 1.4 permits only TCP and UDP; Dart's `name` is lowercase.
      expect(PortMappingProtocol.tcp.wireValue, 'TCP');
      expect(PortMappingProtocol.udp.wireValue, 'UDP');
    });

    test('parses either case from a device', () {
      expect(PortMappingProtocol.tryParse('TCP'), PortMappingProtocol.tcp);
      expect(PortMappingProtocol.tryParse('udp'), PortMappingProtocol.udp);
    });

    test('returns null for a value outside the allowed list', () {
      expect(PortMappingProtocol.tryParse('SCTP'), isNull);
      expect(PortMappingProtocol.tryParse(''), isNull);
      expect(PortMappingProtocol.tryParse(null), isNull);
    });
  });

  group('addPortMapping', () {
    setUp(() => replyEmpty('AddPortMapping'));

    test('sends every in argument in SCPD order', () async {
      // WANIPConnection:1 Table 16 fixes this order, and UDA 1.1 §3.2.1 makes
      // it normative.
      await connection().addPortMapping(
        externalPort: 8080,
        protocol: PortMappingProtocol.tcp,
        internalPort: 9090,
        internalClient: '192.168.1.10',
        description: 'my mapping',
      );

      final action = sentAction(0);
      expect(action.name.local, 'AddPortMapping');
      expect(action.childElements.map((e) => e.name.local).toList(), [
        'NewRemoteHost',
        'NewExternalPort',
        'NewProtocol',
        'NewInternalPort',
        'NewInternalClient',
        'NewEnabled',
        'NewPortMappingDescription',
        'NewLeaseDuration',
      ]);
    });

    test('sends the protocol uppercase', () async {
      await connection().addPortMapping(
        externalPort: 1,
        protocol: PortMappingProtocol.udp,
        internalPort: 1,
        internalClient: '192.168.1.10',
      );
      expect(sentAction(0).getElement('NewProtocol')!.innerText, 'UDP');
    });

    test(
      'defaults to a wildcard host, enabled, and a permanent lease',
      () async {
        await connection().addPortMapping(
          externalPort: 8080,
          protocol: PortMappingProtocol.tcp,
          internalPort: 9090,
          internalClient: '192.168.1.10',
        );
        final action = sentAction(0);
        expect(action.getElement('NewRemoteHost')!.innerText, isEmpty);
        expect(action.getElement('NewEnabled')!.innerText, '1');
        expect(action.getElement('NewLeaseDuration')!.innerText, '0');
      },
    );

    test('sends a lease in seconds', () async {
      await connection().addPortMapping(
        externalPort: 8080,
        protocol: PortMappingProtocol.tcp,
        internalPort: 9090,
        internalClient: '192.168.1.10',
        leaseDuration: const Duration(minutes: 2),
      );
      expect(sentAction(0).getElement('NewLeaseDuration')!.innerText, '120');
    });

    test('sends a disabled mapping as 0', () async {
      await connection().addPortMapping(
        externalPort: 8080,
        protocol: PortMappingProtocol.tcp,
        internalPort: 9090,
        internalClient: '192.168.1.10',
        enabled: false,
      );
      expect(sentAction(0).getElement('NewEnabled')!.innerText, '0');
    });

    test('resolves the nested controlURL against the base', () async {
      await connection().addPortMapping(
        externalPort: 1,
        protocol: PortMappingProtocol.tcp,
        internalPort: 1,
        internalClient: '192.168.1.10',
      );
      expect(paths.single, '/gw/WANIPConn/control');
      expect(soapActions.single, '"$_igdNs#AddPortMapping"');
    });

    test(
      'propagates a conflict instead of deleting the other mapping',
      () async {
        // 718 means the port belongs to a different internal client. Deleting
        // and retrying would hijack another host's mapping.
        reply(500, soapFault(718));
        await expectLater(
          connection().addPortMapping(
            externalPort: 8080,
            protocol: PortMappingProtocol.tcp,
            internalPort: 9090,
            internalClient: '192.168.1.10',
          ),
          throwsA(
            isA<UPnPException>().having(
              (e) => e.errorCode,
              'errorCode',
              WanConnectionError.conflictInMappingEntry,
            ),
          ),
        );
        expect(bodies, hasLength(1), reason: 'no silent retry');
      },
    );

    test('propagates a lease refusal', () async {
      reply(500, soapFault(725));
      await expectLater(
        connection().addPortMapping(
          externalPort: 8080,
          protocol: PortMappingProtocol.tcp,
          internalPort: 9090,
          internalClient: '192.168.1.10',
          leaseDuration: const Duration(minutes: 5),
        ),
        throwsA(
          isA<UPnPException>().having(
            (e) => e.errorCode,
            'errorCode',
            WanConnectionError.onlyPermanentLeasesSupported,
          ),
        ),
      );
    });

    // Every code AddPortMapping can answer with, asserted against the literal
    // the spec publishes rather than derived from the constant - a typo in the
    // constant would otherwise be invisible. 715, 716, 726 and 727 were absent
    // when this package was audited, which mattered because §2.4.16 warns
    // about exactly the cases 716 and 727 report.
    test('surfaces every AddPortMapping code with its spec number', () async {
      const expected = {
        715: WanConnectionError.wildCardNotPermittedInSrcIp,
        716: WanConnectionError.wildCardNotPermittedInExtPort,
        718: WanConnectionError.conflictInMappingEntry,
        724: WanConnectionError.samePortValuesRequired,
        725: WanConnectionError.onlyPermanentLeasesSupported,
        726: WanConnectionError.remoteHostOnlySupportsWildcard,
        727: WanConnectionError.externalPortOnlySupportsWildcard,
        // WANIPConnection:2 adds these three, and version-independent
        // matching brings a v2 gateway through this same method.
        728: WanConnectionError.noPortMapsAvailable,
        729: WanConnectionError.conflictWithOtherMechanisms,
        732: WanConnectionError.wildCardNotPermittedInIntPort,
      };

      for (final entry in expected.entries) {
        expect(entry.value, entry.key, reason: 'constant value');
        reply(500, soapFault(entry.key));
        await expectLater(
          connection().addPortMapping(
            externalPort: 8080,
            protocol: PortMappingProtocol.tcp,
            internalPort: 9090,
            internalClient: '192.168.1.10',
          ),
          throwsA(
            isA<UPnPException>().having(
              (e) => e.errorCode,
              'errorCode',
              entry.key,
            ),
          ),
          reason: 'code ${entry.key}',
        );
      }
    });

    test('the enumeration codes keep their spec numbers', () {
      // These two are load-bearing: 713 ends a table walk and 714 means "no
      // such mapping", and both are turned into null rather than an exception.
      expect(WanConnectionError.specifiedArrayIndexInvalid, 713);
      expect(WanConnectionError.noSuchEntryInArray, 714);
    });
  });

  group('deletePortMapping', () {
    test('sends only the three identifying arguments, in order', () async {
      replyEmpty('DeletePortMapping');
      await connection().deletePortMapping(
        externalPort: 8080,
        protocol: PortMappingProtocol.tcp,
      );
      final action = sentAction(0);
      expect(action.childElements.map((e) => e.name.local).toList(), [
        'NewRemoteHost',
        'NewExternalPort',
        'NewProtocol',
      ]);
      expect(action.getElement('NewExternalPort')!.innerText, '8080');
    });
  });

  group('getGenericPortMappingEntry', () {
    test('parses a full entry', () async {
      replyByIndex((_) => entry(lease: '3600', remoteHost: '203.0.113.5'));
      final mapping = await connection().getGenericPortMappingEntry(0);
      expect(mapping!.remoteHost, '203.0.113.5');
      expect(mapping.externalPort, 8080);
      expect(mapping.protocol, PortMappingProtocol.tcp);
      expect(mapping.internalPort, 9090);
      expect(mapping.internalClient, '192.168.1.10');
      expect(mapping.enabled, isTrue);
      expect(mapping.description, 'mapping');
      expect(mapping.leaseDuration, const Duration(hours: 1));
    });

    test('sends the index as the only argument', () async {
      replyByIndex((_) => entry());
      await connection().getGenericPortMappingEntry(7);
      expect(sentAction(0).getElement('NewPortMappingIndex')!.innerText, '7');
    });

    test('returns null past the end of the table', () async {
      // 713 SpecifiedArrayIndexInvalid is how a gateway ends an enumeration.
      reply(500, soapFault(713));
      expect(await connection().getGenericPortMappingEntry(99), isNull);
    });

    test('propagates any other fault', () async {
      reply(500, soapFault(501));
      await expectLater(
        connection().getGenericPortMappingEntry(0),
        throwsA(isA<UPnPException>()),
      );
    });

    test('reads a permanent lease as zero, not null', () async {
      replyByIndex((_) => entry(lease: '0'));
      final mapping = await connection().getGenericPortMappingEntry(0);
      expect(mapping!.leaseDuration, Duration.zero);
    });

    test('leaves a malformed port null rather than reading it as 0', () async {
      // 0 is the wildcard external port, so a fallback of 0 would invent a
      // different mapping than the device described.
      replyByIndex((_) => entry(externalPort: 'not-a-port', lease: 'x'));
      final mapping = await connection().getGenericPortMappingEntry(0);
      expect(mapping!.externalPort, isNull);
      expect(mapping.leaseDuration, isNull);
    });

    test('leaves an unknown protocol null', () async {
      replyByIndex((_) => entry(protocol: 'SCTP'));
      final mapping = await connection().getGenericPortMappingEntry(0);
      expect(mapping!.protocol, isNull);
    });

    test('accepts deprecated boolean spellings for NewEnabled', () async {
      for (final raw in ['1', 'true', 'yes']) {
        replyByIndex((_) => entry(enabled: raw));
        final mapping = await connection().getGenericPortMappingEntry(0);
        expect(mapping!.enabled, isTrue, reason: raw);
      }
      replyByIndex((_) => entry(enabled: '0'));
      expect(
        (await connection().getGenericPortMappingEntry(0))!.enabled,
        isFalse,
      );
    });
  });

  group('getSpecificPortMappingEntry', () {
    test('fills the entry in from the arguments it sent', () async {
      // The response carries only the five out arguments.
      reply(
        200,
        soapResponse('''
<u:GetSpecificPortMappingEntryResponse xmlns:u="$_igdNs">
  <NewInternalPort>9090</NewInternalPort>
  <NewInternalClient>192.168.1.10</NewInternalClient>
  <NewEnabled>1</NewEnabled>
  <NewPortMappingDescription>mapping</NewPortMappingDescription>
  <NewLeaseDuration>0</NewLeaseDuration>
</u:GetSpecificPortMappingEntryResponse>'''),
      );
      final mapping = await connection().getSpecificPortMappingEntry(
        externalPort: 8080,
        protocol: PortMappingProtocol.udp,
        remoteHost: '203.0.113.5',
      );
      expect(mapping!.externalPort, 8080);
      expect(mapping.protocol, PortMappingProtocol.udp);
      expect(mapping.remoteHost, '203.0.113.5');
      expect(mapping.internalPort, 9090);
    });

    test('returns null when there is no such mapping', () async {
      reply(500, soapFault(714));
      expect(
        await connection().getSpecificPortMappingEntry(
          externalPort: 8080,
          protocol: PortMappingProtocol.tcp,
        ),
        isNull,
      );
    });
  });

  group('listPortMappings', () {
    test('walks the table until the gateway reports the end', () async {
      replyByIndex(
        (i) => i < 3
            ? entry(externalPort: '${8080 + i}')
            : (status: 500, body: soapFault(713)),
      );
      final mappings = await connection().listPortMappings();
      expect(mappings.map((m) => m.externalPort), [8080, 8081, 8082]);
      expect(bodies, hasLength(4), reason: '3 entries plus the terminator');
    });

    test('reads indices from 0 upwards', () async {
      replyByIndex(
        (i) => i < 2 ? entry() : (status: 500, body: soapFault(713)),
      );
      await connection().listPortMappings();
      expect(
        [
          for (var i = 0; i < 2; i++)
            sentAction(i).getElement('NewPortMappingIndex')!.innerText,
        ],
        ['0', '1'],
      );
    });

    test('returns empty for a gateway with no mappings', () async {
      reply(500, soapFault(713));
      expect(await connection().listPortMappings(), isEmpty);
    });

    test(
      'throws rather than truncate when a device never ends the table',
      () async {
        // Returning the first `limit` entries would be indistinguishable from a
        // complete read of a short table.
        replyByIndex((_) => entry());
        await expectLater(
          connection().listPortMappings(limit: 5),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('did not end within 5 entries'),
            ),
          ),
        );
        expect(bodies, hasLength(5), reason: 'the walk is still bounded');
      },
    );

    test('surfaces an unexpected fault instead of truncating', () async {
      // A short list would look like a complete read.
      replyByIndex(
        (i) => i < 2 ? entry() : (status: 500, body: soapFault(501)),
      );
      await expectLater(
        connection().listPortMappings(),
        throwsA(isA<UPnPException>()),
      );
    });
  });

  group('connection information', () {
    test('getExternalIpAddress returns the address', () async {
      reply(
        200,
        soapResponse(
          '<u:GetExternalIPAddressResponse xmlns:u="$_igdNs">'
          '<NewExternalIPAddress>203.0.113.7</NewExternalIPAddress>'
          '</u:GetExternalIPAddressResponse>',
        ),
      );
      expect(await connection().getExternalIpAddress(), '203.0.113.7');
    });

    test('getStatusInfo parses the uptime as a duration', () async {
      reply(
        200,
        soapResponse('''
<u:GetStatusInfoResponse xmlns:u="$_igdNs">
  <NewConnectionStatus>Connected</NewConnectionStatus>
  <NewLastConnectionError>ERROR_NONE</NewLastConnectionError>
  <NewUptime>3661</NewUptime>
</u:GetStatusInfoResponse>'''),
      );
      final info = await connection().getStatusInfo();
      expect(info.connectionStatus, 'Connected');
      expect(info.lastConnectionError, 'ERROR_NONE');
      expect(info.uptime, const Duration(hours: 1, minutes: 1, seconds: 1));
    });

    test('getNatRsipStatus parses both booleans', () async {
      reply(
        200,
        soapResponse('''
<u:GetNATRSIPStatusResponse xmlns:u="$_igdNs">
  <NewRSIPAvailable>0</NewRSIPAvailable>
  <NewNATEnabled>1</NewNATEnabled>
</u:GetNATRSIPStatusResponse>'''),
      );
      final status = await connection().getNatRsipStatus();
      expect(status.rsipAvailable, isFalse);
      expect(status.natEnabled, isTrue);
    });
  });

  test('PortMapping.toString names the type and fields', () async {
    replyByIndex((_) => entry());
    final mapping = await connection().getGenericPortMappingEntry(0);
    expect(mapping.toString(), startsWith('PortMapping{'));
    expect(mapping.toString(), contains('192.168.1.10'));
  });
}
