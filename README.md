
# UPnP Client

[![License](https://img.shields.io/badge/License-MIT-brightgreen.svg)](https://github.com/Hillpro/upnp_client/blob/main/LICENSE)
[![Supported Dart SDK](https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2FHillpro%2Fupnp_client%2Frefs%2Fheads%2Fmain%2Fpubspec.yaml&query=%24.environment.sdk&label=dart&color=blue)](https://dart.dev/)
[![Package Version](https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2FHillpro%2Fupnp_client%2Frefs%2Fheads%2Fmain%2Fpubspec.yaml&query=%24.version&label=version&color=orange)](https://pub.dev/packages/upnp_client)
[![Package download statistics](https://img.shields.io/pub/dm/upnp_client.svg?color=brightgreen)](https://pub.dev/packages/upnp_client/score)
[![Development Status](https://img.shields.io/badge/status-stable-blue.svg)](https://en.wikipedia.org/wiki/Software_release_life_cycle#Stable_release)

Universal Plug and Play (UPnP) Client Implementation. Supports IGD control as well as DLNA media casting.

**Covered**

- **Discovery** — SSDP search over IPv4 and IPv6, returning typed device profiles
- **DLNA casting** — `AVTransport` playback, `RenderingControl` volume and mute,
  `ConnectionManager` format negotiation, and DIDL-Lite metadata
- **IGD port forwarding** — NAT port mapping on `WANIPConnection` /
  `WANPPPConnection`, plus external IP and WAN connection status

**Not covered** — eventing (GENA `SUBSCRIBE`/`NOTIFY`), `ContentDirectory`
browsing, and IPv6 pinholes. Services without a typed wrapper are still
reachable through `Service.invokeAction`.

## Installation

Use the package manager [pub](https://pub.dev/) to install the upnp client.

```
dart pub add upnp_client
```

## Usage

See [example/example.md](example/example.md) for discovery, port forwarding and
media casting, or run one of the examples against your own network:

```
dart run example/upnp_client_example.dart                 # discover everything
dart run example/port_forward_example.dart 8080           # map a port on the router
dart run example/media_cast_example.dart <http url>       # cast audio to a renderer
```


### To use on an Android device

You must add the following permissions in your AndroidManifest.xml

``` xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" android.usesPermissionFlags="neverForLocation"/>
```


### To use on an iOS device (Required for iOS 14+)

You need to follow these steps to use Multicast Networking functionalities on any iOS device:

1. Go to https://developer.apple.com/contact/request/networking-multicast and fill out the form for your app.
2. Wait for the acceptance email (Approx. 30 days).
3. Go to https://developer.apple.com/account/resources/identifiers/list.
4. Choose the needed app.
5. Go to "Additional Capabilities".
6. Mark "Multicast Networking".
7. Go to your project file "Runner.xcworkspace".
8. Choose "Runner" -> "Signing & Capabilities" -> "+ capability" and search for "Multicast Networking".
9. Build your project.

## Contributing

Pull requests are welcome. For major changes, please open an issue first
to discuss what you would like to change.

## License

[MIT](https://choosealicense.com/licenses/mit/)
