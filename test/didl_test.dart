import 'package:test/test.dart';
import 'package:upnp_client/didl.dart';
import 'package:upnp_client/src/didl/utils.dart';
import 'package:xml/xml.dart';

const _didl = 'urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/';
const _dc = 'http://purl.org/dc/elements/1.1/';
const _upnp = 'urn:schemas-upnp-org:metadata-1-0/upnp/';

MusicTrack track({
  String? artist = 'Artist',
  String? artUri = 'http://h/art.jpg',
  String protocolInfo = 'http-get:*:*:*',
  Duration duration = const Duration(minutes: 3, seconds: 7),
}) => MusicTrack(
  id: 'id-1',
  uri: 'http://host/song.mp3',
  title: 'Title',
  artist: artist,
  album: 'Album',
  duration: duration,
  artUri: artUri,
  protocolInfo: protocolInfo,
);

XmlElement itemOf(MusicTrack t) => XmlDocument.parse(
  t.toXml(),
).rootElement.getElement('item', namespace: _didl)!;

void main() {
  group('durationToHHMMSS', () {
    test('pads to two digits', () {
      expect(
        durationToHHMMSS(const Duration(minutes: 3, seconds: 7)),
        '00:03:07',
      );
      expect(durationToHHMMSS(Duration.zero), '00:00:00');
    });

    test('does not wrap at 24 hours', () {
      expect(
        durationToHHMMSS(const Duration(hours: 123, minutes: 45, seconds: 6)),
        '123:45:06',
      );
    });

    test('truncates sub-second precision', () {
      expect(durationToHHMMSS(const Duration(milliseconds: 1500)), '00:00:01');
    });
  });

  group('MusicTrack.toXml', () {
    test('declares the DIDL-Lite namespaces', () {
      final root = XmlDocument.parse(track().toXml()).rootElement;
      expect(root.name.local, 'DIDL-Lite');
      expect(root.name.namespaceUri, _didl);
    });

    test('emits dc:title before upnp:class', () {
      // Regression: didl-lite.xsd item.type is a sequence requiring dc:title
      // first; the original order was schema-invalid.
      final children = itemOf(
        track(),
      ).childElements.map((e) => e.name.local).toList();
      expect(children.indexOf('title'), 0);
      expect(children.indexOf('class'), 1);
    });

    test('sets the required res@protocolInfo', () {
      // Regression: res had no protocolInfo, which didl-lite.xsd requires and
      // which a renderer reads as "not yet accessible for playback".
      final res = itemOf(track()).getElement('res', namespace: _didl)!;
      expect(res.getAttribute('protocolInfo'), 'http-get:*:*:*');
      expect(res.getAttribute('duration'), '00:03:07');
      expect(res.innerText, 'http://host/song.mp3');
    });

    test('honours a caller-supplied protocolInfo', () {
      final res = itemOf(
        track(protocolInfo: 'http-get:*:audio/mpeg:*'),
      ).getElement('res', namespace: _didl)!;
      expect(res.getAttribute('protocolInfo'), 'http-get:*:audio/mpeg:*');
    });

    test('defaults protocolInfo to a wildcard http-get entry', () {
      final t = MusicTrack(
        id: 'x',
        uri: 'http://h/a.mp3',
        title: 'T',
        artist: null,
        album: 'A',
        duration: Duration.zero,
        artUri: null,
      );
      expect(t.protocolInfo, 'http-get:*:*:*');
    });

    test('carries the metadata elements', () {
      final item = itemOf(track());
      expect(item.getElement('title', namespace: _dc)!.innerText, 'Title');
      expect(
        item.getElement('class', namespace: _upnp)!.innerText,
        'object.item.audioItem.musicTrack',
      );
      expect(item.getElement('artist', namespace: _upnp)!.innerText, 'Artist');
      expect(item.getElement('album', namespace: _upnp)!.innerText, 'Album');
      expect(
        item.getElement('albumArtURI', namespace: _upnp)!.innerText,
        'http://h/art.jpg',
      );
      expect(item.getAttribute('id'), 'id-1');
      expect(item.getAttribute('restricted'), '1');
    });

    test('emits empty elements when artist and artUri are null', () {
      final item = itemOf(track(artist: null, artUri: null));
      expect(item.getElement('artist', namespace: _upnp)!.innerText, isEmpty);
      expect(
        item.getElement('albumArtURI', namespace: _upnp)!.innerText,
        isEmpty,
      );
    });

    test('escapes XML metacharacters', () {
      final t = MusicTrack(
        id: 'a&b<c>',
        uri: 'http://host/song.mp3?x=1&y=2',
        title: 'Rock & <Roll>',
        artist: 'A & B',
        album: "O'Brien",
        duration: const Duration(seconds: 42),
        artUri: null,
      );
      final raw = t.toXml();
      expect(raw, contains('&amp;'));
      expect(
        raw,
        isNot(contains('Rock & <Roll>')),
        reason: 'raw metacharacters must not survive into the markup',
      );

      // The escaping must round-trip back to the original values.
      final item = itemOf(t);
      expect(
        item.getElement('title', namespace: _dc)!.innerText,
        'Rock & <Roll>',
      );
      expect(item.getAttribute('id'), 'a&b<c>');
      expect(
        item.getElement('res', namespace: _didl)!.innerText,
        'http://host/song.mp3?x=1&y=2',
      );
    });

    test('survives being embedded as a SOAP argument value', () {
      // This is how the metadata actually travels: as text inside
      // CurrentURIMetaData, so it is escaped a second time.
      final didl = track().toXml();
      final builder = XmlBuilder();
      builder.element('CurrentURIMetaData', nest: didl);
      final wrapped = builder.buildDocument().toXmlString();
      expect(XmlDocument.parse(wrapped).rootElement.innerText, didl);
    });

    test('toString reports the fields', () {
      final s = track().toString();
      expect(s, startsWith('MusicTrack{'));
      expect(s, contains('Title'));
      expect(s, contains('http-get:*:*:*'));
    });
  });
}
