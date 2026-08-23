import 'package:test/test.dart';
import 'package:upnp_client/upnp_client.dart';

void main() {
  group('UpnpDeviceType', () {
    test('builds the URN the spec publishes', () {
      // Asserted against literals on purpose: deriving the expectation from
      // the enum would make a typo in the enum invisible.
      expect(
        UpnpDeviceType.internetGatewayDevice.urn(),
        'urn:schemas-upnp-org:device:InternetGatewayDevice:1',
      );
      expect(
        UpnpDeviceType.wanDevice.urn(),
        'urn:schemas-upnp-org:device:WANDevice:1',
      );
      expect(
        UpnpDeviceType.wanConnectionDevice.urn(),
        'urn:schemas-upnp-org:device:WANConnectionDevice:1',
      );
      expect(
        UpnpDeviceType.mediaRenderer.urn(),
        'urn:schemas-upnp-org:device:MediaRenderer:1',
      );
      expect(
        UpnpDeviceType.mediaServer.urn(),
        'urn:schemas-upnp-org:device:MediaServer:1',
      );
    });

    test('takes an explicit version', () {
      expect(
        UpnpDeviceType.internetGatewayDevice.urn(2),
        'urn:schemas-upnp-org:device:InternetGatewayDevice:2',
      );
    });

    test('baseUrn ends in a colon and carries no version', () {
      expect(
        UpnpDeviceType.mediaRenderer.baseUrn,
        'urn:schemas-upnp-org:device:MediaRenderer:',
      );
      for (final type in UpnpDeviceType.values) {
        expect(type.baseUrn, startsWith('urn:schemas-upnp-org:device:'));
        expect(type.baseUrn, endsWith(':'));
        expect(type.baseUrn, isNot(matches(RegExp(r'\d+:$'))));
      }
    });

    test('parses its own URN at any version', () {
      for (final type in UpnpDeviceType.values) {
        for (final version in [1, 2, 7]) {
          expect(
            UpnpDeviceType.tryParse(type.urn(version)),
            type,
            reason: '${type.typeName} v$version',
          );
        }
      }
    });

    test('returns null for an unknown or malformed type', () {
      expect(
        UpnpDeviceType.tryParse('urn:acme-example:device:Toaster:1'),
        isNull,
      );
      expect(
        UpnpDeviceType.tryParse('urn:schemas-upnp-org:device:LANDevice:1'),
        isNull,
        reason: 'a real type, but not one this package models',
      );
      expect(UpnpDeviceType.tryParse(''), isNull);
      expect(UpnpDeviceType.tryParse(null), isNull);
    });

    test('does not match a service URN of the same name', () {
      expect(
        UpnpDeviceType.tryParse('urn:schemas-upnp-org:service:MediaRenderer:1'),
        isNull,
      );
    });
  });

  group('UpnpServiceType', () {
    test('builds the URN the spec publishes', () {
      expect(
        UpnpServiceType.avTransport.urn(),
        'urn:schemas-upnp-org:service:AVTransport:1',
      );
      expect(
        UpnpServiceType.renderingControl.urn(),
        'urn:schemas-upnp-org:service:RenderingControl:1',
      );
      expect(
        UpnpServiceType.connectionManager.urn(),
        'urn:schemas-upnp-org:service:ConnectionManager:1',
      );
      expect(
        UpnpServiceType.contentDirectory.urn(),
        'urn:schemas-upnp-org:service:ContentDirectory:1',
      );
      expect(
        UpnpServiceType.layer3Forwarding.urn(),
        'urn:schemas-upnp-org:service:Layer3Forwarding:1',
      );
      expect(
        UpnpServiceType.wanCommonInterfaceConfig.urn(),
        'urn:schemas-upnp-org:service:WANCommonInterfaceConfig:1',
      );
      expect(
        UpnpServiceType.wanIpConnection.urn(),
        'urn:schemas-upnp-org:service:WANIPConnection:1',
      );
      expect(
        UpnpServiceType.wanPppConnection.urn(),
        'urn:schemas-upnp-org:service:WANPPPConnection:1',
      );
    });

    test('baseUrn ends in a colon and carries no version', () {
      for (final type in UpnpServiceType.values) {
        expect(type.baseUrn, startsWith('urn:schemas-upnp-org:service:'));
        expect(type.baseUrn, endsWith(':'));
        expect(type.baseUrn, isNot(matches(RegExp(r'\d+:$'))));
      }
    });

    test('parses its own URN at any version', () {
      for (final type in UpnpServiceType.values) {
        for (final version in [1, 2, 7]) {
          expect(
            UpnpServiceType.tryParse(type.urn(version)),
            type,
            reason: '${type.typeName} v$version',
          );
        }
      }
    });

    test('returns null for an unknown type', () {
      expect(
        UpnpServiceType.tryParse(
          'urn:schemas-upnp-org:service:SomethingElse:1',
        ),
        isNull,
      );
      expect(UpnpServiceType.tryParse(null), isNull);
    });

    test('every type name is distinct', () {
      final names = UpnpServiceType.values.map((t) => t.typeName).toSet();
      expect(names, hasLength(UpnpServiceType.values.length));
    });
  });

  // Every wire value the package can put on the wire, asserted against the
  // literal the normative allowedValueList publishes. Same reasoning as the
  // URNs above: deriving the expectation from the enum would make a typo in
  // the enum invisible, which is exactly how `DIRECT 1` and `TAPE_INDEX`
  // survived. Each group ends by checking the enum has no value the group
  // forgot, so adding one without a spec check fails here.
  group('enum wire values', () {
    test('PlayMode matches CurrentPlayMode (AVTransport:1)', () {
      expect(PlayMode.normal.value, 'NORMAL');
      expect(PlayMode.shuffle.value, 'SHUFFLE');
      expect(PlayMode.repeatOne.value, 'REPEAT_ONE');
      expect(PlayMode.repeatAll.value, 'REPEAT_ALL');
      expect(PlayMode.random.value, 'RANDOM');
      // Underscore, not a space.
      expect(PlayMode.direct1.value, 'DIRECT_1');
      expect(PlayMode.intro.value, 'INTRO');
      expect(PlayMode.values, hasLength(7));
    });

    test('SeekMode matches A_ARG_TYPE_SeekMode (AVTransport:1)', () {
      expect(SeekMode.trackNr.value, 'TRACK_NR');
      expect(SeekMode.absTime.value, 'ABS_TIME');
      expect(SeekMode.relTime.value, 'REL_TIME');
      expect(SeekMode.absCount.value, 'ABS_COUNT');
      expect(SeekMode.relCount.value, 'REL_COUNT');
      expect(SeekMode.channelFreq.value, 'CHANNEL_FREQ');
      // Hyphen, not an underscore - the only one in the list.
      expect(SeekMode.tapeIndex.value, 'TAPE-INDEX');
      expect(SeekMode.frame.value, 'FRAME');
      expect(SeekMode.values, hasLength(8));
    });

    test('TransportState matches its allowedValueList', () {
      expect(TransportState.stopped.value, 'STOPPED');
      expect(TransportState.playing.value, 'PLAYING');
      expect(TransportState.transitioning.value, 'TRANSITIONING');
      expect(TransportState.pausedPlayback.value, 'PAUSED_PLAYBACK');
      expect(TransportState.pausedRecording.value, 'PAUSED_RECORDING');
      expect(TransportState.recording.value, 'RECORDING');
      expect(TransportState.noMediaPresent.value, 'NO_MEDIA_PRESENT');
      expect(TransportState.values, hasLength(7));
    });

    test('TransportStatus matches its allowedValueList', () {
      expect(TransportStatus.ok.value, 'OK');
      expect(TransportStatus.errorOccurred.value, 'ERROR_OCCURRED');
      expect(TransportStatus.values, hasLength(2));
    });

    test('PortMappingProtocol matches its allowedValueList', () {
      // WANIPConnection:1 Table 1.4 - uppercase, so Dart's `name` will not do.
      expect(PortMappingProtocol.tcp.wireValue, 'TCP');
      expect(PortMappingProtocol.udp.wireValue, 'UDP');
      expect(PortMappingProtocol.values, hasLength(2));
    });

    test('Direction matches the SCPD direction enumeration', () {
      expect(Direction.in_.value, 'in');
      expect(Direction.out.value, 'out');
      expect(Direction.values, hasLength(2));
    });

    test('DataType separators are dots, never underscores', () {
      // The Dart identifiers use underscores because a dot is not legal in
      // one; the wire values must keep the spec's dots.
      expect(DataType.fixed_14_4.value, 'fixed.14.4');
      expect(DataType.dateTime_tz.value, 'dateTime.tz');
      expect(DataType.time_tz.value, 'time.tz');
      expect(DataType.bin_base64.value, 'bin.base64');
      expect(DataType.bin_hex.value, 'bin.hex');
      expect(
        DataType.values.where((t) => t.value.contains('_')),
        isEmpty,
        reason: 'no UPnP data type name contains an underscore',
      );
    });
  });
}
