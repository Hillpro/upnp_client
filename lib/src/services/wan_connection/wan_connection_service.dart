import 'package:upnp_client/src/services/wan_connection/connection_status_info.dart';
import 'package:upnp_client/src/services/wan_connection/nat_rsip_status.dart';
import 'package:upnp_client/src/services/wan_connection/port_mapping.dart';
import 'package:upnp_client/src/services/wan_connection/port_mapping_protocol.dart';
import 'package:upnp_client/src/services/wan_connection/wan_connection_error.dart';
import 'package:upnp_client/src/device.dart';
import 'package:upnp_client/src/service.dart';
import 'package:upnp_client/src/upnp_exception.dart';
import 'package:upnp_client/src/types/data_type_parsers.dart';

/// The behaviour shared by the IGD WAN connection services.
///
/// `WANIPConnection:1` and `WANPPPConnection:1` declare the same connection
/// management and NAT port mapping actions, so both are reachable through this
/// type. Which one a gateway exposes depends on how its modem attaches, so
/// prefer looking for the base type:
///
/// ```dart
/// final connection = gateway.findService<WanConnectionService>();
/// ```
///
/// These services sit two `deviceList` levels below the root device, under
/// `WANDevice` then `WANConnectionDevice`, so [Device.findService] is the way
/// to reach them - the root-scoped accessors never see them.
///
/// PPP-specific actions such as `GetLinkLayerMaxBitRates` are not wrapped;
/// reach them with [invokeAction].
///
/// Bare section references below are to WANIPConnection:1; WANPPPConnection:1
/// numbers its equivalents differently.
///
/// UDA 1.1 §3.2.1 - `in` arguments are sent in the order the SCPD declares
/// them, so the order of the maps below is significant and must not change.
abstract class WanConnectionService extends Service {
  WanConnectionService.fromXml(super.device, super.xml) : super.fromXml();

  /// The gateway's WAN-side IP address, empty when it has no connection
  /// (§2.4.18).
  Future<String?> getExternalIpAddress() async {
    final args = await invokeAction('GetExternalIPAddress', {});
    return args['NewExternalIPAddress'];
  }

  /// The connection's status, last error and uptime (§2.4.9).
  Future<ConnectionStatusInfo> getStatusInfo() async {
    final args = await invokeAction('GetStatusInfo', {});
    return ConnectionStatusInfo(
      connectionStatus: args['NewConnectionStatus'],
      lastConnectionError: args['NewLastConnectionError'],
      uptime: parseUpnpSeconds(args['NewUptime']),
    );
  }

  /// Whether the gateway performs NAT, and whether RSIP is available
  /// (§2.4.13).
  Future<NatRsipStatus> getNatRsipStatus() async {
    final args = await invokeAction('GetNATRSIPStatus', {});
    return NatRsipStatus(
      rsipAvailable: parseUpnpBool(args['NewRSIPAvailable']),
      natEnabled: parseUpnpBool(args['NewNATEnabled']),
    );
  }

  /// Creates a port mapping, or overwrites one already held by the same
  /// [internalClient] (§2.4.16).
  ///
  /// An empty [remoteHost] is the wildcard, accepting traffic from any source.
  /// A [leaseDuration] of [Duration.zero] requests a permanent mapping.
  ///
  /// Throws [UPnPException] with [WanConnectionError.conflictInMappingEntry]
  /// when [externalPort] and [protocol] are already mapped to a *different*
  /// internal client. That mapping belongs to another host, so this does not
  /// delete and retry behind the caller's back.
  ///
  /// §2.4.16 warns that a gateway need not support a wildcard [externalPort],
  /// an [internalPort] differing from it, or a non-zero [leaseDuration]. Such
  /// a gateway answers [WanConnectionError.samePortValuesRequired] or
  /// [WanConnectionError.onlyPermanentLeasesSupported]; retrying with
  /// [Duration.zero] is the usual response to the latter.
  Future<void> addPortMapping({
    required int externalPort,
    required PortMappingProtocol protocol,
    required int internalPort,
    required String internalClient,
    String remoteHost = '',
    bool enabled = true,
    String description = '',
    Duration leaseDuration = Duration.zero,
  }) async {
    await invokeAction('AddPortMapping', {
      'NewRemoteHost': remoteHost,
      'NewExternalPort': externalPort,
      'NewProtocol': protocol.wireValue,
      'NewInternalPort': internalPort,
      'NewInternalClient': internalClient,
      'NewEnabled': enabled ? '1' : '0',
      'NewPortMappingDescription': description,
      'NewLeaseDuration': leaseDuration.inSeconds,
    });
  }

