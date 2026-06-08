import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('color tab avoids whole-page device provider rebuilds', () {
    final source = File('lib/pages/color_tab.dart').readAsStringSync();

    expect(source, isNot(contains('final s = ref.watch(deviceProvider)')));
    expect(source, contains('deviceProvider.select((s) =>'));
  });
}
