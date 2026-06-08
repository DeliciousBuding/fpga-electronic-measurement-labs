import 'package:flutter_blue_plus/flutter_blue_plus.dart';

String scanResultDisplayName(ScanResult result) {
  final advName = result.advertisementData.advName;
  if (advName.isNotEmpty) return advName;
  final platformName = result.device.platformName;
  if (platformName.isNotEmpty) return platformName;
  return result.device.remoteId.str;
}

bool scanResultLooksLikeTarget(ScanResult result) {
  final name =
      '${result.advertisementData.advName} ${result.device.platformName}'
          .toLowerCase();
  final services = result.advertisementData.serviceUuids
      .map((uuid) => uuid.toString().toLowerCase())
      .join(' ');
  return name.contains('ch9143') ||
      name.contains('rgb') ||
      name.contains('uart') ||
      services.contains('fff0');
}

int compareScanResultsForTarget(ScanResult a, ScanResult b) {
  final aTarget = scanResultLooksLikeTarget(a);
  final bTarget = scanResultLooksLikeTarget(b);
  if (aTarget != bTarget) return aTarget ? -1 : 1;
  return b.rssi.compareTo(a.rssi);
}
