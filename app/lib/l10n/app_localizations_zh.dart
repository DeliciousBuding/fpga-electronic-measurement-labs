// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'RGB Controller';

  @override
  String get navLed => 'LED';

  @override
  String get navEffect => '灯效';

  @override
  String get navScene => '情景';

  @override
  String get navSettings => '设置';

  @override
  String get ledStrip => 'LED 灯带';

  @override
  String get brightness => '亮度';

  @override
  String brightnessPercent(int pct) {
    return '$pct%';
  }

  @override
  String get modeStatic => '静态';

  @override
  String get modeBreath => '呼吸';

  @override
  String get modeFlow => '流水';

  @override
  String get modeGradient => '渐变';

  @override
  String get modeMusic => '音乐';

  @override
  String get descStatic => '固定颜色常亮';

  @override
  String get descBreath => '正弦包络周期明暗';

  @override
  String get descFlow => '灯光逐位移动';

  @override
  String get descGradient => 'HSV 色相平滑过渡';

  @override
  String get descMusic => 'FFT 联动 (未实现)';

  @override
  String get wip => 'WIP';

  @override
  String get flowSpeed => '流水速度';

  @override
  String get gradientSpeed => '渐变速度';

  @override
  String get breathPeriod => '呼吸周期';

  @override
  String get presetColors => '预设颜色';

  @override
  String get quickActions => '快捷操作';

  @override
  String get actionPowerOff => '关灯';

  @override
  String get actionFullWhite => '全白';

  @override
  String get actionRandom => '随机';

  @override
  String get actionWarmLight => '暖光';

  @override
  String get actionCoolLight => '冷光';

  @override
  String get actionRainbow => '彩虹';

  @override
  String copyHexTooltip(String hex) {
    return '点击复制 $hex';
  }

  @override
  String hexCopied(String hex) {
    return '已复制 $hex';
  }

  @override
  String get bleNotConnected => '未连接蓝牙设备';

  @override
  String get bleConnect => '连接';

  @override
  String bleTooltipConnected(String name) {
    return '已连接 $name - 长按刷新状态';
  }

  @override
  String get bleTooltipDisconnected => '未连接 - 点击扫描';

  @override
  String get bleRefreshing => '正在刷新 FPGA 状态...';

  @override
  String get bleCmdFailed => '命令执行失败 (0xEE)';

  @override
  String bleConnected(String name) {
    return '已连接 $name';
  }

  @override
  String get sceneTitle => '情景模式';

  @override
  String get sceneHint => '轻点加载 · 长按保存';

  @override
  String sceneSaved(String name) {
    return '已保存「$name」';
  }

  @override
  String get sceneSunset => '日暮';

  @override
  String get sceneAurora => '极光';

  @override
  String get sceneNeon => '霓虹';

  @override
  String get sceneFlame => '烈焰';

  @override
  String get sceneForest => '森林';

  @override
  String get sceneOcean => '深海';

  @override
  String get sceneWarmSun => '暖阳';

  @override
  String get sceneLightning => '电光';

  @override
  String sceneLoaded(String name) {
    return '已加载「$name」';
  }

  @override
  String get scanTitle => '扫描蓝牙设备';

  @override
  String get scanHint => '请确保 CH9143 BLE 模块已上电';

  @override
  String get scanScanning => '正在扫描...';

  @override
  String get scanScanningBtn => '扫描中...';

  @override
  String get scanRescan => '重新扫描';

  @override
  String get scanNoDevice => '未发现设备';

  @override
  String get scanRetryHint => '点击下方按钮重新扫描';

  @override
  String get scanConnectFail => '连接失败，请重试';

  @override
  String get bleOffTitle => '蓝牙已关闭';

  @override
  String get bleOffHint => '请先在系统设置中开启蓝牙';

  @override
  String get bleTurnOn => '开启蓝牙';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLangZh => '中文';
  @override
  String get settingsLangEn => '英语';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsThemeSystem => '跟随系统';

  @override
  String get settingsBluetooth => '蓝牙';

  @override
  String get settingsAbout => '关于';

  @override
  String get bleStatusConnected => '已连接';

  @override
  String get bleStatusOffline => '离线';

  @override
  String get bleStatusDetailConnected => '已连接 · 长按蓝牙图标刷新状态';

  @override
  String get bleStatusDetailDisconnected => '点击蓝牙图标扫描设备';

  @override
  String get aboutAppName => 'RGB 彩灯蓝牙控制器';

  @override
  String get aboutVersion => 'v0.1 · 湖南大学 · 工训中心';

  @override
  String get aboutDesc =>
      '基于 CH9143 BLE 模块 + FPGA Cyclone IV E 控制 WS2812 RGB 彩灯';

  @override
  String get debugLogTitle => 'BLE 调试日志';

  @override
  String debugLogCount(int count) {
    return '$count 条记录';
  }

  @override
  String get debugLogEmpty => '暂无日志';

  @override
  String get bleNotSupported => 'BLE 不支持';

  @override
  String get colorRed => '红';

  @override
  String get colorOrange => '橙';

  @override
  String get colorYellow => '黄';

  @override
  String get colorGreen => '绿';

  @override
  String get colorCyan => '青';

  @override
  String get colorBlue => '蓝';

  @override
  String get colorPurple => '紫';

  @override
  String get colorPink => '粉';

  @override
  String get colorWhite => '白';

  @override
  String get colorWarmRed => '暖红';

  @override
  String get colorWarmYellow => '暖黄';

  @override
  String get colorWarmGreen => '暖绿';

  @override
  String get colorCoral => '珊瑚';

  @override
  String get colorMint => '薄荷';

  @override
  String get colorLavender => '薰衣草';

  @override
  String get colorAmber => '琥珀';

  @override
  String get colorTangerine => '橘';

  @override
  String get colorEmerald => '翠';

  @override
  String get colorSkyBlue => '天蓝';

  @override
  String get colorMagenta => '洋红';
}
