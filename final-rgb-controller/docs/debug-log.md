# 综合实验 — 调试记录

日期: 2026-06-04

## 工程文件清单

`D:/Code/Quartus/final-rgb-controller/src/`

| 文件 | 行数 | 状态 | 说明 |
|------|------|------|------|
| `uart_tx_byte.v` | ~60 | 复用 task2-1 | UART 8N1 发送，BAUD_DIV=434 |
| `uart_rx_byte.v` | ~100 | 复用 task2-1 | UART 8N1 接收，起始位确认+中心采样+停止位校验 |
| `ws2812_driver.v` | ~120 | 改造 task1-1 | 外部 GRB 输入驱动，update/busy 握手，8 灯 24bit |
| `cmd_parser.v` | ~225 | 新写 v5 | 帧解析+命令分发+ACK/Status 回复 |
| `rgb_pwm_core.v` | ~20 | 新写 | 3ch 8bit PWM，0-255 计数器比较 |
| `breath_engine.v` | ~80 | 新写 | 64项 sin LUT，period 控制呼吸速度 |
| `flow_engine.v` | ~45 | 新写 | speed 控制流水位移，8bit mask |
| `gradient_engine.v` | ~120 | 新写 | 128项彩虹 LUT，24bit RGB |
| `scene_store.v` | ~40 | 新写 | 8×4B 寄存器组，save/load |
| `rgb_controller_top.v` | ~295 | 新写 | 顶层连线，5个 I/O，模块实例化 |

## Quartus 编译记录

```
quartus_map   (Analysis & Synthesis):  0 errors, 3 warnings — 1569 LC, 6 DSP
quartus_fit   (Fitter):                0 errors, 4 warnings — EP4CE15F17C8
quartus_asm   (Assembler):             0 errors, 1 warning
quartus_pgm   (JTAG):                  Configuration succeeded
```

## BLE 测试记录 (COM4, 115200 8N1)

测试时间: 2026-06-04 13:13

| # | 命令 | 发送数据 | 期望回复 | 实际回复 | 结果 |
|---|------|----------|----------|----------|------|
| 1 | QueryStatus | `FF` | 5B status | `00 00 00 00 80` | PASS |
| 2 | SetColor Red | `10 FF 00 00` | `AA` | `AA` | PASS |
| 3 | SetBrightness 128 | `11 80` | `AA` | `AA` | PASS |
| 4 | QueryStatus | `FF` | 5B status | `00 FF 00 00 80` | PASS |
| 5 | SetMode Breath | `20 01` | `AA` | `AA` | PASS |
| 6 | SetMode Static | `20 00` | `AA` | `AA` | PASS |
| 7 | Invalid CMD | `AA` | `EE` | `EE` | PASS |
| 8 | QueryStatus (recover) | `FF` | 5B status | `00 FF 00 00 80` | PASS |
| 9 | SetFlowSpeed 200 | `21 C8` | `AA` | `AA` | PASS |
| 10 | SetBreathPeriod 50 | `22 32` | `AA` | `AA` | PASS |
| 11 | SaveScene slot0 | `30 00` | `AA` | `AA` | PASS |
| 12 | LoadScene slot0 | `31 00` | `AA` | `AA` | PASS |
| 13 | SetColor Green | `10 00 FF 00` | `AA` | `AA` | PASS |
| 14 | QueryStatus (Green) | `FF` | 5B status | `00 00 FF 00 80` | PASS |
| 15 | SetMode Flow | `20 02` | `AA` | `AA` | PASS |
| 16 | SetMode Gradient | `20 03` | `AA` | `AA` | PASS |

**所有 8 个命令码全部通过，QueryStatus 回复 5 字节正确。**

## BLE 协议实现细节

### CH9143 BLE 透传参数

- Service UUID: `0000FFF0-...`
- TX Characteristic (APP→FPGA): `0000FFF2-...` (writeWithoutResponse)
- RX Characteristic (FPGA→APP): `0000FFF1-...` (notify)
- UART: 115200, 8N1, BAUD_DIV=434

