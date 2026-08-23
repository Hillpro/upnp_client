import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:upnp_client/src/device.dart';
import 'package:upnp_client/src/utils/user_agent.dart';
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

    final Uri locationUri;
    try {
      locationUri = Uri.parse(location);
    } on FormatException catch (e, st) {
      // A device advertising an unparseable LOCATION is worth reporting, so
      // this stays on the errors stream rather than being dropped quietly.
      _errors.addError(e, st);
      return;
    }

    // UDA 1.1 §1.3.3: LOCATION must be a single absolute URL.
    // Accept http and https; drop anything else (e.g. malformed or unknown schemes).
    if (!{'http', 'https'}.contains(locationUri.scheme) ||
        locationUri.host.isEmpty) {
      return;
    }

    final httpClient = HttpClient();
    httpClient.connectionTimeout = _descriptionTimeout;
    try {
      // One deadline for the whole fetch. A device that sends headers and then
      // stalls mid-body used to hold this future open forever, and one such
      // device on the network was enough to leak a socket per search.
      await _fetchDevice(
        httpClient,
        locationUri,
        location,
      ).timeout(_descriptionTimeout);
    } on Exception catch (e, st) {
      _errors.addError(e, st);
    } finally {
      // force, or the connection the timeout abandoned stays open: a plain
      // close leaves active connections alone.
      httpClient.close(force: true);
    }
  }

  Future<void> _fetchDevice(
    HttpClient httpClient,
    Uri locationUri,
    String location,
  ) async {
    final request = await httpClient.getUrl(locationUri);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    // UDA 1.1 §2.11 defines the description response as "200 OK";
    // anything else is an error page rather than XML.
    if (response.statusCode != 200) {
      throw Exception(
        'ERROR: Device description request failed with status '
        '${response.statusCode}: $location',
      );
    }

    final rootElement = XmlDocument.parse(body).rootElement;
    final urlBase = rootElement.getElement('URLBase')?.innerText;
    final deviceXml = rootElement.getElement('device');

    if (deviceXml != null) {
      _devices.add(Device.fromXmlTyped(deviceXml, location, urlBase));
    }
  }

  Future<void> _search([String searchTarget = 'upnp:rootdevice']) async {
    final random = Random();

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
          ..writeln('USER-AGENT: $userAgent\n');

        final data = utf8.encode(buff.toString().replaceAll('\n', '\r\n'));

        // UDA 1.1 §1.3.2: retransmit 3x with a random delay to avoid flooding.
        for (var i = 0; i < 3; i++) {
          runZonedGuarded(
            () => socket.send(data, target.address, 1900),
            _errors.addError,
          );
          if (i < 2) {
            await Future.delayed(Duration(milliseconds: random.nextInt(100)));
          }
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

    await _search(searchTarget ?? 'upnp:rootdevice');
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
          (
            address: InternetAddress('239.255.255.250'),
            host: '239.255.255.250:1900',
          ),
        ];
      case InternetAddressType.IPv6:
        return [
          (address: InternetAddress('FF02::C'), host: '[FF02::C]:1900'),
          (address: InternetAddress('FF05::C'), host: '[FF05::C]:1900'),
        ];
      default:
        throw ArgumentError("Internet Address Type not valid");
    }
  }
}

typedef _MulticastTarget = ({InternetAddress address, String host});
