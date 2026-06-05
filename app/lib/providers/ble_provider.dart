import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logger/logger.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

// --- BLE event types ---

sealed class BleEvent {
  final DateTime ts = DateTime.now();
}

class BleAckEvent extends BleEvent {
  final bool success;
  BleAckEvent(this.success);

  String get label => success ? 'ACK OK' : 'ACK ERR';
}

class BleStatusEvent extends BleEvent {
  final int mode, r, g, b, brightness;
  BleStatusEvent(this.mode, this.r, this.g, this.b, this.brightness);

  @override
  String toString() =>
      'Status: mode=$mode rgb=($r,$g,$b) br=$brightness';
}

class BleLogEvent extends BleEvent {
  final String direction; // TX | RX
  final String hex;
  BleLogEvent(this.direction, this.hex);

  String get label => '$direction $hex';
}

class BleConnectionEvent extends BleEvent {
  final bool connected;
  final String? name;
  BleConnectionEvent(this.connected, [this.name]);

  String get label =>
      connected ? 'Connected${name != null ? ": $name" : ""}' : 'Disconnected';
}

// --- BLE service ---

enum _ParseState { idle, collectingStatus }

class BLEService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _txChar;
  StreamSubscription<List<int>>? _rxSub;
  StreamSubscription? _connSub;

  final _isConnected = ValueNotifier<bool>(false);
  final _eventController = StreamController<BleEvent>.broadcast();

  _ParseState _parseState = _ParseState.idle;
  final _statusBuffer = <int>[];
  Timer? _statusTimeout;

  // circular debug log
  final _debugLog = <String>[];
  static const _maxDebugLog = 50;
  final _debugLogNotifier = ValueNotifier<int>(0); // bump on change

  String? _lastConnectedDeviceId;

  // --- public accessors ---

  ValueListenable<bool> get isConnected => _isConnected;
  Stream<BleEvent> get events => _eventController.stream;
  List<String> get debugLog => List.unmodifiable(_debugLog);
  ValueListenable<int> get debugLogVersion => _debugLogNotifier;
  String? get lastConnectedDeviceId => _lastConnectedDeviceId;

  String get deviceName =>
      _device?.platformName.isNotEmpty == true
          ? _device!.platformName
          : (_device?.remoteId.str ?? '');

  bool get hasDevice => _device != null;

  // --- init ---

  Future<void> init() async {
    if (!await FlutterBluePlus.isSupported) {
      throw Exception('BLE 不支持');
    }
    await FlutterBluePlus.adapterState
        .where((s) => s == BluetoothAdapterState.on)
        .first
        .timeout(const Duration(seconds: 5));
    _addDebug('BLE adapter ready');
  }

  // --- scan ---

  Future<List<ScanResult>> scan({int seconds = 5}) async {
    await FlutterBluePlus.startScan(timeout: Duration(seconds: seconds));
    // wait for scan to complete
    await FlutterBluePlus.isScanning
        .where((s) => !s)
        .first;
    final results = await FlutterBluePlus.scanResults.last;
    await FlutterBluePlus.stopScan();
    final sorted = List<ScanResult>.from(results)
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    _addDebug('Scan done: ${sorted.length} devices');
    return sorted;
  }

  // --- connect ---

  Future<bool> connect(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _device = device;
      _lastConnectedDeviceId = device.remoteId.str;
      final services = await device.discoverServices();

      BluetoothService? target;
      for (final s in services) {
        if (s.uuid.toString().toLowerCase().contains('fff0')) {
          target = s;
          break;
        }
      }
      if (target == null) {
        _log.w('No FFF0 service');
        _addDebug('No FFF0 service found');
        await device.disconnect();
        return false;
      }

      for (final c in target.characteristics) {
        final u = c.uuid.toString().toLowerCase();
        if (u.contains('fff2') && c.properties.writeWithoutResponse) {
          _txChar = c;
        }
        if (u.contains('fff1') && c.properties.notify) {
          // set up listener BEFORE enabling notify to avoid race
          _rxSub = c.lastValueStream.listen(_handleRawData);
          await c.setNotifyValue(true);
        }
      }

      if (_txChar == null) {
        _log.w('No TX characteristic (FFF2 write)');
        _addDebug('No TX char found');
        await device.disconnect();
        return false;
      }

      _isConnected.value = true;

      // listen for disconnect
      _connSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _isConnected.value = false;
          _addDebug('Disconnected');
          _eventController.add(BleConnectionEvent(false));
          _device = null;
          _txChar = null;
          _resetParser();
          _rxSub?.cancel();
          _connSub?.cancel();
        }
      });

      final name = deviceName;
      _addDebug('Connected: $name');
      _eventController.add(BleConnectionEvent(true, name));

      // auto-query FPGA status
      await queryStatus();
      return true;
    } catch (e) {
      _log.e('Connect failed: $e');
      _addDebug('Connect error: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    _lastConnectedDeviceId = _device?.remoteId.str;
    await _device?.disconnect();
  }

  // --- raw data handler ---

  void _handleRawData(List<int> data) {
    final hex = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    _addDebug('RX: $hex');

    for (final byte in data) {
      switch (_parseState) {
        case _ParseState.collectingStatus:
          _statusBuffer.add(byte);
          if (_statusBuffer.length >= 5) {
            _statusTimeout?.cancel();
            _parseState = _ParseState.idle;
            final evt = BleStatusEvent(
              _statusBuffer[0], _statusBuffer[1], _statusBuffer[2],
              _statusBuffer[3], _statusBuffer[4],
            );
            _addDebug('← $evt');
            _eventController.add(evt);
            _statusBuffer.clear();
          }
          break;

        case _ParseState.idle:
          if (byte == 0xAA) {
            _eventController.add(BleAckEvent(true));
          } else if (byte == 0xEE) {
            _eventController.add(BleAckEvent(false));
          }
          break;
      }
    }
  }

  // --- parser helpers ---

  void _resetParser() {
    _statusTimeout?.cancel();
    _statusBuffer.clear();
    _parseState = _ParseState.idle;
  }

  // --- send ---

  final _throttleTimers = <String, Timer>{};
  final _throttlePending = <String, Uint8List>{};

  Future<void> _send(Uint8List data) async {
    if (_txChar == null) {
      _addDebug('TX skipped (no char): ${_hex(data)}');
      return;
    }
    try {
      await _txChar!.write(data, withoutResponse: true);
      _addDebug('TX: ${_hex(data)}');
    } catch (e) {
      _log.e('TX error: $e');
      _addDebug('TX error: $e');
    }
  }

  /// Throttle: first call sends immediately; subsequent calls within [ms]
  /// are coalesced — only the latest payload is sent when the window closes.
  void _throttledSend(String key, Uint8List data, {int ms = 80}) {
    _throttlePending[key] = data;
    if (_throttleTimers.containsKey(key)) return; // within window, data stored
    _flushThrottle(key, ms);
  }

  void _flushThrottle(String key, int ms) {
    final d = _throttlePending.remove(key);
    if (d != null) _send(d);
    _throttleTimers[key] = Timer(Duration(milliseconds: ms), () {
      _throttleTimers.remove(key);
      if (_throttlePending.containsKey(key)) _flushThrottle(key, ms);
    });
  }

  // --- public commands (immediate for discrete, throttled for continuous) ---

  Future<void> setColor(int r, int g, int b) =>
      _send(Uint8List.fromList([0x10, r, g, b]));
  void setColorThrottled(int r, int g, int b) =>
      _throttledSend('color', Uint8List.fromList([0x10, r, g, b]));
  Future<void> setBrightness(int v) =>
      _send(Uint8List.fromList([0x11, v.clamp(0, 255)]));
  void setBrightnessThrottled(int v) =>
      _throttledSend('bright', Uint8List.fromList([0x11, v.clamp(0, 255)]));
  Future<void> setMode(int m) =>
      _send(Uint8List.fromList([0x20, m]));
  Future<void> setFlowSpeed(int v) =>
      _send(Uint8List.fromList([0x21, v.clamp(0, 255)]));
  void setFlowSpeedThrottled(int v) =>
      _throttledSend('flow', Uint8List.fromList([0x21, v.clamp(0, 255)]));
  Future<void> setBreathPeriod(int v) =>
      _send(Uint8List.fromList([0x22, v.clamp(0, 255)]));
  void setBreathPeriodThrottled(int v) =>
      _throttledSend('breath', Uint8List.fromList([0x22, v.clamp(0, 255)]));
  Future<void> saveScene(int v) =>
      _send(Uint8List.fromList([0x30, v]));
  Future<void> loadScene(int v) =>
      _send(Uint8List.fromList([0x31, v]));

  Future<void> queryStatus() async {
    _resetParser();
    _parseState = _ParseState.collectingStatus;
    _statusTimeout = Timer(const Duration(seconds: 2), () {
      _log.w('Status timeout (${_statusBuffer.length}/5 bytes)');
      _addDebug('Status timeout (${_statusBuffer.length}/5)');
      _resetParser();
    });
    await _send(Uint8List.fromList([0xFF]));
  }

  // --- utilities ---

  void _addDebug(String msg) {
    _debugLog.add(msg);
    if (_debugLog.length > _maxDebugLog) _debugLog.removeAt(0);
    _debugLogNotifier.value++;
  }

  static String _hex(Uint8List data) =>
      data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

  // --- dispose ---

  void dispose() {
    _rxSub?.cancel();
    _connSub?.cancel();
    _statusTimeout?.cancel();
    for (final t in _throttleTimers.values) { t.cancel(); }
    _eventController.close();
    _debugLogNotifier.dispose();
    _isConnected.dispose();
  }
}

// --- provider ---

final bleServiceProvider = Provider<BLEService>((ref) {
  final svc = BLEService();
  ref.onDispose(() => svc.dispose());
  return svc;
});
