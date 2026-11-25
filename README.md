# ARM-AMBA-APB3-Slave-RTL-Self-Checking-SystemVerilog-Verification-
Synthesizable ARM AMBA 3 APB Slave (16 x 32-bit registers) paired with a layered, self-checking SystemVerilog OOP verification environment, concurrent SVA protocol checkers, and functional coverage (`covergroup`).

## Verification Architecture
- **Interface (`apb_if`):** Parameterized bundle connecting `PCLK`, `PRESETn`, `PSEL`, `PENABLE`, `PWRITE`, `PADDR`, `PWDATA`, `PRDATA`, `PREADY`, and `PSLVERR`.
- **Transaction (`apb_transaction`):** Randomized Read/Write operations, 4-bit addresses (`0x0`–`0xF`), and 32-bit payloads.
- **Driver (`drive_apb_transfer`):** Cycle-accurate 2-phase APB handshake (`SETUP` -> `ACCESS`).
- **Scoreboard (`apb_scoreboard`):** Mirrors internal registers and validates every read transaction (`0` errors).
- **SVA & Coverage (`apb_coverage`):** Enforces `PENABLE`–`PSEL` rules and `PADDR`/`PWRITE` phase stability; achieves **100% cross-coverage** across all 16 registers x Read/Write operations.

## How to Run (Verilator)
```bash
verilator --binary --timing --assert --coverage -Wall -Wno-fatal 
