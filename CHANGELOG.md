# Changelog

All notable changes to this project will be documented in this file.

## 1.4.1

- **FIX**: The SSDP `USER-AGENT` sends three sanitised product tokens (UDA 1.1 §1.3.2). The third token is now `upnp_client/<version>`, not `Dart/<version>`
- **INFO**: Silenced the four `constant_identifier_names` infos on the spec-named `DataType` constants
- **INFO**: Declared `topics` and `issue_tracker` in `pubspec.yaml`


## 1.4.0

- **FIX**: `manufacturerUrl` and `modelUrl` were permanently null; the elements are `<manufacturerURL>` and `<modelURL>` (UDA 1.1 §3.2.1)
- **FIX**: `sendEventsAttribute` defaults to true when the attribute is omitted, and accepts the `"1"`/`"0"` spelling (UDA 1.1 §2.5)
- **FIX**: UPnP boolean values match case-insensitively (UDA 1.1 §2.5 and §3.2)
- **FIX**: `PlayMode.direct1` sends `DIRECT_1`, not `"DIRECT 1"` (AVTransport:1 §3)
- **FIX**: `SeekMode.tapeIndex` sends `TAPE-INDEX`, not `TAPE_INDEX` (AVTransport:1 §3)
- **FIX**: `getCurrentTransportActions()` trims its entries (AVTransport:1 §2.2.26)
- **FIX**: A response body carrying no `<nameResponse>`, or a SOAP fault under HTTP 200, now throws instead of returning `{}` (UDA 1.1 §3.2.5). Callers previously got `-1` from `getVolume()` and `null` from `getExternalIpAddress()` where the response was unreadable
- **FIX**: The 30-second timeout covers the whole HTTP exchange, not just the wait for headers (UDA 1.1 §3.2.2). A device stalling mid-body previously hung forever
- **FIX**: `getProtocolInfo()` skips malformed entries instead of discarding every format that parsed
- **FEAT**: `ProtocolInfo.tryParse`, the lenient counterpart of `fromString`
- **FEAT**: `WanConnectionError` names twelve codes where it named five, adding 715, 716, 726 and 727 from WANIPConnection:1 and 728, 729 and 732 from WANIPConnection:2
- **DEPRECATED**: `DeviceDescription.modelType` — no UPnP version defines a `<modelType>` element. Still parses until removal
- **INFO**: Added the AVTransport:3 specification under `doc/`


## 1.3.1

- **INFO**: Silenced the `namespace`/`namespaces` deprecation warnings introduced by xml 7.0.1. No behaviour change: the replacements require Dart 3.11, above this package's 3.8 SDK floor.

## 1.3.0

- **FEAT**: IGD NAT port mapping through `WanConnectionService`, subclassed as `WanIpConnectionService` (`WANIPConnection`) and `WanPppConnectionService` (`WANPPPConnection`) because both declare the same actions: `addPortMapping()`, `deletePortMapping()`, `getSpecificPortMappingEntry()`, `getGenericPortMappingEntry()` and `listPortMappings()`
- **FEAT**: WAN connection state on the same services: `getExternalIpAddress()`, `getStatusInfo()` and `getNatRsipStatus()`. IGD error codes are named in `WanConnectionError`; 713 ends a mapping enumeration and 714 means "no such mapping", both surfacing as `null`
- **FEAT**: Typed device profiles `InternetGatewayDevice`, `WanDevice`, `WanConnectionDevice`, `MediaRenderer` and `MediaServer`, returned by the new `Device.fromXmlTyped()` that discovery now uses. The gateway tiers mirror IGD:1 §2.2, so `gateway.connections` walks the two `deviceList` levels the template requires rather than searching for the service
- **FEAT**: `UpnpDeviceType` and `UpnpServiceType` name every standard type URN this package references, matching version-independently per UDA 1.1 §1.3.2. `urn()` doubles as an SSDP search target: `getDevices(searchTarget: UpnpDeviceType.internetGatewayDevice.urn())`
- **FEAT**: `Device.findService<T>()`, `findServices<T>()` and `allServices` search a device's whole subtree, for devices that do not follow their template
- **FEAT**: `Device.serviceOfType()` and `Service.standardType` match on the UPnP service type rather than a Dart type, which is how to reach a service with no typed wrapper
- **DEPRECATED**: `Device.avTransportService()`, `renderingControlService()` and `connectionManagerService()` — these belong to a device profile rather than to every device. Use `MediaRenderer.avTransport`, `MediaRenderer.renderingControl` and `MediaRenderer.connectionManager`, or the `MediaServer` equivalents. The old methods still behave identically
- **INFO**: New `example/port_forward_example.dart` and `example/media_cast_example.dart`, with `example/example.md` as the entry point
- **INFO**: Added the InternetGatewayDevice, WANDevice, WANConnectionDevice, WANIPConnection and WANPPPConnection specifications under doc/
- **INFO**: Reorganised `lib/src/` into `devices/`, `services/`, `types/`, `utils/` and `didl/`.

