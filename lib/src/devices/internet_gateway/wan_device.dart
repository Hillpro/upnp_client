import 'package:upnp_client/src/devices/internet_gateway/wan_connection_device.dart';
import 'package:upnp_client/src/device.dart';
import 'package:upnp_client/src/service.dart';
import 'package:upnp_client/src/types/upnp_service_type.dart';

/// An UPnP WANDevice, the gateway tier modelling a physical WAN interface.
/// https://upnp.org/specs/gw/UPnP-gw-WANDevice-v1-Device.pdf
///
/// The middle tier of the gateway tree - see [InternetGatewayDevice] for the
/// shape of the whole thing. Reached through
/// [InternetGatewayDevice.wanDevices].
class WanDevice extends Device {
  WanDevice.fromXml(super.xml, [super.url, super.urlBase]) : super.fromXml();

  /// The connection device tiers beneath this interface. WANDevice:1 §2.2
  /// allows more than one.
  List<WanConnectionDevice> get connectionDevices =>
      devices.whereType<WanConnectionDevice>().toList();

  /// The `WANCommonInterfaceConfig:1` service, required by WANDevice:1 §2.2.
  ///
  /// Returned untyped: it carries link properties and byte counters, which are
  /// not modelled. Reach its actions through [Service.invokeAction].
  Service? get wanCommonInterfaceConfig =>
      serviceOfType(UpnpServiceType.wanCommonInterfaceConfig);
}
