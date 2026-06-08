import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioLevelService {
  static const _channel = EventChannel('rgb_ble_controller/audio_level');

  Future<bool> ensurePermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    final before = await Permission.microphone.status;
    final after = before.isGranted
        ? before
        : await Permission.microphone.request();
    return after.isGranted;
  }

  Stream<int> watchLevels() {
    return _channel.receiveBroadcastStream().map((event) {
      final value = event is num ? event.round() : int.tryParse('$event') ?? 0;
      return value.clamp(0, 255);
    });
  }
}

final audioLevelServiceProvider = Provider<AudioLevelService>((ref) {
  return AudioLevelService();
});
