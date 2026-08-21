# Examples

Three runnable programs, each needing a real device on the local network:

| File | What it does |
| --- | --- |
| `upnp_client_example.dart` | Discovers every UPnP device and prints the tree |
| `port_forward_example.dart` | Opens and removes a NAT port mapping on the router (IGD) |
| `media_cast_example.dart` | Casts an audio URL to a renderer and reports position (DLNA) |

```
dart run example/upnp_client_example.dart
dart run example/port_forward_example.dart 8080
dart run example/media_cast_example.dart http://192.168.1.20:8000/song.mp3
```

## Discovery

`getDevices` returns typed profiles, so a `MediaRenderer` or an
`InternetGatewayDevice` arrives ready to use. Passing a search target means
only devices of that type answer, which is faster and quieter than filtering
afterwards — and the type enum produces the target for you.

```dart
final discoverer = DeviceDiscoverer();
await discoverer.start(addressTypes: [InternetAddressType.IPv4]);

final devices = await discoverer.getDevices(
  searchTarget: UpnpDeviceType.mediaRenderer.urn(),
);
discoverer.stop();

for (final device in devices) {
  print('${device.description?.friendlyName} (${device.runtimeType})');
}
```

## Port forwarding (InternetGatewayDevice)

A gateway does not put its connection service on the root device. IGD:1 §2.2
nests it two `deviceList` levels down, and `connections` walks those tiers for
you:

```dart
final gateway = devices.whereType<InternetGatewayDevice>().first;
final connection = gateway.connections.first;

print(await connection.getExternalIpAddress());

await connection.addPortMapping(
  externalPort: 8080,
  protocol: PortMappingProtocol.tcp,
  internalPort: 8080,
  internalClient: '192.168.1.42', // this host's LAN address
  description: 'my app',
);

for (final mapping in await connection.listPortMappings()) {
  print('${mapping.externalPort} -> ${mapping.internalClient}');
}

await connection.deletePortMapping(
  externalPort: 8080,
  protocol: PortMappingProtocol.tcp,
);
```

Three things worth knowing before relying on this:

- **`internalClient` is yours to supply.** The package will not guess which of
  your addresses to forward to. Note that Dart offers no local address for a
  connected socket — `Socket.address` is the *remote* end despite the name — so
  `port_forward_example.dart` matches the local interface sharing the longest
  address prefix with the gateway, which beats taking the first private address
  on a host that also has a VM bridge or VPN.
- **Many gateways refuse timed leases**, answering
  `WanConnectionError.onlyPermanentLeasesSupported` (725). Retry with
  `Duration.zero` and delete the mapping yourself on shutdown.
- **A conflicting port throws** `WanConnectionError.conflictInMappingEntry`
  (718) rather than stealing the mapping, because the port belongs to another
  host on the network.

`WanIpConnectionService` and `WanPppConnectionService` share one action set, so
match on the base `WanConnectionService` — which of the two a router exposes
depends on how its modem attaches.

## Casting media (MediaRenderer)

AV profiles advertise services on the device itself, so the accessors read
straight off the renderer:

```dart
final renderer = devices.whereType<MediaRenderer>().first;

const track = MusicTrack(
  id: '0',
  uri: 'http://192.168.1.20:8000/song.mp3',
  title: 'Example track',
  artist: 'upnp_client',
  album: 'Examples',
  duration: Duration(minutes: 3, seconds: 30),
  artUri: null,
  protocolInfo: 'http-get:*:audio/mpeg:*',
);

await renderer.avTransport!.setAVTransportURI(track.uri, metadata: track.toXml());
await renderer.avTransport!.play();

await renderer.renderingControl!.setVolume(volume: 30);
print(await renderer.avTransport!.getPositionInfo().then((p) => p.relTime));
```

- **The URL must be reachable by the renderer**, not by you — a `localhost`
  address will not play.
- **`avTransport` may be null.** MediaRenderer:1 §2.2 makes AVTransport
  optional, so a volume-only renderer has none.
- **A wildcarded `protocolInfo` is rejected by some renderers.** Give a
  concrete MIME type when a cast fails for no obvious reason;
  `connectionManager.getProtocolInfo()` lists what the renderer accepts.

## Reaching anything not modelled

Services without a typed wrapper are plain `Service`, driven through
`invokeAction`. `serviceOfType` finds one by its UPnP type:

```dart
final l3f = gateway.serviceOfType(UpnpServiceType.layer3Forwarding);
final args = await l3f!.invokeAction('GetDefaultConnectionService', {});
print(args['NewDefaultConnectionService']);
```

And when a device does not follow its template — gateways are the usual
offenders — `findService` searches the whole subtree regardless of shape:

```dart
final connection = gateway.findService<WanConnectionService>();
```
