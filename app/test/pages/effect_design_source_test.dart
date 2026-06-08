import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('effect tab uses a compact mode selector with one preview panel', () {
    final source = File('lib/pages/effect_tab.dart').readAsStringSync();

    expect(source, contains('_EffectModeSelector'));
    expect(source, contains('_EffectPreviewPanel'));
    expect(source, isNot(contains('for (final e in effects)')));
  });

  test('music mode is presented as disabled WIP instead of a fake control', () {
    final source = File('lib/pages/effect_tab.dart').readAsStringSync();

    expect(source, contains('t.modeMusic'));
    expect(source, contains('wip: true'));
    expect(
      source,
      contains('onTap: effect.wip ? null : () => onSelect(effect)'),
    );
    expect(source, contains('if (effect.wip || effect.mode == activeMode)'));
    expect(source, contains('enabled: !def.wip'));
    expect(
      source,
      contains("label: def.wip ? '\${def.name}, \$wipLabel' : def.name"),
    );
    expect(source, isNot(contains('setMode(4)')));
    expect(source, isNot(contains('ble.setMode(4)')));
  });
}
