import 'package:upnp_client/src/utils/diagnostics.dart';

/// Whether the gateway performs NAT, and whether RSIP is available.
///
/// Returned by `GetNATRSIPStatus`. Section references are to
/// WANIPConnection:1.
class NatRsipStatus {
  /// Whether Realm-Specific IP is available (§2.2.9).
  final bool rsipAvailable;

  /// Whether the gateway is translating addresses (§2.2.10).
  final bool natEnabled;

  const NatRsipStatus({required this.rsipAvailable, required this.natEnabled});

  @override
  String toString() => buildDescription(runtimeType, describeFields());

  Map<String, dynamic> describeFields() => {
    'rsipAvailable': rsipAvailable,
    'natEnabled': natEnabled,
  };
}
