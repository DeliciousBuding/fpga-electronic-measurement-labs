import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logger/logger.dart';

final _log = Logger();

class BLEService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _txChar;
  StreamSubscription<List<int>>? _rxSub;

  final _isConnected = ValueNotifier<bool>(false);
  final _rxStream = StreamController<List<int>>.broadcast();

  ValueListenable<bool> get isConnected => _isConnected;
  Stream<List<int>> get rxStream => _rxStream.stream;
  String get deviceName =>
      _device?.platformName.isNotEmpty == true
          ? _device!.platformName
          : (_device?.remoteId.str ?? '');
  bool get hasDevice => _device != null;

  Future<void> init() async {
    if (!await FlutterBluePlus.isSupported) throw Exception('BLE 不支持');
    await FlutterBluePlus.adapterState
        .where((s) => s == BluetoothAdapterState.on)
        .first
        .timeout(const Duration(seconds: 5));
  }

  Future<List<ScanResult>> scan({int seconds = 5}) async {
    final results = <ScanResult>[];
    await FlutterBluePlus.startScan(timeout: Duration(seconds: seconds));
    await for (final r in FlutterBluePlus.scanResults) {
      results
        ..clear()
        ..addAll(r);
    }
    results.sort((a, b) => b.rssi.compareTo(a.rssi));
    return results;
  }

  Future<bool> connect(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _device = device;
      final services = await device.discoverServices();

      BluetoothService? target;
      for (final s in services) {
        final u = s.uuid.toString().toLowerCase();
        if (u.contains('fff0')) {
          target = s;
          break;
        }
      }
      if (target == null) {
        _log.w('No FFF0 service');
        await device.disconnect();
        return false;
      }

      for (final c in target.characteristics) {
        final u = c.uuid.toString().toLowerCase();
        if (u.contains('fff2') && c.properties.writeWithoutResponse) {
          _txChar = c;
        }
        if (u.contains('fff1') && c.properties.notify) {
          await c.setNotifyValue(true);
          _rxSub = c.lastValueStream.listen((d) {
            _rxStream.add(Uint8List.fromList(d));
          });
        }
      }

      if (_txChar == null) {
        await device.disconnect();
        return false;
      }

      _isConnected.value = true;
      device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _isConnected.value = false;
          _device = null;
          _txChar = null;
          _rxSub?.cancel();
        }
      });
      return true;
    } catch (e) {
      _log.e('Connect: $e');
      return false;
    }
  }

  Future<void> disconnect() async => await _device?.disconnect();

  Future<void> send(Uint8List data) async {
    if (_txChar == null) return;
    try {
      await _txChar!.write(data, withoutResponse: true);
    } catch (_) {}
  }

  Future<void> setColor(int r, int g, int b) =>
      send(Uint8List.fromList([0x10, r, g, b]));
  Future<void> setBrightness(int v) =>
      send(Uint8List.fromList([0x11, v.clamp(0, 255)]));
  Future<void> setMode(int m) => send(Uint8List.fromList([0x20, m]));
  Future<void> setFlowSpeed(int v) =>
      send(Uint8List.fromList([0x21, v.clamp(0, 255)]));
  Future<void> setBreathPeriod(int v) =>
      send(Uint8List.fromList([0x22, v.clamp(0, 255)]));
  Future<void> saveScene(int s) => send(Uint8List.fromList([0x30, s]));
  Future<void> loadScene(int s) => send(Uint8List.fromList([0x31, s]));

  void dispose() {
    _rxSub?.cancel();
    _rxStream.close();
    _isConnected.dispose();
  }
}

final bleServiceProvider = Provider<BLEService>((ref) => BLEService());
