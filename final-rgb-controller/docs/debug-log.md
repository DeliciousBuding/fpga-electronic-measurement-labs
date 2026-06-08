# 综合实验 — 调试记录 & 交付清单

日期: 2026-06-04 | 状态: FPGA 侧完成

## 工程文件清单 (9 个综合 Verilog 模块)

| 文件 | 类型 | 功能 |
|------|------|------|
| `uart_tx_byte.v` | 复用 task2-1 | UART 8N1 TX, BAUD_DIV=434 |
| `uart_rx_byte.v` | 复用 task2-1 | UART 8N1 RX, 起始位确认+中心采样+停止位校验 |
| `ws2812_driver.v` | 改造 task1-1 | 外部 8 组 GRB 输入, update/busy 握手 |
| `cmd_parser.v` | 新写 v6 | 7 态 FSM, 命令帧解析 (1-4B), ACK/Status 回复 |
| `breath_engine.v` | 新写 | 64 项 sin LUT (8bit), period 控制呼吸速度 |
| `flow_engine.v` | 新写 | speed 控制流水位移, 8bit mask |
| `gradient_engine.v` | 新写 | 128 项彩虹 LUT (24bit), HSV 色相环 |
| `scene_store.v` | 新写 | 8×4B 寄存器组, save/load, 复位初始化 |
| `rgb_controller_top.v` | 新写 | 顶层连线, 5 个 I/O, 当前综合模块实例化 |

`rgb_pwm_core.v` 保留为早期 3ch 8bit PWM 参考实现，当前 WS2812 方案未实例化它，也不再加入 QSF/ModelSim 全链路编译列表。

## Quartus 编译

| 阶段 | 结果 | 资源 |
|------|------|------|
| Analysis & Synthesis | 0 errors, 3 warnings | 1569 LC, 6 DSP |
| Fitter | 0 errors, 4 warnings | EP4CE15F17C8 |
| Assembler | 0 errors, 1 warning | — |
| JTAG Program | Configuration succeeded | — |

## 命令协议验证 (COM4 BLE, 115200 8N1)

8 个命令码全部验证通过, QueryStatus 5 字节正确:

| CMD | Name | Test | Result |
|-----|------|------|--------|
| 0x10 | SetColor (R,G,B) | 颜色切换+确认 | PASS |
| 0x11 | SetBrightness (V) | 亮度变更+确认 | PASS |
| 0x20 | SetMode (0-4) | 模式切换+确认 | PASS |
| 0x21 | SetFlowSpeed (S) | 流水速度 | PASS |
| 0x22 | SetBreathPeriod (P) | 呼吸周期 | PASS |
| 0x30 | SaveScene (slot) | 情景保存 | PASS |
| 0x31 | LoadScene (slot) | 情景加载 | PASS |
| 0xFF | QueryStatus | 5B status reply | PASS |
| other | illegal | 0xEE, FSM 恢复 | PASS |

## ModelSim 仿真

全链路 testbench `tb_rgb_controller.v`:
- **18/18 tests PASS**
- 覆盖: 所有命令码, QueryStatus 5 字节, 非法 CMD 0xEE, 错误恢复, Save/Load 全部 8 slots
- 运行: `do sim/run.do` in ModelSim

## 交叉审查 (3 个并行 agent)

| Agent | 审查范围 | 发现 | 处理 |
|-------|---------|------|------|
| cmd_parser + top | 状态机, 连线, 仲裁 | tx_start 未复位 (critical) | 已修复 |
| | | scene_store 复位未初始化 (critical) | 已修复 |
| | | MODE_MUSIC 未实现 (minor) | 已知, 预留 |
| 效果引擎 (breath/flow/gradient/pwm) | LUT 值, 乘法, 分频 | 无 critical/major | — |
| | | speed N+1 偏差 (minor) | 统一设计风格, 不阻塞 |
| ws2812/UART/scene | 时序, 寄存器 | uart_tx/rx 与原版逐位一致 | — |
| | | ws2812 时序参数正确 | — |

## 已知 Bugs 修复记录

1. **frame_len 非阻塞延迟** → 组合 function `get_frame_len()` 即时计算
2. **TX 多字节握手卡死** → ST_WAIT_BUSY/ST_NEXT_BYTE 两阶段握手
3. **多 constant driver** → 合并 cur_r/g/b 单一 always 块
4. **scene_store 未初始化** → 8 组全复位为 (0,0,0,128)
5. **cmd_parser tx_start 未复位** → 显式赋 0

## 引脚约束 (已验证)

| Signal | Pin | Direction | IO |
|--------|-----|-----------|-----|
| clk | PIN_E1 | In | 3.3-V LVTTL |
| nrst | PIN_L2 | In | 3.3-V LVTTL |
| rx_din | PIN_B11 | In | 3.3-V LVTTL |
| tx_dout | PIN_D6 | Out | 3.3-V LVTTL |
| led_din | PIN_T2 | Out | 3.3-V LVTTL |

## 内部信号路由

```
rx_din → uart_rx_byte → cmd_parser
                            ├→ cur_r/g/b/brightness/mode
                            ├→ scene_store (save/load)
                            └→ tx_dout (ACK/Status via uart_tx_byte)

cur_r/g/b ─┬─ breath_engine   → src_r/g/b (mode==1)
           ├─ flow_engine     → led_mask  (mode==2)
           ├─ gradient_engine → src_r/g/b (mode==3)
           └─ (passthrough)   → src_r/g/b (mode==0)

src × brightness → final → ws2812_driver → led_din
```

## 待完成项 (非 FPGA)

| 项 | 负责 | 状态 |
|----|------|------|
| Flutter APP BLE 联调 | app agent | wip |
| SignalTap 波形捕获 | 上板时 | todo |
| 90 分演示报告 | 全组 | todo |
| FFT 音乐联动 (M5) | 选做 | todo |
| 多灯同步控制 (M6) | 选做 | todo |
