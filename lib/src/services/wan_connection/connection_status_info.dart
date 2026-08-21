import 'package:upnp_client/src/utils/diagnostics.dart';

/// The connection status of a WAN connection.
///
/// Returned by `GetStatusInfo`. Section references are to
/// WANIPConnection:1.
class ConnectionStatusInfo {
  /// One of `Unconfigured`, `Connecting`, `Connected`, `PendingDisconnect`,
  /// `Disconnecting` or `Disconnected` (§2.2.3, Table 1.2).
  final String? connectionStatus;

  /// The most recent connection error, `ERROR_NONE` when there was none
  /// (§2.2.5, Table 1.3).
  final String? lastConnectionError;

  /// How long the connection has been up (§2.2.4).
  final Duration? uptime;

  const ConnectionStatusInfo({
    required this.connectionStatus,
    required this.lastConnectionError,
    required this.uptime,
  });

  @override
  String toString() => buildDescription(runtimeType, describeFields());

  Map<String, dynamic> describeFields() => {
    'connectionStatus': connectionStatus,
    'lastConnectionError': lastConnectionError,
    'uptime': uptime,
  };
}
