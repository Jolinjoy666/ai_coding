# AI Project Context: Uart_Controller

## Bootstrap summary

- **Project name**: `Uart_Controller`
- **Block name**: `uart_packet_controller`
- **Design type**: `digital_peripheral`
- **Target language**: SystemVerilog
- **Target simulator**: `vcs`
- **Created from**: design specification (DESIGN_SPEC.md)

## Source of truth

- Design spec: `spec/DESIGN_SPEC.md`
- Project metadata: `project.yaml`
- Common workflow root: `../common/workflows`
- Common skill root: `../common/skills`

## Current workflow stage

```text
project_bootstrap_from_spec
```

## Next recommended stage

```text
rtl_generation
```

## Design parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| CLK_FREQ_HZ | 50_000_000 | System clock frequency |
| BAUD_RATE | 115_200 | UART baud rate |
| OVERSAMPLE | 16 | UART RX oversampling ratio |
| DATA_WIDTH | 8 | UART byte width (fixed) |
| FIFO_DEPTH | 32 | RX/TX FIFO depth (power of 2) |
| MAX_PAYLOAD_BYTES | 16 | Max command/response payload bytes |
| MEM_ADDR_WIDTH | 4 | Internal memory window address width |
| APB_ADDR_WIDTH | 8 | APB byte address width |
| APB_DATA_WIDTH | 32 | APB data width (fixed) |
| TIMEOUT_BITS | 16 | Parser inter-byte timeout counter width |
| INTER_BYTE_TIMEOUT | 50_000 | Max cycles between packet bytes |

## Target modules (14)

1. uart_packet_controller - Top-level integration
2. apb_lite_slave - APB-Lite slave frontend
3. baud_tick_gen - Baud tick generator
4. uart_rx - UART receiver
5. uart_tx - UART transmitter
6. byte_fifo - Synchronous FIFO
7. crc8_stream - CRC-8 stream processor
8. packet_parser - Packet parser with validation
9. command_arbiter - UART/APB arbitration
10. command_engine - Command execution
11. reg_file - Register file
12. memory_window - Byte-addressable memory
13. response_builder - Response packet assembly
14. irq_status_ctrl - IRQ status control

## Key interfaces

- UART RX/TX (serial)
- APB-Lite (parallel bus)
- Byte stream (internal valid/ready)
- Decoded command (internal valid/ready)
- Response (internal valid/ready)
- Shared register/memory request (internal valid/ready)

## AI operating rules for this project

- Preserve design spec exactly.
- Put generated RTL drafts under `rtl/generated/` until reviewed.
- Put reviewed RTL under `rtl/src/`.
- Keep project-specific scripts under `tools/` or `sim/`.
- Keep reusable assets under `../common`, not inside this project.
- Record major assumptions and decisions in `ai/` or `docs/`.
- Do not overwrite existing source or reports without checking.

## Open questions

- None currently. All design decisions are specified in DESIGN_SPEC.md.
