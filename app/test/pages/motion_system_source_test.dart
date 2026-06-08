import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app defines a consistent smooth scroll behavior', () {
    final source = File('lib/theme/app_design.dart').readAsStringSync();
    final app = File('lib/main.dart').readAsStringSync();

    expect(source, contains('class SmoothScrollBehavior'));
    expect(source, contains('BouncingScrollPhysics'));
    expect(source, contains('class AppMotion'));
    expect(source, contains('effectPreviewCycle = Duration(seconds: 3)'));
    expect(source, contains('class AppSpacing'));
    expect(source, contains('class AppRadii'));
    expect(source, isNot(contains('GlowingOverscrollIndicator')));
    expect(app, contains('scrollBehavior: const SmoothScrollBehavior()'));
    expect(app, contains('backgroundColor: lightScheme.surface'));
    expect(app, contains('backgroundColor: darkScheme.surface'));
    expect(app, contains('surfaceTintColor: Colors.transparent'));
    expect(app, isNot(contains('surface.withAlpha(220)')));
  });

  test('effect preview animations share one global cycle duration', () {
    final colorTab = File('lib/pages/color_tab.dart').readAsStringSync();
    final effectTab = File('lib/pages/effect_tab.dart').readAsStringSync();

    expect(colorTab, contains('duration: AppMotion.effectPreviewCycle'));
    expect(effectTab, contains('duration: AppMotion.effectPreviewCycle'));
    expect(colorTab, isNot(contains('Duration(seconds: 3)')));
    expect(effectTab, isNot(contains('Duration(seconds: 2)')));
  });

  test('motion helpers respect system reduced-animation preference', () {
    final design = File('lib/theme/app_design.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final shell = File('lib/pages/main_shell.dart').readAsStringSync();

    expect(design, contains('static bool reduced(BuildContext context)'));
    expect(design, contains('MediaQuery.disableAnimationsOf(context)'));
    expect(design, contains('static Duration duration('));
    expect(design, contains('static Curve curve('));
    expect(main, contains('AppMotion.duration('));
    expect(main, contains('AppMotion.curve('));
    expect(shell, contains('AppMotion.duration('));
    expect(shell, contains('AppMotion.curve('));
  });

  test('major implicit animations use context-aware motion tokens', () {
    final files = [
      'lib/pages/color_tab.dart',
      'lib/pages/effect_tab.dart',
      'lib/pages/scene_tab.dart',
      'lib/pages/settings_page.dart',
      'lib/pages/scanner_page.dart',
      'lib/pages/shared/ble_widgets.dart',
      'lib/pages/shared/scanner_widgets.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source, contains('AppMotion.duration('), reason: path);
      expect(source, contains('AppMotion.curve('), reason: path);
      expect(source, isNot(contains('duration: AppMotion.fast')), reason: path);
      expect(
        source,
        isNot(contains('duration: AppMotion.normal')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('switchInCurve: AppMotion.emphasized')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('switchOutCurve: AppMotion.standard')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('curve: AppMotion.standard')),
        reason: path,
      );
    }
  });

  test('BLE gate starts motion-aware initialization after first frame', () {
    final main = File('lib/main.dart').readAsStringSync();

    expect(main, contains('WidgetsBinding.instance.addPostFrameCallback'));
    expect(main, isNot(contains('    _initBLE();')));
  });

  test('connection banner avoids layout-size animation during scroll', () {
    final source = File('lib/pages/shared/ble_widgets.dart').readAsStringSync();

    expect(source, isNot(contains('AnimatedSize')));
    expect(source, contains('AnimatedSwitcher'));
  });

  test('preset color swatches keep stable dimensions', () {
    final source = File('lib/pages/color_tab.dart').readAsStringSync();

    expect(source, isNot(contains('width: active ? 36 : 32')));
    expect(source, isNot(contains('height: active ? 36 : 32')));
    expect(source, isNot(contains('child: AnimatedScale(')));
    expect(source, isNot(contains('child: AnimatedOpacity(')));
  });

  test('LED strip preview uses fixed grid spacing without dot overlap', () {
    final source = File('lib/pages/color_tab.dart').readAsStringSync();

    expect(source, contains('static const double previewHeight = 132'));
    expect(source, contains('static const int _columns = 4'));
    expect(source, contains('static const int _rows = 2'));
    expect(source, contains('static const double _preferredDotGap = 20'));
    expect(source, contains('static const double _maxDotRadius = 22'));
    expect(source, contains('static const double _fallbackDotRadius = 1'));
    expect(source, contains('computeLedStripDotLayout(size)'));
    expect(source, contains('List<LedStripDotLayout>'));
    expect(source, contains('final cellWidth = usableWidth / columns'));
    expect(source, contains('final cellHeight = usableHeight / rows'));
    expect(source, contains('final safeRadius = math.min'));
    expect(
      source,
      contains('math.max(_LedStripPainter._fallbackDotRadius, safeRadius)'),
    );
    expect(source, contains('final glowOutset = math.min'));
    expect(source, contains('cellWidth * (col + 0.5)'));
    expect(source, contains('SingleChildScrollView'));
    expect(source, contains('scrollDirection: Axis.horizontal'));
    expect(source, isNot(contains('clamp(10.0, _maxDotRadius)')));
    expect(source, isNot(contains('clamp(_minDotRadius, _maxDotRadius)')));
    expect(source, isNot(contains('radius * 2 + gapY')));
    expect(source, isNot(contains('size.height * 0.28')));
    expect(source, isNot(contains('size.height * 0.72')));
  });

  test('bottom navigation is icon-only without Material pill labels', () {
    final source = File('lib/pages/main_shell.dart').readAsStringSync();

    expect(source, contains('_IconBottomBar'));
    expect(source, contains('GestureDetector'));
    expect(source, contains('Tooltip('));
    expect(source, contains('Semantics('));
    expect(source, contains('button: true'));
    expect(source, contains('selected: selected'));
    expect(source, contains('onTap: onTap'));
    expect(source, contains('FocusableActionDetector'));
    expect(source, contains('ActivateIntent'));
    expect(source, contains('ExcludeSemantics'));
    expect(source, contains('SystemMouseCursors.click'));
    expect(source, isNot(contains('NavigationBar(')));
    expect(source, isNot(contains('NavigationDestination(')));
    expect(source, isNot(contains('InkResponse(')));
  });

  test('main shell hides and restores bottom bar from scroll thresholds', () {
    final source = File('lib/pages/main_shell.dart').readAsStringSync();

    expect(source, contains('NotificationListener<ScrollNotification>'));
    expect(source, contains('_handleScrollNotification'));
    expect(source, contains('_hideScrollThreshold = 36'));
    expect(source, contains('_showScrollThreshold = 18'));
    expect(source, contains('_topRevealExtent = 6'));
    expect(source, contains('notification.metrics.axis != Axis.vertical'));
    expect(source, contains('ScrollUpdateNotification'));
    expect(source, contains('ScrollEndNotification'));
    expect(source, contains('notification.scrollDelta'));
    expect(source, contains('notification.metrics.pixels'));
    expect(source, contains('notification.metrics.minScrollExtent'));
    expect(source, contains('_barScrollAccumulator'));
    expect(source, contains('bar.hide()'));
    expect(source, contains('bar.show()'));
    expect(source, contains('_showBarIfHidden()'));
    expect(source, contains('ref.read(barVisibilityProvider) != 1.0'));
    expect(source, contains('hideBarOnScroll'));
    expect(source, contains('AnimatedSlide'));
    expect(source, contains('AnimatedOpacity'));
    expect(source, contains('IgnorePointer'));
    expect(source, contains('RepaintBoundary'));
    expect(source, contains('AppMotion.normal'));
    expect(source, isNot(contains('heightFactor: visibility')));
  });
}
