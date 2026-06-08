import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('report draft verification is wired into the local quality gate', () {
    final verifyApp = File('../tools/verify-app.ps1').readAsStringSync();
    final reportScript = File('../tools/verify-report-draft.ps1').readAsStringSync();

    expect(verifyApp, contains('[switch]\$ReportDraft'));
    expect(verifyApp, contains('verify-report-draft.ps1'));
    expect(verifyApp, contains('report draft verification'));

    expect(reportScript, contains('[string]\$TexFile'));
    expect(reportScript, contains('*RGB*TeX*.tex'));
    expect(reportScript, contains('xelatex'));
    expect(reportScript, contains('hardware-photo-overview-v4.png'));
    expect(reportScript, contains('hardware-photo-ledmap-v4.png'));
    expect(reportScript, contains('Assert-PortraitImage'));
    expect(reportScript, contains('PDF page count must be 1-6 pages'));
    expect(reportScript, contains('Assert-TextNotMatches'));
    expect(reportScript, contains('C301'));
    expect(reportScript, contains('CH9143'));
    expect(reportScript, contains('WS2812'));
    expect(reportScript, contains('APK'));
    expect(reportScript, contains('SOF'));
    expect(reportScript, contains('pdftotext'));
    expect(reportScript, contains('pdfinfo'));
    expect(reportScript, isNot(contains('Find-ReportMarkdown')));
    expect(reportScript, isNot(contains('pandoc')));
    expect(reportScript, isNot(contains('word/media/*')));
  });
}
