# CLAUDE.md — FPGA Lab Monorepo

## Scope

This repository contains FPGA lab projects for the Electronic Measurement course, targeting Cyclone IV E (EP4CE15F17C8).

## Toolchain

| Tool | Purpose |
|------|---------|
| Quartus Prime 25.1 Lite | Synthesis, place & route, programming |
| ModelSim | Simulation |
| Flutter | Mobile app development |

## Pin Constraints (verified)

| Signal | Pin | Dir | Note |
|--------|-----|-----|------|
| `clk` | PIN_E1 | In | 50 MHz |
| `nrst` | PIN_L2 | In | Low active |
| `rx_din` | PIN_B11 | In | CH9143 TX |
| `tx_dout` | PIN_D6 | Out | CH9143 RX |
| `led_din` | PIN_T2 | Out | WS2812 |

## Monorepo Modules

- `final-rgb-controller/` — Final project FPGA (Verilog)
- `app/` — Flutter BLE controller app
- `task1-serial-output/` — Milestone, read-only
- `task2-serial-transceiver/` — Milestone, read-only
- `task3-softcore-logic-analysis/` — Milestone, read-only
- `docs/` — Project documentation

## Development Rules

1. New Verilog modules in dedicated files, simulate before integration
2. Reuse verified task1/task2 modules without invasive changes
3. Git commit granularity: one independent module per commit
4. Hardware debug: ModelSim → Quartus compile → on-board test
