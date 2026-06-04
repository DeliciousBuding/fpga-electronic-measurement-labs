# CLAUDE.md — Quartus Monorepo

## 范围

本文件作用于 `D:\Code\Quartus` 全部子目录。这是《电子测量》FPGA 实验的工程仓库，基于 Cyclone IV E (EP4CE15F17C8)。

## 优先级

1. 管理员即时指令
2. 本文件
3. 上级 `C:\Users\Ding\AGENTS.md`
4. 各子模块 `CLAUDE.md`（如有）

## 工具链

| 工具 | 路径 | 用途 |
|------|------|------|
| Quartus Prime 25.1 Lite | `C:\altera_lite\25.1std\quartus\bin64` | 综合/布局布线/下载 |
| ModelSim SE 2020.4 | `C:\Program Files\ModelSim\win64` | 仿真（非 Questa） |
| Flutter | `D:\Code\Tools\flutter\bin` | APP 开发 |
| Android SDK | `C:\Users\Ding\AppData\Local\Android\Sdk` | APK 构建 |

环境变量：
- `LM_LICENSE_FILE = C:\Program Files\ModelSim\win64\LICENSE.TXT`
- `SALT_LICENSE_FILE = (empty)`
- `SALT_LICENSE_SERVER = (empty)`

## 关键引脚 (已验证)

| Signal | Pin | Dir | Note |
|--------|-----|-----|------|
| `clk` | PIN_E1 | In | 50 MHz |
| `nrst` | PIN_L2 | In | Low active |
| `rx_din` | PIN_B11 | In | CH9143 TX |
| `tx_dout` | PIN_D6 | Out | CH9143 RX |
| `led_din` | PIN_T2 | Out | WS2812 |
| `tx_en` | PIN_K1 | In | K1 button |
| `tx_busy_flag_qn` | PIN_A7 | Out | Debug |

注意：不要用 PIN_D5 做 RX，那是早期接线误判。

## Monorepo 模块

- `final-rgb-controller/` — 综合实验 FPGA 工程（Verilog）
- `app/` — Flutter APP
- `task1-serial-output/` — 里程碑，只读
- `task2-serial-transceiver/` — 里程碑，只读
- `task3-softcore-logic-analysis/` — 里程碑，只读
- `ref-bt-module/` — CH9143 参考
- `docs/` — 实验报告素材

## 开发规则

1. 新 Verilog 模块独立文件，先仿真后集成
2. 复用 task1/task2 已验证模块，不做侵入修改
3. Flutter 依赖用 `flutter pub add`，不手动改 pubspec.yaml
4. Git 提交粒度：每个独立模块一个 commit
5. 硬件调试：先 ModelSim 仿真通过 → Quartus 编译通过 → 上板
