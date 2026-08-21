import 'package:upnp_client/src/devices/internet_gateway/wan_connection_device.dart';
import 'package:upnp_client/src/devices/internet_gateway/wan_device.dart';
import 'package:upnp_client/src/services/wan_connection.dart';
import 'package:upnp_client/src/device.dart';
import 'package:upnp_client/src/service.dart';
import 'package:upnp_client/src/types/upnp_service_type.dart';

/// An UPnP InternetGatewayDevice, the root of a residential gateway.
/// https://upnp.org/specs/gw/UPnP-gw-InternetGatewayDevice-v1-Device.pdf
///
/// IGD:1 §2.2 Table 1 fixes the shape of the tree beneath this device, and the
/// classes here mirror it rather than searching for services by type:
///
/// ```
/// InternetGatewayDevice:1          Layer3Forwarding:1
/// ├── WANDevice:1                  WANCommonInterfaceConfig:1
/// │   └── WANConnectionDevice:1    WANIPConnection:1 / WANPPPConnection:1
/// └── LANDevice:1                  LANHostConfigManagement:1
/// ```
///
/// One class per tier, one file per tier: [WanDevice], then
/// [WanConnectionDevice]. `LANDevice` is not modelled, so it parses as a plain
/// [Device] and stays reachable through [Device.devices].
///
/// The accessors are deliberately strict: they report what this gateway
/// actually advertises at each tier, so a device that does not follow the
/// template reads as empty rather than being papered over. Gateways do
/// deviate; [Device.findService] searches the whole subtree regardless of
/// shape when that is what you need.
class InternetGatewayDevice extends Device {
  InternetGatewayDevice.fromXml(super.xml, [super.url, super.urlBase])
    : super.fromXml();

  /// The WAN tiers beneath this gateway. Required, and IGD:1 §2.2 allows more
  /// than one.
  List<WanDevice> get wanDevices => devices.whereType<WanDevice>().toList();

  /// The `Layer3Forwarding:1` service, if this gateway offers it (optional per
  /// IGD:1 §2.2).
  ///
  /// Returned untyped: its `DefaultConnectionService` names which of
  /// [connections] the gateway prefers, but that is not modelled yet, so reach
  /// its actions through [Service.invokeAction].
  Service? get layer3Forwarding =>
      serviceOfType(UpnpServiceType.layer3Forwarding);

  /// Every WAN connection service beneath this gateway, in tree order.
  ///
  /// A gateway may expose several - one per WAN link, and WANConnectionDevice:1
  /// §2.2 allows several within one connection device. Layer3Forwarding's
  /// `DefaultConnectionService` is how the spec says to choose between them; it
  /// is a 2-tuple of the owning `WANConnectionDevice` UDN and the service id,
  /// both of which [Service.device] and [Service.id] expose. Picking one is
  /// left to the caller until that selection is modelled.
  List<WanConnectionService> get connections => wanDevices
      .expand((wan) => wan.connectionDevices)
      .expand((connectionDevice) => connectionDevice.connections)
      .toList();
}
