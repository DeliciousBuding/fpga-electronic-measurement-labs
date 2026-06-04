/// 命令协议常量
class Cmd {
  static const setColor = 0x10;
  static const setBrightness = 0x11;
  static const setMode = 0x20;
  static const setFlowSpeed = 0x21;
  static const setBreathPeriod = 0x22;
  static const saveScene = 0x30;
  static const loadScene = 0x31;
  static const queryStatus = 0xFF;

  static const ackOk = 0xAA;
  static const ackErr = 0xEE;
}

/// 灯效模式
enum LightMode {
  static_(0, '静态'),
  breath(1, '呼吸'),
  flow(2, '流水'),
  gradient(3, '渐变'),
  music(4, '音乐');

  final int code;
  final String label;
  const LightMode(this.code, this.label);

  static LightMode fromCode(int code) {
    for (final m in values) {
      if (m.code == code) return m;
    }
    return static_;
  }
}

/// 情景模式数据
class SceneData {
  final int r, g, b;
  final int brightness;
  final int mode;

  const SceneData({
    this.r = 255,
    this.g = 0,
    this.b = 0,
    this.brightness = 200,
    this.mode = 0,
  });
}
