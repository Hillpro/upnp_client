import 'dart:io';

import 'package:upnp_client/src/device.dart';
import 'package:upnp_client/upnp_client.dart';

main() {
  print("Searching for devices");

  searchDevices().then((devices) =>
      devices.isEmpty ? print('No devices found') : devices.forEach(print));
}

Future<List<Device>> searchDevices() async {
  var deviceDiscover = DeviceDiscoverer();
  await deviceDiscover.start(addressTypes: [InternetAddressType.IPv4]);
  var devices = await deviceDiscover.getDevices();

  deviceDiscover.stop();
  return devices;
}
