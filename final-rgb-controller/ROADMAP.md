# 综合3 FPGA — RGB 彩灯蓝牙控制器

## 目录

```
final-rgb-controller/
├── ROADMAP.md          ← 本文件
├── src/                ← Verilog 源码
│   ├── rgb_controller_top.v
│   ├── uart_rx_byte.v
│   ├── uart_tx_byte.v
│   ├── cmd_parser.v
│   ├── breath_engine.v
│   ├── flow_engine.v
│   ├── gradient_engine.v
│   ├── ws2812_driver.v
│   └── scene_store.v
├── sim/                ← ModelSim testbench
├── stp/                ← SignalTap 配置
├── tools/              ← 辅助脚本
└── docs/               ← 模块文档
```

`src/rgb_pwm_core.v` 保留为早期 PWM 参考实现，不参与当前 Quartus 工程和 ModelSim 全链路仿真；当前 LED 输出路径为 `rgb_controller_top` → `ws2812_driver` → `led_din`。

## 命令协议

参见根 ROADMAP.md 中的协议定义。

## 设计约束

1. 基于 Cyclone IV E (EP4CE15F17C8)，50MHz clk
2. UART 115200 8N1，BAUD_DIV = 434
3. WS2812 8灯，GRB MSB first，1.25us/bit
4. 所有控制逻辑手写 Verilog，不用软核 CPU
