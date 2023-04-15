import 'dart:io';

import 'package:upnp_client/upnp_client.dart';

Future<void> main() async {
  var deviceDiscover = DeviceDiscoverer();
  await deviceDiscover.start(addressType: InternetAddressType.IPv4);
  var devices = await deviceDiscover.getDevices();

  devices.forEach(print);
}
