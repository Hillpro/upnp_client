import 'package:test/test.dart';
import 'package:upnp_client/upnp_client.dart';
import 'package:xml/xml.dart';

import 'fixtures.dart';

Device parseDevice() {
  final root = XmlDocument.parse(deviceDescriptionXml).rootElement;
  return Device.fromXml(
    root.getElement('device')!,
    null,
    root.getElement('URLBase')?.innerText,
  );
}

void main() {
  late Device device;

  setUp(() => device = parseDevice());

  group('Service.fromXmlTyped', () {
    test('rejects XML that is not a <service>', () {
      final xml = XmlDocument.parse('<notService/>').rootElement;
      expect(
        () => Service.fromXmlTyped(device, xml),
        throwsA(isA<Exception>()),
      );
    });

    test('returns the typed subclass for known service types', () {
      expect(device.services[0], isA<AvTransportService>());
      expect(device.services[1], isA<RenderingControlService>());
      expect(device.services[2], isA<ConnectionManagerService>());
    });

    test('matches regardless of service version', () {
      // The fixture declares ConnectionManager:2, not :1.
      expect(device.services[2].type, endsWith('ConnectionManager:2'));
      expect(device.services[2], isA<ConnectionManagerService>());
    });

    test('falls back to plain Service for unknown types', () {
      final other = device.services[3];
      expect(other.runtimeType, Service);
      expect(other.type, endsWith('SomethingElse:1'));
    });
  });

  group('Service.fromXml', () {
    test('parses every URL element', () {
      final s = device.services.first;
      expect(s.id, 'urn:upnp-org:serviceId:AVTransport');
      expect(s.url, 'AVTransport.xml');
      expect(s.controlUrl, 'AVTransport/control');
    });

    test('reads eventSubURL with its spec casing', () {
      // Regression: this was read as 'eventsubURL' and so was always null.
      expect(device.services.first.eventSubUrl, 'AVTransport/event');
      for (final s in device.services) {
        expect(s.eventSubUrl, isNotNull);
      }
    });

    test('toString reports the concrete subclass', () {
      expect(
        device.services.first.toString(),
        startsWith('AvTransportService{'),
      );
      expect(device.services.first.toString(), contains('AVTransport'));
    });
  });

  group('ServiceDescription.fromXml', () {
    late ServiceDescription description;

    setUp(() {
      final scpd = XmlDocument.parse(scpdXml).rootElement;
      description = ServiceDescription.fromXml(device.services.first, scpd);
    });

    test('rejects XML that is not an <scpd>', () {
      final xml = XmlDocument.parse('<notScpd/>').rootElement;
      expect(
        () => ServiceDescription.fromXml(device.services.first, xml),
        throwsA(isA<Exception>()),
      );
    });

    test('parses actions and their arguments in document order', () {
      expect(description.actions, hasLength(1));
      final action = description.actions.single;
      expect(action.name, 'SetVolume');
      expect(action.arguments.map((a) => a.name), [
        'InstanceID',
        'CurrentVolume',
      ]);
      expect(action.arguments.first.direction, Direction.in_);
      expect(action.arguments.last.direction, Direction.out);
      expect(
        action.arguments.first.relatedStateVariable,
        'A_ARG_TYPE_InstanceID',
      );
    });

    test('parses state variables', () {
      expect(description.stateVariables, hasLength(2));
      final volume = description.stateVariables.first;
      expect(volume.name, 'Volume');
      expect(volume.sendEventsAttribute, isTrue);
      expect(volume.dataType, DataType.ui2);
      expect(volume.allowedValues, isEmpty);

      final playMode = description.stateVariables.last;
      expect(playMode.sendEventsAttribute, isFalse);
      expect(playMode.dataType, DataType.string);
      expect(playMode.allowedValues, ['NORMAL', 'SHUFFLE']);
    });
  });
}
