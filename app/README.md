# APP — RGB 彩灯蓝牙控制器

Flutter Android APK，Material 3 + Dynamic Color，BLE 连接 CH9143 控制 FPGA RGB 彩灯。

## 目录

```
app/
├── lib/
│   ├── main.dart                    ← 入口: DynamicColor + BLEGate
│   ├── pages/
│   │   ├── main_shell.dart          ← 主框架: 底部导航(颜色/灯效/情景/设置)
│   │   ├── scanner_page.dart        ← BLE 扫描连接页
│   │   └── settings_page.dart       ← 设置: 语言/主题/关于
│   ├── providers/
│   │   ├── ble_provider.dart        ← BLE 服务: 扫描/连接/CH9143 UUID
│   │   ├── device_provider.dart     ← 设备状态: RGB/亮度/模式/速度
│   │   ├── theme_provider.dart      ← 主题: Material 3 + MiSans
│   │   ├── locale_provider.dart     ← 语言: zh/en 切换
│   │   └── preferences_provider.dart← 偏好: 底栏隐藏等
│   ├── models/
│   │   └── command.dart             ← 命令协议 & 模式枚举
│   └── utils/
│       └── colors.dart              ← 预设颜色
├── android/app/src/main/
│   └── AndroidManifest.xml          ← BLE 权限 (SCAN/CONNECT/ADVERTISE/LOCATION)
└── pubspec.yaml                     ← 依赖
```

## 依赖

| 包 | 用途 |
|---|------|
| flutter_blue_plus | BLE 扫描/连接/收发 |
| flutter_riverpod | 状态管理 |
| dynamic_color | Material You 动态取色 |
| shared_preferences | 本地持久化 |

## 设计规范

Material 3 框架：

- `DynamicColorBuilder` + `ColorScheme.fromSeed` + `DynamicSchemeVariant.fidelity`
- 字体: MiSans (google_fonts)
- Card: `elevation: 0`, `borderRadius: 12`, `surfaceContainerLow`
- 沉浸式 edge-to-edge，状态栏/导航栏透明
- 语言: 默认中文，SegmentedButton 切换 zh/en
- 主题: SegmentedButton 切换 system/light/dark

## BLE 协议

CH9143 UUID: Service `FFF0`, Write `FFF2`, Notify `FFF1`

帧: `[CMD(1B)] [ARGS(0-3B)]`

见根 ROADMAP.md 完整协议定义。