  /// Removes the mapping for [externalPort] and [protocol] (§2.4.17).
  ///
  /// [remoteHost] must match the value the mapping was created with; empty is
  /// the wildcard.
  Future<void> deletePortMapping({
    required int externalPort,
    required PortMappingProtocol protocol,
    String remoteHost = '',
  }) async {
    await invokeAction('DeletePortMapping', {
      'NewRemoteHost': remoteHost,
      'NewExternalPort': externalPort,
      'NewProtocol': protocol.wireValue,
    });
  }

  /// The mapping for [externalPort] and [protocol], or null if there is none
  /// (§2.4.15).
  ///
  /// A gateway reports "no such mapping" as
  /// [WanConnectionError.noSuchEntryInArray], which becomes null here. Every
  /// other fault propagates.
  Future<PortMapping?> getSpecificPortMappingEntry({
    required int externalPort,
    required PortMappingProtocol protocol,
    String remoteHost = '',
  }) async {
    try {
      final args = await invokeAction('GetSpecificPortMappingEntry', {
        'NewRemoteHost': remoteHost,
        'NewExternalPort': externalPort,
        'NewProtocol': protocol.wireValue,
      });
      return PortMapping.fromArgs(
        args,
        remoteHost: remoteHost,
        externalPort: externalPort,
        protocol: protocol,
      );
    } on UPnPException catch (e) {
      if (e.errorCode == WanConnectionError.noSuchEntryInArray) return null;
      rethrow;
    }
  }

  /// The mapping at [index] in the gateway's table, or null once [index] is
  /// past the end (§2.4.14).
  ///
  /// The end of the table is reported as
  /// [WanConnectionError.specifiedArrayIndexInvalid], which becomes null here.
  /// Every other fault propagates.
  Future<PortMapping?> getGenericPortMappingEntry(int index) async {
    try {
      final args = await invokeAction('GetGenericPortMappingEntry', {
        'NewPortMappingIndex': index,
      });
      return PortMapping.fromArgs(args);
    } on UPnPException catch (e) {
      if (e.errorCode == WanConnectionError.specifiedArrayIndexInvalid) {
        return null;
      }
      rethrow;
    }
  }

  /// Every mapping in the gateway's table, read by walking
  /// [getGenericPortMappingEntry] from index 0.
  ///
  /// The table has no length action, so enumeration stops at the first
  /// [WanConnectionError.specifiedArrayIndexInvalid].
  ///
  /// Nothing here returns a partial list quietly. A gateway that ends the
  /// table with some other fault - some report `501 Action Failed` - surfaces
  /// it as a [UPnPException], and a gateway that never reports the end at all
  /// exhausts [limit] and throws. Either way the caller can tell a truncated
  /// read from a complete one; [getGenericPortMappingEntry] is there to walk
  /// the table by hand when a partial read is what you want.
  ///
  /// [limit] is a backstop against a device that answers every index, not a
  /// page size. It sits far above any real table - `PortMappingNumberOfEntries`
  /// is a `ui2` (§2.2.12), so 65535 is the spec ceiling - while still bounding
  /// a broken gateway to a wait rather than an afternoon, since every index
  /// costs a round trip.
  Future<List<PortMapping>> listPortMappings({int limit = 1024}) async {
    final mappings = <PortMapping>[];
    for (var index = 0; index < limit; index++) {
      final mapping = await getGenericPortMappingEntry(index);
      if (mapping == null) return mappings;
      mappings.add(mapping);
    }
    throw Exception(
      'ERROR: Port mapping table did not end within $limit entries; the '
      'gateway never returned ${WanConnectionError.specifiedArrayIndexInvalid} '
      '(SpecifiedArrayIndexInvalid). Raise limit or walk the table with '
      'getGenericPortMappingEntry.',
    );
  }
}
