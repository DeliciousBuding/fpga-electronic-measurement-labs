# 板级引脚完整映射表

收集自 `/home/user/quartus/` 下所有 `.qsf` 文件的引脚分配。

## 固定信号（所有工程共用）

| 信号 | FPGA Pin | 方向 | IO Standard | 描述 |
|------|----------|------|-------------|------|
| `clk` | PIN_E1 | In | 3.3-V LVTTL | 50 MHz 板载时钟 |
| `nrst` / `rst_n` | PIN_L2 | In | 3.3-V LVTTL | 低电平复位 |

## UART / BLE 蓝牙 （CH9143 PMOD）

| 信号 | FPGA Pin | 方向 | IO Standard | 描述 |
|------|----------|------|-------------|------|
| `rx_din` | PIN_B11 | In | 3.3-V LVTTL | CH9143 TX → FPGA RX |
| `tx_dout` | PIN_D6 | Out | 3.3-V LVTTL | FPGA TX → CH9143 RX |
| `tx_busy_flag_qn` | PIN_A7 | Out | 3.3-V LVTTL | 调试：TX 空闲=1，发送中=0 |

> **注意**: `PIN_D5` 是早期错误接线，已被 `PIN_B11` 替代。不要改回。

## WS2812 LED

| 信号 | FPGA Pin | 方向 | IO Standard | 描述 |
|------|----------|------|-------------|------|
| `led_din` / `led_out` | PIN_T2 | Out | 3.3-V LVTTL | WS2812 数据线 |

## 按键

| 信号 | FPGA Pin | 方向 | IO Standard | 描述 |
|------|----------|------|-------------|------|
| `tx_en` / `key_brightness_down` | PIN_K1 | In | 3.3-V LVTTL | K1 按键，低电平有效 |
| `key_brightness_up` | PIN_K2 | In | 3.3-V LVTTL | K2 按键 |
| `key_led_mode` | PIN_L1 | In | 3.3-V LVTTL | L1 按键 |

## PMOD 扩展口 (debug-rx-scan 项目扫描映射)

用于 GPIO 扩展或逻辑分析仪探头：

```
p00  = PIN_A2      p01  = PIN_A3      p02  = PIN_A4
p03  = PIN_A5      p04  = PIN_A6      p05  = PIN_B3
p06  = PIN_B4      p07  = PIN_B5      p08  = PIN_B6
p09  = PIN_B7      p10  = PIN_C3      p11  = PIN_C6
p12  = PIN_C8      p13  = PIN_D3      p14  = PIN_D5  ← 注意：历史错误 RX 引脚
p15  = PIN_D8      p16  = PIN_E6      p17  = PIN_E7
p18  = PIN_E8      p19  = PIN_F8      p20  = PIN_A7
p21  = PIN_A10     p22  = PIN_A11     p23  = PIN_B10
p24  = PIN_B11
```
