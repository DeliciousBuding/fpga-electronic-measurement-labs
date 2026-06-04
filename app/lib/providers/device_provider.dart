import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeviceState {
  final int r, g, b;
  final int brightness;
  final int mode;
  final int flowSpeed;
  final int breathPeriod;

  const DeviceState({
    this.r = 255,
    this.g = 0,
    this.b = 0,
    this.brightness = 200,
    this.mode = 0,
    this.flowSpeed = 128,
    this.breathPeriod = 128,
  });

  DeviceState copyWith({
    int? r, int? g, int? b,
    int? brightness, int? mode,
    int? flowSpeed, int? breathPeriod,
  }) =>
      DeviceState(
        r: r ?? this.r, g: g ?? this.g, b: b ?? this.b,
        brightness: brightness ?? this.brightness,
        mode: mode ?? this.mode,
        flowSpeed: flowSpeed ?? this.flowSpeed,
        breathPeriod: breathPeriod ?? this.breathPeriod,
      );
}

class DeviceNotifier extends Notifier<DeviceState> {
  @override
  DeviceState build() => const DeviceState();

  void setColor(int r, int g, int b) => state = state.copyWith(r: r, g: g, b: b);
  void setBrightness(int v) => state = state.copyWith(brightness: v);
  void setMode(int m) => state = state.copyWith(mode: m);
  void setFlowSpeed(int v) => state = state.copyWith(flowSpeed: v);
  void setBreathPeriod(int v) => state = state.copyWith(breathPeriod: v);
}

final deviceProvider = NotifierProvider<DeviceNotifier, DeviceState>(
  DeviceNotifier.new,
);
