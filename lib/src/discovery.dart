import 'dart:convert';
import 'dart:io';

class DeviceDiscoverer {
  final _sockets = <RawDatagramSocket>[];

  // TODO: Change how to receive addressType(s) choice
  Future<void> start(
      {int port = 0,
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

    socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final packet = socket.receive();

        if (packet == null) return;

        final data = utf8.decode(packet.data);
        final parts = data.split('\r\n');

        print(parts);

        // TODO: Decode data
      }
    });

    _sockets.add(socket);
  }

  void search([String searchTarget = 'upnp:rootdevice']) {
    final buff = StringBuffer()
      ..writeln('M-SEARCH * HTTP/1.1')
      ..writeln('HOST: 239.255.255.250:1900')
      ..writeln('MAN: "ssdp:discover"')
      ..writeln('MX: 3')
      ..writeln('ST: $searchTarget\n');

    final data = utf8.encode(buff.toString().replaceAll('\n', '\r\n'));

    for (var socket in _sockets) {
      // Repeated 3 times beacuse UDP messages might be lost
      for (var i = 0; i < 3; i++) {
        socket.send(data, _getMulticastAddress(socket.address.type), 1900);
      }
    }
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
