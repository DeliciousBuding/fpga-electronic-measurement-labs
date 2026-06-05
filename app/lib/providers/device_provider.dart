import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeviceState {
  final int r, g, b;
  final int brightness;
  final int mode;
  final int flowSpeed;
  final int breathPeriod;
  final List<bool> sceneSaved;

  const DeviceState({
    this.r = 255,
    this.g = 0,
    this.b = 0,
    this.brightness = 200,
    this.mode = 0,
    this.flowSpeed = 128,
    this.breathPeriod = 128,
    this.sceneSaved = const [false, false, false, false, false, false, false, false],
  });

  DeviceState copyWith({
    int? r, int? g, int? b,
    int? brightness, int? mode,
    int? flowSpeed, int? breathPeriod,
    List<bool>? sceneSaved,
  }) =>
      DeviceState(
        r: r ?? this.r, g: g ?? this.g, b: b ?? this.b,
        brightness: brightness ?? this.brightness,
        mode: mode ?? this.mode,
        flowSpeed: flowSpeed ?? this.flowSpeed,
        breathPeriod: breathPeriod ?? this.breathPeriod,
        sceneSaved: sceneSaved ?? this.sceneSaved,
      );
}

class DeviceNotifier extends Notifier<DeviceState> {
  @override
  DeviceState build() => const DeviceState();

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

  void setColor(int r, int g, int b) =>
      state = state.copyWith(r: r.clamp(0, 255), g: g.clamp(0, 255), b: b.clamp(0, 255));
  void setBrightness(int v) =>
      state = state.copyWith(brightness: v.clamp(0, 255));
  void setMode(int m) =>
      state = state.copyWith(mode: m.clamp(0, 4));
  void setFlowSpeed(int v) =>
      state = state.copyWith(flowSpeed: v.clamp(0, 255));
  void setBreathPeriod(int v) =>
      state = state.copyWith(breathPeriod: v.clamp(0, 255));
  void markSceneSaved(int i) {
    final l = List<bool>.from(state.sceneSaved);
    l[i] = true;
    state = state.copyWith(sceneSaved: l);
  }
}

final deviceProvider = NotifierProvider<DeviceNotifier, DeviceState>(
  DeviceNotifier.new,
);