### 帧格式

| CMD | Name | Args | Len | Response |
|-----|------|------|-----|----------|
| 0x10 | SetColor | [R] [G] [B] | 4B | 0xAA/0xEE |
| 0x11 | SetBrightness | [V(0-255)] | 2B | 0xAA/0xEE |
| 0x20 | SetMode | [M(0-4)] | 2B | 0xAA/0xEE |
| 0x21 | SetFlowSpeed | [S(0-255)] | 2B | 0xAA/0xEE |
| 0x22 | SetBreathPeriod | [P(0-255)] | 2B | 0xAA/0xEE |
| 0x30 | SaveScene | [Slot(0-7)] | 2B | 0xAA/0xEE |
| 0x31 | LoadScene | [Slot(0-7)] | 2B | 0xAA/0xEE |
| 0xFF | QueryStatus | (none) | 1B | [mode][R][G][B][BR] (5B) |
| other | (illegal) | — | 1B | 0xEE |

### FPGA 内部信号路由

```
UART RX (PIN_B11) → uart_rx_byte → cmd_parser
                                         ├→ cur_r/g/b/brightness/mode
                                         ├→ scene_store (save/load)
                                         └→ UART TX (ACK/Status reply via PIN_D6)

cur_r/g/b → breath_engine → src_r/g/b (if mode==1)
          → flow_engine   → led_mask  (if mode==2)
          → gradient_engine → src_r/g/b (if mode==3)

src_r/g/b × brightness → final_r/g/b → ws2812_driver → led_din (PIN_T2)
```

## 已知问题 & 已修复 Bugs

### Bug 1: frame_len 非阻塞赋值延迟 (已修复)
cmd_parser 在 ST_DECODE 中用 `<=` 给 `frame_len` 赋值，同一周期用 `==` 判断读旧值。
**修复**: 改为组合逻辑 `function get_frame_len(input [7:0] b)` 即时计算。

### Bug 2: TX 忙等待卡死 (已修复)
多字节 Status 回复中 `tx_start` 持续拉高导致重复发送同一字节。
**修复**: 增加 `ST_WAIT_TX`/`ST_NEXT_BYTE` 两阶段握手机制：拉 tx_start → 等 tx_busy 变高 → 拉低 tx_start → 等 tx_busy 变低 → 下一字节。

### Bug 3: 多 constant driver (已修复)
`rgb_controller_top` 中 `cur_r/g/b/brightness` 由两个 `always` 块驱动。
**修复**: 合并为单一 always 块，scene_load_done 优先级最高。

## 后续调试建议

1. **LED 灯珠实测**: 当前验证了 UART 协议链路，WS2812 物理输出需要接灯条确认颜色和效果
2. **SignalTap 配置**: 在 `final-rgb-controller/stp/` 下创建 .stp 文件，抓取 `cmd_parser` 状态机 + WS2812 时序
3. **APP 联调**: Flutter APP 已实现全部命令，需要 Android 实机连接 CH9143 BLE 并验证 UI 流畅性
4. **ModelSim 仿真**: 在 `final-rgb-controller/sim/` 下补 testbench 覆盖全协议

## 压力测试记录 (2026-06-04 13:18)

连续发送 18 条命令（正常+异常+边界），全部通过：

- 8 个正常命令 (0x10-0x31)：全部回复 `aa`
- 3 个非法 CMD (0xAB, 0xCD, 0x00)：全部回复 `ee`，且未卡死 FSM
- 非法 CMD 后的 QueryStatus：正常回复 5 字节（证明 FSM 恢复）
- SetColor 后 QueryStatus：颜色值正确 (`AB CD EF`、`11 22 33`)
- 边界值 SetMode(7)：mode 被存入低 3 位 = 7，不影响 FPGA 正常运行
