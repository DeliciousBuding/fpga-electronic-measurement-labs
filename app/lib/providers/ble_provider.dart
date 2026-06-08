import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ble_diagnostics.dart';
import '../models/ble_rx_parser.dart';
import '../models/ble_status_query_tracker.dart';
import '../models/command.dart';
import '../utils/ble_scan_matcher.dart';
import 'theme_provider.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

// --- BLE event types ---

sealed class BleEvent {
  final DateTime ts = DateTime.now();
}

class BleAckEvent extends BleEvent {
  final bool success;
  BleAckEvent(this.success);
}

class BleStatusEvent extends BleEvent {
  final int mode, r, g, b, brightness;
  BleStatusEvent(this.mode, this.r, this.g, this.b, this.brightness);

  @override
  String toString() => 'Status: mode=$mode rgb=($r,$g,$b) br=$brightness';
}

class BleLogEvent extends BleEvent {
  final String direction; // TX | RX
  final String hex;
  BleLogEvent(this.direction, this.hex);
}

class BleConnectionEvent extends BleEvent {
  final bool connected;
  final String? name;
  BleConnectionEvent(this.connected, [this.name]);
}

// --- BLE service ---

class BLEService {
  static const _kLastDevice = 'ble_last_device_id';

  BluetoothDevice? _device;
  BluetoothCharacteristic? _txChar;
  bool _txWithoutResponse = true;
  StreamSubscription<List<int>>? _rxSub;
  StreamSubscription? _connSub;
  SharedPreferences? _prefs;

  final _isConnected = ValueNotifier<bool>(false);
  final _eventController = StreamController<BleEvent>.broadcast();

  final _rxParser = BleRxParser();
  final _statusQuery = BleStatusQueryTracker();
  Timer? _statusTimeout;
  Completer<void>? _writeLock;

  // circular debug log
  final _debugLog = <String>[];
  static const _maxDebugLog = 120;
  final _debugLogNotifier = ValueNotifier<int>(0); // bump on change
  final _diagnostics = ValueNotifier<BleDiagnostics>(const BleDiagnostics());

  String? _lastConnectedDeviceId;
  Timer? _reconnectTimer;
  bool _manualDisconnect = false;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 3;

  // --- public accessors ---

  ValueListenable<bool> get isConnected => _isConnected;
  Stream<BleEvent> get events => _eventController.stream;
  List<String> get debugLog => List.unmodifiable(_debugLog);
  ValueListenable<int> get debugLogVersion => _debugLogNotifier;
  ValueListenable<BleDiagnostics> get diagnostics => _diagnostics;
  String? get lastConnectedDeviceId => _lastConnectedDeviceId;

  String get deviceName => _device?.platformName.isNotEmpty == true
      ? _device!.platformName
      : (_device?.remoteId.str ?? '');

  bool get hasDevice => _device != null;

  // --- init ---

  Future<void> init() async {
    _updateDiagnostics(phase: BleDiagnosticPhase.checkingAdapter);
    final supported = await FlutterBluePlus.isSupported;
    _updateDiagnostics(bleSupported: supported);
    if (!supported) {
      _failDiagnostics('BLE not supported');
      throw Exception('BLE not supported');
    }
    final adapterState = await FlutterBluePlus.adapterState
        .where((s) => s == BluetoothAdapterState.on)
        .first
        .timeout(const Duration(seconds: 5));
    _updateDiagnostics(adapterState: adapterState.name);
    _addDebug('BLE adapter ready');

    // auto-reconnect to last known device
    final lastId = _prefs?.getString(_kLastDevice);
    if (lastId != null) {
      _lastConnectedDeviceId = lastId;
      _addDebug('Auto-reconnect to $lastId...');
      try {
        final device = BluetoothDevice.fromId(lastId);
        await connect(device);
      } catch (e) {
        _addDebug('Auto-reconnect skipped: $e');
        _scheduleReconnect();
      }
    }
  }

  // --- scan ---

