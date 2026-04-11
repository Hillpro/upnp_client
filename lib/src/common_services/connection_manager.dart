import 'package:upnp_client/src/diagnostics.dart';
import 'package:upnp_client/src/service.dart';

/// An UPnP ConnectionManager service
/// https://upnp.org/specs/av/UPnP-av-ConnectionManager-v1-Service.pdf
class ConnectionManagerService extends Service {
  ConnectionManagerService.fromXml(super.device, super.xml) : super.fromXml();

  Future<ProtocolInfoData> getProtocolInfo() async {
    final args = await invokeAction('GetProtocolInfo', {});
    return ProtocolInfoData(
      sink: (args['Sink']?.split(',') ?? [])
          .where((e) => e.isNotEmpty)
          .map(ProtocolInfo.fromString)
          .toList(),
      source: (args['Source']?.split(',') ?? [])
          .where((e) => e.isNotEmpty)
          .map(ProtocolInfo.fromString)
          .toList(),
    );
  }
}

class ProtocolInfoData {
  final List<ProtocolInfo> sink;
  final List<ProtocolInfo> source;

  const ProtocolInfoData({required this.sink, required this.source});

  @override
  String toString() => buildDescription(runtimeType, describeFields());

  Map<String, dynamic> describeFields() => {'sink': sink, 'source': source};
}

class ProtocolInfo {
  final String protocol;
  final String network;
  final String contentFormat;
  final String additionalInfo;

  const ProtocolInfo._(
    this.protocol,
    this.network,
    this.contentFormat,
    this.additionalInfo,
  );

  /// Parses a `<protocol>:<network>:<contentFormat>:<additionalInfo>` string.
  /// The additionalInfo field may contain colons (e.g. DLNA.ORG_OP=01:01),
  /// per ConnectionManager:1 §2.5.2.
  static ProtocolInfo fromString(String protocolInfoString) {
    final List<String> parts = protocolInfoString.split(':');
    if (parts.length < 4) {
      throw ArgumentError('Invalid protocol info string: $protocolInfoString');
    }

    return ProtocolInfo._(
      parts[0],
      parts[1],
      parts[2],
      parts.sublist(3).join(':'),
    );
  }

  @override
  String toString() => '$protocol:$network:$contentFormat:$additionalInfo';
}
