import 'package:collection/collection.dart';
import 'package:upnp_client/src/types/type_urn.dart';

/// The namespace all UPnP Forum standard service types live in.
const _serviceUrnPrefix = 'urn:schemas-upnp-org:service:';

/// A standard UPnP service type, as it appears in a `<serviceType>` element.
///
/// Listed whether or not the service has a typed wrapper: the gateway and
/// media profiles reach some of theirs as a plain `Service`.
enum UpnpServiceType {
  // AV
  avTransport('AVTransport'),
  renderingControl('RenderingControl'),
  connectionManager('ConnectionManager'),
  contentDirectory('ContentDirectory'),
  // Internet gateway
  layer3Forwarding('Layer3Forwarding'),
  wanCommonInterfaceConfig('WANCommonInterfaceConfig'),
  wanIpConnection('WANIPConnection'),
  wanPppConnection('WANPPPConnection');

  const UpnpServiceType(this.typeName);

  /// The type name without namespace or version, e.g. `AVTransport`.
  ///
  /// Named [typeName] rather than `name` because [Enum] already provides that
  /// for the Dart identifier, which differs in case.
  final String typeName;

  /// The type URN with its version stripped, ending in a colon.
  ///
  /// This is the form to compare against, since it matches any version of the
  /// type. See [baseTypeUrn].
  String get baseUrn => '$_serviceUrnPrefix$typeName:';

  /// The full type URN at [version], as a service description declares it and
  /// as the `SOAPACTION` header names it.
  String urn([int version = 1]) => '$baseUrn$version';

  /// The service type [urn] names, whatever its version, or null if it is not
  /// one of these.
  static UpnpServiceType? tryParse(String? urn) {
    final base = baseTypeUrn(urn);
    return values.firstWhereOrNull((type) => type.baseUrn == base);
  }
}