## 1.2.2

- **FIX**: `Device` equality and hashCode disagreed when one device had a UDN and the other did not (UDA 1.1 §2.3)


## 1.2.0

- **FEAT**: Widened the `xml` constraint to `>=6.6.1 <8.0.0`, so packages depending on xml 7 are no longer blocked
- **INFO**: Added a test suite, and CI running analyze, tests and packaging checks on pull requests


## 1.1.1

- **FIX**: Check the HTTP status before parsing device and service descriptions (UDA 1.1 §2.11)


## 1.1.0

- **FEAT**: New `MusicTrack.protocolInfo` for the required `res@protocolInfo` attribute
- **FIX**: DIDL-Lite element order, `dc:title` precedes `upnp:class` (ContentDirectory:1)
- **FIX**: SOAP `in` argument order now follows the SCPD (UDA 1.1 §3.2.1)
- **FIX**: `eventSubURL` element name (UDA 1.1 §2.3)
- **INFO**: Added UPnP specs and XML schemas under doc/, with an index


## 1.0.5

- **FIX**: Excluded `doc/` from the published package (1.0.4 shipped 4.5 MB of spec PDFs)


## 1.0.4

- **INFO**: Moved UPnP specs to doc/spec
- **FEAT**: Improved sendToControlUrl() statusCode handling
- **FEAT**: Faster device discovery stream deduplication
- **FIX**: ProtocolInfo colons parsing (ConnectionManager:1 §2.5.2)
- **FIX**: Added random delay between UDP retransmission (UDA 1.1 §1.3.2)
- **FIX**: Only check for `200 OK` response in status line (UDA 1.1 §1.3.3)
- **FIX**: Device equality and hashCode for UUID-less devices
- **FIX**: fixed_14_4 DataType value


## 1.0.3

- **INFO**: Updated the SDK lower bound to 3.8
- **FIX**: UPnP v1.0 boolean handling (UDA 1.1 §2.3.9)
- **FIX**: URLBase retrieval in Discoverer (UDA 1.1 §2.3)
- **FIX**: Service url resolution (UDA 1.1 §2.3)
- **FIX**: RangeError on invalid LOCATION header (UDA 1.1 §1.3.3)

## 1.0.2

- **INFO**: Stable release
- **INFO**: Added documentation for UPnP Device Architecture (UDA 1.0 and UDA 1.1)  
- **FEAT**: New method to dispose the discoverer
- **FEAT**: New UPnPException to parse the error SOAP
- **FEAT**: Configurable multicastHops in the discoverer (UDA 1.1 §1.3.2:)
- **FIX**: Discovering devices on IPv6 networks
- **FIX**: HttpClient(s) never closed
- **FIX**: Removed HTTP version and ServiceType version restrictions
- **FIX**: Adjusted UPnP 1.0 device handling (UDA 1.1 §1.1.4)
- **FIX**: Missing USER-AGENT header (UDA 1.1)
- **FIX**: No timeout on requests (UDA 1.1 §3.2.2)

## 1.0.1

- **FEAT**: Improving error handling

## 1.0.0

- **FEAT**: First DLNA Implementation for media casting
- **INFO**: Add Documentation for Android permissions

## 0.0.12

- **FEAT**: Add searchTarget in discovery getDevices() method
- **FIX**: Skip closed connections and partial reponses details

## 0.0.11

- **FEAT**: New method to stop the discoverer

## 0.0.10

- **INFO**: Add dart fix to workflow

## 0.0.9

- **INFO**: Automatic publish workflow
            Adjust dart formatting

## 0.0.8

- **FEAT**: Bump dart sdk constraint to >=3.0.0 <4.0.0
            Updated dependencies

## 0.0.7

- **FEAT**: Bump dart sdk constraint to >=2.19.0

## 0.0.6

- **NEW**: Devices now support embedded devices, loaded in constructor
- **FIX**: urlBase default value and removed it from device constructor

## 0.0.5

- **BREAKING**: Device xml constructor now needs to receive a \<device/> node to be considerer valid
- **NEW**: Added Service class with constructor/loader from xml
- **FEAT**: Icon List now loading in Device class

## 0.0.4

- **FEAT**: Decrease dart sdk constraint to >=2.12.0

## 0.0.3

- **BREAKING**: Discoverer search function now private
- **NEW**: Added Device class with constructor/loader from xml
- **NEW**: Added getDevices method in DeviceDiscoverer to get list of devices

## 0.0.2

- **NEW**: SSDP Discovery M-Search request

## 0.0.1

- First attemp to publish package
