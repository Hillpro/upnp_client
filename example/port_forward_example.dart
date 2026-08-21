// Opens a NAT port mapping on the local router, lists the mapping table, then
// removes the mapping again.
//
//   dart run example/port_forward_example.dart [port]
//
// Requires a router with UPnP IGD enabled. Many ship with it turned off.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:upnp_client/upnp_client.dart';

Future<void> main(List<String> args) async {
  final port = int.tryParse(args.isNotEmpty ? args.first : '') ?? 8080;

  final gateway = await _findGateway();
  if (gateway == null) {
    print('No InternetGatewayDevice answered. Is UPnP enabled on the router?');
    return;
  }
  print('Gateway: ${gateway.description?.friendlyName}');

  // The typed walk mirrors IGD:1 Table 1. A router that does not follow the
  // template reports no connections, so fall back to searching the subtree.
  final connection =
      gateway.connections.firstOrNull ??
      gateway.findService<WanConnectionService>();
  if (connection == null) {
    print('Gateway exposes no WAN connection service.');
    return;
  }
  print('Connection: ${connection.id} (${connection.runtimeType})');

  final status = await connection.getStatusInfo();
  print('Status: ${status.connectionStatus}, up ${status.uptime}');
  print('External IP: ${await connection.getExternalIpAddress()}');

  final internalClient = await _lanAddressToward(gateway);
  print('Mapping $port -> $internalClient:$port ...');
  await _addMapping(connection, port: port, internalClient: internalClient);

  print('Port mapping table:');
  for (final mapping in await connection.listPortMappings()) {
    print(
      '  ${mapping.protocol?.wireValue} ${mapping.externalPort}'
      ' -> ${mapping.internalClient}:${mapping.internalPort}'
      '  lease=${mapping.leaseDuration}'
      '  ${mapping.description}',
    );
  }

  await connection.deletePortMapping(
    externalPort: port,
    protocol: PortMappingProtocol.tcp,
  );
  print('Mapping removed.');
}

/// Adds the mapping, retrying without a lease if the gateway refuses one.
///
/// WANIPConnection:1 §2.4.16 warns that a gateway need not support timed
/// leases, and plenty do not: they answer 725 OnlyPermanentLeasesSupported.
/// A permanent mapping has to be deleted explicitly, so a program that relies
/// on this should remove it on shutdown rather than leaving it behind.
Future<void> _addMapping(
  WanConnectionService connection, {
  required int port,
  required String internalClient,
}) async {
  Future<void> add(Duration lease) => connection.addPortMapping(
    externalPort: port,
    protocol: PortMappingProtocol.tcp,
    internalPort: port,
    internalClient: internalClient,
    description: 'upnp_client example',
    leaseDuration: lease,
  );

  try {
    await add(const Duration(hours: 1));
  } on UPnPException catch (e) {
    switch (e.errorCode) {
      case WanConnectionError.onlyPermanentLeasesSupported:
        print('Gateway refuses timed leases; mapping permanently instead.');
        await add(Duration.zero);
      case WanConnectionError.conflictInMappingEntry:
        // The port belongs to another host. Deleting its mapping to take the
        // port would break whatever is using it, so this reports instead.
        print('Port $port is already mapped to a different client.');
        rethrow;
      default:
        rethrow;
    }
  }
}

Future<InternetGatewayDevice?> _findGateway() async {
  final discoverer = DeviceDiscoverer();
  try {
    await discoverer.start(addressTypes: [InternetAddressType.IPv4]);
    // The enum doubles as an SSDP search target, so only gateways reply.
    final devices = await discoverer.getDevices(
      searchTarget: UpnpDeviceType.internetGatewayDevice.urn(),
    );
    return devices.whereType<InternetGatewayDevice>().firstOrNull;
  } finally {
    discoverer.stop();
  }
}

/// The address of this host on the same network as [gateway].
///
/// `AddPortMapping` needs the LAN address to forward traffic to, and the
/// package deliberately does not guess it. Dart exposes no local address for a
/// connected socket - `Socket.address` is the *remote* end, despite the name -
/// so this picks the local interface sharing the longest address prefix with
/// the gateway. On a host with several interfaces that beats taking the first
/// private address, which may belong to a VM bridge or VPN.
Future<String> _lanAddressToward(InternetGatewayDevice gateway) async {
  final host = Uri.parse(gateway.urlBase!).host;
  final gatewayIp = (await InternetAddress.lookup(
    host,
  )).firstWhere((a) => a.type == InternetAddressType.IPv4).rawAddress;

  String? best;
  var bestBits = -1;
  for (final interface in await NetworkInterface.list(
    type: InternetAddressType.IPv4,
  )) {
    for (final address in interface.addresses) {
      final bits = _commonPrefixBits(address.rawAddress, gatewayIp);
      if (bits > bestBits) {
        bestBits = bits;
        best = address.address;
      }
    }
  }
  if (best == null) throw StateError('No IPv4 interface found');
  return best;
}

/// How many leading bits [a] and [b] share.
int _commonPrefixBits(List<int> a, List<int> b) {
  var bits = 0;
  for (var i = 0; i < a.length && i < b.length; i++) {
    final differing = a[i] ^ b[i];
    if (differing == 0) {
      bits += 8;
      continue;
    }
    for (var bit = 7; bit >= 0 && differing & (1 << bit) == 0; bit--) {
      bits++;
    }
    break;
  }
  return bits;
}
