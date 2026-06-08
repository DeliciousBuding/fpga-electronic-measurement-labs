import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('report draft verification is wired into the local quality gate', () {
    final verifyApp = File('../tools/verify-app.ps1').readAsStringSync();
    final reportScript = File('../tools/verify-report-draft.ps1').readAsStringSync();

    expect(verifyApp, contains('[switch]\$ReportDraft'));
    expect(verifyApp, contains('verify-report-draft.ps1'));
    expect(verifyApp, contains('report draft verification'));

    expect(reportScript, contains('Find-ReportMarkdown'));
    expect(reportScript, contains('*RGB*.md'));
    expect(reportScript, contains('WebVisualQA'));
    expect(reportScript, contains('CH9143 RGB Controller'));
    expect(reportScript, contains('ADB'));
    expect(reportScript, contains('APK'));
    expect(reportScript, contains('BLE'));
    expect(reportScript, contains('SignalTap'));
    expect(reportScript, contains('word/media/*'));
    expect(reportScript, contains('pdftotext'));
    expect(reportScript, contains('pdfinfo'));
    expect(reportScript, contains('pandoc'));
    expect(reportScript, contains('LastWriteTime -lt \$markdownFile.LastWriteTime'));
  });
}
