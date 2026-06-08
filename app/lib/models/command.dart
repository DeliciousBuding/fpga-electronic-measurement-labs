import 'dart:typed_data';

/// 命令协议常量
class Cmd {
  static const setColor = 0x10;
  static const setBrightness = 0x11;
  static const setMode = 0x20;
  static const setFlowSpeed = 0x21;
  static const setBreathPeriod = 0x22;
  static const setMusicLevel = 0x23;
  static const saveScene = 0x30;
  static const loadScene = 0x31;
  static const queryStatus = 0xFF;

  static const ackOk = 0xAA;
  static const ackErr = 0xEE;

  static Uint8List setColorFrame(int r, int g, int b) =>
      Uint8List.fromList([setColor, _byte(r), _byte(g), _byte(b)]);
  static Uint8List setBrightnessFrame(int value) =>
      Uint8List.fromList([setBrightness, _byte(value)]);
  static Uint8List setModeFrame(int mode) =>
      Uint8List.fromList([setMode, _mode(mode)]);
  static Uint8List setFlowSpeedFrame(int value) =>
      Uint8List.fromList([setFlowSpeed, _byte(value)]);
  static Uint8List setBreathPeriodFrame(int value) =>
      Uint8List.fromList([setBreathPeriod, _byte(value)]);
  static Uint8List setMusicLevelFrame(int value) =>
      Uint8List.fromList([setMusicLevel, _byte(value)]);
  static Uint8List saveSceneFrame(int slot) =>
      Uint8List.fromList([saveScene, _sceneSlot(slot)]);
  static Uint8List loadSceneFrame(int slot) =>
      Uint8List.fromList([loadScene, _sceneSlot(slot)]);
  static Uint8List queryStatusFrame() => Uint8List.fromList([queryStatus]);

  static int _byte(int value) => value.clamp(0, 255);
  static int _mode(int value) => value.clamp(0, 4);
  static int _sceneSlot(int value) => value.clamp(0, 7);
}

enum LightMode {
  static_(0),
  breath(1),
  flow(2),
  gradient(3),
  music(4);

  final int code;
  const LightMode(this.code);

  static LightMode fromCode(int code) {
    for (final m in values) {
      if (m.code == code) return m;
    }
    return static_;
  }
}
