import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// App title
  ///
  /// In zh, this message translates to:
  /// **'RGB Controller'**
  String get appTitle;

  /// No description provided for @navLed.
  ///
  /// In zh, this message translates to:
  /// **'LED'**
  String get navLed;

  /// No description provided for @navEffect.
  ///
  /// In zh, this message translates to:
  /// **'灯效'**
  String get navEffect;

  /// No description provided for @navScene.
  ///
  /// In zh, this message translates to:
  /// **'情景'**
  String get navScene;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @ledStrip.
  ///
  /// In zh, this message translates to:
  /// **'LED 灯带'**
  String get ledStrip;

  /// No description provided for @brightness.
  ///
  /// In zh, this message translates to:
  /// **'亮度'**
  String get brightness;

  /// No description provided for @brightnessPercent.
  ///
  /// In zh, this message translates to:
  /// **'{pct}%'**
  String brightnessPercent(int pct);

  /// No description provided for @modeStatic.
  ///
  /// In zh, this message translates to:
  /// **'静态'**
  String get modeStatic;

  /// No description provided for @modeBreath.
  ///
  /// In zh, this message translates to:
  /// **'呼吸'**
  String get modeBreath;

  /// No description provided for @modeFlow.
  ///
  /// In zh, this message translates to:
  /// **'流水'**
  String get modeFlow;

  /// No description provided for @modeGradient.
  ///
  /// In zh, this message translates to:
  /// **'渐变'**
  String get modeGradient;

  /// No description provided for @modeMusic.
  ///
  /// In zh, this message translates to:
  /// **'音乐'**
  String get modeMusic;

  /// No description provided for @descStatic.
  ///
  /// In zh, this message translates to:
  /// **'固定颜色常亮'**
  String get descStatic;

  /// No description provided for @descBreath.
  ///
  /// In zh, this message translates to:
  /// **'正弦包络周期明暗'**
  String get descBreath;

  /// No description provided for @descFlow.
  ///
  /// In zh, this message translates to:
  /// **'灯光逐位移动'**
  String get descFlow;

  /// No description provided for @descGradient.
  ///
  /// In zh, this message translates to:
  /// **'HSV 色相平滑过渡'**
  String get descGradient;

  /// No description provided for @descMusic.
  ///
  /// In zh, this message translates to:
  /// **'FFT 联动 (未实现)'**
  String get descMusic;

  /// No description provided for @wip.
  ///
  /// In zh, this message translates to:
  /// **'WIP'**
  String get wip;

  /// No description provided for @flowSpeed.
  ///
  /// In zh, this message translates to:
  /// **'流水速度'**
  String get flowSpeed;

  /// No description provided for @gradientSpeed.
  ///
  /// In zh, this message translates to:
  /// **'渐变速度'**
  String get gradientSpeed;

  /// No description provided for @breathPeriod.
  ///
  /// In zh, this message translates to:
  /// **'呼吸周期'**
  String get breathPeriod;

  /// No description provided for @presetColors.
  ///
  /// In zh, this message translates to:
  /// **'预设颜色'**
  String get presetColors;

  /// No description provided for @quickActions.
  ///
  /// In zh, this message translates to:
  /// **'快捷操作'**
  String get quickActions;

  /// No description provided for @actionPowerOff.
  ///
  /// In zh, this message translates to:
  /// **'关灯'**
  String get actionPowerOff;

  /// No description provided for @actionFullWhite.
  ///
  /// In zh, this message translates to:
  /// **'全白'**
  String get actionFullWhite;

  /// No description provided for @actionRandom.
  ///
  /// In zh, this message translates to:
  /// **'随机'**
  String get actionRandom;

  /// No description provided for @actionWarmLight.
  ///
  /// In zh, this message translates to:
  /// **'暖光'**
  String get actionWarmLight;

  /// No description provided for @actionCoolLight.
  ///
  /// In zh, this message translates to:
  /// **'冷光'**
  String get actionCoolLight;

  /// No description provided for @actionRainbow.
  ///
  /// In zh, this message translates to:
  /// **'彩虹'**
  String get actionRainbow;

  /// No description provided for @copyHexTooltip.
  ///
  /// In zh, this message translates to:
  /// **'点击复制 {hex}'**
  String copyHexTooltip(String hex);

  /// No description provided for @hexCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制 {hex}'**
  String hexCopied(String hex);

  /// No description provided for @bleNotConnected.
  ///
  /// In zh, this message translates to:
  /// **'未连接蓝牙设备'**
  String get bleNotConnected;

  /// No description provided for @bleConnect.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get bleConnect;

  /// No description provided for @bleTooltipConnected.
  ///
  /// In zh, this message translates to:
  /// **'已连接 {name} - 长按刷新状态'**
  String bleTooltipConnected(String name);

  /// No description provided for @bleTooltipDisconnected.
  ///
  /// In zh, this message translates to:
  /// **'未连接 - 点击扫描'**
  String get bleTooltipDisconnected;

  /// No description provided for @bleRefreshing.
  ///
  /// In zh, this message translates to:
  /// **'正在刷新 FPGA 状态...'**
  String get bleRefreshing;

  /// No description provided for @bleCmdFailed.
  ///
  /// In zh, this message translates to:
  /// **'命令执行失败 (0xEE)'**
  String get bleCmdFailed;

  /// No description provided for @bleConnected.
  ///
  /// In zh, this message translates to:
  /// **'已连接 {name}'**
  String bleConnected(String name);

  /// No description provided for @sceneTitle.
  ///
  /// In zh, this message translates to:
  /// **'情景模式'**
  String get sceneTitle;

  /// No description provided for @sceneHint.
  ///
  /// In zh, this message translates to:
  /// **'轻点加载 · 长按保存'**
  String get sceneHint;

  /// No description provided for @sceneSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存「{name}」'**
  String sceneSaved(String name);

  /// No description provided for @sceneSunset.
  ///
  /// In zh, this message translates to:
  /// **'日暮'**
  String get sceneSunset;

  /// No description provided for @sceneAurora.
  ///
  /// In zh, this message translates to:
  /// **'极光'**
  String get sceneAurora;

  /// No description provided for @sceneNeon.
  ///
  /// In zh, this message translates to:
  /// **'霓虹'**
  String get sceneNeon;

  /// No description provided for @sceneFlame.
  ///
  /// In zh, this message translates to:
  /// **'烈焰'**
  String get sceneFlame;

  /// No description provided for @sceneForest.
  ///
  /// In zh, this message translates to:
  /// **'森林'**
  String get sceneForest;

  /// No description provided for @sceneOcean.
  ///
  /// In zh, this message translates to:
  /// **'深海'**
  String get sceneOcean;

  /// No description provided for @sceneWarmSun.
  ///
  /// In zh, this message translates to:
  /// **'暖阳'**
  String get sceneWarmSun;

  /// No description provided for @sceneLightning.
  ///
  /// In zh, this message translates to:
  /// **'电光'**
  String get sceneLightning;

  /// No description provided for @sceneLoaded.
  ///
  /// In zh, this message translates to:
  /// **'已加载「{name}」'**
  String sceneLoaded(String name);

  /// No description provided for @scanTitle.
  ///
  /// In zh, this message translates to:
  /// **'扫描蓝牙设备'**
  String get scanTitle;

  /// No description provided for @scanHint.
  ///
  /// In zh, this message translates to:
  /// **'请确保 CH9143 BLE 模块已上电'**
  String get scanHint;

  /// No description provided for @scanScanning.
  ///
  /// In zh, this message translates to:
  /// **'正在扫描...'**
  String get scanScanning;

  /// No description provided for @scanScanningBtn.
  ///
  /// In zh, this message translates to:
  /// **'扫描中...'**
  String get scanScanningBtn;

  /// No description provided for @scanRescan.
  ///
  /// In zh, this message translates to:
  /// **'重新扫描'**
  String get scanRescan;

  /// No description provided for @scanNoDevice.
  ///
  /// In zh, this message translates to:
  /// **'未发现设备'**
  String get scanNoDevice;

  /// No description provided for @scanRetryHint.
  ///
  /// In zh, this message translates to:
  /// **'点击下方按钮重新扫描'**
  String get scanRetryHint;

  /// No description provided for @scanConnectFail.
  ///
  /// In zh, this message translates to:
  /// **'连接失败，请重试'**
  String get scanConnectFail;

  /// No description provided for @bleOffTitle.
  ///
  /// In zh, this message translates to:
  /// **'蓝牙已关闭'**
  String get bleOffTitle;

  /// No description provided for @bleOffHint.
  ///
  /// In zh, this message translates to:
  /// **'请先在系统设置中开启蓝牙'**
  String get bleOffHint;

  /// No description provided for @bleTurnOn.
  ///
  /// In zh, this message translates to:
  /// **'开启蓝牙'**
  String get bleTurnOn;

  /// No description provided for @settingsAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsAppearance;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// No description provided for @settingsLangZh.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get settingsLangZh;

  String get settingsLangEn;

  /// No description provided for @settingsTheme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get settingsTheme;

  /// No description provided for @settingsThemeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get settingsThemeSystem;

  /// No description provided for @settingsBluetooth.
  ///
  /// In zh, this message translates to:
  /// **'蓝牙'**
  String get settingsBluetooth;

  /// No description provided for @settingsAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsAbout;

  /// No description provided for @bleStatusConnected.
  ///
  /// In zh, this message translates to:
  /// **'已连接'**
  String get bleStatusConnected;

  /// No description provided for @bleStatusOffline.
  ///
  /// In zh, this message translates to:
  /// **'离线'**
  String get bleStatusOffline;

  /// No description provided for @bleStatusDetailConnected.
  ///
  /// In zh, this message translates to:
  /// **'已连接 · 长按蓝牙图标刷新状态'**
  String get bleStatusDetailConnected;

  /// No description provided for @bleStatusDetailDisconnected.
  ///
  /// In zh, this message translates to:
  /// **'点击蓝牙图标扫描设备'**
  String get bleStatusDetailDisconnected;

  /// No description provided for @aboutAppName.
  ///
  /// In zh, this message translates to:
  /// **'RGB 彩灯蓝牙控制器'**
  String get aboutAppName;

  /// No description provided for @aboutVersion.
  ///
  /// In zh, this message translates to:
  /// **'v0.1 · 湖南大学 · 工训中心'**
  String get aboutVersion;

  /// No description provided for @aboutDesc.
  ///
  /// In zh, this message translates to:
  /// **'基于 CH9143 BLE 模块 + FPGA Cyclone IV E 控制 WS2812 RGB 彩灯'**
  String get aboutDesc;

  /// No description provided for @debugLogTitle.
  ///
  /// In zh, this message translates to:
  /// **'BLE 调试日志'**
  String get debugLogTitle;

  /// No description provided for @debugLogCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条记录'**
  String debugLogCount(int count);

  /// No description provided for @debugLogEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无日志'**
  String get debugLogEmpty;

  /// No description provided for @bleNotSupported.
  ///
  /// In zh, this message translates to:
  /// **'BLE 不支持'**
  String get bleNotSupported;

  /// No description provided for @colorRed.
  ///
  /// In zh, this message translates to:
  /// **'红'**
  String get colorRed;

  /// No description provided for @colorOrange.
  ///
  /// In zh, this message translates to:
  /// **'橙'**
  String get colorOrange;

  /// No description provided for @colorYellow.
  ///
  /// In zh, this message translates to:
  /// **'黄'**
  String get colorYellow;

  /// No description provided for @colorGreen.
  ///
  /// In zh, this message translates to:
  /// **'绿'**
  String get colorGreen;

  /// No description provided for @colorCyan.
  ///
  /// In zh, this message translates to:
  /// **'青'**
  String get colorCyan;

  /// No description provided for @colorBlue.
  ///
  /// In zh, this message translates to:
  /// **'蓝'**
  String get colorBlue;

  /// No description provided for @colorPurple.
  ///
  /// In zh, this message translates to:
  /// **'紫'**
  String get colorPurple;

  /// No description provided for @colorPink.
  ///
  /// In zh, this message translates to:
  /// **'粉'**
  String get colorPink;

  /// No description provided for @colorWhite.
  ///
  /// In zh, this message translates to:
  /// **'白'**
  String get colorWhite;

  /// No description provided for @colorWarmRed.
  ///
  /// In zh, this message translates to:
  /// **'暖红'**
  String get colorWarmRed;

  /// No description provided for @colorWarmYellow.
  ///
  /// In zh, this message translates to:
  /// **'暖黄'**
  String get colorWarmYellow;

  /// No description provided for @colorWarmGreen.
  ///
  /// In zh, this message translates to:
  /// **'暖绿'**
  String get colorWarmGreen;

  /// No description provided for @colorCoral.
  ///
  /// In zh, this message translates to:
  /// **'珊瑚'**
  String get colorCoral;

  /// No description provided for @colorMint.
  ///
  /// In zh, this message translates to:
  /// **'薄荷'**
  String get colorMint;

  /// No description provided for @colorLavender.
  ///
  /// In zh, this message translates to:
  /// **'薰衣草'**
  String get colorLavender;

  /// No description provided for @colorAmber.
  ///
  /// In zh, this message translates to:
  /// **'琥珀'**
  String get colorAmber;

  /// No description provided for @colorTangerine.
  ///
  /// In zh, this message translates to:
  /// **'橘'**
  String get colorTangerine;

  /// No description provided for @colorEmerald.
  ///
  /// In zh, this message translates to:
  /// **'翠'**
  String get colorEmerald;

  /// No description provided for @colorSkyBlue.
  ///
  /// In zh, this message translates to:
  /// **'天蓝'**
  String get colorSkyBlue;

  /// No description provided for @colorMagenta.
  ///
  /// In zh, this message translates to:
  /// **'洋红'**
  String get colorMagenta;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
