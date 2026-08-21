import 'package:upnp_client/src/services/wan_connection/port_mapping_protocol.dart';
import 'package:upnp_client/src/types/data_type_parsers.dart';
import 'package:upnp_client/src/utils/diagnostics.dart';

/// A single NAT port mapping entry.
///
/// Section references are to WANIPConnection:1, whose state variables
/// these fields mirror.
///
/// The numeric fields are nullable because a device that reports a
/// non-numeric value must not be read as one: `0` already means "wildcard"
/// for [externalPort], so falling back to it would invent a different
/// mapping.
class PortMapping {
  /// The WAN-side host this mapping accepts traffic from. Empty is the
  /// wildcard, meaning any host (§2.2.15).
  final String remoteHost;

  /// The WAN-side port. `0` is the wildcard, on gateways that support it
  /// (§2.2.16).
  final int? externalPort;

  /// Null if the gateway reported a protocol other than `TCP` or `UDP`.
  final PortMappingProtocol? protocol;

  /// The LAN-side port traffic is forwarded to. Between 1 and 65535 (§2.2.17).
  final int? internalPort;

  /// The LAN-side host traffic is forwarded to (§2.2.19).
  final String internalClient;

  /// Whether the mapping is currently active (§2.2.13).
  final bool enabled;

  /// The gateway's free-text label for the mapping (§2.2.20).
  final String description;

  /// Time remaining on the mapping. [Duration.zero] means permanent
  /// (§2.2.14).
  final Duration? leaseDuration;

  const PortMapping({
    required this.remoteHost,
    required this.externalPort,
    required this.protocol,
    required this.internalPort,
    required this.internalClient,
    required this.enabled,
    required this.description,
    required this.leaseDuration,
  });

  /// Builds an entry from an action response.
  ///
  /// `GetSpecificPortMappingEntry` returns only the five `out` arguments, so
  /// the caller supplies the three it sent as `in` arguments.
  factory PortMapping.fromArgs(
    Map<String, String> args, {
    String? remoteHost,
    int? externalPort,
    PortMappingProtocol? protocol,
  }) => PortMapping(
    remoteHost: remoteHost ?? args['NewRemoteHost'] ?? '',
    externalPort: externalPort ?? int.tryParse(args['NewExternalPort'] ?? ''),
    protocol: protocol ?? PortMappingProtocol.tryParse(args['NewProtocol']),
    internalPort: int.tryParse(args['NewInternalPort'] ?? ''),
    internalClient: args['NewInternalClient'] ?? '',
    enabled: parseUpnpBool(args['NewEnabled']),
    description: args['NewPortMappingDescription'] ?? '',
    leaseDuration: parseUpnpSeconds(args['NewLeaseDuration']),
  );

  @override
  String toString() => buildDescription(runtimeType, describeFields());

  Map<String, dynamic> describeFields() => {
    'remoteHost': remoteHost,
    'externalPort': externalPort,
    'protocol': protocol?.wireValue,
    'internalPort': internalPort,
    'internalClient': internalClient,
    'enabled': enabled,
    'description': description,
    'leaseDuration': leaseDuration,
  };
}
