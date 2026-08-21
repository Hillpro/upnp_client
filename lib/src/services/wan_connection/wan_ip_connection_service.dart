import 'package:upnp_client/src/services/wan_connection/wan_connection_service.dart';

/// An UPnP WANIPConnection service, for a router-attached WAN link.
/// https://upnp.org/specs/gw/UPnP-gw-WANIPConnection-v1-Service.pdf
class WanIpConnectionService extends WanConnectionService {
  WanIpConnectionService.fromXml(super.device, super.xml) : super.fromXml();
}
