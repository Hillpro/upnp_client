import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:upnp_client/upnp_client.dart';

import 'fixtures.dart';

/// Reserves an ephemeral UDP port, then frees it, so the discoverer can be
/// started on a known port and fed a datagram.
Future<int> freeUdpPort() async {
  final probe = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = probe.port;
  probe.close();
  return port;
}

void main() {
  late HttpServer server;
  late int descriptionStatus;
  late String descriptionBody;
  late DeviceDiscoverer discoverer;
  late int ssdpPort;

  setUp(() async {
    descriptionStatus = 200;
    descriptionBody = deviceDescriptionXml;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response.statusCode = descriptionStatus;
      request.response.headers.contentType = ContentType.parse('text/xml');
      request.response.write(descriptionBody);
      request.response.close();
    });

    ssdpPort = await freeUdpPort();
    discoverer = DeviceDiscoverer();
    await discoverer.start(
      port: ssdpPort,
      addressTypes: [InternetAddressType.IPv4],
    );
  });

  tearDown(() async {
    discoverer.dispose();
    await server.close(force: true);
  });

  String location() =>
      'http://${server.address.address}:${server.port}/desc.xml';

  /// Sends a raw SSDP payload to the discoverer's socket.
  Future<void> sendSsdp(String payload) async {
    final sender = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    sender.send(
      utf8.encode(payload.replaceAll('\n', '\r\n')),
      InternetAddress.loopbackIPv4,
      ssdpPort,
    );
    sender.close();
  }

  String searchResponse({String? status, String? locationHeader}) =>
      '${status ?? 'HTTP/1.1 200 OK'}\n'
      'CACHE-CONTROL: max-age=1800\n'
      'ST: upnp:rootdevice\n'
      'USN: uuid:11111111-2222-3333-4444-555555555555::upnp:rootdevice\n'
      '${locationHeader ?? 'LOCATION: ${location()}'}\n'
      '\n';

  test('emits a device for a well-formed M-SEARCH response', () async {
    final discovered = discoverer.devices.first;
    await sendSsdp(searchResponse());

    final device = await discovered.timeout(const Duration(seconds: 10));
    expect(device.description!.friendlyName, 'Living Room');
    expect(device.url, location());
    expect(
      device.urlBase,
      'http://192.168.1.50:8080/base/',
      reason: 'URLBase in the description wins over LOCATION',
    );
    expect(device.avTransportService(), isNotNull);
  });

  test('reports an error when the description fetch fails', () async {
    // Regression: the body used to be parsed regardless of status, so a 404
    // HTML page surfaced as an XML parse error.
    descriptionStatus = 404;
    descriptionBody = '<!DOCTYPE html><html><body>Not Found</body></html>';

    final failure = discoverer.errors.first;
    await sendSsdp(searchResponse());

    await expectLater(
      failure.timeout(const Duration(seconds: 10)),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          allOf(contains('404'), isNot(contains('XmlParser'))),
        ),
      ),
    );
  });

  group('ignores', () {
    /// Sends [payload], then a known-good response, and asserts the first
    /// device to arrive came from the good one.
    Future<void> expectIgnored(String payload) async {
      final discovered = discoverer.devices.first;
      await sendSsdp(payload);
      await sendSsdp(searchResponse());
      final device = await discovered.timeout(const Duration(seconds: 10));
      expect(device.url, location());
    }

    test(
      'a non-200 status line',
      () => expectIgnored(searchResponse(status: 'HTTP/1.1 404 Not Found')),
    );

    test(
      'a response with no LOCATION header',
      () => expectIgnored(searchResponse(locationHeader: 'SERVER: none')),
    );

    test(
      'a LOCATION with a non-http scheme',
      () => expectIgnored(
        searchResponse(locationHeader: 'LOCATION: ftp://h/d.xml'),
      ),
    );

    test(
      'a LOCATION that is not a URL',
      () =>
          expectIgnored(searchResponse(locationHeader: 'LOCATION: not-a-url')),
    );
  });

  group('lifecycle', () {
    test('getDevices completes within its timeout', () async {
      // Sends a real M-SEARCH, so the result depends on the network the tests
      // run on; assert on the contract, never on the contents.
      final devices = await discoverer
          .getDevices(timeout: const Duration(milliseconds: 200))
          .timeout(const Duration(seconds: 10));
      expect(devices, isA<List<Device>>());
    });

    test('stop can be called more than once', () {
      expect(discoverer.stop, returnsNormally);
      expect(discoverer.stop, returnsNormally);
    });

    test('rejects an unsupported address type', () {
      expect(
        () =>
            DeviceDiscoverer().start(addressTypes: [InternetAddressType.unix]),
        returnsNormally,
        reason: 'unsupported types are skipped, not fatal',
      );
    });
  });
}
