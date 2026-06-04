# RGB 彩灯蓝牙控制器 — 综合实验 Monorepo

Last updated: 2026-06-04

## 项目定位

C301 综合选题3：基于 Cyclone IV FPGA 的无线 RGB 彩灯控制系统。手机 APP 通过 BLE 蓝牙发送命令，FPGA 解析后驱动 WS2812 LED 实现静态/呼吸/流水/渐变/音乐律动等多种灯效。

## Monorepo 结构

```
D:\Code\Quartus
├── ROADMAP.md                        ← 综合实验总路线图（本文件）
├── CLAUDE.md                         ← AI agent 项目须知
├── app/                              ← Flutter APP (Android APK)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── pages/                    ← 页面
│   │   ├── providers/                ← Riverpod 状态
│   │   ├── services/                 ← BLE 等底层服务
│   │   ├── models/                   ← 数据模型
│   │   ├── widgets/                  ← 可复用组件
│   │   └── utils/                    ← 工具函数
│   ├── i18n/                         ← slang 翻译文件
│   ├── android/                      ← Android 工程
│   │   └── app/src/main/
│   │       ├── AndroidManifest.xml   ← BLE 权限
│   │       └── kotlin/.../
│   └── pubspec.yaml
├── final-rgb-controller/             ← FPGA Verilog 工程
│   ├── ROADMAP.md
│   ├── src/                          ← 源码
│   ├── sim/                          ← ModelSim testbench
│   ├── stp/                          ← SignalTap 配置
│   ├── tools/                        ← 辅助脚本
│   └── docs/                         ← FPGA 文档
├── docs/                             ← 综合实验报告素材
│   └── demo-90-points.md
├── task1-serial-output/              ← [里程碑] 不修改
├── task2-serial-transceiver/         ← [里程碑] 不修改
├── task3-softcore-logic-analysis/    ← [里程碑] 不修改
└── ref-bt-module/                    ← 蓝牙模块参考
```

## 系统架构

```
┌─────────────────────────┐        BLE          ┌──────────────────┐
│  Flutter Android APK     │ ◄────────────────► │  CH9143 BLE PMOD  │
│                          │    UART over BLE    │  (从机模式)        │
│  ScannerPage             │                     └────────┬─────────┘
│  ├─ BLE 设备扫描          │                     UART 115200│8N1
│  └─ 连接 CH9143          │                     ┌────────┴─────────┐
│                          │                     │  Cyclone IV FPGA  │
│  ControlPage             │                     │  EP4CE15F17C8     │
│  ├─ 颜色 Tab              │                     │                   │
│  │   ├─ RGB 滑块          │    ┌───────┐        │  rgb_controller   │
│  │   ├─ 预设色盘           │    │ 0x10  │ set   │  ┌──────────────┐ │
│  │   └─ 亮度滑块           │    │ R G B │──────►│  │ cmd_parser   │ │
│  ├─ 灯效 Tab              │    │       │        │  │  ├─ 帧解码    │ │
│  │   ├─ 模式选择           │    │ 0x20  │ set   │  │  ├─ 命令分发  │ │
│  │   ├─ 流水速度           │    │ mode  │──────►│  │  └─ ACK 回传  │ │
│  │   └─ 呼吸周期           │    │       │        │  ├──────────────┤ │
│  └─ 情景 Tab              │    │ 0x30  │ save   │  │ effect engines│ │
│      ├─ 8 组保存/加载      │    │ slot  │──────►│  │  ├─ static    │ │
│      └─ 长按保存           │    │       │        │  │  ├─ breath    │ │
│                          │    │ 0x31  │ load   │  │  ├─ flow      │ │
│  SettingsPage            │    │ slot  │──────►│  │  └─ gradient  │ │
│  ├─ 语言切换 zh/en        │    └───────┘        │  ├──────────────┤ │
│  └─ 主题切换 明/暗         │                     │  │ ws2812_driver│ │
└─────────────────────────┘                      │  │  PIN_T2 ────►│─┐
                                                  │  └──────────────┘ │
                                                  │  uart_rx / uart_tx│ │
                                                  │  PIN_B11 / PIN_D6 │ │
                                                  └───────────────────┘ │
                                                                        │
                                                  ┌───────────────────┐ │
                                                  │ WS2812 RGB 8灯    │◄┘
                                                  │ (PMOD 扩展)        │
                                                  └───────────────────┘
```

