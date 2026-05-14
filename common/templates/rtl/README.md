# RTL Templates

Reusable RTL module templates for digital IC design.

## Available Templates

### Communication Interfaces
- `uart_rx.sv.template` - UART receiver with oversampling and framing error detection
- `uart_tx.sv.template` - UART transmitter with baud rate generation
- `baud_tick_gen.sv.template` - Baud rate tick generator with oversampling
- `apb_lite_slave.sv.template` - APB-Lite slave interface with wait states

### Storage Elements
- `byte_fifo.sv.template` - Synchronous FIFO with configurable depth and width

### Processing Elements
- `crc8_stream.sv.template` - CRC-8 stream calculator with standard polynomial
- `packet_parser.sv.template` - Generic packet parser with CRC validation and timeout
- `command_engine.sv.template` - Command execution engine with shared resource access
- `command_arbiter.sv.template` - Command arbiter for shared resource access
- `response_builder.sv.template` - Response packet builder with CRC generation

### Register and Memory
- `reg_file.sv.template` - Register file with read-clear and memory debug
- `memory_window.sv.template` - Byte-addressable memory window with address validation

### Control and Status
- `irq_status_ctrl.sv.template` - IRQ status controller with sticky bits and masking

### Top-Level Integration
- `uart_packet_controller.sv.template` - Complete UART packet controller with APB-Lite interface

## Usage

These templates provide starting points for common RTL modules. Customize them for your specific:

- Protocol requirements (start/end bytes, opcodes, status codes)
- Interface widths and depths
- Timing requirements
- Error handling behavior

## Customization Points

Each template includes comments indicating where to customize:

1. **Parameters** - Adjust widths, depths, and timing values
2. **Constants** - Modify protocol-specific bytes and codes
3. **State Machine** - Adapt states and transitions as needed
4. **Error Handling** - Configure error codes and behaviors
5. **Interface Signals** - Add or modify ports as required

## Design Patterns

See `common/knowledge_base/uart_design_patterns.md` for detailed design patterns and best practices.