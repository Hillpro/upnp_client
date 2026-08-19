# Changelog

All notable changes to this project will be documented in this file.

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
