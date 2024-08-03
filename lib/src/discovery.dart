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
  static const _supportedAddressTypes = [
    InternetAddressType.IPv4,
    InternetAddressType.IPv6
  ];

  ///
  /// Starts the Discoverer.
  ///
  /// Starts a socket to listen to UPnP devices responses on a given [port]
  /// Listen for all given [InternetAddressType]
  /// By default, a socket will be created for every supported types.
  /// Currently, IP version 4 (IPv4), IP version 6 (IPv6) are supported.
  ///
  Future<void> start(
      {int port = 0,
      List<InternetAddressType> addressTypes = _supportedAddressTypes}) async {
    for (var addressType in addressTypes) {
      if (_supportedAddressTypes.contains(addressType)) {
        await _createSocket(_getBroadcastAddress(addressType), port);
      }
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
        final headers = data.split('\r\n');

        if (headers.indexWhere((e) => e.contains('HTTP/1.1 200 OK')) == -1) return;

        _addDevice(headers);
      }
    });
  }

  void _addDevice(List<String> headers) async {
    var location = headers.firstWhere(
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
    final List<Device> devices = [];

    var sub = _devices.stream
        .listen((d) {if (!devices.contains(d)) devices.add(d);});

    _search();
    await Future.delayed(timeout);
    await sub.cancel();

    return devices;
  }

  InternetAddress _getBroadcastAddress(InternetAddressType addressType) {
    switch (addressType) {
      case InternetAddressType.IPv4:
        return InternetAddress.anyIPv4;
      case InternetAddressType.IPv6:
        return InternetAddress.anyIPv6;
      default:
        throw ArgumentError("Internet Address Type not valid");
    }
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
