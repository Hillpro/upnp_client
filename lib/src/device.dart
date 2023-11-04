import 'package:upnp_client/src/service.dart';
import 'package:upnp_client/src/xml_utils.dart';
import 'package:xml/xml.dart';

/// An UPnP device
class Device {
  /// The xml element the properties of this object were initialized from
  XmlElement xml;

  /// The location of the device
  String? url;

  /// The base url of this device
  String? urlBase;

  /// The device description information
  DeviceDescription? description;

  /// The list of provided services
  List<Service> services = [];

  /// The list of embedded devices
  List<Device> devices = [];

  Device.fromXml(this.xml, [this.url]) {
    if (xml.name.toString() != 'device') {
      throw Exception('ERROR: Invalid Device XML!\n$xml');
    }

    urlBase = xml.getElement('URLBase')?.innerText ?? url;

    description = DeviceDescription.fromXml(xml);

    services = xml.loadList('serviceList', Service.fromXml);
    devices = xml.loadList('deviceList', Device.fromXml);
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer()
      ..writeln('Url: $url')
      ..writeln(description.toString());

    if (services.isNotEmpty) sb.writeln('Services');

    for (var service in services) {
      sb.writeln('\t${service.toString().replaceAll('\n', '\n\t')}');
    }

    if (devices.isNotEmpty) sb.writeln('Embedded Devices');

    for (var device in devices) {
      sb.writeln('\t${device.toString().replaceAll('\n', '\n\t')}');
    }

    return sb.toString();
  }

  @override
  bool operator ==(Object other) {
    return other.runtimeType == runtimeType &&
        other is Device &&
        other.description?.uuid != null &&
        description?.uuid != null &&
        description!.uuid == other.description!.uuid;
  }

  @override
  int get hashCode =>
      description?.uuid.hashCode ?? xml.toString().hashCode;
}

/// The general information about this UPnP device
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
    deviceType = _xml.getElement('deviceType')?.innerText;
    friendlyName = _xml.getElement('friendlyName')?.innerText;
    manufacturer = _xml.getElement('manufacturer')?.innerText;
    manufacturerUrl = _xml.getElement('manufacturerUrl')?.innerText;
    modelName = _xml.getElement('modelName')?.innerText;
    modelNumber = _xml.getElement('modelNumber')?.innerText;
    modelDescription = _xml.getElement('modelDescription')?.innerText;
    modelType = _xml.getElement('modelType')?.innerText;
    modelUrl = _xml.getElement('modelUrl')?.innerText;
    serialNumber = _xml.getElement('serialNumber')?.innerText;
    udn = _xml.getElement('UDN')?.innerText;
    upc = _xml.getElement('UPC')?.innerText;

    icons = _xml.loadList('iconList', (icon) => Icon.fromXml(icon));
  }

  @override
  String toString() {
    return 'FriendlyName: $friendlyName, uuid: $uuid\nDeviceType: $deviceType';
  }
}

/// An UPnP device icon
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
    mimetype = _xml.getElement('mimetype')?.innerText;
    width = int.parse(_xml.getElement('width')?.innerText ?? '');
    height = int.parse(_xml.getElement('height')?.innerText ?? '');
    depth = int.parse(_xml.getElement('depth')?.innerText ?? '');
    url = _xml.getElement('url')?.innerText;
  }
}
