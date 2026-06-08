import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web visual QA covers scanner entry and debug sample states', () {
    final qaScript = File('../tools/web-visual-qa.ps1').readAsStringSync();
    final captureScript = File(
      '../tools/web-visual-qa-capture.mjs',
    ).readAsStringSync();

    expect(qaScript, contains('mobile-390-scanner'));
    expect(qaScript, contains('mobile-390-scanner-debug'));
    expect(qaScript, contains('mobile-390-scroll-return'));
    expect(qaScript, contains('[int]\$WaitMs = 18000'));
    expect(qaScript, contains('TapSequence'));
    expect(qaScript, contains('ScrollSequence'));
    expect(qaScript, contains('--tap-sequence'));
    expect(qaScript, contains('--scroll-sequence'));
    expect(qaScript, contains('Test-WebPerfMetrics'));
    expect(qaScript, contains('--metrics-out'));
    expect(qaScript, contains('.perf.json'));
    expect(qaScript, contains('avgFrameMs='));
    expect(qaScript, contains('Test-PngSimilar'));
    expect(qaScript, contains('resolvedOutDir'));
    expect(qaScript, contains(r'Join-Path $resolvedOutDir'));
    expect(captureScript, contains('metricsOut'));
    expect(captureScript, contains('Performance.enable'));
    expect(captureScript, contains('Performance.getMetrics'));
    expect(captureScript, contains('measureFrameCadence'));
    expect(captureScript, contains('requestAnimationFrame(step)'));
    expect(captureScript, contains('tapSequence'));
    expect(captureScript, contains('scrollSequence'));
    expect(captureScript, contains('Invalid --tap-sequence item'));
    expect(captureScript, contains('Invalid --scroll-sequence item'));
  });
}
