import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('field evidence verifier tracks final hardware submission evidence', () {
    final verifyApp = File('../tools/verify-app.ps1').readAsStringSync();
    final verifier = File('../tools/verify-field-evidence.ps1').readAsStringSync();

    expect(verifyApp, contains('[switch]\$FieldEvidence'));
    expect(verifyApp, contains('[switch]\$RequireFieldEvidence'));
    expect(verifyApp, contains('verify-field-evidence.ps1'));
    expect(verifyApp, contains('field evidence status'));

    expect(verifier, contains('01-ble-scan'));
    expect(verifier, contains('02-ble-connect'));
    expect(verifier, contains('03-led-effects'));
    expect(verifier, contains('04-serial-log'));
    expect(verifier, contains('05-waveform'));
    expect(verifier, contains('06-cover-info'));
    expect(verifier, contains('field-evidence-status.json'));
    expect(verifier, contains('RequireComplete'));
    expect(verifier, contains('minFiles = 3'));
    expect(verifier, contains('Field evidence is incomplete'));
  });
}
