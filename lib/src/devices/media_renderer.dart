import 'package:collection/collection.dart';
import 'package:upnp_client/src/services/av_transport.dart';
import 'package:upnp_client/src/services/connection_manager.dart';
import 'package:upnp_client/src/services/rendering_control.dart';
import 'package:upnp_client/src/device.dart';

/// An UPnP MediaRenderer, a device that plays media it is handed.
/// https://upnp.org/specs/av/UPnP-av-MediaRenderer-v1-Device.pdf
///
/// MediaRenderer:1 §2.2 requires RenderingControl and ConnectionManager, and
/// makes AVTransport optional, so [avTransport] may be null on a renderer that
/// only exposes volume control.
///
/// Unlike the gateway tiers, the AV profiles advertise their services on the
/// device itself rather than nesting them, so these accessors read
/// [Device.services] directly. Table 1 lists one service id per service - the
/// gateway tables call out where repeats are allowed and this one does not -
/// so an accessor returns null rather than guessing if a device advertises
/// the same service twice.
class MediaRenderer extends Device {
  MediaRenderer.fromXml(super.xml, [super.url, super.urlBase])
    : super.fromXml();

  /// Playback transport control: play, pause, stop, seek.
  AvTransportService? get avTransport =>
      services.whereType<AvTransportService>().singleOrNull;

  /// Volume and mute control.
  RenderingControlService? get renderingControl =>
      services.whereType<RenderingControlService>().singleOrNull;

  /// Connection setup and format negotiation.
  ConnectionManagerService? get connectionManager =>
      services.whereType<ConnectionManagerService>().singleOrNull;
}
