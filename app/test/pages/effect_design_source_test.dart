import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('effect tab uses a compact mode selector with one preview panel', () {
    final source = File('lib/pages/effect_tab.dart').readAsStringSync();

    expect(source, contains('_EffectModeSelector'));
    expect(source, contains('_EffectPreviewPanel'));
    expect(source, isNot(contains('for (final e in effects)')));
  });

  test('music mode is a real audio-following control', () {
    final source = File('lib/pages/effect_tab.dart').readAsStringSync();

    expect(source, contains('t.modeMusic'));
    expect(source, contains('audioLevelServiceProvider'));
    expect(source, contains('setMusicLevelThrottled'));
    expect(source, isNot(contains('wip: true')));
    expect(source, isNot(contains('effect.wip ? null')));
  });
}
