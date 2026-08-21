import 'package:upnp_client/src/services/wan_connection.dart';
import 'package:upnp_client/src/device.dart';

/// An UPnP WANConnectionDevice, the gateway tier that hosts the connection
/// services.
/// https://upnp.org/specs/gw/UPnP-gw-WANConnectionDevice-v1-Device.pdf
///
/// The innermost tier of the gateway tree - see [InternetGatewayDevice] for
/// the shape of the whole thing. Reached through [WanDevice.connectionDevices].
class WanConnectionDevice extends Device {
  WanConnectionDevice.fromXml(super.xml, [super.url, super.urlBase])
    : super.fromXml();

  /// The connection services on this device.
  ///
  /// WANConnectionDevice:1 §2.2 requires `WANIPConnection:1` for IP-based
  /// modems and `WANPPPConnection:1` for PPP-based ones, and allows several
  /// instances of either, distinguished by service id (`WANIPConn1`,
  /// `WANIPConn2`, ...).
  List<WanConnectionService> get connections =>
      services.whereType<WanConnectionService>().toList();
}