## UART 命令协议

CH9143 透明桥接：APP BLE 写特征值 → FPGA UART RX 收到原始字节。

```
帧格式: [CMD(1B)] [ARGS(0-3B)]

CMD   Name            Args              FPGA Response
0x10  SetColor        [R] [G] [B]       0xAA / 0xEE
0x11  SetBrightness   [V(0-255)]        0xAA / 0xEE
0x20  SetMode         [M(0-4)]          0xAA / 0xEE
0x21  SetFlowSpeed    [S(0-255)]        0xAA / 0xEE
0x22  SetBreathPeriod [P(0-255)]        0xAA / 0xEE
0x30  SaveScene       [Slot(0-7)]       0xAA / 0xEE
0x31  LoadScene       [Slot(0-7)]       0xAA / 0xEE
0xFF  QueryStatus     (none)            [mode] [R] [G] [B] [brightness]
```

## FPGA 模块依赖图

```
rgb_controller_top
├── uart_rx_byte          [复用 task2-1/UART RX]
├── uart_tx_byte          [复用 task2-1/UART TX]
├── cmd_parser            [新写: 5B 帧缓冲 + 命令解码 + ACK]
│   └── 输出 → effect engines
├── rgb_pwm_core          [新写: 3ch PWM, 256 级]
├── breath_engine         [新写: sin LUT, period × pwm]
├── flow_engine           [新写: FSM, speed × step]
├── gradient_engine       [新写: HSV→RGB, 24bit color ramp]
├── ws2812_driver         [复用 task1-1/ws2812 编码]
├── scene_store           [新写: 8×4B 寄存器组]
└── fft_core              [选做 M5: 音频 FFT]
```

## APP 依赖图

```
main.dart
├── Dynamic Color (Material You)
├── Riverpod providers
│   ├── themeProvider     → ThemeState (mode, seedColor)
│   ├── bleServiceProvider→ BLEService (scan, connect, send)
│   ├── deviceProvider    → DeviceState (r,g,b, mode, speed)
│   └── localeProvider    → 语言切换
├── Pages
│   ├── ScannerPage       → 扫描 + 连接
│   ├── ControlPage       → 3 Tab (颜色/灯效/情景)
│   └── SettingsPage      → 语言/主题
├── i18n (slang)
│   ├── strings_zh.i18n.json
│   └── strings_en.i18n.json
└── Android Manifest
    ├── BLE permissions (SCAN/CONNECT/ADVERTISE)
    └── ACCESS_FINE_LOCATION
```

## 里程碑

| M | 内容 | 产出 | 状态 |
|---|------|------|------|
| M0 | 项目骨架 + 环境 | ROADMAP, CLAUDE.md, 目录结构 | done |
| M1 | FPGA RGB 控制器 | PWM/呼吸/流水/渐变 Verilog 模块 | todo |
| M2 | UART 命令集成 | cmd_parser + ACK + 顶层连线 | todo |
| M3 | ModelSim 全链路仿真 | testbench + 波形证据 | todo |
| M4 | Flutter APP 全功能 | BLE扫描/连接/颜色/灯效/情景/i18n | wip |
| M5 | FFT 音乐联动 | 音频 FFT → LED 律动 | todo |
| M6 | 多灯同步控制 | 多 PMOD WS2812 并行驱动 | todo |
| M7 | Quartus 编译 + 上板 | .sof + SignalTap + 实物演示 | todo |

## 复用 & 参考

| 来源 | 内容 |
|------|------|
| `task2-1/src/uart_loopback_top.v` | UART TX/RX 模块 (PIN_B11/D6 已验证) |
| `task1-1/src/ws2812_stub.v` | WS2812 编码时序 |
| `ref-bt-module/WeActStudio-CH9143/` | CH9143 BLE 数据手册 + 上位机 |
| `../fluxdo/` (D:\Code\Projects\tools\fluxdo\) | Material 3 UI 参考 |
| `docs/demo-90-points.md` | 90 分演示指南 |
