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
const _rcsNs = 'urn:schemas-upnp-org:service:RenderingControl:1';

/// What the device saw.
class Captured {
  final String method;
  final String path;
  final String body;
  final String? soapAction;
  final String? contentType;

  Captured(
    this.method,
    this.path,
    this.body,
    this.soapAction,
    this.contentType,
  );
}

/// Decides how the fake device replies.
typedef Responder = void Function(HttpRequest request);

void main() {
  late HttpServer server;
  late List<Captured> seen;
  late Responder respond;
  late MediaRenderer device;

  setUp(() async {
    seen = [];
    respond = (r) => r.response.close();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      seen.add(
        Captured(
          request.method,
          request.uri.path,
          body,
          request.headers.value('soapaction'),
          request.headers.contentType?.toString(),
        ),
      );
      respond(request);
    });

    final base = 'http://${server.address.address}:${server.port}/base/';
    final root = XmlDocument.parse(deviceDescriptionXml).rootElement;
    device =
        Device.fromXmlTyped(root.getElement('device')!, base, base)
            as MediaRenderer;
  });

  tearDown(() => server.close(force: true));

  void reply(int status, String body, {String contentType = 'text/xml'}) {
    respond = (r) {
      r.response.statusCode = status;
      r.response.headers.contentType = ContentType.parse(contentType);
      r.response.write(body);
      r.response.close();
    };
  }

  String soapResponse(String inner) =>
      '''
<?xml version="1.0"?>
<s:Envelope xmlns:s="$_soapNs" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>$inner</s:Body>
</s:Envelope>''';

  group('request construction', () {
    setUp(
      () => reply(
        200,
        soapResponse(
          '<u:SetAVTransportURIResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"/>',
        ),
      ),
    );

    test('sends in arguments in SCPD order', () async {
      // Regression: InstanceID was sent last, violating UDA 1.1 §3.2.1.
      await device.avTransport!.setAVTransportURI(
        'http://host/a.mp3',
        metadata: '<didl/>',
      );

      final action = XmlDocument.parse(seen.single.body).rootElement
          .getElement('Body', namespace: _soapNs)!
          .childElements
          .single;
      expect(action.name.local, 'SetAVTransportURI');
      expect(action.childElements.map((e) => e.name.local).toList(), [
        'InstanceID',
        'CurrentURI',
        'CurrentURIMetaData',
      ]);
      expect(action.getElement('CurrentURI')!.innerText, 'http://host/a.mp3');
      expect(action.getElement('CurrentURIMetaData')!.innerText, '<didl/>');
    });

    test('sets SOAPACTION and the SOAP content type', () async {
      await device.avTransport!.setAVTransportURI('http://host/a.mp3');
      expect(
        seen.single.soapAction,
        '"urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI"',
      );
      expect(seen.single.contentType, contains('text/xml'));
      expect(seen.single.contentType, contains('utf-8'));
      expect(seen.single.method, 'POST');
    });

    test('resolves a relative controlURL against urlBase', () async {
      await device.avTransport!.setAVTransportURI('http://host/a.mp3');
      expect(seen.single.path, '/base/AVTransport/control');
    });

    test('resolves an absolute controlURL against the host', () async {
      reply(
        200,
        soapResponse(
          '<u:GetVolumeResponse xmlns:u="$_rcsNs"><CurrentVolume>7</CurrentVolume></u:GetVolumeResponse>',
        ),
      );
      await device.renderingControl!.getVolume();
      expect(seen.single.path, '/abs/RenderingControl/control');
    });
  });

  group('response handling', () {
    test('returns out arguments on success', () async {
      reply(
        200,
        soapResponse(
          '<u:GetVolumeResponse xmlns:u="$_rcsNs"><CurrentVolume>42</CurrentVolume></u:GetVolumeResponse>',
        ),
      );
      expect(await device.renderingControl!.getVolume(), 42);
    });

    test('accepts deprecated boolean spellings from UPnP 1.0 devices', () async {
      for (final raw in ['1', 'true', 'yes']) {
        reply(
          200,
          soapResponse(
            '<u:GetMuteResponse xmlns:u="$_rcsNs"><CurrentMute>$raw</CurrentMute></u:GetMuteResponse>',
          ),
        );
        expect(await device.renderingControl!.getMute(), isTrue, reason: raw);
      }
      reply(
        200,
        soapResponse(
          '<u:GetMuteResponse xmlns:u="$_rcsNs"><CurrentMute>0</CurrentMute></u:GetMuteResponse>',
        ),
      );
      expect(await device.renderingControl!.getMute(), isFalse);
    });

    test('turns a SOAP fault into a typed UPnPException', () async {
      reply(500, soapFaultXml);
      await expectLater(
        device.avTransport!.play(),
        throwsA(
          isA<UPnPException>()
              .having((e) => e.errorCode, 'errorCode', 701)
              .having(
                (e) => e.errorDescription,
                'errorDescription',
                'Transition not available',
              )
              .having((e) => e.actionName, 'actionName', 'Play'),
        ),
      );
    });

    test('reports a non-XML error page without an XML parse error', () async {
      // Regression: the body was parsed before the status was checked, so an
      // HTML error page surfaced as XmlParserException.
      reply(
        500,
        '<!DOCTYPE html><html><body>Server Error</body></html>',
        contentType: 'text/html',
      );
      await expectLater(
        device.avTransport!.play(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            isNot(contains('XmlParser')),
          ),
        ),
      );
    });

    test('rejects a 200 response that is not a SOAP envelope', () async {
      reply(200, '<NotAnEnvelope/>');
      await expectLater(device.avTransport!.play(), throwsA(isA<Exception>()));
    });
  });

  group('getDescription', () {
    test('fetches and parses the SCPD', () async {
      reply(200, scpdXml);
      final description = await device.services.first.getDescription();
      expect(seen.single.method, 'GET');
      expect(seen.single.path, '/base/AVTransport.xml');
      expect(description.actions.single.name, 'SetVolume');
      expect(description.stateVariables, hasLength(2));
    });

    test('reports the HTTP status instead of an XML parse error', () async {
      // Regression: the body was parsed regardless of status.
      reply(
        404,
        '<!DOCTYPE html><html><body>Not Found</body></html>',
        contentType: 'text/html',
      );
      await expectLater(
        device.services.first.getDescription(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('404'), isNot(contains('XmlParser'))),
          ),
        ),
      );
    });
  });
}
