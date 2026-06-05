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
