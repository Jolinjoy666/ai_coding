# UART Design Patterns

## Overview

This document describes common UART design patterns extracted from the Uart_Controller project. These patterns can be reused for similar UART implementations.

## 1. UART Receiver (RX) Pattern

### Key Components
- Double-flop synchronizer for metastability protection
- Oversampling state machine (IDLE → START → DATA → STOP → DONE)
- Bit counter and sample counter
- Shift register for data collection

### Design Rules
- Always use double-flop synchronizer for external inputs
- Sample data at the middle of each bit period (OVERSAMPLE/2)
- Check stop bit validity for framing error detection
- Support back-to-back frame reception

### State Machine
```
IDLE → (detect start bit) → START → (verify start bit) → DATA → (receive all bits) → STOP → (verify stop bit) → DONE → IDLE
```

## 2. UART Transmitter (TX) Pattern

### Key Components
- Shift register for data serialization
- Bit counter
- Baud rate tick generation

### Design Rules
- Maintain idle high state when not transmitting
- LSB first transmission
- Generate proper start and stop bits
- Support continuous transmission

### State Machine
```
IDLE → (data available) → START → (baud tick) → DATA → (all bits sent) → STOP → (baud tick) → DONE → IDLE
```

## 3. Synchronous FIFO Pattern

### Key Components
- Dual-port memory array
- Read and write pointers
- Count logic for full/empty detection

### Design Rules
- Use power-of-2 depth for efficient pointer wrapping
- Implement separate read and write enables
- Provide full, empty, and level outputs
- Handle simultaneous read/write correctly

### Pointer Management
```systemverilog
// Write pointer update
if (wr_en && !full) begin
  mem[wr_ptr] <= wr_data;
  wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
end

// Read pointer update
if (rd_en && !empty) begin
  rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
end
```

## 4. CRC-8 Stream Pattern

### Key Components
- CRC register
- Update function with polynomial division

### Design Rules
- Support initialization, update, and output
- Use standard CRC-8 polynomial (x^8 + x^2 + x + 1)
- Implement byte-serial processing
- No reflection or final XOR for simplicity

### Update Function
```systemverilog
function automatic logic [7:0] crc8_update(input logic [7:0] crc, input logic [7:0] data);
  logic [7:0] result;
  result = crc ^ data;
  for (int i = 0; i < 8; i++) begin
    if (result[7])
      result = (result << 1) ^ 8'h07;
    else
      result = result << 1;
  end
  return result;
endfunction
```

## 5. Packet Parser Pattern

### Key Components
- State machine for packet field extraction
- CRC calculator for validation
- Timeout counter for error detection
- Error status register

### Design Rules
- Ignore noise bytes before start byte
- Validate each field as it's received
- Support timeout detection for inter-byte gaps
- Generate appropriate error codes for different failure modes

### State Machine
```
IDLE → SEQ → CMD → LEN → PAYLOAD → CRC → END → DONE
  ↓                                              ↓
ERROR ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ←
```

## 6. Command Engine Pattern

### Key Components
- Command decoder
- Shared resource requester
- Response generator
- Status tracking

### Design Rules
- Support multiple command opcodes
- Implement proper resource arbitration
- Track command status and errors
- Generate appropriate responses

### Execution Flow
```
IDLE → (command valid) → EXECUTE → (resource request) → WAIT_RESP → (response ready) → RESPONSE → IDLE
```

## 7. Response Builder Pattern

### Key Components
- State machine for packet construction
- CRC calculator for generation
- TX FIFO interface

### Design Rules
- Construct response according to protocol
- Include sequence echo for correlation
- Generate CRC over all payload bytes
- Support variable-length payloads

### State Machine
```
IDLE → START → SEQ → CMD → STATUS → LEN → PAYLOAD → CRC → END → DONE
```

## 8. UVM Agent Pattern

### Key Components
- Driver for stimulus generation
- Monitor for observation
- Sequencer for sequence management

### Design Rules
- Support active and passive modes
- Connect driver to sequencer
- Provide analysis port from monitor
- Use factory override for customization

## 9. Scoreboard Pattern

### Key Components
- Analysis implementations for different transaction types
- Expected response queue
- Register shadow model
- Statistics counters

### Design Rules
- Compare actual vs expected responses
- Track design statistics
- Report pass/fail status
- Support multiple transaction types

## 10. Verification Environment Pattern

### Key Components
- Agents for different interfaces
- Scoreboard for checking
- Environment configuration

### Design Rules
- Create agents for each interface
- Connect monitors to scoreboard
- Support configuration via factory
- Provide clean phase structure

## Best Practices

### RTL Design
1. Use explicit state machines for complex control logic
2. Implement proper reset behavior
3. Use nonblocking assignments in sequential logic
4. Provide clear interface contracts
5. Support parameterization for reusability

### Verification
1. Use UVM for standardized verification methodology
2. Implement coverage-driven verification
3. Use assertions for protocol checking
4. Support multiple test scenarios
5. Provide comprehensive reporting

### Documentation
1. Document interface protocols
2. Specify timing requirements
3. Describe error handling
4. Provide usage examples
5. Include verification plans