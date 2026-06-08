import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deliverable package gate verifies zip contents and documented hash', () {
    final verifyApp = File('../tools/verify-app.ps1').readAsStringSync();
    final packageScript =
        File('../tools/verify-deliverable-package.ps1').readAsStringSync();

    expect(verifyApp, contains('[switch]\$DeliverablePackage'));
    expect(verifyApp, contains('verify-deliverable-package.ps1'));
    expect(verifyApp, contains('\$DeliverablePackage = \$true'));

    expect(packageScript, contains('Expand-Archive'));
    expect(packageScript, contains('SHA256SUMS.txt'));
    expect(packageScript, contains('Release 附件 SHA256'));
    expect(packageScript, contains('README.md contains unexpected control bytes'));
    expect(packageScript, contains('*.sof'));
    expect(packageScript, contains('*.apk'));
    expect(packageScript, contains('noDeviceEvidence'));
  });
}
