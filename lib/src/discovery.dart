import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:upnp_client/src/device.dart';
import 'package:xml/xml.dart';

const _descriptionTimeout = Duration(seconds: 30);

/// [DeviceDiscoverer] uses Simple Service Discovery Protocol Based on UDP Multicast (SSDP) to issue searches and find UPnP devices and services.
///
/// You can start the discoverer in either IPv4 or IPv6, or both.
class DeviceDiscoverer {
  final _sockets = <RawDatagramSocket>[];
  final _devices = StreamController<Device>.broadcast();
  final _errors = StreamController<void>.broadcast();
  static const _supportedAddressTypes = [
    InternetAddressType.IPv4,
    InternetAddressType.IPv6,
  ];

  /// A stream of discovered UPnP devices.
  Stream<Device> get devices => _devices.stream;

  /// A stream of errors occurred during the discovery process.
  /// These errors are not fatal and will not stop the discovery process.
  Stream<void> get errors => _errors.stream;

  /// Starts the Discoverer.
  ///
  /// Starts a socket to listen to UPnP devices responses on a given [port]
  /// Listen for all given [InternetAddressType]
  /// By default, a socket will be created for every supported types.
  /// Currently, IP version 4 (IPv4), IP version 6 (IPv6) are supported.
  Future<void> start({
    int port = 0,
    int multicastHops = 2,
    List<InternetAddressType> addressTypes = _supportedAddressTypes,
  }) async {
    for (var addressType in addressTypes) {
      if (_supportedAddressTypes.contains(addressType)) {
        await _createSocket(
          _getBroadcastAddress(addressType),
          port,
          multicastHops,
        );
      }
    }
  }

  /// Stops the Discoverer.
  ///
  /// Closes all udp sockets.
  void stop() {
    for (var socket in _sockets) {
      socket.close();
    }
    _sockets.clear();
  }

  /// Disposes the Discoverer.
  ///
  /// Stops discovery and closes all streams. After calling this,
  /// the discoverer cannot be reused.
  void dispose() {
    stop();
    _devices.close();
    _errors.close();
  }

  Future<void> _createSocket(
    InternetAddress address, [
    int port = 0,
    int multicastHops = 2,
  ]) async {
    final socket = await RawDatagramSocket.bind(address, port);

    // UDA 1.1 §1.3.2: TTL SHOULD default to 2 and SHOULD be configurable.
    socket.multicastHops = multicastHops;
    _sockets.add(socket);

    socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final packet = socket.receive();
        if (packet == null) return;

        final List<String> headers;
        try {
          headers = utf8.decode(packet.data).split('\r\n');
        } on FormatException catch (e, st) {
          _errors.addError(e, st);
          return;
        }

        // UDA 1.1 §1.3.3: status line is always first; only accept 200 OK responses.
        if (!headers.first.contains('200 OK')) {
          return;
        }

        _addDevice(headers);
      }
    }, onError: _errors.addError);
  }

  Future<void> _addDevice(List<String> headers) async {
    final locationHeader = headers.firstWhere(
      (element) => element.toUpperCase().startsWith('LOCATION'),
      orElse: () => '',
    );

    if (locationHeader.isEmpty) return;

    final separatorIndex = locationHeader.indexOf(':');
    if (separatorIndex == -1) return;
    final location = locationHeader.substring(separatorIndex + 1).trim();

    final httpClient = HttpClient();
    httpClient.connectionTimeout = _descriptionTimeout;
    try {
      final locationUri = Uri.parse(location);
      // UDA 1.1 §1.3.3: LOCATION must be a single absolute URL.
      // Accept http and https; drop anything else (e.g. malformed or unknown schemes).
      if (!{'http', 'https'}.contains(locationUri.scheme) ||
          locationUri.host.isEmpty) {
        return;
      }

      final request = await httpClient.getUrl(locationUri);
      final response = await request.close().timeout(_descriptionTimeout);
      final rootElement = XmlDocument.parse(
        await response.transform(utf8.decoder).join(),
      ).rootElement;
      final urlBase = rootElement.getElement('URLBase')?.innerText;
      final deviceXml = rootElement.getElement('device');

      if (deviceXml != null) {
        _devices.add(Device.fromXml(deviceXml, location, urlBase));
      }
    } on Exception catch (e, st) {
      _errors.addError(e, st);
    } finally {
      httpClient.close();
    }
  }

  void _search([String searchTarget = 'upnp:rootdevice']) {
    for (var socket in _sockets) {
      final targets = _getMulticastTargets(socket.address.type);

      for (var target in targets) {
        // UDA 1.1 §1.3.2 - Search request with M-SEARCH
        final buff = StringBuffer()
          ..writeln('M-SEARCH * HTTP/1.1')
          ..writeln('HOST: ${target.host}')
          ..writeln('MAN: "ssdp:discover"')
          ..writeln('MX: 3')
          ..writeln('ST: $searchTarget')
          ..writeln(
            'USER-AGENT: ${Platform.operatingSystem}/${Platform.operatingSystemVersion} UPnP/1.1 Dart/${Platform.version}\n',
          );

        final data = utf8.encode(buff.toString().replaceAll('\n', '\r\n'));

        // Repeated 3 times because UDP messages might be lost
        for (var i = 0; i < 3; i++) {
          runZonedGuarded(
            () => socket.send(data, target.address, 1900),
            _errors.addError,
          );
        }
      }
    }
  }

  /// Search for UPnP devices matching [searchTarget]
  /// for a given [timeout] time, then returns the list.
  Future<List<Device>> getDevices({
    Duration timeout = const Duration(seconds: 5),
    String? searchTarget,
  }) async {
    final devices = <Device>{};

    var sub = _devices.stream.listen(devices.add);

    _search(searchTarget ?? 'upnp:rootdevice');
    await Future.delayed(timeout);
    await sub.cancel();

    return devices.toList();
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

  /// Returns the multicast targets for a given address type.
  ///
  /// Per UPnP Device Architecture 2.0 (section A.4.5):
  /// - IPv4: single target 239.255.255.250:1900
  /// - IPv6: Link-Local scope FF02::C (mandatory) and
  ///   Site-Local scope FF05::C (for discovery across subnets)
  List<_MulticastTarget> _getMulticastTargets(InternetAddressType addressType) {
    switch (addressType) {
      case InternetAddressType.IPv4:
        return [
          _MulticastTarget(
            InternetAddress('239.255.255.250'),
            '239.255.255.250:1900',
          ),
        ];
      case InternetAddressType.IPv6:
        return [
          _MulticastTarget(InternetAddress('FF02::C'), '[FF02::C]:1900'),
          _MulticastTarget(InternetAddress('FF05::C'), '[FF05::C]:1900'),
        ];
      default:
        throw ArgumentError("Internet Address Type not valid");
    }
  }
}

class _MulticastTarget {
  final InternetAddress address;
  final String host;

  const _MulticastTarget(this.address, this.host);
}
