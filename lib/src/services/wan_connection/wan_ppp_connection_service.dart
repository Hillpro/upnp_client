import 'package:upnp_client/src/services/wan_connection/wan_connection_service.dart';

/// An UPnP WANPPPConnection service, for a WAN link that dials rather than
/// routes.
/// https://upnp.org/specs/gw/UPnP-gw-WANPPPConnection-v1-Service.pdf
class WanPppConnectionService extends WanConnectionService {
  WanPppConnectionService.fromXml(super.device, super.xml) : super.fromXml();
}
