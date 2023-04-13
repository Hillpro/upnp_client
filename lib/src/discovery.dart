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

  Future<void> _createSocket(InternetAddress address, int port) async {
    final socket = await RawDatagramSocket.bind(address, port);

    socket.listen((event) {
      print(event);
      if (event == RawSocketEvent.read) {
        final packet = socket.receive();

        if (packet == null) return;

        final data = utf8.decode(packet.data);
        final parts = data.split('\r\n');

        print(parts);
      }
    });

    _sockets.add(socket);
  }

  void search([String searchTarget = 'upnp:rootdevice']) {
    final buff = StringBuffer();

    buff.write('M-SEARCH * HTTP/1.1\r\n');
    buff.write('HOST: 239.255.255.250:1900\r\n');
    buff.write('MAN: "ssdp:discover"\r\n');
    buff.write('MX: 3\r\n');
    buff.write('ST: $searchTarget\r\n');
    final data = utf8.encode(buff.toString());

    for (var socket in _sockets) {
      // Repeated 3 times beacuse UDP messages might be lost
      for (int i = 0; i < 3; i++) {
        socket.send(data, _getMulticastAddress(socket.address.type), 1900);
      }
    }
  }

  List<InternetAddress> _getAddresses(InternetAddressType addressType) {
    if (addressType == InternetAddressType.any) {
      return [InternetAddress.anyIPv4, InternetAddress.loopbackIPv6];
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
