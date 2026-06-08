import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BLE scan matcher prioritizes only specific target signals', () {
    final source = File('lib/utils/ble_scan_matcher.dart').readAsStringSync();

    expect(source, contains("name.contains('ch9143')"));
    expect(source, contains("name.contains('rgb')"));
    expect(source, contains("name.contains('uart')"));
    expect(source, contains("services.contains('fff0')"));
    expect(source, contains('compareScanResultsForTarget'));
    expect(source, contains('b.rssi.compareTo(a.rssi)'));
    expect(source, isNot(contains("name.contains('ble')")));
    expect(source, isNot(contains("name.contains('bt')")));
  });
}
