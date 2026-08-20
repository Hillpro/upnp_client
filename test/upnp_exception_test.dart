import 'package:test/test.dart';
import 'package:upnp_client/upnp_client.dart';
import 'package:xml/xml.dart';

import 'fixtures.dart';

const _soapNs = 'http://schemas.xmlsoap.org/soap/envelope/';

XmlElement bodyOf(String envelope) => XmlDocument.parse(
  envelope,
).rootElement.getElement('Body', namespace: _soapNs)!;

void main() {
  group('UPnPException.tryParseFromBody', () {
    test('parses a prefixed SOAP fault', () {
      final ex = UPnPException.tryParseFromBody(
        bodyOf(soapFaultXml),
        actionName: 'Play',
      );
      expect(ex, isNotNull);
      expect(ex!.errorCode, 701);
      expect(ex.errorDescription, 'Transition not available');
      expect(ex.actionName, 'Play');
    });

    test('parses a fault with no namespace prefixes', () {
      const unprefixed = '''
        <Body>
          <Fault>
            <detail>
              <UPnPError>
                <errorCode>401</errorCode>
                <errorDescription>Invalid Action</errorDescription>
              </UPnPError>
            </detail>
          </Fault>
        </Body>''';
      final ex = UPnPException.tryParseFromBody(
        XmlDocument.parse(unprefixed).rootElement,
      );
      expect(ex?.errorCode, 401);
      expect(ex?.errorDescription, 'Invalid Action');
      expect(ex?.actionName, isNull);
    });

    test('defaults errorDescription to empty when absent', () {
      const noDescription = '''
        <Body><Fault><detail>
          <UPnPError xmlns="urn:schemas-upnp-org:control-1-0">
            <errorCode>501</errorCode>
          </UPnPError>
        </detail></Fault></Body>''';
      final ex = UPnPException.tryParseFromBody(
        XmlDocument.parse(noDescription).rootElement,
      );
      expect(ex?.errorCode, 501);
      expect(ex?.errorDescription, isEmpty);
    });

    test('returns null when the body is not a UPnP fault', () {
      for (final xml in const [
        '<Body><PlayResponse/></Body>',
        '<Body><Fault><faultstring>x</faultstring></Fault></Body>',
        '<Body><Fault><detail/></Fault></Body>',
        '<Body><Fault><detail><UPnPError/></detail></Fault></Body>',
        '<Body><Fault><detail><UPnPError>'
            '<errorCode>abc</errorCode></UPnPError></detail></Fault></Body>',
      ]) {
        expect(
          UPnPException.tryParseFromBody(XmlDocument.parse(xml).rootElement),
          isNull,
          reason: xml,
        );
      }
    });
  });

  test('toString includes the code, description and action', () {
    expect(
      UPnPException(
        errorCode: 402,
        errorDescription: 'Invalid Args',
        actionName: 'Seek',
      ).toString(),
      'UPnPException: 402 Invalid Args (action: Seek)',
    );
    expect(UPnPException(errorCode: 501).toString(), 'UPnPException: 501 ');
  });
}
