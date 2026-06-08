import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_ble_controller/l10n/app_localizations.dart';
import 'package:rgb_ble_controller/models/ble_diagnostics.dart';
import 'package:rgb_ble_controller/pages/settings_page.dart';
import 'package:rgb_ble_controller/providers/ble_provider.dart';
import 'package:rgb_ble_controller/providers/theme_provider.dart';
import 'package:rgb_ble_controller/theme/app_design.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSettingsBleService extends BLEService {
  _FakeSettingsBleService() {
    _log.addAll([
      'TX 10 ff 00 00',
      'RX aa',
      'Scan failed: Android BLUETOOTH_SCAN permission is missing or denied.',
    ]);
  }

  final _connected = ValueNotifier<bool>(false);
  final _logVersion = ValueNotifier<int>(0);
  final _diagnostics = ValueNotifier<BleDiagnostics>(
    BleDiagnostics(
      bleSupported: true,
      adapterState: 'on',
      phase: BleDiagnosticPhase.ready,
      scanCount: 2,
      targetServiceFound: true,
      notifyCharacteristicFound: true,
      notifyEnabled: true,
      writeCharacteristicFound: true,
      lastTxHex: '10 ff 00 00',
      lastRxHex: 'aa',
      updatedAt: DateTime(2026, 6, 7, 22),
    ),
  );
  final _log = <String>[];
  int selfTestCalls = 0;

  @override
  ValueListenable<bool> get isConnected => _connected;

  @override
  ValueListenable<int> get debugLogVersion => _logVersion;

  @override
  ValueListenable<BleDiagnostics> get diagnostics => _diagnostics;

  @override
  List<String> get debugLog => List.unmodifiable(_log);

  @override
  String get deviceName => 'Fake BLE';

  @override
  Future<void> runSelfTest({int seconds = 3}) async {
    selfTestCalls++;
    _log.add('SELF TEST');
    _logVersion.value++;
  }

  @override
  Future<bool> queryStatus() async {
    _log.add('QUERY STATUS');
    _logVersion.value++;
    return true;
  }

  @override
  void clearDebugLog() {
    _log.clear();
    _logVersion.value++;
  }

  @override
  String exportDebugSnapshot() =>
      _diagnostics.value.exportSnapshot(debugLog: _log);

  @override
  void dispose() {
    _connected.dispose();
    _logVersion.dispose();
    _diagnostics.dispose();
    super.dispose();
  }
}

Future<_FakeSettingsBleService> _pumpSettingsPage(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final fakeBle = _FakeSettingsBleService();
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
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const SettingsPage(),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 350));
  return fakeBle;
}

Future<void> _tapTextInSafeArea(WidgetTester tester, String text) async {
  final finder = find.text(text);
  final viewHeight =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;

  for (var i = 0; i < 12; i++) {
    if (tester.any(finder)) {
      final center = tester.getCenter(finder);
      if (center.dy >= 120 && center.dy <= viewHeight - 96) {
        break;
      }
      final dragOffset = center.dy < 120
          ? const Offset(0, 160)
          : const Offset(0, -160);
      await tester.drag(find.byType(ListView).first, dragOffset);
    } else {
      await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    }
    await tester.pump(const Duration(milliseconds: 120));
  }

  await tester.tap(finder);
}

void main() {
  testWidgets('settings diagnostics expand, copy, and clear safely', (
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

    final fakeBle = await _pumpSettingsPage(
      tester,
      size: const Size(320, 780),
      textScale: 1.2,
    );

    expect(find.text('连接诊断'), findsOneWidget);
    expect(find.text('协议'), findsNothing);

    await tester.tap(find.text('连接诊断'));
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('协议'), findsOneWidget);
    expect(find.textContaining('FFF0 OK'), findsOneWidget);
    expect(find.textContaining('TX 10'), findsOneWidget);

    await _tapTextInSafeArea(tester, '复制快照');
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('诊断快照已复制'), findsOneWidget);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    expect(data?.text, contains('protocol_ready=true'));
    expect(data?.text, contains('debug_log:'));

    await _tapTextInSafeArea(tester, '运行诊断');
    await tester.pump();
    expect(fakeBle.selfTestCalls, 1);

    await _tapTextInSafeArea(tester, '清空日志');
    await tester.pump(const Duration(milliseconds: 350));

    expect(fakeBle.debugLog, isEmpty);
    expect(find.textContaining('TX 10'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
