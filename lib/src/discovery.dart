import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:upnp_client/src/device.dart';
import 'package:xml/xml.dart';

///
/// [DeviceDiscoverer] uses Simple Service Discovery Protocol Based on UDP Multicast (SSDP) to issue searches and find UPnP devices and services.
///
/// You can start the discoverer in either IPv4 or IPv6, or both.
///
class DeviceDiscoverer {
  final _sockets = <RawDatagramSocket>[];
  final _devices = StreamController<Device>.broadcast();

  ///
  /// Starts the Discoverer.
  ///
  /// Starts a socket to listen to UPnP devices responses for a given [InternetAddressType] and [port]
  /// If the address type is [InternetAddressType.any], a socket will be created for every supported types.
  /// Currently, IP version 4 (IPv4), IP version 6 (IPv6) are supported.
  ///
  /// Throws an [ArgumentError] if the [InternetAddressType] is not supported.
  ///
  Future<void> start(
      {int port = 0,
      // TODO: Change how to receive addressType(s) choice
      InternetAddressType addressType = InternetAddressType.any}) async {
    if (addressType == InternetAddressType.unix) {
      throw ArgumentError("Internet Address Type not valid");
    }

    for (var address in _getAddresses(addressType)) {
      await _createSocket(address, port);
    }
  }

  Future<void> _createSocket(InternetAddress address, [int port = 0]) async {
    final socket = await RawDatagramSocket.bind(address, port);
    _sockets.add(socket);

    socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final packet = socket.receive();

        if (packet == null) return;

        final data = utf8.decode(packet.data);
        final parts = data.split('\r\n');

        if (parts
                .indexWhere((element) => element.contains('HTTP/1.1 200 OK')) ==
            -1) return;

        _addDevice(parts);
      }
    });
  }

  void _addDevice(List<String> message) async {
    var location = message.firstWhere(
        (element) => element.toUpperCase().contains('LOCATION'),
        orElse: () => '');

    if (location == '') return;

    location = location.substring(location.indexOf('http'));

    var request = await HttpClient().getUrl(Uri.parse(location));
    var response = await request.close();

    final deviceXml =
        XmlDocument.parse(await response.transform(utf8.decoder).join())
            .rootElement
            .getElement('device');

    if (deviceXml != null) _devices.add(Device.fromXml(deviceXml, location));
  }

  void _search([String searchTarget = 'upnp:rootdevice']) {
    final buff = StringBuffer()
      ..writeln('M-SEARCH * HTTP/1.1')
      ..writeln('HOST: 239.255.255.250:1900')
      ..writeln('MAN: "ssdp:discover"')
      ..writeln('MX: 3')
      ..writeln('ST: $searchTarget\n');

    final data = utf8.encode(buff.toString().replaceAll('\n', '\r\n'));

    for (var socket in _sockets) {
      var multicastAddress = _getMulticastAddress(socket.address.type);
      // Repeated 3 times beacuse UDP messages might be lost
      for (var i = 0; i < 3; i++) {
        socket.send(data, multicastAddress, 1900);
      }
    }
  }

  ///
  /// Search for UPnP devices for a given [timeout] time, then returns the list
  ///
  Future<List<Device>> getDevices(
      {Duration timeout = const Duration(seconds: 5)}) async {
    final list = <Device>[];

    final sub = _devices.stream
        .listen((device) => {if (!list.contains(device)) list.add(device)});

    _search();
    await Future.delayed(timeout);
    await sub.cancel();

    return list;
  }

  List<InternetAddress> _getAddresses(InternetAddressType addressType) {
    if (addressType == InternetAddressType.any) {
      return [InternetAddress.anyIPv4, InternetAddress.anyIPv6];
    }
    return [
      addressType == InternetAddressType.IPv4
          ? InternetAddress.anyIPv4
          : InternetAddress.anyIPv6
    ];
  }

  InternetAddress _getMulticastAddress(InternetAddressType addressType) {
    switch (addressType) {
      case InternetAddressType.IPv4:
        return InternetAddress('239.255.255.250');
      case InternetAddressType.IPv6:
        return InternetAddress('FF05::C');
      default:
        throw ArgumentError("Internet Address Type not valid");
    }
  }
}
