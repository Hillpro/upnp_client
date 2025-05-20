import 'dart:io';

import 'package:upnp_client/upnp_client.dart';

main(List<String> args) {
  print("Searching for devices");

  searchDevices(searchTarget: args.isNotEmpty ? args[0] : null).then(
      (devices) =>
          devices.isEmpty ? print('No devices found') : devices.forEach(print));
}

Future<List<Device>> searchDevices({String? searchTarget}) async {
  var deviceDiscover = DeviceDiscoverer();
  await deviceDiscover.start(addressTypes: [InternetAddressType.IPv4]);
  var devices = await deviceDiscover.getDevices(searchTarget: searchTarget);

  deviceDiscover.stop();
  return devices;
}
