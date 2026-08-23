import 'package:collection/collection.dart';
import 'package:upnp_client/src/devices/internet_gateway.dart';
import 'package:upnp_client/src/devices/media_renderer.dart';
import 'package:upnp_client/src/devices/media_server.dart';
import 'package:upnp_client/src/services/av_transport.dart';
import 'package:upnp_client/src/services/connection_manager.dart';
import 'package:upnp_client/src/services/rendering_control.dart';
import 'package:upnp_client/src/service.dart';
import 'package:upnp_client/src/types/upnp_device_type.dart';
import 'package:upnp_client/src/types/upnp_service_type.dart';
import 'package:upnp_client/src/utils/diagnostics.dart';
import 'package:upnp_client/src/utils/xml_utils.dart';
import 'package:xml/xml.dart';

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

  /// Builds a [Device], returning the subclass matching its `deviceType`.
  ///
  /// An unrecognised profile yields a plain [Device]. Embedded devices are
  /// always typed, whichever constructor built their parent.
  static Device fromXmlTyped(XmlElement xml, [String? url, String? urlBase]) =>
      switch (UpnpDeviceType.tryParse(
        xml.getElement('deviceType')?.innerText,
      )) {
        UpnpDeviceType.internetGatewayDevice => InternetGatewayDevice.fromXml(
          xml,
          url,
          urlBase,
        ),
        UpnpDeviceType.wanDevice => WanDevice.fromXml(xml, url, urlBase),
        UpnpDeviceType.wanConnectionDevice => WanConnectionDevice.fromXml(
          xml,
          url,
          urlBase,
        ),
        UpnpDeviceType.mediaRenderer => MediaRenderer.fromXml(
          xml,
          url,
          urlBase,
        ),
        UpnpDeviceType.mediaServer => MediaServer.fromXml(xml, url, urlBase),
        null => Device.fromXml(xml, url, urlBase),
      };

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
      (xml) => Device.fromXmlTyped(xml, null, urlBase),
    );
  }

  /// The RenderingControl service on this device, if it has exactly one.
  ///
  /// Deprecated: use [MediaRenderer.renderingControl]. Behaviour is unchanged.
  @Deprecated('Use MediaRenderer.renderingControl')
  RenderingControlService? renderingControlService() =>
      services.whereType<RenderingControlService>().singleOrNull;

  /// The ConnectionManager service on this device, if it has exactly one.
  ///
  /// Deprecated: use [MediaRenderer.connectionManager] or
  /// [MediaServer.connectionManager]. Behaviour is unchanged.
  @Deprecated(
    'Use MediaRenderer.connectionManager or MediaServer.connectionManager',
  )
  ConnectionManagerService? connectionManagerService() =>
      services.whereType<ConnectionManagerService>().singleOrNull;

  /// The AVTransport service on this device, if it has exactly one.
  ///
  /// Deprecated: playback belongs to a device profile, not to every device.
  /// Use [MediaRenderer.avTransport] (or [MediaServer.avTransport], where the
  /// transfer protocol requires one) after obtaining the device through
  /// [Device.fromXmlTyped].
  ///
  /// Behaviour is unchanged: this device's own [services] only, and null when
  /// there is no single match.
  @Deprecated('Use MediaRenderer.avTransport or MediaServer.avTransport')
  AvTransportService? avTransportService() =>
      services.whereType<AvTransportService>().singleOrNull;

  /// Every service in this device's subtree, depth first: this device's own
  /// [services], then those of each embedded device in turn.
  ///
  /// A device profile decides how deep its services sit. The AV profiles put
  /// theirs on the root device, so [services] alone is enough to find them.
  /// IGD does not: it nests the WAN connection services two `deviceList`
  /// levels down, under `WANDevice` then `WANConnectionDevice`, so a lookup
  /// limited to [services] finds nothing on a gateway.
  Iterable<Service> get allServices =>
      services.followedBy(devices.expand((device) => device.allServices));

  /// This device's own service of [type], or null if it advertises none.
  ///
  /// Matches on the UPnP service type rather than a Dart type, which is how to
  /// reach a service with no typed wrapper. Scoped to [services], like the
  /// profile accessors and unlike [findService]:
  ///
  /// ```dart
  /// gateway.serviceOfType(UpnpServiceType.layer3Forwarding);
  /// ```
  Service? serviceOfType(UpnpServiceType type) =>
      services.firstWhereOrNull((service) => service.standardType == type);

  /// The first service of type [T] in this device's subtree, or null if the
  /// subtree holds none.
  ///
  /// The only lookup here that leaves this device: [serviceOfType] and the
  /// profile accessors on the typed devices all read [services] alone.
  T? findService<T extends Service>() => allServices.whereType<T>().firstOrNull;

  /// Every service of type [T] in this device's subtree, in [allServices]
  /// order.
  ///
  /// A subtree may legitimately hold several services of one type. A gateway
  /// is the standing example: WANConnectionDevice:1 §2.2 allows multiple
  /// connection services within one `WANConnectionDevice`, and WANDevice:1
  /// §2.2 allows multiple `WANConnectionDevice` instances within a
  /// `WANDevice`.
  List<T> findServices<T extends Service>() =>
      allServices.whereType<T>().toList();

  @override
  String toString() =>
      buildDescription(runtimeType, describeFields(), describeChildren());

  Map<String, dynamic> describeFields() => {
    'url': url,
    'description': description,
  };

  Map<String, List> describeChildren() => {
    'services': services,
    'devices': devices,
  };

  /// The key this device is identified by, tagged with its kind.
  ///
  /// UDA 1.1 §2.3 - UDN is REQUIRED, universally unique and MUST survive
  /// reboots, so it is the only sound identity. Some devices omit it, so the
  /// LOCATION URL serves as a fallback; that is adequate within one subnet,
  /// but private IPs repeat across subnets and Dart exposes no per-interface
  /// socket metadata to tell them apart.
  ///
  /// The kind tag keeps the two namespaces disjoint: §1.1.4 requires control
  /// points to accept malformed UUIDs, so a UDN may itself look like a URL.
  ({String kind, String value})? get _identity {
    final uuid = description?.uuid;
    if (uuid != null) return (kind: 'uuid', value: uuid);
    final location = url;
    return location == null ? null : (kind: 'url', value: location);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Device) return false;
    final identity = _identity;
    return identity != null && identity == other._identity;
  }

  @override
  int get hashCode => _identity.hashCode;
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
  ///
  /// Parsed from `<manufacturerURL>`.
  String? manufacturerUrl;

  /// The name of this model
  String? modelName;

  /// The model number of this device
  String? modelNumber;

  /// The model description of this device
  String? modelDescription;

  /// The type of model of this device
  ///
  /// Deprecated: no UPnP version defines a `<modelType>` element. UDA 1.0,
  /// 1.1 and 2.0 list exactly four - `modelDescription`, `modelName`,
  /// `modelNumber` and `modelURL` - and `device-1-0.xsd` admits vendor
  /// elements only through `<xsd:any namespace="##other">`, so a schema-valid
  /// extension is namespace-qualified and never matches this unqualified
  /// lookup. Use [modelName], [modelNumber] or [modelDescription] instead.
  ///
  /// Behaviour is unchanged until removal: a device that emits the element
  /// unqualified, against the schema, still populates it.
  @Deprecated(
    'No UPnP version defines <modelType>; '
    'use modelName, modelNumber or modelDescription',
  )
  String? modelType;

  /// The URL to the model site
  ///
  /// Parsed from `<modelURL>`.
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
    manufacturerUrl = _xml.getElement('manufacturerURL')?.innerText;
    modelName = _xml.getElement('modelName')?.innerText;
    modelNumber = _xml.getElement('modelNumber')?.innerText;
    modelDescription = _xml.getElement('modelDescription')?.innerText;
    // ignore: deprecated_member_use_from_same_package
    modelType = _xml.getElement('modelType')?.innerText;
    modelUrl = _xml.getElement('modelURL')?.innerText;
    serialNumber = _xml.getElement('serialNumber')?.innerText;
    udn = _xml.getElement('UDN')?.innerText;
    upc = _xml.getElement('UPC')?.innerText;

    icons = _xml.loadList('iconList', (icon) => Icon.fromXml(icon));
  }

  @override
  String toString() {
    return buildDescription(runtimeType, describeFields());
  }

  Map<String, dynamic> describeFields() => {
    'deviceType': deviceType,
    'friendlyName': friendlyName,
    'manufacturer': manufacturer,
    'modelName': modelName,
    'modelNumber': modelNumber,
    'modelDescription': modelDescription,
    'serialNumber': serialNumber,
    'udn': udn,
    'upc': upc,
  };
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
    return buildDescription(runtimeType, describeFields());
  }

  Map<String, dynamic> describeFields() => {
    'mimetype': mimetype,
    'width': width,
    'height': height,
    'depth': depth,
    'url': url,
  };
}
