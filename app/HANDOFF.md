# APP 交接文档 — RGB 彩灯蓝牙控制器

Date: 2026-06-04  |  Monorepo: `D:\Code\Quartus\app`

## 1. 项目概览

Flutter Android APK，Material 3 + Dynamic Color + Riverpod，通过 BLE 蓝牙连接 CH9143 模块，远程控制 FPGA Cyclone IV 开发板上的 WS2812 RGB 彩灯。

## 2. 编译环境

| 工具 | 路径 | 状态 |
|------|------|------|
| Flutter SDK 3.38.7 | `D:\Code\Tools\flutter` | **已安装，PATH 已配** |
| Dart | 内嵌于 Flutter | 可用 |
| Android SDK | `C:\Users\Ding\AppData\Local\Android\Sdk` | 已安装 |
| Android API 35 | `platforms/android-35` | 已安装 |
| NDK 28.2 | `ndk/28.2.13676358` | 已安装 |
| 模拟器 | `rgb_ble_controller` (Pixel 6, API 35, Google APIs x86_64) | 已创建 |

### PATH

```powershell
$env:PATH = "D:\Code\Tools\flutter\bin;$env:PATH"
```

## 3. 快速命令

```powershell
# 进入 APP 目录
cd D:\Code\Quartus\app

# 安装依赖
flutter pub get

# 静态分析 (当前 0 error)
flutter analyze

# 列出设备
flutter devices

# 启动模拟器 (如果没跑起来)
flutter emulators --launch rgb_ble_controller
# 或
emulator -avd rgb_ble_controller

# 安装到模拟器 (debug)
flutter build apk --debug
# 或热重载开发
flutter run -d emulator-5556

# 仅验证 dart 代码
dart analyze
```

## 4. 目录结构

```
app/
├── pubspec.yaml                     ← 依赖: flutter_blue_plus, riverpod, dynamic_color, shared_preferences
├── lib/
│   ├── main.dart                    ← 入口: DynamicColorBuilder + BLEGate 初始化门
│   ├── pages/
│   │   ├── main_shell.dart          ← 主框架: 底部导航 4 Tab (颜色/灯效/情景/设置)
│   │   ├── scanner_page.dart        ← BLE 扫描连接页 (蓝牙图标脉冲动画)
│   │   └── settings_page.dart       ← 设置: 语言切换/主题切换/关于
│   ├── providers/
│   │   ├── ble_provider.dart        ← BLE 服务: 扫描/连接/CH9143 UUID 发现/命令发送
│   │   ├── device_provider.dart     ← 设备状态: RGB/亮度/模式/速度/周期
│   │   ├── theme_provider.dart      ← 主题: Material 3 + MiSans 字体
│   │   ├── locale_provider.dart     ← 语言: zh/en 切换
│   │   └── preferences_provider.dart← 偏好: 底栏隐藏
│   ├── models/
│   │   └── command.dart             ← 命令协议枚举 (0x10-0xFF)
│   └── utils/
│       └── colors.dart              ← 12 种预设颜色
├── assets/fonts/
│   └── MiSans-Regular.ttf           ← 小米 MiSans 字体 (从 fluxdo 复制)
├── android/
│   ├── app/src/main/AndroidManifest.xml  ← BLE 权限 (已配)
│   ├── build.gradle.kts                 ← Android build (compileSdk 35)
│   ├── gradle.properties                ← android.useAndroidX=true
│   └── gradle/wrapper/gradle-wrapper.properties ← Gradle 8.14
└── test/
    └── widget_test.dart             ← 占位测试
```

## 5. 设计规范 (照抄 fluxdo)

| 项 | 值 |
|----|-----|
| 主题系统 | `DynamicColorBuilder` + `ColorScheme.fromSeed` + `DynamicSchemeVariant.fidelity` |
| 卡片 | `CardThemeData(elevation: 0, borderRadius: 12, color: surfaceContainerLow)` |
| 字体 | MiSans (若不可用则回退系统默认) |
| 沉浸 | edge-to-edge，状态栏/导航栏透明 |
| 背景 | `LinearGradient` 用 primaryContainer + tertiaryContainer 叠加 |
| 选中的灯效卡片 | `cs.primaryContainer` 背景 |
| 情景模式 Button | `Material` + `InkWell` 无边框 |

## 6. UI 页面清单

### 6.1 ScannerPage (扫描页)
- 蓝牙图标脉冲动画 (`AnimationController` repeat reverse scale 1.0 → 1.08)
- RSSI 排序设备列表
- `Card` + `ListTile` + `CircleAvatar`
- 点击连接 → `Navigator.pop` 回主界面

