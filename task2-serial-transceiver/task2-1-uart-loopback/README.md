# Task2-1 UART Loopback + FSM Integration Note

This project is the current hardware-verified UART loopback build for the CY4
board with the WeAct CH9143 BLE/UART PMOD. The hardware top now integrates the
dual-layer FSM and arbitration logic, not only a flat echo path.

## Implemented Task2 Steps

- Step 1: CH9143 Bluetooth/UART serial link at 115200 8N1. Re-scan ports if
  Windows changes the COM number.
- Step 2: dual-layer FSM, verified in ModelSim SE 2020.4.
- Step 3: UART RX module with center-point sampling and false-start filtering.
- Step 4: priority arbitration; `rx_ready` has priority over the K1 request,
  with a one-byte pending buffer while the FSM is busy.

## Current PMOD Wiring Result

For the current PMOD insertion confirmed on the bench, the CY4 pin order is:

```text
A7 B7 B10 A10 B11 A11 D6 D5 G G V V
```

The RX scan bitstream showed that sending data from the active serial port returned `O`, and the
scan mapping was `O = p24 = PIN_B11`. Therefore the verified UART wiring for
this insertion is:

| FPGA signal | FPGA pin | CH9143 side | Direction |
| --- | --- | --- | --- |
| `rx_din` | `PIN_B11` | CH9143 TX | CH9143 to FPGA |
| `tx_dout` | `PIN_D6` | CH9143 RX | FPGA to CH9143 |

Do not use `PIN_D5` for `rx_din` with this PMOD orientation. `PIN_D5` belongs
to the adjacent PMOD position in the observed scan and did not receive serial
traffic for this setup.

## Verified Behavior

- `K1` sends `U` from FPGA TX on `PIN_D6`.
- Serial commands `0`, `1`, `2`, `3`, `A`, and `a` echo back correctly.
- Invalid command `X` is ignored and has no echo.
- If `rx_ready` and K1 request arrive at the same time, the FSM handles
  `rx_ready` first so the just-received byte is not dropped.
- If a new byte arrives while the previous command is waiting for `tx_busy` to
  clear, the FSM stores one pending byte and handles it after the current ACK.

The formal QSF for this project should keep:

```tcl
set_location_assignment PIN_D6 -to tx_dout
set_location_assignment PIN_B11 -to rx_din
```

## Local Simulation Environment

Use ModelSim SE 2020.4 from:

```text
C:\Program Files\ModelSim\win64
```

Keep `LM_LICENSE_FILE` pointed at `C:\Program Files\ModelSim\win64\LICENSE.TXT`
and clear `SALT_LICENSE_FILE` / `SALT_LICENSE_SERVER`. The Quartus 25.1 bundled
`questa_fse\win64\vsim.exe` can report its version but fails simulation license
checkout on this machine.

## Before Downloading to Board

Run the preflight script first:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\preflight-task2.ps1
```

For a full Quartus compile as well:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\preflight-task2.ps1 -Compile
```

Only download the `.sof` after the script prints `PRE_FLIGHT_OK`.
