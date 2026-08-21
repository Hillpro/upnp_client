import 'package:upnp_client/src/services/av_transport.dart';
import 'package:upnp_client/src/services/connection_manager.dart';
import 'package:upnp_client/src/device.dart';
import 'package:upnp_client/src/service.dart';
import 'package:upnp_client/src/types/upnp_service_type.dart';

/// An UPnP MediaServer, a device that offers content to the network.
/// https://upnp.org/specs/av/UPnP-av-MediaServer-v1-Device.pdf
///
/// MediaServer:1 §2.2 requires ContentDirectory and ConnectionManager.
/// AVTransport is conditional: required only when the server supports a
/// transfer protocol that needs it, so [avTransport] is often null.
class MediaServer extends Device {
  MediaServer.fromXml(super.xml, [super.url, super.urlBase]) : super.fromXml();

  /// The `ContentDirectory:1` service, which enumerates available content.
  ///
  /// Returned untyped: browsing and searching are not modelled, so reach its
  /// actions through [Service.invokeAction]. Its metadata format, DIDL-Lite,
  /// *is* modelled - see `package:upnp_client/didl.dart`.
  Service? get contentDirectory =>
      serviceOfType(UpnpServiceType.contentDirectory);

  /// Connection setup and format negotiation.
  ConnectionManagerService? get connectionManager =>
      services.whereType<ConnectionManagerService>().singleOrNull;

  /// Transport control, present only for transfer protocols that require it.
  AvTransportService? get avTransport =>
      services.whereType<AvTransportService>().singleOrNull;
}
