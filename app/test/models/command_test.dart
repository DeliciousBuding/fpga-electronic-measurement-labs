import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_ble_controller/models/command.dart';

void main() {
  test('builds byte-exact command frames for FPGA UART protocol', () {
    expect(Cmd.setColorFrame(1, 2, 3), [0x10, 1, 2, 3]);
    expect(Cmd.setBrightnessFrame(300), [0x11, 255]);
    expect(Cmd.setModeFrame(2), [0x20, 2]);
    expect(Cmd.setFlowSpeedFrame(-1), [0x21, 0]);
    expect(Cmd.setBreathPeriodFrame(128), [0x22, 128]);
    expect(Cmd.setMusicLevelFrame(300), [0x23, 255]);
    expect(Cmd.saveSceneFrame(7), [0x30, 7]);
    expect(Cmd.loadSceneFrame(0), [0x31, 0]);
    expect(Cmd.queryStatusFrame(), [0xFF]);
  });
}
