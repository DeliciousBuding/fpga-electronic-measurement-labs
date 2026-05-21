# FPGA Lab Projects for Electronic Measurement

This repository contains Quartus / Verilog lab projects for the Electronic Measurement course. The projects target an Altera Cyclone IV E board and cover WS2812 output, UART serial communication, finite-state-machine control, PLL/FIFO IP usage, and SignalTap-oriented logic analysis.

The repository is organized as source-first coursework material. Quartus databases, programming files, ModelSim work libraries, and local vendor reference packages are intentionally ignored.

## Project Layout

```text
.
├── task1-serial-output/
│   ├── task1-1-ws2812/          # WS2812流水彩灯
│   ├── task1-4-uart-tx/         # UART TX, 115200 8N1, 0x55
│   └── scripts/                 # Evidence figure helpers
├── task2-serial-transceiver/
│   ├── task2-1-uart-loopback/   # Bluetooth UART RX/TX loopback and arbitration
│   └── task2-2-fsm-sim/         # Dual-layer FSM ModelSim simulation
├── task3-softcore-logic-analysis/
│   └── src/                     # Counter, PLL, async FIFO, SDFIFO_CTL integration
├── debug-rx-edge/               # RX pin bring-up/debug project
├── debug-rx-scan/               # RX pin scan project
└── HANDOFF_*.md                 # Time-stamped lab handoff snapshots
```

## Current Status

| Task | Scope | Simulation | Quartus compile | Board |
| --- | --- | --- | --- | --- |
| Task1-1 | WS2812流水彩灯 | N/A | Passed | Passed |
| Task1-4 | UART TX, 115200/8N1/0x55 | Passed | Passed | Passed |
| Task2-1 | Bluetooth loopback, UART RX, arbitration | Passed | Passed | Passed |
| Task2-2 | Dual-layer FSM | Passed | N/A | N/A |
| Task3-1 | LPM counter and SignalTap | N/A | Passed | SignalTap capture pending |
| Task3-2 | PLL and reset synchronization | Passed | Passed | Passed |
| Task3-3 | Async FIFO | Passed | Passed | Not required |
| Task3-4 | SDFIFO_CTL controller | Passed | Passed | Not required |

The only known missing course artifact is the Task3-1 SignalTap board capture screenshot. The checked-in Task3 project now compiles with SignalTap enabled.

## Toolchain

Verified local toolchain:

- Quartus Prime Lite / Standard 25.1
- ModelSim SE 2020.4
- Target FPGA: Cyclone IV E, `EP4CE15F17C8`
- JTAG: USB-Blaster
- UART: 115200 baud, 8 data bits, no parity, 1 stop bit

Quartus 9.0 may match older course screenshots, but the checked-in projects are maintained against Quartus 25.1.

## Quick Verification

Task2 full preflight:

```powershell
cd task2-serial-transceiver\task2-1-uart-loopback
powershell -ExecutionPolicy Bypass -File .\tools\preflight-task2.ps1 -Compile
```

Expected marker:

```text
PRE_FLIGHT_OK
```

Task3 simulation and compile preflight:

```powershell
cd task3-softcore-logic-analysis
powershell -ExecutionPolicy Bypass -File .\tools\preflight-task3.ps1 -Compile
```

Expected marker:

```text
TASK3_PRE_FLIGHT_OK
```

## Hardware Notes

For the Task2 Bluetooth UART setup, the confirmed mapping is:

| FPGA signal | FPGA pin | Direction |
| --- | --- | --- |
| `rx_din` | `PIN_B11` | Bluetooth module to FPGA |
| `tx_dout` | `PIN_D6` | FPGA to Bluetooth module |
| `tx_busy_flag_qn` | `PIN_A7` | Debug output |
| `clk` | `PIN_E1` | 50 MHz board clock |
| `nrst` | `PIN_L2` | Active-low reset |
| `tx_en` | `PIN_K1` | Active-low manual TX key |

Do not change Task2 RX back to `PIN_D5`; that was an earlier wiring assumption and is wrong for the confirmed PMOD placement.

## Repository Policy

Tracked:

- Verilog source and testbenches
- Quartus project/settings files needed to rebuild
- ModelSim `.do` scripts and small helper scripts
- Small evidence figures and handoff notes

Ignored:

- Quartus `db/`, `incremental_db/`, `output_files/`, generated reports, and bitstreams
- ModelSim `work/`, `work_*`, `.wlf`, `.mpf`, `.cr.mti`, and transient `wlft*` files
- Vendor reference packages under `ref-bt-module/`
