import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_ble_controller/l10n/app_localizations.dart';
import 'package:rgb_ble_controller/models/ble_diagnostics.dart';
import 'package:rgb_ble_controller/pages/scanner_page.dart';
import 'package:rgb_ble_controller/pages/shared/scanner_widgets.dart';
import 'package:rgb_ble_controller/providers/ble_provider.dart';
import 'package:rgb_ble_controller/providers/theme_provider.dart';
import 'package:rgb_ble_controller/theme/app_design.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBleService extends BLEService {
  _FakeBleService();

  final diagnosticsNotifier = ValueNotifier<BleDiagnostics>(
    const BleDiagnostics(),
  );
  int scanCalls = 0;

  @override
  ValueListenable<BleDiagnostics> get diagnostics => diagnosticsNotifier;

  @override
  Future<List<ScanResult>> scan({int seconds = 5}) async {
    scanCalls++;
    diagnosticsNotifier.value = BleDiagnostics(
      phase: BleDiagnosticPhase.failed,
      scanInProgress: false,
      scanCount: 0,
      targetServiceFound: true,
      notifyCharacteristicFound: true,
      writeCharacteristicFound: false,
      notifyEnabled: false,
      lastError:
          'Scan failed: Android BLUETOOTH_SCAN permission is missing or denied.',
      updatedAt: DateTime(2026, 6, 7, 20),
    );
    return const [];
  }

  @override
  String exportDebugSnapshot() =>
      'fake diagnostic snapshot\nlast_error=${diagnosticsNotifier.value.failureSummary}';

  @override
  void dispose() {
    diagnosticsNotifier.dispose();
    super.dispose();
  }
}

Future<_FakeBleService> _pumpScannerPage(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final fakeBle = _FakeBleService();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      bleServiceProvider.overrideWithValue(fakeBle),
    ],
  );
  addTearDown(container.dispose);

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SmoothScrollBehavior(),
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF8B5CF6),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: ScannerPage(
          adapterStateStream: const Stream.empty(),
          readInitialAdapterState: () async => BluetoothAdapterState.on,
          autoScanOnAdapterOn: false,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 350));
  return fakeBle;
}

