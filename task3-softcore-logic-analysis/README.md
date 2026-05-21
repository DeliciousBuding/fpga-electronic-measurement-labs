# Task3 Softcore Customization and Logic Analysis

Course scope: Chapter 4, Task 3, "softcore customization and logic analysis".

This project is the current executable Task3 handoff. It now uses real Quartus megafunction/IP wrappers for the PLL and FIFO paths, while keeping behavioral `SIM` models for ModelSim self-tests:

- Step 1: `lpm_counter_demo`, an LPM_COUNTER-equivalent wrapper exposing `clock`, `aclr`, `clk_en`, `cnt_en`, `sset`, `q`, and `cout` for SignalTap observation.
- Step 2: `task3_pll_ip`, an `altpll` megafunction wrapper. Input is 50 MHz; outputs are `c0=50 MHz`, `c1=100 MHz`, and `c2=100 MHz` with 90 degree phase shift. `locked` is used by reset synchronizers.
- Step 3: `task3_dcfifo_ip`, a `dcfifo` megafunction wrapper. It is configured as 16-bit, 512-word, dual-clock FIFO with EAB memory and synchronizer pipelines.
- Step 4: `sdfifo_ctl`, a data-flow controller following the course rules: write priority over read, start RAM write when `wr_fifo_usedw >= 8`, start UART output when `rd_fifo_usedw >= 4`.

The current top entity is `task3_top`. It is intended as a bring-up and SignalTap target, not the final SDRAM task. Task4 in the slides starts SDRAM controller work separately.

## Files

- `src/task3_pll_ip.v`: real `altpll` wrapper for Quartus synthesis; simulation uses the local PLL behavior model.
- `src/task3_dcfifo_ip.v`: real `dcfifo` wrapper for Quartus synthesis; simulation uses `async_fifo`.
- `src/async_fifo.v`: behavioral FIFO model used by `SIM` builds.
- `src/task3_soft_modules.v`: counter, PLL simulation model, reset synchronizer, UART TX helper.
- `src/sdfifo_ctl.v`: data-flow transfer controller.
- `src/task3_top.v`: top-level integration.
- `sim/tb_async_fifo.v`: ModelSim FIFO self-test.
- `sim/tb_sdfifo_ctl.v`: ModelSim controller self-test.
- `run.do`: ModelSim batch run.
- `tools/preflight-task3.ps1`: simulation and optional Quartus compile check.

## Verify

Run simulation only:

```powershell
cd task3-softcore-logic-analysis
powershell -ExecutionPolicy Bypass -File .\tools\preflight-task3.ps1
```

Run simulation and Quartus compile:

```powershell
cd task3-softcore-logic-analysis
powershell -ExecutionPolicy Bypass -File .\tools\preflight-task3.ps1 -Compile
```

Expected final marker:

```text
TASK3_PRE_FLIGHT_OK
```

Latest verified result, 2026-05-18 13:58:

- ModelSim: both self-tests passed, 0 errors / 0 warnings.
- Quartus: full compilation passed, 0 errors / 27 warnings.
- Generated bitstream: `output_files/task3.sof`.
- Quartus confirmed real IP expansion:
  - `altpll` generated `db/task3_pll_ip_altpll.v`.
  - `dcfifo` generated `db/dcfifo_*.tdf` plus internal Gray counter/synchronizer files.
  - Timing analyzer derived PLL clocks for `clk[0]` 50 MHz, `clk[1]` 100 MHz, and `clk[2]` 100 MHz with 90 degree phase shift.

The remaining warnings are not fatal for the current bring-up:

- `debug_toggle` outputs PLL `c2` through a normal output pin for oscilloscope observation, so Quartus warns about non-dedicated PLL output routing. This is acceptable for a lab observation pin, not for a production clock distribution path.
- Upper FIFO data bits may be optimized away in paths where the UART only uses the low byte. Keep this in mind when choosing SignalTap nodes.

## SignalTap Nodes To Add

Use `clk` as the initial 50 MHz sample clock.

Recommended nodes:

- Counter: `u_counter|q`, `u_counter|cout`, `slow_div`
- PLL/reset: `c0`, `c1`, `c2`, `pll_locked`, `sys_rst_n`, `fast_rst_n`, `c2_probe_toggle`
- Write FIFO: `wr_fifo_wrreq`, `wr_fifo_full`, `wr_fifo_wr_usedw`, `ctl_wr_fifo_rdreq`, `wr_fifo_rd_usedw`
- Read FIFO: `ctl_rd_fifo_wrreq`, `rd_fifo_full`, `rd_fifo_wr_usedw`, `rd_fifo_rdreq`, `rd_fifo_rd_usedw`
- Controller: `ctl_state_dbg`, `wr_done_dbg`, `ram_wr_req`, `ram_rd_req`
- UART: `uart_req`, `uart_busy`, `uart_done`, `tx_dout`

For board validation, enable Power-Up Trigger when trying to catch the early FIFO write burst.

## Board Notes

- `debug_toggle` is assigned to `PIN_A7` and currently outputs PLL `c2`, a 100 MHz clock with 90 degree phase shift relative to `c1`.
- Do not leave the Bluetooth PMOD driving or loading `PIN_A7` while using it as a PLL scope output.
- `tx_dout` remains on `PIN_D6`.
