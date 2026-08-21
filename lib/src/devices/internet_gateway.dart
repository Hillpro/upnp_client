/// The InternetGatewayDevice family.
///
/// IGD:1 §2.2 defines a gateway as a tree of three device tiers rather than a
/// single device, and none of them is useful alone: reaching a connection
/// service means descending [InternetGatewayDevice] to [WanDevice] to
/// [WanConnectionDevice]. Import this file to get the whole tree.
library;

export 'internet_gateway/internet_gateway_device.dart';
export 'internet_gateway/wan_connection_device.dart';
export 'internet_gateway/wan_device.dart';
