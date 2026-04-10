import 'package:upnp_client/src/service.dart';
import 'package:upnp_client/src/xml_utils.dart';
import 'package:xml/xml.dart';
import 'package:collection/collection.dart';
import 'package:upnp_client/src/common_services/rendering_control.dart';
import 'package:upnp_client/src/common_services/connection_manager.dart';
import 'package:upnp_client/src/common_services/av_transport.dart';

/// An UPnP device
class Device {
  /// The xml element the properties of this object were initialized from
  final XmlElement xml;

  /// The location of the device
  String? url;

  /// The base URL for resolving relative URLs in this device's description.
  ///
  /// UDA 1.1 §2.3 - Deprecated `<URLBase>`,
  /// UDA 1.0 devices may still provide it. Per spec, control points MUST
  /// resolve relative URLs using URLBase if present, else the LOCATION URL.
  String? urlBase;

  /// The device description information
  DeviceDescription? description;

  /// The list of provided services
  List<Service> services = [];

  /// The list of embedded devices
  List<Device> devices = [];

  Device.fromXml(this.xml, [this.url, this.urlBase]) {
    if (xml.name.toString() != 'device') {
      throw Exception('ERROR: Invalid Device XML!\n$xml');
    }

    urlBase ??= url;

    description = DeviceDescription.fromXml(xml);

    services = xml.loadList(
      'serviceList',
      (xml) => Service.fromXmlTyped(this, xml),
    );
    devices = xml.loadList(
      'deviceList',
      (xml) => Device.fromXml(xml, null, urlBase),
    );
  }

  RenderingControlService? renderingControlService() =>
      services.whereType<RenderingControlService>().singleOrNull;

  ConnectionManagerService? connectionManagerService() =>
      services.whereType<ConnectionManagerService>().singleOrNull;

  AvTransportService? avTransportService() =>
      services.whereType<AvTransportService>().singleOrNull;

  @override
  String toString() {
    StringBuffer sb = StringBuffer()
      ..write('Device{url: $url, description: $description, services: [');
    for (var service in services) {
      sb.write('\n\t${service.toString().replaceAll('\n', '\n\t')}');
    }
    sb.write('\n], devices: [');
    for (var device in devices) {
      sb.writeln('\n\t${device.toString().replaceAll('\n', '\n\t')}');
    }
    sb.write('\n]}');
    return sb.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Device) return false;
    final thisUuid = description?.uuid;
    final otherUuid = other.description?.uuid;
    if (thisUuid != null && otherUuid != null) return thisUuid == otherUuid;

    // UDN is required by spec but some real-world devices omit it.
    // Fall back to LOCATION URL — sufficient within a single subnet;
    // private IP collisions across subnets are not distinguishable without
    // per-interface socket metadata that Dart does not expose.
    return url != null && url == other.url;
  }

  @override
  int get hashCode => description?.uuid?.hashCode ?? url.hashCode;
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

  /// UDA 1.1 §1.1.4 — UDN MUST begin with "uuid:", but some UDA 1.0 devices
  /// may not comply. Falls back to the raw UDN as the identifier.
  String? get uuid =>
      udn?.startsWith('uuid:') == true ? udn?.substring(5) : udn;

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
    return 'DeviceDescription{deviceType: $deviceType, friendlyName: $friendlyName, manufacturer: $manufacturer, modelName: $modelName, modelNumber: $modelNumber, modelDescription: $modelDescription, serialNumber: $serialNumber, udn: $udn, upc: $upc}';
  }
}

/// An UPnP device icon
class Icon {
  /// The xml element the properties of this object were initialized from
  final XmlElement _xml;

  /// The mimetype of this icon, always `image/<format>` like `image/png`
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
    width = int.tryParse(_xml.getElement('width')?.innerText ?? '');
    height = int.tryParse(_xml.getElement('height')?.innerText ?? '');
    depth = int.tryParse(_xml.getElement('depth')?.innerText ?? '');
    url = _xml.getElement('url')?.innerText;
  }

  @override
  String toString() {
    return 'Icon{mimetype: $mimetype, width: $width, height: $height, depth: $depth, url: $url}';
  }
}
