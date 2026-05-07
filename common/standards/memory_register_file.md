# Memory and Register File Standard

## Scope

This standard defines RTL guidance for RAM, SRAM wrappers, register files, and memory-like structures.

## Memory wrapper principles

- Large memories should be isolated behind wrappers.
- Wrappers should hide ASIC macro, FPGA BRAM/LUTRAM, and simulation model differences.
- Wrapper interfaces must define read latency, write latency, byte enable behavior, collision behavior, reset behavior, and initialization behavior.
- Simulation models must match the intended synthesis or macro behavior.
- Upper-level logic should not depend on implementation-specific memory internals.

## Common memory port types

- 1RW: single read/write shared port.
- 1R1W: one read port and one write port.
- 2RW: two read/write capable ports.
- Banked SRAM: bank select distributes accesses.
- Multi-pumped RAM: higher frequency internal access, requiring careful clocking and STA.

## Read/write collision semantics

Every memory must define same-address read/write behavior:

- Read returns old data.
- Read returns new data.
- Read returns unknown or don't-care.
- Same-address read/write is illegal and prevented by protocol.

Do not leave collision semantics implicit.

## Reset and initialization

- Do not reset large memory arrays with reset loops unless explicitly required.
- Reset pointers, valid bits, counters, and control metadata instead.
- If contents are architecturally visible after reset, define initialization method.
- FPGA memory initialization must be supported by the synthesis flow.

## Register file guidance

- Small register files may be implemented as flop arrays.
- Medium and large register files should map to SRAM, LUTRAM, or BRAM when possible.
- Asynchronous-read register files can create large muxes and long timing paths.
- Multi-write-port register files grow quickly in area and may require banking, replication, arbitration, or time multiplexing.

## Review questions

- Is memory size appropriate for flop, LUTRAM, BRAM, or SRAM macro?
- Is read latency explicitly documented?
- Is write masking or byte-enable behavior clear?
- Is same-address collision behavior defined?
- Is reset/init behavior consistent with spec?
- Does the wrapper support DFT/BIST/repair needs?
- Does the testbench model match implementation semantics?
