# Verification Record: 2026-05-21

Environment:

- Quartus Prime 25.1std Lite Edition
- ModelSim
- Target device: Cyclone IV E `EP4CE15F17C8`
- Host shell: Windows PowerShell

## Task2

Command:

```powershell
cd task2-serial-transceiver\task2-1-uart-loopback
powershell -ExecutionPolicy Bypass -File .\tools\preflight-task2.ps1 -Compile
```

Result:

```text
PRE_FLIGHT_OK
Quartus Prime Full Compilation was successful. 0 errors, 8 warnings
```

Checks covered:

- `rx_din = PIN_B11`
- `tx_dout = PIN_D6`
- Dual-layer FSM ModelSim self-test
- UART RX ModelSim self-test
- Quartus full compile

## Task3

Command:

```powershell
cd task3-softcore-logic-analysis
powershell -ExecutionPolicy Bypass -File .\tools\preflight-task3.ps1 -Compile
```

Result:

```text
TASK3_PRE_FLIGHT_OK
Quartus Prime Full Compilation was successful. 0 errors, 29 warnings
```

Checks covered:

- Async FIFO ModelSim self-test
- SDFIFO controller ModelSim self-test
- Quartus full compile with SignalTap enabled
- `altpll` and `dcfifo` megafunction expansion

Known remaining item:

- Task3-1 still needs a board-side SignalTap capture screenshot for the course report.
