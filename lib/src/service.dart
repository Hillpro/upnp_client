import 'package:xml/xml.dart';
import 'package:upnp_client/src/device.dart';

/// An UPnP Service
class Service {
  /// The device that provides this service
  final Device device;

  /// The xml element the properties of this object were initialized from
  final XmlElement xml;

  /// The service type
  String? type;

  /// The service ID
  String? id;

  /// The location of the service description
  String? url;

  /// The location for service control
  String? controlUrl;

  /// The location for service eventing
  String? eventSubUrl;

  Service.fromXml(this.device, this.xml) {
    if (xml.name.toString() != 'service') {
      throw Exception('ERROR: Invalid Service XML!\n$xml');
    }

    type = xml.getElement('serviceType')?.innerText;
    id = xml.getElement('serviceId')?.innerText;
    url = xml.getElement('SCPDURL')?.innerText;
    controlUrl = xml.getElement('controlURL')?.innerText;
    eventSubUrl = xml.getElement('eventsubURL')?.innerText;
  }

  @override
  String toString() {
    return 'Service{type: $type, id: $id}';
  }
}
