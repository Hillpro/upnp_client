import 'package:upnp_client/src/device.dart';
import 'package:upnp_client/src/service.dart';
import 'package:xml/xml.dart';
import 'package:collection/collection.dart';

/// An UPnP AVTransport service
/// https://upnp.org/specs/av/UPnP-av-AVTransport-v1-Service.pdf
class AvTransportService extends Service {
  AvTransportService.fromXml(Device device, XmlElement xml)
      : super.fromXml(device, xml);

  Future<void> setAVTransportURI(String uri,
      {String metadata = '', int instanceId = 0}) async {
    await invokeAction('SetAVTransportURI', {
      'CurrentURI': uri,
      'CurrentURIMetaData': metadata,
      'InstanceID': instanceId
    });
  }

  Future<void> setNextAVTransportURI(String uri,
      {String metadata = '', int instanceId = 0}) async {
    await invokeAction('SetNextAVTransportURI', {
      'NextURI': uri,
      'NextURIMetaData': metadata,
      'InstanceID': instanceId
    });
  }

  Future<MediaInfo> getMediaInfo({int instanceId = 0}) async {
    final args = await invokeAction('GetMediaInfo', {'InstanceID': instanceId});
    return MediaInfo(
      nrTracks: args['NrTracks'],
      mediaDuration: args['MediaDuration'],
      currentURI: args['CurrentURI'],
      currentURIMetaData: args['CurrentURIMetaData'],
      nextURI: args['NextURI'],
      nextURIMetaData: args['NextURIMetaData'],
      playMedium: args['PlayMedium'],
      recordMedium: args['RecordMedium'],
      writeStatus: args['WriteStatus'],
    );
  }

  Future<TransportInfo> getTransportInfo({int instanceId = 0}) async {
    final args =
        await invokeAction('GetTransportInfo', {'InstanceID': instanceId});
    return TransportInfo(
      currentTransportState: args['CurrentTransportState'],
      currentTransportStatus: args['CurrentTransportStatus'],
      currentSpeed: args['CurrentSpeed'],
    );
  }

  Future<PositionInfo> getPositionInfo({int instanceId = 0}) async {
    final args =
        await invokeAction('GetPositionInfo', {'InstanceID': instanceId});
    return PositionInfo(
      track: args['Track'],
      trackDuration: args['TrackDuration'],
      trackMetaData: args['TrackMetaData'],
      trackURI: args['TrackURI'],
      relTime: args['RelTime'],
      absTime: args['AbsTime'],
      relCount: args['RelCount'],
      absCount: args['AbsCount'],
    );
  }

  Future<DeviceCapabilities> getDeviceCapabilities({int instanceId = 0}) async {
    final args =
        await invokeAction('GetDeviceCapabilities', {'InstanceID': instanceId});
    return DeviceCapabilities(
      playMedia: args['PlayMedia'],
      recMedia: args['RecMedia'],
      recQualityModes: args['RecQualityModes'],
    );
  }

  Future<TransportSettings> getTransportSettings({int instanceId = 0}) async {
    final args =
        await invokeAction('GetTransportSettings', {'InstanceID': instanceId});
    return TransportSettings(
      playMode: args['PlayMode'],
      recQualityMode: args['RecQualityMode'],
    );
  }

  Future<void> stop({int instanceId = 0}) async {
    await invokeAction('Stop', {'InstanceID': instanceId});
  }

  Future<void> play({int instanceId = 0, String speed = '1'}) async {
    await invokeAction('Play', {'InstanceID': instanceId, 'Speed': speed});
  }

  Future<void> pause({int instanceId = 0}) async {
    await invokeAction('Pause', {'InstanceID': instanceId});
  }

  Future<void> record({int instanceId = 0}) async {
    await invokeAction('Record', {'InstanceID': instanceId});
  }

  Future<void> seek(SeekMode mode, String target, {int instanceId = 0}) async {
    await invokeAction('Seek', {
      'InstanceID': instanceId,
      'Unit': mode.value,
      'Target': target,
    });
  }

  Future<void> next({int instanceId = 0}) async {
    await invokeAction('Next', {'InstanceID': instanceId});
  }

  Future<void> previous({int instanceId = 0}) async {
    await invokeAction('Previous', {'InstanceID': instanceId});
  }

  Future<void> setPlayMode(PlayMode playMode, {int instanceId = 0}) async {
    await invokeAction('SetPlayMode',
        {'InstanceID': instanceId, 'NewPlayMode': playMode.value});
  }

  Future<List<String>> getCurrentTransportActions({int instanceId = 0}) async {
    final args = await invokeAction(
        'GetCurrentTransportActions', {'InstanceID': instanceId});
    return args['Actions']?.split(',') ?? [];
  }

