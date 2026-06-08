import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main shell pauses offscreen page tickers', () {
    final source = File('lib/pages/main_shell.dart').readAsStringSync();

    expect(source, contains('TickerMode'));
    expect(source, contains('PageStorageKey'));
  });

  test(
    'hot animation previews use custom painters instead of blur-heavy widgets',
    () {
      final colorTab = File('lib/pages/color_tab.dart').readAsStringSync();
      final sliders = File('lib/pages/shared/sliders.dart').readAsStringSync();

      expect(colorTab, contains('CustomPainter'));
      expect(colorTab, contains('RepaintBoundary'));
      expect(sliders, isNot(contains('MaskFilter.blur')));
    },
  );

  test('scene tab uses slivers and scoped provider subscriptions', () {
    final source = File('lib/pages/scene_tab.dart').readAsStringSync();

    expect(source, contains('CustomScrollView'));
    expect(source, contains('SliverGrid'));
    expect(source, contains('deviceProvider.select'));
    expect(source, contains('activeSceneIndex'));
    expect(source, contains('markSceneActive(i)'));
    expect(source, contains('Icons.play_arrow_rounded'));
    expect(source, contains('scale: saved && !active ? 1 : 0'));
    expect(source, isNot(contains('GridView.builder')));
    expect(source, isNot(contains('shrinkWrap: true')));
    expect(source, isNot(contains('final s = ref.watch(deviceProvider)')));
  });

  test('settings keeps diagnostics behind one advanced panel', () {
    final source = File('lib/pages/settings_page.dart').readAsStringSync();

    expect(source, contains('_AdvancedDiagnosticsCard'));
    expect(source, contains('_InlineDebugLog'));
    expect(source, isNot(contains('_DiagnosticsCard(')));
    expect(source, isNot(contains('_DebugLogCard(')));
  });

  test('settings debug log uses a bounded lazy viewport', () {
    final source = File('lib/pages/settings_page.dart').readAsStringSync();

    expect(source, contains('Semantics('));
    expect(source, contains('label: t.debugLogTitle'));
    expect(source, contains('height: 240'));
    expect(source, contains('ListView.builder'));
    expect(source, contains('primary: false'));
    expect(source, contains('itemExtent: 17'));
    expect(source, contains('TextOverflow.ellipsis'));
    expect(source, isNot(contains('shrinkWrap: true')));
  });
}
