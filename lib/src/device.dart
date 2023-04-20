import 'package:upnp_client/src/service.dart';
import 'package:xml/xml.dart';

class Device {
  /// The xml element the properties of this object were initialized from
  XmlElement xml;

  /// The location of the device
  String? url;

  /// The base url of this device
  String? urlBase;

  /// The device description information
  DeviceDescription? deviceDescription;

  /// The list of provided services
  List<Service> services = [];

  Device.fromXml(this.xml, [this.url, this.urlBase]) {
    if (xml.name.toString() != 'device') {
      throw Exception('ERROR: Invalid Device XML!\n$xml');
    }

    deviceDescription = DeviceDescription.fromXml(xml);

    var serviceList = xml.getElement('serviceList');

    if (serviceList != null) {
      for (var serviceInformation in serviceList.childElements) {
        services.add(Service.fromXml(serviceInformation));
      }
    }
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer()
      ..writeln('Url: $url')
      ..writeln(deviceDescription.toString());

    if (services.isNotEmpty) sb.writeln('Services');

    services.forEach(sb.writeln);

    return sb.toString();
  }

  @override
  bool operator ==(Object other) {
    return other.runtimeType == runtimeType &&
        other is Device &&
        other.deviceDescription?.uuid != null &&
        deviceDescription?.uuid != null &&
        deviceDescription!.uuid == other.deviceDescription!.uuid;
  }

  @override
  int get hashCode =>
      deviceDescription?.uuid.hashCode ?? xml.toString().hashCode;
}

class DeviceDescription {
  /// The xml element the properties of this object were initialized from
  final XmlElement _xml;

  /// The device type
  String? deviceType;

  /// The user friendly name
  String? friendlyName;

  /// The manufacturer of this device
  String? manufacturer;

  /// The URL to the manufacturer site
  String? manufacturerUrl;

  /// The name of this model
  String? modelName;

  /// The model number of this device
  String? modelNumber;

  /// The model description of this device
  String? modelDescription;

  /// The type of model of this device
  String? modelType;

  /// The URL to the model site
  String? modelUrl;

  /// The serial number of this device
  String? serialNumber;

  /// The universal device name of this device
  String? udn;

  /// The universal product code of this device
  String? upc;

  List<Icon> icons = [];

  String? get uuid => udn?.substring('uuid:'.length);

  DeviceDescription.fromXml(this._xml) {
    deviceType = _xml.getElement('deviceType')?.text;
    friendlyName = _xml.getElement('friendlyName')?.text;
    manufacturer = _xml.getElement('manufacturer')?.text;
    manufacturerUrl = _xml.getElement('manufacturerUrl')?.text;
    modelName = _xml.getElement('modelName')?.text;
    modelNumber = _xml.getElement('modelNumber')?.text;
    modelDescription = _xml.getElement('modelDescription')?.text;
    modelType = _xml.getElement('modelType')?.text;
    modelUrl = _xml.getElement('modelUrl')?.text;
    serialNumber = _xml.getElement('serialNumber')?.text;
    udn = _xml.getElement('UDN')?.text;
    upc = _xml.getElement('UPC')?.text;

    var iconList = _xml.getElement('iconList');

    if (iconList != null) {
      for (var icon in iconList.childElements) {
        icons.add(Icon.fromXml(icon));
      }
    }
  }

  @override
  String toString() {
    return 'FriendlyName: $friendlyName, uuid: $uuid';
  }
}

/// An upnp device icon
class Icon {
  /// The xml element the properties of this object were initialized from
  final XmlElement _xml;

  /// The mimetype of this icon, always "image/<format>" like "image/png"
  String? mimetype;

  /// The amount of horizontal pixels
  int? width;

  /// The amount of vertical pixels
  int? height;

  /// The color depth of this image
  int? depth;

  /// The url to this icon
  String? url;

  Icon.fromXml(this._xml) {
    mimetype = _xml.getElement('mimetype')?.text;
    width = int.parse(_xml.getElement('width')?.text ?? '');
    height = int.parse(_xml.getElement('height')?.text ?? '');
    depth = int.parse(_xml.getElement('depth')?.text ?? '');
    url = _xml.getElement('url')?.text;
  }
}
