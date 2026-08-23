import 'package:upnp_client/src/didl/utils.dart';
import 'package:upnp_client/src/utils/diagnostics.dart';
import 'package:xml/xml.dart';

const String _didlLiteNamespace =
    'urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/';
const String _dcNamespace = 'http://purl.org/dc/elements/1.1/';
const String _upnpNamespace = 'urn:schemas-upnp-org:metadata-1-0/upnp/';
const String _secNamespace = 'http://www.sec.co.kr/';

class MusicTrack {
  final String id;
  final String uri;
  final String title;
  final String? artist;
  final String album;
  final Duration duration;
  final String? artUri;

  /// Defaults to a fully wildcarded `http-get` entry. Renderers that match
  /// strictly on content format do better with a concrete MIME type, e.g.
  /// `http-get:*:audio/mpeg:*`. REQUIRED
  final String protocolInfo;

  const MusicTrack({
    required this.id,
    required this.uri,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.artUri,
    this.protocolInfo = 'http-get:*:*:*',
  });

  String toXml() {
    XmlBuilder builder = XmlBuilder();
    builder.element(
      'DIDL-Lite',
      // ignore: deprecated_member_use
      namespace: _didlLiteNamespace,
      // ignore: deprecated_member_use
      namespaces: {
        _didlLiteNamespace: null,
        _dcNamespace: 'dc',
        _upnpNamespace: 'upnp',
        _secNamespace: 'sec',
      },
      nest: () {
        builder.element(
          'item',
          attributes: {'id': id, 'parentID': '', 'restricted': '1'},
          nest: () {
            // didl-lite.xsd item.type requires dc:title first, then upnp:class.
            // ignore: deprecated_member_use
            builder.element('title', namespace: _dcNamespace, nest: title);
            builder.element(
              'class',
              // ignore: deprecated_member_use
              namespace: _upnpNamespace,
              nest: 'object.item.audioItem.musicTrack',
            );
            // ignore: deprecated_member_use
            builder.element('artist', namespace: _upnpNamespace, nest: artist);
            // ignore: deprecated_member_use
            builder.element('album', namespace: _upnpNamespace, nest: album);
            builder.element(
              'albumArtURI',
              // ignore: deprecated_member_use
              namespace: _upnpNamespace,
              nest: artUri,
            );
            builder.element(
              'res',
              attributes: {
                'protocolInfo': protocolInfo,
                'duration': durationToHHMMSS(duration),
              },
              nest: uri,
            );
          },
        );
      },
    );
    return builder.buildDocument().toXmlString();
  }

  @override
  String toString() {
    return buildDescription(runtimeType, describeFields());
  }

  Map<String, dynamic> describeFields() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'duration': duration,
    'protocolInfo': protocolInfo,
  };
}