  Future<List<ScanResult>> scan({int seconds = 5}) async {
    _updateDiagnostics(
      phase: BleDiagnosticPhase.checkingAdapter,
      scanInProgress: false,
      lastError: '',
    );
    final canScan = await _ensureBlePermissions(forScan: true);
    if (!canScan) return const [];
    _updateDiagnostics(
      phase: BleDiagnosticPhase.scanning,
      scanInProgress: true,
      lastError: '',
    );
    final timeout = Duration(seconds: seconds + 2);
    var latestResults = <ScanResult>[];
    StreamSubscription<List<ScanResult>>? scanSub;
    try {
      scanSub = FlutterBluePlus.scanResults.listen((results) {
        latestResults = List<ScanResult>.from(results);
      });
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: seconds),
      ).timeout(timeout);
      await FlutterBluePlus.isScanning.where((s) => !s).first.timeout(timeout);
      final sorted = latestResults..sort(compareScanResultsForTarget);
      _updateDiagnostics(
        phase: BleDiagnosticPhase.idle,
        scanInProgress: false,
        scanCount: sorted.length,
        scanSummary: sorted.take(12).map(_scanSummary).toList(),
      );
      _addDebug('Scan done: ${sorted.length} devices');
      return sorted;
    } catch (e) {
      final sorted = latestResults..sort(compareScanResultsForTarget);
      final error = _classifyBleError(e, fallback: 'Scan failed or timed out');
      _failDiagnostics(error);
      _updateDiagnostics(
        scanInProgress: false,
        scanCount: sorted.length,
        scanSummary: sorted.take(12).map(_scanSummary).toList(),
      );
      _addDebug(error);
      return sorted;
    } finally {
      await scanSub?.cancel();
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }
  }

  // --- connect ---

  Future<bool> connect(BluetoothDevice device) async {
    try {
      _manualDisconnect = false;
      _cancelReconnect();
      _reconnectAttempts = 0;
      await _teardownConnection();
      _resetLinkDiagnostics(device);
      final canConnect = await _ensureBlePermissions(forScan: false);
      if (!canConnect) return false;
      _updateDiagnostics(phase: BleDiagnosticPhase.connecting);
      await device.connect(timeout: const Duration(seconds: 10));
      _device = device;
      _lastConnectedDeviceId = device.remoteId.str;
      _prefs?.setString(_kLastDevice, _lastConnectedDeviceId!);
      _updateDiagnostics(phase: BleDiagnosticPhase.discoveringServices);
      final services = await device.discoverServices();
      _addDebug('Services discovered: ${services.length}');
      for (final s in services) {
        _addDebug('SERVICE ${s.uuid}');
        for (final c in s.characteristics) {
          _addDebug('  CHAR ${c.uuid} props=${_charProps(c)}');
        }
      }

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
        _failDiagnostics('FFF0 service missing');
        await _teardownConnection(deviceOverride: device);
        return false;
      }
      _updateDiagnostics(
        phase: BleDiagnosticPhase.checkingCharacteristics,
        targetServiceFound: true,
      );

      for (final c in target.characteristics) {
        final u = c.uuid.toString().toLowerCase();
        if (u.contains('fff2') &&
            (c.properties.writeWithoutResponse || c.properties.write)) {
          _txChar = c;
          _txWithoutResponse = c.properties.writeWithoutResponse;
          _addDebug(
            'FFF2 write mode: ${_txWithoutResponse ? 'withoutResponse' : 'withResponse'} props=${_charProps(c)}',
          );
          _updateDiagnostics(writeCharacteristicFound: true);
        }
        if (u.contains('fff1') && c.properties.notify) {
          _updateDiagnostics(notifyCharacteristicFound: true);
          _updateDiagnostics(phase: BleDiagnosticPhase.enablingNotify);
          // set up listener BEFORE enabling notify to avoid race
          _rxSub = c.lastValueStream.listen(_handleRawData);
          await c.setNotifyValue(true);
          _updateDiagnostics(notifyEnabled: true);
        }
      }

      final d = _diagnostics.value;
      if (!d.notifyCharacteristicFound) {
        _log.w('No RX characteristic (FFF1 notify)');
        _addDebug('No RX notify char found');
        _failDiagnostics('FFF1 notify characteristic missing');
        await _teardownConnection(deviceOverride: device);
        return false;
      }

      if (_txChar == null) {
        _log.w('No TX characteristic (FFF2 write)');
        _addDebug('No TX char found');
        _failDiagnostics('FFF2 write characteristic missing');
        await _teardownConnection(deviceOverride: device);
        return false;
      }

      _isConnected.value = true;

      // listen for disconnect
      _connSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _isConnected.value = false;
          _addDebug('Disconnected');
          _eventController.add(BleConnectionEvent(false));
          unawaited(_teardownConnection(disconnectDevice: false));
          _scheduleReconnect();
        }
      });

      final name = deviceName;
      _addDebug('Connected: $name');
      _eventController.add(BleConnectionEvent(true, name));

      // auto-query FPGA status
      _updateDiagnostics(phase: BleDiagnosticPhase.queryingStatus);
      final statusOk = await queryStatus();
      if (statusOk) {
        _updateDiagnostics(phase: BleDiagnosticPhase.ready);
      }
      return true;
    } catch (e) {
      _log.e('Connect failed: $e');
      final error = _classifyBleError(e, fallback: 'Connect failed');
      _addDebug(error);
      _failDiagnostics(error);
      await _teardownConnection(deviceOverride: device);
      return false;
    }
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _cancelReconnect();
    _prefs?.remove(_kLastDevice);
    _lastConnectedDeviceId = _device?.remoteId.str;
    await _device?.disconnect();
  }

  // --- raw data handler ---

  void _handleRawData(List<int> data) {
    final hex = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    _addDebug('RX: $hex');
    _updateDiagnostics(lastRxHex: hex);

    final events = _rxParser.handleBytes(data, onDebug: _addDebug);
    for (final event in events) {
      switch (event) {
        case BleRxAck(:final success):
          _eventController.add(BleAckEvent(success));
          break;
        case BleRxStatus(
          :final mode,
          :final r,
          :final g,
          :final b,
          :final brightness,
        ):
          _statusTimeout?.cancel();
          _statusTimeout = null;
          _completeStatusQuery(true);
          final evt = BleStatusEvent(mode, r, g, b, brightness);
          _addDebug('← $evt');
          _eventController.add(evt);
          break;
      }
    }
  }

  // --- parser helpers ---

  void _resetParser({bool completePendingStatus = false}) {
    _statusTimeout?.cancel();
    _statusTimeout = null;
    _rxParser.reset();
    if (completePendingStatus) {
      _completeStatusQuery(false);
    }
  }

  void _completeStatusQuery(bool success) {
    if (success) {
      _statusQuery.succeed();
    } else {
      _statusQuery.fail();
    }
  }

  // --- send ---

  final _throttleTimers = <String, Timer>{};
  final _throttlePending = <String, Uint8List>{};

  Future<void> _send(
    Uint8List data, {
    VoidCallback? beforeWrite,
    VoidCallback? onWriteFailed,
  }) async {
    if (_txChar == null) {
      _addDebug('TX skipped (no char): ${_hex(data)}');
      onWriteFailed?.call();
      return;
    }
    while (_writeLock != null) {
      try {
        await _writeLock!.future;
      } catch (_) {}
    }
    _writeLock = Completer<void>();
    try {
      beforeWrite?.call();
      await _txChar!.write(data, withoutResponse: _txWithoutResponse);
      final hex = _hex(data);
      _addDebug('TX: $hex');
      _updateDiagnostics(lastTxHex: hex);
    } catch (e) {
      _log.e('TX error: $e');
      final error = _classifyBleError(e, fallback: 'TX failed');
      _addDebug(error);
      _failDiagnostics(error);
      onWriteFailed?.call();
    } finally {
      final c = _writeLock;
      _writeLock = null;
      c?.complete();
    }
  }

  /// Throttle: first call sends immediately; subsequent calls within [ms]
  /// are coalesced — only the latest payload is sent when the window closes.
  void _throttledSend(String key, Uint8List data, {int ms = 48}) {
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
      _send(Cmd.setColorFrame(r, g, b));
  void setColorThrottled(int r, int g, int b) =>
      _throttledSend('color', Cmd.setColorFrame(r, g, b));
  Future<void> setBrightness(int v) => _send(Cmd.setBrightnessFrame(v));
  void setBrightnessThrottled(int v) =>
      _throttledSend('bright', Cmd.setBrightnessFrame(v));
  Future<void> setMode(int m) => _send(Cmd.setModeFrame(m));
  Future<void> setFlowSpeed(int v) => _send(Cmd.setFlowSpeedFrame(v));
  void setFlowSpeedThrottled(int v) =>
      _throttledSend('flow', Cmd.setFlowSpeedFrame(v));
  Future<void> setBreathPeriod(int v) => _send(Cmd.setBreathPeriodFrame(v));
  void setBreathPeriodThrottled(int v) =>
      _throttledSend('breath', Cmd.setBreathPeriodFrame(v));
  Future<void> setMusicLevel(int v) => _send(Cmd.setMusicLevelFrame(v));
  void setMusicLevelThrottled(int v) =>
      _throttledSend('music', Cmd.setMusicLevelFrame(v), ms: 48);
  Future<void> saveScene(int v) => _send(Cmd.saveSceneFrame(v));
  Future<void> loadScene(int v) => _send(Cmd.loadSceneFrame(v));

  Future<bool> queryStatus() async {
    _resetParser(completePendingStatus: true);
    final statusFuture = _statusQuery.begin();
    var queryStarted = false;

    void beginStatusQuery() {
      queryStarted = true;
      _rxParser.startStatusCollecting();
      _statusTimeout = Timer(const Duration(seconds: 2), () {
        final received = _rxParser.statusBytesReceived;
        _log.w('Status timeout ($received/5 bytes)');
        _addDebug('Status timeout ($received/5)');
        _failDiagnostics('Status query timeout ($received/5 bytes)');
        _completeStatusQuery(false);
        _resetParser();
      });
    }

    void failStatusQuery() {
      _completeStatusQuery(false);
      _resetParser();
    }

    await _send(
      Cmd.queryStatusFrame(),
      beforeWrite: beginStatusQuery,
      onWriteFailed: failStatusQuery,
    );
    if (!queryStarted) {
      failStatusQuery();
    }

    return statusFuture;
  }

  Future<void> runSelfTest({int seconds = 3}) async {
    try {
      _updateDiagnostics(phase: BleDiagnosticPhase.checkingAdapter);
      final supported = await FlutterBluePlus.isSupported;
      final adapter = await FlutterBluePlus.adapterState.first;
      _updateDiagnostics(bleSupported: supported, adapterState: adapter.name);
      if (!supported) {
        _failDiagnostics('BLE not supported');
        return;
      }
      if (adapter != BluetoothAdapterState.on) {
        _failDiagnostics('Bluetooth adapter is ${adapter.name}');
        return;
      }
      final results = await scan(seconds: seconds);
      final likelyTargets = results.where(scanResultLooksLikeTarget).length;
      _addDebug('Self-test: $likelyTargets likely CH9143/FFF0 target(s)');
      _updateDiagnostics(
        phase: likelyTargets > 0
            ? BleDiagnosticPhase.idle
            : BleDiagnosticPhase.failed,
        lastError: likelyTargets > 0
            ? ''
            : 'No CH9143/FFF0-like device found in scan',
      );
    } catch (e) {
      _failDiagnostics(_classifyBleError(e, fallback: 'Self-test failed'));
    }
  }

  void clearDebugLog() {
    _debugLog.clear();
    _debugLogNotifier.value++;
  }

  String exportDebugSnapshot() =>
      _diagnostics.value.exportSnapshot(debugLog: _debugLog);

  // --- utilities ---

  void _addDebug(String msg) {
    _debugLog.add(msg);
    if (_debugLog.length > _maxDebugLog) _debugLog.removeAt(0);
    _debugLogNotifier.value++;
  }

  void _updateDiagnostics({
    bool? bleSupported,
    String? adapterState,
    bool? scanInProgress,
    int? scanCount,
    List<String>? scanSummary,
    String? selectedDeviceId,
    String? selectedDeviceName,
    BleDiagnosticPhase? phase,
    bool? targetServiceFound,
    bool? notifyCharacteristicFound,
    bool? writeCharacteristicFound,
    bool? notifyEnabled,
    String? lastTxHex,
    String? lastRxHex,
    String? lastError,
  }) {
    _diagnostics.value = _diagnostics.value.copyWith(
      bleSupported: bleSupported,
      adapterState: adapterState,
      scanInProgress: scanInProgress,
      scanCount: scanCount,
      scanSummary: scanSummary,
      selectedDeviceId: selectedDeviceId,
      selectedDeviceName: selectedDeviceName,
      phase: phase,
      targetServiceFound: targetServiceFound,
      notifyCharacteristicFound: notifyCharacteristicFound,
      writeCharacteristicFound: writeCharacteristicFound,
      notifyEnabled: notifyEnabled,
      lastTxHex: lastTxHex,
      lastRxHex: lastRxHex,
      lastError: lastError,
      updatedAt: DateTime.now(),
    );
  }

  void _failDiagnostics(String error) {
    _updateDiagnostics(phase: BleDiagnosticPhase.failed, lastError: error);
  }

  Future<bool> _ensureBlePermissions({required bool forScan}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    final permissions = <Permission>[
      if (forScan) Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ];
    final denied = <String>[];
    for (final permission in permissions) {
      final before = await permission.status;
      final after = before.isGranted ? before : await permission.request();
      if (!after.isGranted) {
        denied.add('${permission.toString()}=${after.name}');
      }
    }
    if (denied.isEmpty) return true;
    final action = forScan ? 'scan' : 'connect';
    final error =
        'BLE $action permission denied: ${denied.join(', ')}. Grant Android Nearby devices/Bluetooth permission and retry.';
    _addDebug(error);
    _failDiagnostics(error);
    _updateDiagnostics(scanInProgress: false);
    return false;
  }

  String _classifyBleError(Object error, {required String fallback}) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('bluetooth_scan') ||
        lower.contains('bluetooth scan') ||
        lower.contains('scan permission')) {
      return '$fallback: Android BLUETOOTH_SCAN permission is missing or denied. Grant Nearby devices permission and retry. Raw: $raw';
    }
    if (lower.contains('bluetooth_connect') ||
        lower.contains('bluetooth connect') ||
        lower.contains('connect permission')) {
      return '$fallback: Android BLUETOOTH_CONNECT permission is missing or denied. Grant Nearby devices permission and retry. Raw: $raw';
    }
    if (lower.contains('location') || lower.contains('fine_location')) {
      return '$fallback: Android location permission/service may be required for BLE scan on this device. Check location permission and location services. Raw: $raw';
    }
    if (lower.contains('permission') || lower.contains('denied')) {
      return '$fallback: BLE permission denied by Android. Check Nearby devices/Bluetooth permissions. Raw: $raw';
    }
    return '$fallback: $raw';
  }

  Future<void> _teardownConnection({
    BluetoothDevice? deviceOverride,
    bool disconnectDevice = true,
  }) async {
    _resetParser(completePendingStatus: true);
    await _rxSub?.cancel();
    _rxSub = null;
    await _connSub?.cancel();
    _connSub = null;
    final device = deviceOverride ?? _device;
    if (disconnectDevice && device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
    _device = null;
    _txChar = null;
    _txWithoutResponse = true;
    _isConnected.value = false;
  }

  void _resetLinkDiagnostics(BluetoothDevice device) {
    _updateDiagnostics(
      selectedDeviceId: device.remoteId.str,
      selectedDeviceName: device.platformName,
      targetServiceFound: false,
      notifyCharacteristicFound: false,
      writeCharacteristicFound: false,
      notifyEnabled: false,
      lastError: '',
    );
  }

  static String _hex(Uint8List data) =>
      data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

  static String _charProps(BluetoothCharacteristic c) {
    final p = c.properties;
    return [
      if (p.read) 'read',
      if (p.write) 'write',
      if (p.writeWithoutResponse) 'writeWithoutResponse',
      if (p.notify) 'notify',
      if (p.indicate) 'indicate',
    ].join(',');
  }

  static String _scanSummary(ScanResult r) {
    final adv = r.advertisementData;
    final name = scanResultDisplayName(r);
    final services = adv.serviceUuids.map((u) => u.toString()).join(',');
    return '$name id=${r.device.remoteId.str} rssi=${r.rssi} services=[$services]';
  }

  // --- auto reconnect ---

  void _scheduleReconnect() {
    if (_manualDisconnect || _lastConnectedDeviceId == null) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _addDebug('Max reconnect attempts reached ($_reconnectAttempts)');
      return;
    }
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: 3 + _reconnectAttempts * 2);
    _addDebug(
      'Reconnect attempt ${_reconnectAttempts + 1}/$_maxReconnectAttempts in ${delay.inSeconds}s...',
    );
    _reconnectTimer = Timer(delay, () async {
      _reconnectTimer = null;
      if (_manualDisconnect || _isConnected.value) return;
      _reconnectAttempts++;
      _addDebug('Reconnecting to $_lastConnectedDeviceId...');
      try {
        final device = BluetoothDevice.fromId(_lastConnectedDeviceId!);
        await connect(device);
      } catch (e) {
        _addDebug('Reconnect failed: $e');
        _scheduleReconnect();
      }
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  // --- dispose ---

  void dispose() {
    _cancelReconnect();
    _rxSub?.cancel();
    _connSub?.cancel();
    _resetParser(completePendingStatus: true);
    for (final t in _throttleTimers.values) {
      t.cancel();
    }
    _eventController.close();
    _debugLogNotifier.dispose();
    _diagnostics.dispose();
    _isConnected.dispose();
  }
}

// --- provider ---

final bleServiceProvider = Provider<BLEService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final svc = BLEService().._prefs = prefs;
  ref.onDispose(() => svc.dispose());
  return svc;
});
