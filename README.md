# 电子测量 FPGA 实验项目

这是《电子测量》课程相关的 Quartus / Verilog 实验项目仓库。工程面向 Altera Cyclone IV E FPGA 开发板，内容覆盖 WS2812 彩灯控制、UART 串口通信、有限状态机控制、PLL/FIFO IP 使用，以及面向 SignalTap 的逻辑分析实验。

仓库按“源码优先、可复现优先”的方式整理。Quartus 编译数据库、下载文件、ModelSim 工作库、本地厂商参考资料和个人交接记录均不纳入公开仓库。

## 目录结构

```text
.
├── task1-serial-output/
│   ├── task1-1-ws2812/          # WS2812 流水彩灯
│   ├── task1-4-uart-tx/         # UART TX，115200 8N1，发送 0x55
│   └── scripts/                 # 证据图生成脚本
├── task2-serial-transceiver/
│   ├── task2-1-uart-loopback/   # 蓝牙 UART 收发回环与仲裁
│   └── task2-2-fsm-sim/         # 双层 FSM 的 ModelSim 仿真
├── task3-softcore-logic-analysis/
│   ├── src/                     # 计数器、PLL、异步 FIFO、SDFIFO_CTL 集成
│   ├── sim/                     # Task3 自检 testbench
│   └── tools/                   # Task3 预检和 SignalTap 辅助脚本
├── debug-rx-edge/               # RX 引脚边沿检测调试工程
├── debug-rx-scan/               # RX 引脚扫描调试工程
└── docs/                        # 验证记录
```

## 当前状态

| 任务 | 内容 | 仿真 | Quartus 编译 | 上板 |
| --- | --- | --- | --- | --- |
| 综合实验 | RGB 彩灯蓝牙控制器 | 通过 | 通过 | 本轮未使用个人手机/板卡 |
| Task1-1 | WS2812 流水彩灯 | N/A | 通过 | 通过 |
| Task1-4 | UART TX，115200/8N1/0x55 | 通过 | 通过 | 通过 |
| Task2-1 | 蓝牙回环、UART RX、优先级仲裁 | 通过 | 通过 | 通过 |
| Task2-2 | 双层 FSM | 通过 | N/A | N/A |
| Task3-1 | LPM counter 与 SignalTap | N/A | 通过 | 待补 SignalTap 捕获图 |
| Task3-2 | PLL 与复位同步释放 | 通过 | 通过 | 通过 |
| Task3-3 | 异步 FIFO | 通过 | 通过 | 不要求 |
| Task3-4 | SDFIFO_CTL 数据流控制器 | 通过 | 通过 | 不要求 |

目前唯一缺少的课程材料是 Task3-1 的 SignalTap 实机波形截图。仓库中的 Task3 工程已能在启用 SignalTap 的情况下完成 Quartus 编译。

## 工具链

已验证的本地工具链：

- Quartus Prime Lite / Standard 25.1
- ModelSim
- 目标 FPGA：Cyclone IV E，`EP4CE15F17C8`
- JTAG：USB-Blaster
- UART：115200 baud，8 data bits，no parity，1 stop bit

Quartus 9.0 可能更接近旧版课程截图，但本仓库工程按 Quartus 25.1 维护。

## 快速验证

Task2 完整预检：

```powershell
cd task2-serial-transceiver\task2-1-uart-loopback
powershell -ExecutionPolicy Bypass -File .\tools\preflight-task2.ps1 -Compile
```

期望标记：

```text
PRE_FLIGHT_OK
```

Task3 仿真与编译预检：

```powershell
cd task3-softcore-logic-analysis
powershell -ExecutionPolicy Bypass -File .\tools\preflight-task3.ps1 -Compile
```

期望标记：

```text
TASK3_PRE_FLIGHT_OK
```

综合实验本地无设备质量门禁：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\verify-app.ps1 -AllLocal
```

该门禁覆盖 Flutter 静态分析与测试、Web 多视口视觉 QA、ModelSim 协议/灯效仿真、Quartus Analysis & Synthesis、TeX 实验报告校验、Release APK 质量和 local evidence manifest。它不会运行 ADB、APK 安装、手机截图、JTAG 下载或交付包整理；需要实机验证或交付包复核时必须单独授权并显式运行对应门禁。

## 硬件连接说明

Task2 蓝牙 UART 实验中，已确认的关键引脚映射如下：

| FPGA 信号 | FPGA 引脚 | 方向 |
| --- | --- | --- |
| `rx_din` | `PIN_B11` | 蓝牙模块到 FPGA |
| `tx_dout` | `PIN_D6` | FPGA 到蓝牙模块 |
| `tx_busy_flag_qn` | `PIN_A7` | 调试输出 |
| `clk` | `PIN_E1` | 50 MHz 板载时钟 |
| `nrst` | `PIN_L2` | 低电平复位 |
| `tx_en` | `PIN_K1` | 低电平手动发送按键 |

不要把 Task2 的 RX 改回 `PIN_D5`。`PIN_D5` 是早期接线误判，不适用于已确认的 PMOD 插法。

## 仓库规则

纳入版本控制：

- Verilog 源码和 testbench
- 重建工程所需的 Quartus 项目/设置文件
- ModelSim `.do` 脚本和小型辅助脚本
- 小型证据图片和验证记录

不纳入版本控制：

- Quartus `db/`、`incremental_db/`、`output_files/`、生成报告和 bitstream
- ModelSim `work/`、`work_*`、`.wlf`、`.mpf`、`.cr.mti`、临时 `wlft*` 文件
- 本地厂商参考资料、驱动包、PDF 导出件和个人交接记录
