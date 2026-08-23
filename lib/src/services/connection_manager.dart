import 'package:upnp_client/src/service.dart';
import 'package:upnp_client/src/utils/diagnostics.dart';

/// An UPnP ConnectionManager service
/// https://upnp.org/specs/av/UPnP-av-ConnectionManager-v1-Service.pdf
class ConnectionManagerService extends Service {
  ConnectionManagerService.fromXml(super.device, super.xml) : super.fromXml();

  /// The formats this ConnectionManager can source and sink.
  ///
  /// Malformed entries are skipped rather than failing the whole call. A device
  /// that sends one unparseable entry among fifty used to yield nothing at all,
  /// which is the opposite of useful when the reason for asking is to find out
  /// what it accepts. Reach for [ProtocolInfo.fromString] when parsing a single
  /// entry and you want to be told that it is malformed.
  Future<ProtocolInfoData> getProtocolInfo() async {
    final args = await invokeAction('GetProtocolInfo', {});
    return ProtocolInfoData(
      sink: _parseProtocolInfoCsv(args['Sink']),
      source: _parseProtocolInfoCsv(args['Source']),
    );
  }

  /// Parses a protocolInfo CSV, dropping entries that are not four
  /// colon-separated fields.
  ///
  /// Entries are not trimmed. ConnectionManager:1 §2.2.2 declares these
  /// `CSV (string)` and points at ContentDirectory:1 §2.5.1.1 for the type,
  /// which states that whitespace before, after or interior to a non-numeric
  /// value is part of the value.
  static List<ProtocolInfo> _parseProtocolInfoCsv(String? csv) =>
      (csv?.split(',') ?? [])
          .where((entry) => entry.isNotEmpty)
          .map(ProtocolInfo.tryParse)
          .whereType<ProtocolInfo>()
          .toList();
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

  /// Parses a `<protocol>:<network>:<contentFormat>:<additionalInfo>` string,
  /// or null if it does not have those four fields.
  ///
  /// The additionalInfo field may contain colons (e.g. DLNA.ORG_OP=01:01),
  /// per ConnectionManager:1 §2.5.2, so only the first three separators split.
  ///
  /// The lenient counterpart of [fromString]: use this over a device's CSV,
  /// where one unparseable entry should not cost the rest.
  static ProtocolInfo? tryParse(String protocolInfoString) {
    final List<String> parts = protocolInfoString.split(':');
    if (parts.length < 4) return null;

    return ProtocolInfo._(
      parts[0],
      parts[1],
      parts[2],
      parts.sublist(3).join(':'),
    );
  }

  /// Parses a `<protocol>:<network>:<contentFormat>:<additionalInfo>` string,
  /// throwing [ArgumentError] if it does not have those four fields.
  ///
  /// Use [tryParse] where a malformed entry should be skipped instead.
  static ProtocolInfo fromString(String protocolInfoString) {
    final parsed = tryParse(protocolInfoString);
    if (parsed == null) {
      throw ArgumentError('Invalid protocol info string: $protocolInfoString');
    }
    return parsed;
  }

  @override
  String toString() => '$protocol:$network:$contentFormat:$additionalInfo';
}
