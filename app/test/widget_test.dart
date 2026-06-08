import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_ble_controller/l10n/app_localizations.dart';
import 'package:rgb_ble_controller/pages/color_tab.dart';
import 'package:rgb_ble_controller/providers/theme_provider.dart';
import 'package:rgb_ble_controller/theme/app_design.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpColorTab(
  WidgetTester tester, {
  Size size = const Size(280, 800),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
        home: const ColorTab(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets('Color tab does not overflow at a narrow phone width', (
    tester,
  ) async {
    await _pumpColorTab(tester);

    expect(find.byType(ColorTab), findsOneWidget);
    expect(find.text('#FF0000'), findsOneWidget);
    expect(find.text('连接'), findsOneWidget);

    final exception = tester.takeException();
    expect(exception, isNull);
  });

  test('LED preview layout keeps eight dots separated at narrow widths', () {
    for (final size in [
      const Size(160, 132),
      const Size(216, 132),
      const Size(360, 132),
    ]) {
      final dots = computeLedStripDotLayout(size);
      expect(dots, hasLength(8), reason: '$size');
      for (final dot in dots) {
        expect(dot.radius, greaterThan(0), reason: '$size');
        expect(dot.center.dx - dot.radius, greaterThanOrEqualTo(0));
        expect(dot.center.dx + dot.radius, lessThanOrEqualTo(size.width));
        expect(dot.center.dy - dot.radius, greaterThanOrEqualTo(0));
        expect(dot.center.dy + dot.radius, lessThanOrEqualTo(size.height));
      }
      for (var i = 0; i < dots.length; i++) {
        for (var j = i + 1; j < dots.length; j++) {
          final distance = (dots[i].center - dots[j].center).distance;
          final minDistance =
              dots[i].radius +
              dots[j].radius +
              math.max(dots[i].glowOutset, dots[j].glowOutset);
          expect(distance, greaterThan(minDistance), reason: '$size $i/$j');
        }
      }
    }
  });

  test('LED preview follows physical 4321 over 5678 layout', () {
    final dots = computeLedStripDotLayout(const Size(360, 132));

    expect(ledPhysicalLayoutOrder, [3, 2, 1, 0, 4, 5, 6, 7]);
    expect(dots.map((dot) => dot.ledIndex), [3, 2, 1, 0, 4, 5, 6, 7]);

    for (var i = 1; i < 4; i++) {
      expect(dots[i].center.dx, greaterThan(dots[i - 1].center.dx));
      expect(dots[i].center.dy, dots[0].center.dy);
    }
    for (var i = 5; i < 8; i++) {
      expect(dots[i].center.dx, greaterThan(dots[i - 1].center.dx));
      expect(dots[i].center.dy, dots[4].center.dy);
    }
    expect(dots[4].center.dy, greaterThan(dots[0].center.dy));
  });
}
