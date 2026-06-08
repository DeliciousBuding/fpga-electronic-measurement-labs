import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android APK quality gate checks release size and debug leakage', () {
    final verifyApp = File('../tools/verify-app.ps1').readAsStringSync();
    final apkScript = File('../tools/verify-android-apk.ps1').readAsStringSync();

    expect(verifyApp, contains('[switch]\$ApkQuality'));
    expect(verifyApp, contains('verify-android-apk.ps1'));
    expect(verifyApp, contains('Convert-TargetPlatformToAbi'));
    expect(verifyApp, contains('Android APK quality verification'));

    expect(apkScript, contains('MaxReleaseApkMb = 35'));
    expect(apkScript, contains('aapt dump badging'));
    expect(apkScript, contains('versionCode'));
    expect(apkScript, contains('versionName'));
    expect(apkScript, contains('kernel_blob.bin'));
    expect(apkScript, contains('vm_snapshot_data'));
    expect(apkScript, contains('isolate_snapshot_data'));
    expect(apkScript, contains('libapp.so'));
    expect(apkScript, contains('libflutter.so'));
    expect(apkScript, contains('CH9143 RGB Controller'));
    expect(apkScript, contains('UART-FFF0-LED'));
    expect(apkScript, contains('Debug sample only'));
    expect(apkScript, contains('Load debug samples'));
  });
}
