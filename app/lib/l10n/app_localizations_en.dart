// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'RGB Controller';

  @override
  String get navLed => 'LED';

  @override
  String get navEffect => 'Effects';

  @override
  String get navScene => 'Scenes';

  @override
  String get navSettings => 'Settings';

  @override
  String get ledStrip => 'LED Strip';

  @override
  String get brightness => 'Brightness';

  @override
  String brightnessPercent(int pct) {
    return '$pct%';
  }

  @override
  String get modeStatic => 'Static';

  @override
  String get modeBreath => 'Breath';

  @override
  String get modeFlow => 'Flow';

  @override
  String get modeGradient => 'Gradient';

  @override
  String get modeMusic => 'Music';

  @override
  String get descStatic => 'Solid color always on';

  @override
  String get descBreath => 'Sine envelope brightness cycle';

  @override
  String get descFlow => 'Light moves position by position';

  @override
  String get descGradient => 'HSV hue smooth transition';

  @override
  String get descMusic => 'FFT linked (not implemented)';

  @override
  String get wip => 'WIP';

  @override
  String get flowSpeed => 'Flow Speed';

  @override
  String get gradientSpeed => 'Gradient Speed';

  @override
  String get breathPeriod => 'Breath Period';

  @override
  String get presetColors => 'Preset Colors';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get actionPowerOff => 'Off';

  @override
  String get actionFullWhite => 'White';

  @override
  String get actionRandom => 'Random';

  @override
  String get actionWarmLight => 'Warm';

  @override
  String get actionCoolLight => 'Cool';

  @override
  String get actionRainbow => 'Rainbow';

  @override
  String copyHexTooltip(String hex) {
    return 'Tap to copy $hex';
  }

  @override
  String hexCopied(String hex) {
    return 'Copied $hex';
  }

  @override
  String get bleNotConnected => 'No BLE device connected';

  @override
  String get bleConnect => 'Connect';

  @override
  String bleTooltipConnected(String name) {
    return 'Connected to $name — long press to refresh';
  }

  @override
  String get bleTooltipDisconnected => 'Not connected — tap to scan';

  @override
  String get bleRefreshing => 'Refreshing FPGA status…';

  @override
  String get bleCmdFailed => 'Command failed (0xEE)';

  @override
  String bleConnected(String name) {
    return 'Connected to $name';
  }

  @override
  String get sceneTitle => 'Scene Modes';

  @override
  String get sceneHint => 'Tap to load · Long press to save';

  @override
  String sceneSaved(String name) {
    return 'Saved「$name」';
  }

  @override
  String get sceneSunset => 'Sunset';

  @override
  String get sceneAurora => 'Aurora';

  @override
  String get sceneNeon => 'Neon';

  @override
  String get sceneFlame => 'Flame';

  @override
  String get sceneForest => 'Forest';

  @override
  String get sceneOcean => 'Ocean';

  @override
  String get sceneWarmSun => 'Warm Sun';

  @override
  String get sceneLightning => 'Lightning';

  @override
  String get scanTitle => 'Scan BLE Devices';

  @override
  String get scanHint => 'Make sure CH9143 BLE module is powered on';

  @override
  String get scanScanning => 'Scanning…';

  @override
  String get scanScanningBtn => 'Scanning…';

  @override
  String get scanRescan => 'Rescan';

  @override
  String get scanNoDevice => 'No devices found';

  @override
  String get scanRetryHint => 'Tap the button below to scan again';

  @override
  String get scanConnectFail => 'Connection failed, please retry';

  @override
  String get bleOffTitle => 'Bluetooth is off';

  @override
  String get bleOffHint => 'Please turn on Bluetooth in system settings';

  @override
  String get bleTurnOn => 'Turn on Bluetooth';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLangZh => 'Chinese';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsBluetooth => 'Bluetooth';

  @override
  String get settingsAbout => 'About';

  @override
  String get bleStatusConnected => 'Connected';

  @override
  String get bleStatusOffline => 'Offline';

  @override
  String get bleStatusDetailConnected =>
      'Connected · Long press BT icon to refresh';

  @override
  String get bleStatusDetailDisconnected => 'Tap BT icon to scan devices';

  @override
  String get aboutAppName => 'RGB LED Bluetooth Controller';

  @override
  String get aboutVersion => 'v0.1 · Hunan Univ · Engineering Training Center';

  @override
  String get aboutDesc =>
      'CH9143 BLE + FPGA Cyclone IV E controlling WS2812 RGB LED strip';

  @override
  String get debugLogTitle => 'BLE Debug Log';

  @override
  String debugLogCount(int count) {
    return '$count entries';
  }

  @override
  String get debugLogEmpty => 'No logs yet';

  @override
  String get bleNotSupported => 'BLE not supported';

  @override
  String get colorRed => 'Red';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorYellow => 'Yellow';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorCyan => 'Cyan';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorPurple => 'Purple';

  @override
  String get colorPink => 'Pink';

  @override
  String get colorWhite => 'White';

  @override
  String get colorWarmRed => 'Warm Red';

  @override
  String get colorWarmYellow => 'Warm Yellow';

  @override
  String get colorWarmGreen => 'Warm Green';

  @override
  String get colorCoral => 'Coral';

  @override
  String get colorMint => 'Mint';

  @override
  String get colorLavender => 'Lavender';

  @override
  String get colorAmber => 'Amber';

  @override
  String get colorTangerine => 'Tangerine';

  @override
  String get colorEmerald => 'Emerald';

  @override
  String get colorSkyBlue => 'Sky Blue';

  @override
  String get colorMagenta => 'Magenta';
}
