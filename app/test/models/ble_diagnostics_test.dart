import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_ble_controller/models/ble_diagnostics.dart';

void main() {
  group('BleDiagnostics', () {
    test(
      'reports readiness only when service, notify, and write are found',
      () {
        const missingWrite = BleDiagnostics(
          targetServiceFound: true,
          notifyCharacteristicFound: true,
          writeCharacteristicFound: false,
        );

        expect(missingWrite.isProtocolReady, isFalse);

        final ready = missingWrite.copyWith(writeCharacteristicFound: true);

        expect(ready.isProtocolReady, isTrue);
      },
    );

    test('keeps phase labels and classifies connection errors', () {
      const diagnostics = BleDiagnostics(
        phase: BleDiagnosticPhase.discoveringServices,
        lastError: 'FFF0 service missing',
      );

      expect(diagnostics.phaseLabelZh, '发现服务');
      expect(diagnostics.phaseLabelEn, 'Discovering services');
      expect(diagnostics.failureSummary, 'FFF0 service missing');
    });

    test('exports a field debug snapshot with target UUIDs and traffic', () {
      final diagnostics = BleDiagnostics(
        bleSupported: true,
        adapterState: 'on',
        scanCount: 3,
        selectedDeviceName: 'CH9143',
        selectedDeviceId: 'AA:BB',
        targetServiceFound: true,
        notifyCharacteristicFound: true,
        writeCharacteristicFound: true,
        lastTxHex: 'ff',
        lastRxHex: '01 02 03 04 64',
        lastError: 'status timeout',
        updatedAt: DateTime(2026, 6, 6, 18, 30),
      );

      final snapshot = diagnostics.exportSnapshot();

      expect(snapshot, contains('phase=idle'));
      expect(snapshot, contains('target=FFF0/FFF1/FFF2'));
      expect(snapshot, contains('device=CH9143 (AA:BB)'));
      expect(snapshot, contains('last_tx=ff'));
      expect(snapshot, contains('last_rx=01 02 03 04 64'));
      expect(snapshot, contains('last_error=status timeout'));
    });
  });
}
