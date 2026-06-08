import 'command.dart';

enum BleRxParseState { idle, collectingStatus }

sealed class BleRxParseEvent {
  const BleRxParseEvent();
}

class BleRxAck extends BleRxParseEvent {
  const BleRxAck(this.success);

  final bool success;
}

class BleRxStatus extends BleRxParseEvent {
  const BleRxStatus(this.mode, this.r, this.g, this.b, this.brightness);

  final int mode;
  final int r;
  final int g;
  final int b;
  final int brightness;
}

class BleRxParser {
  BleRxParseState _state = BleRxParseState.idle;
  final _statusBuffer = <int>[];

  BleRxParseState get state => _state;
  bool get isCollectingStatus => _state == BleRxParseState.collectingStatus;
  int get statusBytesReceived => _statusBuffer.length;

  void startStatusCollecting() {
    reset();
    _state = BleRxParseState.collectingStatus;
  }

  void reset() {
    _statusBuffer.clear();
    _state = BleRxParseState.idle;
  }

  List<BleRxParseEvent> handleBytes(
    List<int> data, {
    void Function(String message)? onDebug,
  }) {
    final events = <BleRxParseEvent>[];
    for (final byte in data) {
      switch (_state) {
        case BleRxParseState.collectingStatus:
          if (_statusBuffer.isEmpty &&
              (byte == Cmd.ackOk || byte == Cmd.ackErr)) {
            onDebug?.call(
              'Ignored ${byte == Cmd.ackOk ? 'ACK' : 'ERR'} while waiting status',
            );
            break;
          }
          _statusBuffer.add(byte);
          if (_statusBuffer.length >= 5) {
            events.add(
              BleRxStatus(
                _statusBuffer[0],
                _statusBuffer[1],
                _statusBuffer[2],
                _statusBuffer[3],
                _statusBuffer[4],
              ),
            );
            reset();
          }
          break;

        case BleRxParseState.idle:
          if (byte == Cmd.ackOk) {
            events.add(const BleRxAck(true));
          } else if (byte == Cmd.ackErr) {
            events.add(const BleRxAck(false));
          }
          break;
      }
    }
    return events;
  }
}
