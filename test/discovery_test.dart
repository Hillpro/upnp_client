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
  ///
  /// [RawDatagramSocket.send] returns a short count when the socket is not
  /// yet writable, and the datagram is *not* queued - the call has to be
  /// retried or the payload is silently lost. That loss is invisible on an
  /// idle machine and intermittent on a loaded CI runner.
  Future<void> sendSsdp(String payload) async {
    final data = utf8.encode(payload.replaceAll('\n', '\r\n'));
    final sender = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    try {
      for (var attempt = 0; attempt < 100; attempt++) {
        final sent = sender.send(data, InternetAddress.loopbackIPv4, ssdpPort);
        if (sent == data.length) return;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      fail('SSDP payload could not be sent after 100 attempts');
    } finally {
      sender.close();
    }
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
    expect(
      device,
      isA<MediaRenderer>(),
      reason: 'discovery builds the typed profile',
    );
    expect((device as MediaRenderer).avTransport, isNotNull);
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
    /// Sends [payload] and asserts that no device results from it.
    ///
    /// This deliberately does not follow up with a known-good response as a
    /// fence. Datagrams sent back to back are dropped outright when the event
    /// loop is busy - a probe sending three while blocked receives one, and
    /// the rest are gone from the buffer rather than merely unread - so the
    /// fence itself was what went missing, and the test hung waiting for a
    /// device that had never been delivered. Invisible locally, intermittent
    /// on a loaded runner.
    Future<void> expectIgnored(String payload) async {
      final seen = <Device>[];
      final subscription = discoverer.devices.listen(seen.add);
      await sendSsdp(payload);
      // Comfortably longer than a description fetch against the loopback
      // server, so a regression that started fetching would still be caught.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await subscription.cancel();
      expect(
        seen,
        isEmpty,
        reason: 'a malformed search response must not yield a device',
      );
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
