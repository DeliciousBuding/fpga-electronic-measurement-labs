import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'BLE scan has a bounded completion path and cancels stream subscription',
    () {
      final source = File('lib/providers/ble_provider.dart').readAsStringSync();

      expect(source, contains('StreamSubscription<List<ScanResult>>? scanSub'));
      expect(source, contains('FlutterBluePlus.scanResults.listen'));
      expect(source, contains('compareScanResultsForTarget'));
      expect(source, contains('scanResultLooksLikeTarget'));
      expect(source, contains('.timeout(timeout)'));
      expect(source, contains('await scanSub?.cancel()'));
      expect(source, contains('await FlutterBluePlus.stopScan()'));
      expect(source, isNot(contains('FlutterBluePlus.scanResults.last')));
      expect(source, isNot(contains('b.rssi.compareTo(a.rssi)')));
    },
  );

  test('status query enters receive mode before TX and filters stale ACK', () {
    final source = File('lib/providers/ble_provider.dart').readAsStringSync();
    final queryIndex = source.indexOf('Future<bool> queryStatus()');
    final querySource = source.substring(queryIndex);

    expect(
      querySource.indexOf('beforeWrite: beginStatusQuery'),
      lessThan(querySource.indexOf('onWriteFailed: failStatusQuery')),
    );
    expect(source, contains("import '../models/ble_rx_parser.dart';"));
    expect(
      source,
      contains("import '../models/ble_status_query_tracker.dart';"),
    );
    expect(source, contains('final _rxParser = BleRxParser();'));
    expect(source, contains('_rxParser.handleBytes(data, onDebug: _addDebug)'));
    expect(source, contains('_rxParser.statusBytesReceived'));
    expect(source, contains('final _statusQuery = BleStatusQueryTracker();'));
    expect(source, contains('final statusFuture = _statusQuery.begin();'));
    expect(source, contains('final statusOk = await queryStatus();'));
    expect(source, contains('if (statusOk)'));
    expect(source, contains('Future<bool> queryStatus()'));
    expect(source, contains('beforeWrite?.call();'));
    expect(source, contains('_resetParser(completePendingStatus: true);'));
  });

  test('connect failure paths share teardown and FFF2 write can fallback', () {
    final source = File('lib/providers/ble_provider.dart').readAsStringSync();

    expect(source, contains('Future<void> _teardownConnection'));
    expect(source, contains('await _teardownConnection();'));
    expect(
      source,
      contains('await _teardownConnection(deviceOverride: device)'),
    );
    expect(
      source,
      contains('c.properties.writeWithoutResponse || c.properties.write'),
    );
    expect(
      source,
      contains('_txWithoutResponse = c.properties.writeWithoutResponse'),
    );
    expect(source, contains('withoutResponse: _txWithoutResponse'));
    expect(
      source,
      isNot(contains('FFF2 writeWithoutResponse characteristic missing')),
    );
  });

  test(
    'BLE failures are classified into actionable permission diagnostics',
    () {
      final source = File('lib/providers/ble_provider.dart').readAsStringSync();

      expect(source, contains('String _classifyBleError'));
      expect(
        source,
        contains('BLUETOOTH_SCAN permission is missing or denied'),
      );
      expect(
        source,
        contains('BLUETOOTH_CONNECT permission is missing or denied'),
      );
      expect(source, contains('location permission/service may be required'));
      expect(source, contains('Nearby devices/Bluetooth permissions'));
      expect(
        source,
        contains("_classifyBleError(e, fallback: 'Scan failed or timed out')"),
      );
      expect(
        source,
        contains("_classifyBleError(e, fallback: 'Connect failed')"),
      );
      expect(source, contains("_classifyBleError(e, fallback: 'TX failed')"));
    },
  );

  test('BLE scan and connect request Android runtime permissions first', () {
    final source = File('lib/providers/ble_provider.dart').readAsStringSync();
    final scanIndex = source.indexOf('Future<List<ScanResult>> scan');
    final connectIndex = source.indexOf('Future<bool> connect');
    final scanSource = source.substring(scanIndex, connectIndex);
    final connectSource = source.substring(connectIndex);

    expect(
      source,
      contains('package:permission_handler/permission_handler.dart'),
    );
    expect(source, contains('Future<bool> _ensureBlePermissions'));
    expect(source, contains('defaultTargetPlatform != TargetPlatform.android'));
    expect(source, contains('Permission.bluetoothScan'));
    expect(source, contains('Permission.bluetoothConnect'));
    expect(source, contains('await permission.request()'));
    expect(
      source,
      contains('Grant Android Nearby devices/Bluetooth permission'),
    );
    expect(scanSource, contains('_ensureBlePermissions(forScan: true)'));
    expect(connectSource, contains('_ensureBlePermissions(forScan: false)'));
  });
}
