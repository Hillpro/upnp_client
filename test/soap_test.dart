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
const _avtNs = 'urn:schemas-upnp-org:service:AVTransport:1';
// The fixture declares ConnectionManager at :2 on purpose, to exercise
// version-independent service matching.
const _cmNs = 'urn:schemas-upnp-org:service:ConnectionManager:2';

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

    // AVTransport:1 §2.2.26 writes its own examples as "Play, Stop" - a space
    // after each comma. CurrentTransportActions is a plain `string`, not a
    // `CSV (string)`, so the CSV rule that whitespace belongs to the value does
    // not apply and the spaces are formatting. Splitting without trimming
    // returned ' Stop', so contains('Stop') was false.
    group('getCurrentTransportActions', () {
      Future<List<String>> actionsFrom(String raw) {
        reply(
          200,
          soapResponse(
            '<u:GetCurrentTransportActionsResponse xmlns:u="$_avtNs">'
            '<Actions>$raw</Actions>'
            '</u:GetCurrentTransportActionsResponse>',
          ),
        );
        return device.avTransport!.getCurrentTransportActions();
      }

      test('trims the spaces the spec puts after each comma', () async {
        expect(await actionsFrom('Play, Stop'), ['Play', 'Stop']);
        expect(await actionsFrom('Play, Stop, Pause, Seek, Next, Previous'), [
          'Play',
          'Stop',
          'Pause',
          'Seek',
          'Next',
          'Previous',
        ]);
      });

      test('leaves an already-tight list alone', () async {
        expect(await actionsFrom('Play,Pause,Stop'), ['Play', 'Pause', 'Stop']);
      });

      test('drops empty entries from a trailing or doubled comma', () async {
        expect(await actionsFrom('Play,,Stop,'), ['Play', 'Stop']);
      });

      // Trimming is the only change made, so callers must match
      // case-insensitively: §2.2.26's prose spells these "Play", while
      // AVTransport:3 §5.2.28's allowedValueList spells them "PLAY", and both
      // eras of device are on real networks.
      test('passes the casing through untouched', () async {
        expect(await actionsFrom('PLAY, STOP'), ['PLAY', 'STOP']);
      });

      // §5.2.28 lets a device augment the list with its own action names, so
      // the result is not necessarily a subset of the standard seven.
      test('keeps vendor-defined names', () async {
        expect(await actionsFrom('Play,X_VENDOR_Rewind,Stop'), [
          'Play',
          'X_VENDOR_Rewind',
          'Stop',
        ]);
      });

      test(
        'returns an empty list when the device reports no actions',
        () async {
          expect(await actionsFrom(''), isEmpty);
        },
      );
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

    // The three below are one defect: invokeAction could not tell "this action
    // has no out arguments" from "this body is not the response", and returned
    // {} for both. Every wrapper then handed back a sentinel a caller cannot
    // distinguish from data - -1 from getVolume(), null from
    // getExternalIpAddress(), [] from a mapping enumeration.
    test('reports a fault carried under HTTP 200', () async {
      // UDA 1.1 §3.2.5 pairs a fault with 500, but devices send them under 200.
      // This used to yield {} and, through getVolume(), a silent -1.
      reply(200, soapFaultXml);
      await expectLater(
        device.renderingControl!.getVolume(),
        throwsA(
          isA<UPnPException>().having((e) => e.errorCode, 'errorCode', 701),
        ),
      );
    });

    test(
      'accepts a response namespaced at another version of the type',
      () async {
        // UDA 1.1 §3.2.2 says the device must echo the request namespace, so
        // this device is at fault - but it is answering, and the rest of the
        // package matches service types version-independently. Dropping the
        // value here contradicted that.
        reply(
          200,
          soapResponse(
            '<u:GetVolumeResponse '
            'xmlns:u="urn:schemas-upnp-org:service:RenderingControl:2">'
            '<CurrentVolume>42</CurrentVolume></u:GetVolumeResponse>',
          ),
        );
        expect(await device.renderingControl!.getVolume(), 42);
      },
    );

    test('throws when the body carries no response element', () async {
      reply(
        200,
        soapResponse(
          '<u:SomeOtherResponse xmlns:u="$_rcsNs"><X>1</X></u:SomeOtherResponse>',
        ),
      );
      await expectLater(
        device.renderingControl!.getVolume(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('GetVolumeResponse'),
          ),
        ),
      );
    });

    test(
      'still returns an empty map for an action with no out arguments',
      () async {
        // The counterpart: presence of the element is the success signal, so an
        // empty one must stay a success rather than becoming the error above.
        reply(200, soapResponse('<u:StopResponse xmlns:u="$_avtNs"/>'));
        await expectLater(device.avTransport!.stop(), completes);
      },
    );

    // One unparseable entry used to throw ArgumentError out of
    // getProtocolInfo(), discarding every format that did parse - the opposite
    // of useful when the point of asking is to learn what the device accepts.
    test('skips malformed protocolInfo entries rather than failing', () async {
      reply(
        200,
        soapResponse(
          '<u:GetProtocolInfoResponse xmlns:u="$_cmNs">'
          '<Source></Source>'
          '<Sink>http-get:*:audio/mpeg:*,garbage,'
          'http-get:*:video/mp4:DLNA.ORG_OP=01:01</Sink>'
          '</u:GetProtocolInfoResponse>',
        ),
      );
      final info = await device.connectionManager!.getProtocolInfo();
      expect(info.sink.map((p) => p.toString()).toList(), [
        'http-get:*:audio/mpeg:*',
        'http-get:*:video/mp4:DLNA.ORG_OP=01:01',
      ]);
      expect(info.source, isEmpty);
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
