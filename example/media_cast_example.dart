// Casts an audio URL to the first MediaRenderer on the network, then reports
// playback position.
//
//   dart run example/media_cast_example.dart <http url to an mp3>
//
// The URL must be reachable *by the renderer*, so a localhost address will not
// work - serve the file on your LAN address.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:upnp_client/didl.dart';
import 'package:upnp_client/upnp_client.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('usage: dart run example/media_cast_example.dart <url>');
    return;
  }
  final url = args.first;

  final renderer = await _findRenderer();
  if (renderer == null) {
    print('No MediaRenderer answered.');
    return;
  }
  print('Renderer: ${renderer.description?.friendlyName}');

  // AVTransport is optional on a MediaRenderer (MediaRenderer:1 §2.2), so a
  // volume-only renderer has none.
  final transport = renderer.avTransport;
  if (transport == null) {
    print('Renderer exposes no AVTransport, so it cannot be handed a URL.');
    return;
  }

  // Renderers that match strictly on content format need a concrete MIME type
  // rather than the fully wildcarded default.
  final track = MusicTrack(
    id: '0',
    uri: url,
    title: 'Example track',
    artist: 'upnp_client',
    album: 'Examples',
    duration: const Duration(minutes: 3, seconds: 30),
    artUri: null,
    protocolInfo: 'http-get:*:audio/mpeg:*',
  );

  await transport.setAVTransportURI(url, metadata: track.toXml());
  await transport.play();
  print('Playing.');

  final volume = renderer.renderingControl;
  if (volume != null) {
    print(
      'Volume: ${await volume.getVolume()}, muted: ${await volume.getMute()}',
    );
  }

  // Formats the renderer supports, useful when a cast is rejected.
  final formats = await renderer.connectionManager?.getProtocolInfo();
  if (formats != null) {
    print(
      'Renderer accepts ${formats.sink.length} protocolInfo entries, e.g.:',
    );
    for (final info in formats.sink.take(3)) {
      print('  $info');
    }
  }

  await Future<void>.delayed(const Duration(seconds: 5));
  final position = await transport.getPositionInfo();
  print('Position: ${position.relTime} of ${position.trackDuration}');

  await transport.stop();
  print('Stopped.');
}

Future<MediaRenderer?> _findRenderer() async {
  final discoverer = DeviceDiscoverer();
  try {
    await discoverer.start(addressTypes: [InternetAddressType.IPv4]);
    // The enum doubles as an SSDP search target, so only renderers reply.
    final devices = await discoverer.getDevices(
      searchTarget: UpnpDeviceType.mediaRenderer.urn(),
    );
    return devices.whereType<MediaRenderer>().firstOrNull;
  } finally {
    discoverer.stop();
  }
}