void main() {
  test('scanner page uses a ticker provider that supports both animations', () {
    final source = File('lib/pages/scanner_page.dart').readAsStringSync();

    expect(source, contains('TickerProviderStateMixin'));
    expect(source, isNot(contains('SingleTickerProviderStateMixin')));
  });

  test(
    'scanner page exposes inline diagnostics and copyable debug snapshot',
    () {
      final source = File('lib/pages/scanner_page.dart').readAsStringSync();

      expect(source, contains('_ScanDiagnosticsPanel'));
      expect(source, contains('ValueListenableBuilder<BleDiagnostics>'));
      expect(source, contains('ble.diagnostics'));
      expect(source, contains('ble.exportDebugSnapshot()'));
      expect(source, contains('diagnostics.failureSummary'));
      expect(source, contains('forceVisible'));
      expect(source, contains('_scanCompleted'));
      expect(source, contains('diagnostics.scanInProgress'));
      expect(source, contains('t.diagnosticsScanCount'));
    },
  );

  test('scanner header animations are gated by active scanning state', () {
    final scannerPage = File('lib/pages/scanner_page.dart').readAsStringSync();
    final scannerWidgets = File(
      'lib/pages/shared/scanner_widgets.dart',
    ).readAsStringSync();

    expect(scannerPage, contains('_setScanning(true)'));
    expect(scannerPage, contains('_setScanning(false)'));
    expect(scannerPage, contains('ScannerHeader('));
    expect(scannerPage, contains('active: _scanning'));
    expect(scannerWidgets, contains('final bool active'));
    expect(scannerWidgets, contains('if (active)'));
    expect(scannerWidgets, isNot(contains(')..repeat(')));
  });

  test('scanner device tiles highlight likely RGB BLE targets', () {
    final source = File(
      'lib/pages/shared/scanner_widgets.dart',
    ).readAsStringSync();

    expect(source, contains('scanResultLooksLikeTarget'));
    expect(source, contains('likelyTarget'));
    expect(source, contains('CH9143 / FFF0'));
    expect(source, contains("'RGB'"));
    expect(source, contains('cs.primaryContainer.withAlpha(90)'));
  });

  test('scanner page exposes debug sample devices for browser visual QA', () {
    final scannerPage = File('lib/pages/scanner_page.dart').readAsStringSync();
    final scannerWidgets = File(
      'lib/pages/shared/scanner_widgets.dart',
    ).readAsStringSync();

    expect(scannerPage, contains('this.autoScanOnAdapterOn = !kIsWeb'));
    expect(scannerPage, contains('kDebugMode'));
    expect(scannerPage, contains('visualQa'));
    expect(scannerPage, contains("Uri.base.queryParameters['visualQa']"));
    expect(scannerPage, contains('_debugScanDevices'));
    expect(scannerPage, contains('_showDebugDevices'));
    expect(scannerPage, contains('Icons.science_rounded'));
    expect(scannerPage, contains('CH9143 RGB Controller'));
    expect(scannerPage, contains('Debug sample only'));
    expect(scannerWidgets, contains('class ScanDeviceViewData'));
    expect(
      scannerWidgets,
      contains('factory ScanDeviceViewData.fromScanResult'),
    );
  });

  test('Bluetooth turn-on action is disabled on Flutter Web', () {
    final scannerWidgets = File(
      'lib/pages/shared/scanner_widgets.dart',
    ).readAsStringSync();

    expect(
      scannerWidgets,
      contains("import 'package:flutter/foundation.dart'"),
    );
    expect(
      scannerWidgets,
      contains('onPressed: kIsWeb ? null : () => FlutterBluePlus.turnOn()'),
    );
  });

  testWidgets('scanner device tile handles long names on narrow screens', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(280, 640),
            textScaler: TextScaler.linear(1.25),
          ),
          child: Scaffold(
            body: SizedBox(
              width: 280,
              child: ScanDeviceTile(
                device: const ScanDeviceViewData(
                  name:
                      'CH9143 RGB Controller With An Extremely Long Broadcast Name',
                  id: 'AA:BB:CC:DD:EE:FF-very-long-platform-remote-id',
                  rssi: -48,
                  likelyTarget: true,
                ),
                loading: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('CH9143 RGB'), findsOneWidget);
  });

  testWidgets('scanner page renders failed diagnostics and copies snapshot', (
    tester,
  ) async {
    String? clipboardText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final data = Map<String, dynamic>.from(call.arguments as Map);
            clipboardText = data['text'] as String?;
            return null;
          }
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': clipboardText};
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    final fakeBle = await _pumpScannerPage(tester);

    expect(find.text('连接诊断'), findsNothing);

    await tester.tap(find.text('重新扫描'));
    await tester.pumpAndSettle();

    expect(fakeBle.scanCalls, 1);
    expect(find.text('连接诊断'), findsOneWidget);
    expect(find.text('阶段'), findsOneWidget);
    expect(find.text('失败'), findsOneWidget);
    expect(find.text('扫描'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('协议'), findsOneWidget);
    expect(find.textContaining('FFF0 OK'), findsOneWidget);
    expect(find.text('错误'), findsOneWidget);
    expect(find.textContaining('BLUETOOTH_SCAN'), findsOneWidget);

    await tester.tap(find.text('复制快照'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('诊断快照已复制'), findsOneWidget);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    expect(data?.text, contains('fake diagnostic snapshot'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('scanner debug samples render likely target highlight safely', (
    tester,
  ) async {
    await _pumpScannerPage(tester, size: const Size(320, 780));

    await tester.tap(find.byIcon(Icons.science_rounded));
    await tester.pumpAndSettle();

    expect(find.text('CH9143 RGB Controller'), findsOneWidget);
    expect(find.text('UART-FFF0-LED'), findsOneWidget);
    expect(find.text('RGB'), findsNWidgets(2));

    await tester.tap(find.text('CH9143 RGB Controller'));
    await tester.pumpAndSettle();

    expect(find.textContaining('调试样例'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