### 6.2 MainShell → 颜色 Tab
- 大圆球颜色预览 (`AnimatedContainer`, 阴影)
- RGB 数值显示
- 三通道自定义滑块 (红/绿/蓝, 圆角 thumb)
- 亮度滑块
- 12 色预设圆点 (带阴影 + 边框)

### 6.3 MainShell → 灯效 Tab
- 5 种模式卡片 (静态/呼吸/流水/渐变/音乐)
- 选中态: primaryContainer 底色 + check 图标
- 条件显示流水速度/呼吸周期滑块

### 6.4 MainShell → 情景 Tab
- 4×2 GridView 8 组场景
- 轻点加载 → `ble.loadScene(i)`
- 长按保存 → `ble.saveScene(i)` + SnackBar 提示

### 6.5 SettingsPage
- 语言: `SegmentedButton<String>` (中文/EN)
- 主题: `SegmentedButton<ThemeMode>` (跟随系统/浅色/深色)
- 关于卡片

## 7. BLE 协议

CH9143 模块 UUID: Service `FFF0`, Write `FFF2`, Notify `FFF1`

帧格式: `[CMD(1B)] [ARGS(0-3B)]`

| CMD | Name | Args | FPGA Response |
|-----|------|------|---------------|
| 0x10 | SetColor | R G B (各1B) | 0xAA/0xEE |
| 0x11 | SetBrightness | V(0-255) | 0xAA |
| 0x20 | SetMode | M(0-4) | 0xAA |
| 0x21 | SetFlowSpeed | S(0-255) | 0xAA |
| 0x22 | SetBreathPeriod | P(0-255) | 0xAA |
| 0x30 | SaveScene | slot(0-7) | 0xAA |
| 0x31 | LoadScene | slot(0-7) | 0xAA |

## 8. 当前构建状态 & 已知问题

### 编译状态
- **`flutter analyze`**: 通过，No issues
- **`flutter test`**: 42/42 通过
- **`flutter build apk --release --target-platform android-arm64`**: 通过，release APK 约 21.8 MB
- **`WebVisualQA`**: 通过，自动截图 `1280x720`、`390x844`、`460x900` 并采集 console/runtime 日志

### 其他注意
- 当前禁止使用个人手机测试；不要运行 ADB、APK 安装、手机截图或 `device-smoke`，除非用户重新授权。
- 本地验证优先使用 `tools/verify-app.ps1`，UI 视觉验证使用 `tools/verify-app.ps1 -SkipAnalyze -SkipTests -WebVisualQA`。
- BLE 功能无法在模拟器完整验证；后续需要课堂设备或用户重新授权的专用测试设备。

## 9. 交互流程

```
启动 → BLEGate (初始化 BLE 适配器)
         ↓ 成功
       MainShell (IndexedStack 4 Tab)
         ├── 颜色 Tab: 调 RGB + 亮度 → BLE 发 0x10/0x11
         ├── 灯效 Tab: 选模式 → BLE 发 0x20/0x21/0x22
         ├── 情景 Tab: 保存/加载 → BLE 发 0x30/0x31
         └── 设置 Tab: 语言/主题 (纯本地, 不涉及 BLE)
```

ScannerPage 目前不在主流程中——从 scanner 连接成功后会 pop 回到 MainShell。如需重新扫描需从 MainShell 添加触发入口。

## 10. 与 FPGA 顶层的信号对应

| APP 操作 | CMD 帧 | FPGA 模块接收 |
|----------|--------|--------------|
| 拖动 R/G/B | `[0x10, R, G, B]` | `cmd_parser` → `ws2812_driver` |
| 拖动亮度 | `[0x11, V]` | `cmd_parser` → 全局亮度 |
| 选择静态 | `[0x20, 0]` | `cmd_parser` → bypass engine |
| 选择呼吸 | `[0x20, 1]` | `cmd_parser` → `breath_engine` |
| 选择流水 | `[0x20, 2]` | `cmd_parser` → `flow_engine` |
| 选择渐变 | `[0x20, 3]` | `cmd_parser` → `gradient_engine` |
| 选择音乐 | 暂不发送 | FPGA 端未实现，App 端禁用该入口 |
| 保存场景 | `[0x30, slot]` | `cmd_parser` → `scene_store` |
| 加载场景 | `[0x31, slot]` | `cmd_parser` → `scene_store` |
