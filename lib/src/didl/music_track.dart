import 'package:xml/xml.dart';
import 'package:upnp_client/src/didl/utils.dart';

final String _didlLiteNamespace =
    'urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/';
final String _dcNamespace = 'http://purl.org/dc/elements/1.1/';
final String _upnpNamespace = 'urn:schemas-upnp-org:metadata-1-0/upnp/';
final String _secNamespace = 'http://www.sec.co.kr/';

class MusicTrack {
  final String id;
  final String uri;
  final String title;
  final String? artist;
  final String album;
  final Duration duration;
  final String? artUri;

  const MusicTrack({
    required this.id,
    required this.uri,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.artUri,
  });

  String toXml() {
    XmlBuilder builder = XmlBuilder();
    builder.element('DIDL-Lite', namespace: _didlLiteNamespace, namespaces: {
      _didlLiteNamespace: null,
      _dcNamespace: 'dc',
      _upnpNamespace: 'upnp',
      _secNamespace: 'sec',
    }, nest: () {
      builder.element('item', attributes: {
        'id': id,
        'parentID': '',
        'restricted': '1',
      }, nest: () {
        builder.element('class',
            namespace: _upnpNamespace,
            nest: 'object.item.audioItem.musicTrack');
        builder.element('title', namespace: _dcNamespace, nest: title);
        builder.element('artist', namespace: _upnpNamespace, nest: artist);
        builder.element('album', namespace: _upnpNamespace, nest: album);
        builder.element('albumArtURI', namespace: _upnpNamespace, nest: artUri);
        builder.element('res',
            attributes: {
              'duration': durationToHHMMSS(duration),
            },
            nest: uri);
      });
    });
    return builder.buildDocument().toXmlString();
  }

  @override
  String toString() {
    return 'MusicTrack{id: $id, title: $title, artist: $artist, album: $album, duration: $duration}';
  }
}