  @override
  String toString() {
    return 'AvTransportService{}';
  }
}

class MediaInfo {
  final String? nrTracks;
  final String? mediaDuration;
  final String? currentURI;
  final String? currentURIMetaData;
  final String? nextURI;
  final String? nextURIMetaData;
  final String? playMedium;
  final String? recordMedium;
  final String? writeStatus;

  const MediaInfo({
    required this.nrTracks,
    required this.mediaDuration,
    required this.currentURI,
    required this.currentURIMetaData,
    required this.nextURI,
    required this.nextURIMetaData,
    required this.playMedium,
    required this.recordMedium,
    required this.writeStatus,
  });

  @override
  String toString() {
    return 'MediaInfo{nrTracks: $nrTracks, mediaDuration: $mediaDuration, currentURI: $currentURI, currentURIMetaData: $currentURIMetaData, nextURI: $nextURI, nextURIMetaData: $nextURIMetaData, playMedium: $playMedium, recordMedium: $recordMedium, writeStatus: $writeStatus}';
  }
}

enum TransportState {
  stopped('STOPPED'),
  playing('PLAYING'),
  transitioning('TRANSITIONING'),
  pausedPlayback('PAUSED_PLAYBACK'),
  pausedRecording('PAUSED_RECORDING'),
  recording('RECORDING'),
  noMediaPresent('NO_MEDIA_PRESENT');

  const TransportState(this.value);

  final String value;
}

enum TransportStatus {
  ok('OK'),
  errorOccurred('ERROR_OCCURRED');

  const TransportStatus(this.value);

  final String value;
}

class TransportInfo {
  final TransportState? currentTransportState;
  final TransportStatus? currentTransportStatus;
  final String? currentSpeed;

  TransportInfo({
    required String? currentTransportState,
    required String? currentTransportStatus,
    required this.currentSpeed,
  })  : this.currentTransportState = TransportState.values
            .firstWhereOrNull((state) => state.value == currentTransportState),
        this.currentTransportStatus = TransportStatus.values.firstWhereOrNull(
            (status) => status.value == currentTransportStatus);

  @override
  String toString() {
    return 'TransportInfo{currentTransportState: $currentTransportState, currentTransportStatus: $currentTransportStatus, currentSpeed: $currentSpeed}';
  }
}

class PositionInfo {
  final int? track;
  final String? trackDuration;
  final String? trackMetaData;
  final String? trackURI;
  final String? relTime;
  final String? absTime;
  final int? relCount;
  final int? absCount;

  PositionInfo({
    required String? track,
    required this.trackDuration,
    required this.trackMetaData,
    required this.trackURI,
    required this.relTime,
    required this.absTime,
    required String? relCount,
    required String? absCount,
  })  : this.track = int.tryParse(track ?? ''),
        this.relCount = int.tryParse(relCount ?? ''),
        this.absCount = int.tryParse(absCount ?? '');

  @override
  String toString() {
    return 'PositionInfo{track: $track, trackDuration: $trackDuration, trackMetaData: $trackMetaData, trackURI: $trackURI, relTime: $relTime, absTime: $absTime, relCount: $relCount, absCount: $absCount}';
  }
}

class DeviceCapabilities {
  final String? playMedia;
  final String? recMedia;
  final String? recQualityModes;

  const DeviceCapabilities({
    required this.playMedia,
    required this.recMedia,
    required this.recQualityModes,
  });

  @override
  String toString() {
    return 'DeviceCapabilities{playMedia: $playMedia, recMedia: $recMedia, recQualityModes: $recQualityModes}';
  }
}

class TransportSettings {
  final PlayMode? playMode;
  final String? recQualityMode;

  TransportSettings({
    required String? playMode,
    required this.recQualityMode,
  }) : playMode =
            PlayMode.values.firstWhereOrNull((mode) => mode.value == playMode);

  @override
  String toString() {
    return 'TransportSettings{playMode: $playMode, recQualityMode: $recQualityMode}';
  }
}

enum PlayMode {
  normal('NORMAL'),
  shuffle('SHUFFLE'),
  repeatOne('REPEAT_ONE'),
  repeatAll('REPEAT_ALL'),
  random('RANDOM'),
  direct1('DIRECT 1'),
  intro('INTRO');

  const PlayMode(this.value);

  final String value;
}

enum SeekMode {
  trackNr('TRACK_NR'),
  absTime('ABS_TIME'),
  relTime('REL_TIME'),
  absCount('ABS_COUNT'),
  relCount('REL_COUNT'),
  channelFreq('CHANNEL_FREQ'),
  tapeIndex('TAPE_INDEX'),
  frame('FRAME');

  const SeekMode(this.value);

  final String value;
}
