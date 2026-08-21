/// The IGD WAN connection service family.
///
/// `WANIPConnection:1` and `WANPPPConnection:1` declare the same connection
/// management and NAT port mapping actions, so the behaviour lives on the
/// shared [WanConnectionService] base and the two concrete services are thin
/// markers over it. Import this file to get the whole family.
library;

export 'wan_connection/connection_status_info.dart';
export 'wan_connection/nat_rsip_status.dart';
export 'wan_connection/port_mapping.dart';
export 'wan_connection/port_mapping_protocol.dart';
export 'wan_connection/wan_connection_error.dart';
export 'wan_connection/wan_connection_service.dart';
export 'wan_connection/wan_ip_connection_service.dart';
export 'wan_connection/wan_ppp_connection_service.dart';
