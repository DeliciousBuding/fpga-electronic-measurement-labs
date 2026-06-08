import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AllLocal quality gate composes only no-device checks', () {
    final verifyApp = File('../tools/verify-app.ps1').readAsStringSync();

    expect(verifyApp, contains('[switch]\$AllLocal'));
    expect(verifyApp, contains('if (\$AllLocal)'));
    expect(verifyApp, contains('-AllLocal is a no-device local gate'));
    expect(verifyApp, contains('\$DeviceSmoke -or \$Release'));
    expect(verifyApp, contains('\$WebStatus = \$true'));
    expect(verifyApp, contains('\$WebVisualQA = \$true'));
    expect(verifyApp, contains('\$FpgaSim = \$true'));
    expect(verifyApp, contains('\$QuartusMap = \$true'));
    expect(verifyApp, contains('\$ReportDraft = \$true'));
    expect(verifyApp, contains('\$ApkQuality = \$true'));
  });
}
