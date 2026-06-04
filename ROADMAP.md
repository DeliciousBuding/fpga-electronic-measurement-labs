# RGB 彩灯蓝牙控制器 — 综合实验 Monorepo

Last updated: 2026-06-04

## 项目定位

C301 综合选题3：基于 Cyclone IV FPGA 的无线 RGB 彩灯控制系统。手机 APP 通过 BLE 蓝牙发送命令，FPGA 解析后驱动 WS2812 LED 实现静态/呼吸/流水/渐变等多种灯效。

## Monorepo 结构

```
D:\Code\Quartus
├── ROADMAP.md                        ← 综合实验总路线图（本文件）
├── CLAUDE.md                         ← AI agent 项目须知
├── AGENTS.md                         ← 全局安全规则
├── app/                              ← Flutter APP (Android APK) — app agent 负责
├── final-rgb-controller/             ← FPGA Verilog 工程 — FPGA agent 负责
│   ├── ROADMAP.md
│   ├── final-rgb-controller.qpf/qsf/sdc
│   ├── src/         (10 modules, 1093 lines Verilog)
│   ├── sim/         (tb_rgb_controller.v + run.do)
│   ├── stp/         (SignalTap — todo)
│   ├── docs/        (debug-log.md)
│   └── output_files/(.sof — gitignored)
├── docs/                             ← 共享文档
│   ├── board-pinout.md              ← 完整板级引脚映射
│   └── demo-90-points.md            ← 90 分演示指南
├── task1-serial-output/              ← [里程碑] 只读
├── task2-serial-transceiver/         ← [里程碑] 只读
├── task3-softcore-logic-analysis/    ← [里程碑] 只读
└── ref-bt-module/                    ← 蓝牙模块参考 (CH9143)
```

## 系统架构

```
┌──────────────────────┐     BLE      ┌──────────────────┐
│  Flutter Android APK  │◄──────────►│  CH9143 BLE PMOD  │
│  (app agent)          │ UART over BLE│ (透明桥接)        │
└──────────────────────┘             └────────┬─────────┘
                                    UART 115200│8N1
                                    ┌────────┴─────────┐
                                    │  Cyclone IV FPGA  │
                                    │  EP4CE15F17C8     │
                                    │                   │
                                    │  rgb_controller   │
                                    │  ├─ uart_rx_byte   │← PIN_B11
                                    │  ├─ cmd_parser     │→ 命令分发
                                    │  ├─ effect engines │→ PWM/呼吸/流水/渐变
                                    │  ├─ ws2812_driver  │→ PIN_T2 (LED)
                                    │  └─ uart_tx_byte   │→ PIN_D6 (ACK)
                                    └───────────────────┘
```

## 命令协议 (FPGA ↔ APP)

CH9143 透明桥接：APP BLE 写特征值 → FPGA UART RX 收到原始字节。

```
CMD   Name            Args              FPGA Response
0x10  SetColor        [R] [G] [B]       0xAA / 0xEE
0x11  SetBrightness   [V(0-255)]        0xAA
0x20  SetMode         [M(0-4)]          0xAA
0x21  SetFlowSpeed    [S(0-255)]        0xAA
0x22  SetBreathPeriod [P(0-255)]        0xAA
0x30  SaveScene       [Slot(0-7)]       0xAA
0x31  LoadScene       [Slot(0-7)]       0xAA
0xFF  QueryStatus     (none)            [mode][R][G][B][BR] (5B)
```

## 里程碑

| M | 内容 | 状态 |
|---|------|------|
| M0 | 项目骨架 + 环境 | done |
| M1 | FPGA RGB 控制器 (PWM/呼吸/流水/渐变) | **done** |
| M2 | UART 命令集成 (cmd_parser + ACK + 顶层连线) | **done** |
| M3 | ModelSim 全链路仿真 (18/18 PASS) | **done** |
| M4 | Flutter APP 全功能 | **done** |
| M5 | FFT 音乐联动 (选做) | todo |
| M6 | 多灯同步控制 (选做) | todo |
| M7 | Quartus 编译 + 上板 | **done** |
| M8 | SignalTap 波形捕获 | todo |
| M9 | BLE 真机联调 + 端到端验证 | **待手动——手机蓝牙已关闭 7 小时** |

## FPGA 编译与验证总结

| 项目 | 结果 |
|------|------|
| Quartus Analysis & Synthesis | 0 errors, 1569 LC, 6 DSP |
| Quartus Fitter | 0 errors, EP4CE15F17C8 |
| Quartus Assembler | 0 errors |
| JTAG 下载 | Configuration succeeded |
| BLE 协议测试 (COM4) | 8 命令码全部通过 |
| ModelSim 全链路仿真 | 18/18 PASS |
| 交叉审查 (3 agents) | 2 critical 已修复, 0 outstanding |

## 复用 & 参考

| 来源 | 内容 |
|------|------|
| `task2-1/src/uart_loopback_top.v` | UART TX/RX 模块 (PIN_B11/D6 已验证) |
| `task1-1/src/ws2812_stub.v` | WS2812 编码时序 |
| `ref-bt-module/WeActStudio-CH9143/` | CH9143 BLE 数据手册 + 上位机 |
| `docs/demo-90-points.md` | 90 分演示指南 |

## 开发规则

1. FPGA agent 不改 app/, app agent 不改 final-rgb-controller/
2. FPGA 代码修改必须 Quartus 编译通过 → ModelSim 仿真 → 上板验证
3. Git 提交粒度：独立变更一个 commit
4. 里程碑项目 (task1/task2/task3) 只读
