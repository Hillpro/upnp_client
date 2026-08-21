import 'package:collection/collection.dart';
import 'package:upnp_client/src/types/type_urn.dart';

/// The namespace all UPnP Forum standard device types live in.
const _deviceUrnPrefix = 'urn:schemas-upnp-org:device:';

/// A standard UPnP device type, as it appears in a `<deviceType>` element.
///
/// Only the profiles this package models are listed; a device advertising
/// anything else is still parsed, just as a plain `Device`.
///
/// [urn] gives the versioned form, which doubles as an SSDP search target:
///
/// ```dart
/// await discoverer.getDevices(
///   searchTarget: UpnpDeviceType.internetGatewayDevice.urn(),
/// );
/// ```
enum UpnpDeviceType {
  internetGatewayDevice('InternetGatewayDevice'),
  wanDevice('WANDevice'),
  wanConnectionDevice('WANConnectionDevice'),
  mediaRenderer('MediaRenderer'),
  mediaServer('MediaServer');

  const UpnpDeviceType(this.typeName);

  /// The type name without namespace or version, e.g. `MediaRenderer`.
  ///
  /// Named [typeName] rather than `name` because [Enum] already provides that
  /// for the Dart identifier, which differs in case.
  final String typeName;

  /// The type URN with its version stripped, ending in a colon.
  ///
  /// This is the form to compare against, since it matches any version of the
  /// type. See [baseTypeUrn].
  String get baseUrn => '$_deviceUrnPrefix$typeName:';

  /// The full type URN at [version], as a device description declares it and
  /// as an SSDP search target names it.
  String urn([int version = 1]) => '$baseUrn$version';

  /// The device type [urn] names, whatever its version, or null if it is not
  /// one of these.
  static UpnpDeviceType? tryParse(String? urn) {
    final base = baseTypeUrn(urn);
    return values.firstWhereOrNull((type) => type.baseUrn == base);
  }
}
