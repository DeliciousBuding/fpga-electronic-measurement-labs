import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_ble_controller/l10n/app_localizations.dart';
import 'package:rgb_ble_controller/pages/effect_tab.dart';
import 'package:rgb_ble_controller/pages/main_shell.dart';
import 'package:rgb_ble_controller/pages/scene_tab.dart';
import 'package:rgb_ble_controller/providers/device_provider.dart';
import 'package:rgb_ble_controller/providers/preferences_provider.dart';
import 'package:rgb_ble_controller/providers/theme_provider.dart';
import 'package:rgb_ble_controller/services/audio_level_service.dart';
import 'package:rgb_ble_controller/theme/app_design.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _pumpPage(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
  Map<String, Object> prefs = const {},
  AudioLevelService? audioLevelService,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPrefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      if (audioLevelService != null)
        audioLevelServiceProvider.overrideWithValue(audioLevelService),
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
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            color: const Color(0xFF151A18),
            margin: EdgeInsets.zero,
          ),
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 350));
  return container;
}

void main() {
  testWidgets('main shell bottom bar stays icon-only at mobile width', (
    tester,
  ) async {
    await _pumpPage(tester, const MainShell());

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationDestination), findsNothing);
    final tooltips = tester.widgetList<Tooltip>(find.byType(Tooltip));
    final navTooltipMessages = tooltips
        .map((tooltip) => tooltip.message)
        .where((message) => ['LED', '灯效', '情景', '设置'].contains(message))
        .toList(growable: false);
    expect(navTooltipMessages, hasLength(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('main shell hides and restores bottom bar from real scroll', (
    tester,
  ) async {
    final container = await _pumpPage(tester, const MainShell());

    expect(container.read(barVisibilityProvider), 1.0);

    await tester.dragFrom(const Offset(220, 520), const Offset(0, -16));
    await tester.pump();

    expect(container.read(barVisibilityProvider), 1.0);

    await tester.dragFrom(const Offset(220, 520), const Offset(0, -320));
    await tester.pump();

    expect(container.read(barVisibilityProvider), 0.0);
    expect(find.byType(AnimatedSlide), findsOneWidget);
    expect(find.byType(AnimatedOpacity), findsAtLeastNWidgets(1));
    await tester.pumpAndSettle();

    await tester.dragFrom(const Offset(220, 360), const Offset(0, 220));
    await tester.pump();

    expect(container.read(barVisibilityProvider), 1.0);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('effect tab enables music mode without layout overflow', (
    tester,
  ) async {
    final container = await _pumpPage(
      tester,
      const EffectTab(),
      size: const Size(320, 780),
      textScale: 1.25,
      audioLevelService: _FakeAudioLevelService(),
    );

    expect(find.text('音乐'), findsOneWidget);

    await tester.tap(find.text('音乐'));
    await tester.pumpAndSettle();

    expect(container.read(deviceProvider).mode, 4);
    expect(find.text('音乐跟随'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scene grid renders eight scenes safely on narrow screens', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      const SceneTab(),
      size: const Size(320, 780),
      textScale: 1.2,
      prefs: const {
        'device_scene_saved': ['1', '1', '1', '1', '1', '1', '1', '1'],
      },
    );

    expect(find.byType(SceneTab), findsOneWidget);
    expect(find.text('日暮'), findsOneWidget);
    expect(find.text('极光'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('电光'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeAudioLevelService extends AudioLevelService {
  @override
  Future<bool> ensurePermission() async => true;

  @override
  Stream<int> watchLevels() => Stream<int>.value(128);
}
