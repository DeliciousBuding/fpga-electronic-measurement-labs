import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_ble_controller/models/ble_rx_parser.dart';
import 'package:rgb_ble_controller/models/command.dart';

void main() {
  test('idle parser emits ACK and ERR events', () {
    final parser = BleRxParser();

    final events = parser.handleBytes([Cmd.ackOk, Cmd.ackErr, 0x42]);

    expect(events, hasLength(2));
    expect(events[0], isA<BleRxAck>());
    expect((events[0] as BleRxAck).success, isTrue);
    expect(events[1], isA<BleRxAck>());
    expect((events[1] as BleRxAck).success, isFalse);
    expect(parser.state, BleRxParseState.idle);
  });

  test('status parser ignores stale leading ACK and ERR bytes', () {
    final parser = BleRxParser()..startStatusCollecting();
    final debug = <String>[];

    final events = parser.handleBytes([
      Cmd.ackOk,
      Cmd.ackErr,
      0x02,
      0x11,
      0x22,
      0x33,
      0x44,
    ], onDebug: debug.add);

    expect(debug, [
      'Ignored ACK while waiting status',
      'Ignored ERR while waiting status',
    ]);
    expect(events, hasLength(1));
    final status = events.single as BleRxStatus;
    expect(status.mode, 0x02);
    expect(status.r, 0x11);
    expect(status.g, 0x22);
    expect(status.b, 0x33);
    expect(status.brightness, 0x44);
    expect(parser.state, BleRxParseState.idle);
    expect(parser.statusBytesReceived, 0);
  });

  test('status parser keeps partial frame count for timeout diagnostics', () {
    final parser = BleRxParser()..startStatusCollecting();

    final events = parser.handleBytes([0x03, 0xAA, 0xBB]);

    expect(events, isEmpty);
    expect(parser.isCollectingStatus, isTrue);
    expect(parser.statusBytesReceived, 3);
    parser.reset();
    expect(parser.state, BleRxParseState.idle);
    expect(parser.statusBytesReceived, 0);
  });

  test('status parser supports fragmented notify packets', () {
    final parser = BleRxParser()..startStatusCollecting();
    final debug = <String>[];

    expect(parser.handleBytes([Cmd.ackOk], onDebug: debug.add), isEmpty);
    expect(debug, ['Ignored ACK while waiting status']);
    expect(parser.statusBytesReceived, 0);

    expect(parser.handleBytes([0x01, 0x10]), isEmpty);
    expect(parser.statusBytesReceived, 2);

    final events = parser.handleBytes([0x20, 0x30, 0x40]);
    expect(events, hasLength(1));
    final status = events.single as BleRxStatus;
    expect(status.mode, 0x01);
    expect(status.r, 0x10);
    expect(status.g, 0x20);
    expect(status.b, 0x30);
    expect(status.brightness, 0x40);
    expect(parser.state, BleRxParseState.idle);
  });

  test('status parser preserves ACK-like bytes inside a status frame', () {
    final parser = BleRxParser()..startStatusCollecting();

    final events = parser.handleBytes([
      0x03,
      Cmd.ackOk,
      0x12,
      Cmd.ackErr,
      0x55,
    ]);

    expect(events, hasLength(1));
    final status = events.single as BleRxStatus;
    expect(status.mode, 0x03);
    expect(status.r, Cmd.ackOk);
    expect(status.g, 0x12);
    expect(status.b, Cmd.ackErr);
    expect(status.brightness, 0x55);
    expect(parser.state, BleRxParseState.idle);
  });

  test('status parser resumes idle ACK parsing after a frame completes', () {
    final parser = BleRxParser()..startStatusCollecting();

    final events = parser.handleBytes([
      0x02,
      0x11,
      0x22,
      0x33,
      0x44,
      Cmd.ackOk,
    ]);

    expect(events, hasLength(2));
    expect(events.first, isA<BleRxStatus>());
    expect(events.last, isA<BleRxAck>());
    expect((events.last as BleRxAck).success, isTrue);
    expect(parser.state, BleRxParseState.idle);
  });
}
