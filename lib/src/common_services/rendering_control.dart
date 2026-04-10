import 'package:upnp_client/src/data_type_parsers.dart';
import 'package:upnp_client/src/service.dart';

/// An UPnP RenderingControl service
/// https://upnp.org/specs/av/UPnP-av-RenderingControl-v1-Service.pdf
class RenderingControlService extends Service {
  RenderingControlService.fromXml(super.device, super.xml) : super.fromXml();

  Future<int> getVolume({int instanceId = 0, String channel = 'Master'}) async {
    final args = await invokeAction('GetVolume', {
      'InstanceID': instanceId,
      'Channel': channel,
    });
    return int.tryParse(args['CurrentVolume'] ?? '') ?? -1;
  }

  Future<void> setVolume({
    int instanceId = 0,
    String channel = 'Master',
    int volume = 0,
  }) async {
    await invokeAction('SetVolume', {
      'InstanceID': instanceId,
      'Channel': channel,
      'DesiredVolume': volume,
    });
  }

  Future<bool> getMute({int instanceId = 0, String channel = 'Master'}) async {
    final args = await invokeAction('GetMute', {
      'InstanceID': instanceId,
      'Channel': channel,
    });
    return parseUpnpBool(args['CurrentMute']);
  }

  Future<void> setMute({
    int instanceId = 0,
    String channel = 'Master',
    bool mute = false,
  }) async {
    await invokeAction('SetMute', {
      'InstanceID': instanceId,
      'Channel': channel,
      'DesiredMute': mute ? '1' : '0',
    });
  }

  @override
  String toString() {
    return 'RenderingControlService{}';
  }
}
