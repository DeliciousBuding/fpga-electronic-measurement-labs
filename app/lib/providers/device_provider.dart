import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';

class DeviceState {
  final int r, g, b;
  final int brightness;
  final int mode;
  final int flowSpeed;
  final int breathPeriod;
  final int? activeSceneIndex;
  final List<bool> sceneSaved;

  const DeviceState({
    this.r = 255,
    this.g = 0,
    this.b = 0,
    this.brightness = 200,
    this.mode = 0,
    this.flowSpeed = 128,
    this.breathPeriod = 128,
    this.activeSceneIndex,
    this.sceneSaved = const [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
  });

  DeviceState copyWith({
    int? r,
    int? g,
    int? b,
    int? brightness,
    int? mode,
    int? flowSpeed,
    int? breathPeriod,
    int? activeSceneIndex,
    List<bool>? sceneSaved,
    bool clearActiveScene = false,
  }) => DeviceState(
    r: r ?? this.r,
    g: g ?? this.g,
    b: b ?? this.b,
    brightness: brightness ?? this.brightness,
    mode: mode ?? this.mode,
    flowSpeed: flowSpeed ?? this.flowSpeed,
    breathPeriod: breathPeriod ?? this.breathPeriod,
    activeSceneIndex: clearActiveScene
        ? null
        : activeSceneIndex ?? this.activeSceneIndex,
    sceneSaved: sceneSaved ?? this.sceneSaved,
  );
}

class DeviceNotifier extends Notifier<DeviceState> {
  static const _sceneSavedKey = 'device_scene_saved';

  @override
  DeviceState build() => DeviceState(sceneSaved: _loadSceneSaved());

  /// Update all fields from FPGA 0xFF status response.
  void updateFromStatus(int mode, int r, int g, int b, int brightness) {
    state = state.copyWith(
      r: r.clamp(0, 255),
      g: g.clamp(0, 255),
      b: b.clamp(0, 255),
      brightness: brightness.clamp(0, 255),
      mode: mode.clamp(0, 4),
    );
  }

  void setColor(int r, int g, int b) => state = state.copyWith(
    r: r.clamp(0, 255),
    g: g.clamp(0, 255),
    b: b.clamp(0, 255),
    clearActiveScene: true,
  );
  void setBrightness(int v) => state = state.copyWith(
    brightness: v.clamp(0, 255),
    clearActiveScene: true,
  );
  void setMode(int m) =>
      state = state.copyWith(mode: m.clamp(0, 4), clearActiveScene: true);
  void setFlowSpeed(int v) => state = state.copyWith(
    flowSpeed: v.clamp(0, 255),
    clearActiveScene: true,
  );
  void setBreathPeriod(int v) => state = state.copyWith(
    breathPeriod: v.clamp(0, 255),
    clearActiveScene: true,
  );
  void markSceneActive(int i) {
    if (i < 0 || i >= state.sceneSaved.length) return;
    state = state.copyWith(activeSceneIndex: i);
  }

  Future<void> markSceneSaved(int i) async {
    if (i < 0 || i >= state.sceneSaved.length) return;
    final l = List<bool>.from(state.sceneSaved);
    l[i] = true;
    state = state.copyWith(sceneSaved: l);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(
          _sceneSavedKey,
          l.map((saved) => saved ? '1' : '0').toList(),
        );
  }

  List<bool> _loadSceneSaved() {
    final saved = ref
        .read(sharedPreferencesProvider)
        .getStringList(_sceneSavedKey);
    if (saved == null || saved.length != 8) {
      return const [false, false, false, false, false, false, false, false];
    }
    return saved.map((value) => value == '1').toList(growable: false);
  }
}

final deviceProvider = NotifierProvider<DeviceNotifier, DeviceState>(
  DeviceNotifier.new,
);
