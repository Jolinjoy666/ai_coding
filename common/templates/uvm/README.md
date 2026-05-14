# UVM Templates

Reusable UVM component templates for digital IC verification.

## Available Templates

### Agents
- `uart_agent.sv.template` - UART agent with driver, monitor, and sequencer
- `apb_agent.sv.template` - APB-Lite agent with driver, monitor, and sequencer

### Transactions
- `uart_transaction.sv.template` - UART transaction with data and error flags

### Drivers and Monitors
- `uart_driver.sv.template` - UART driver for stimulus generation
- `uart_monitor.sv.template` - UART monitor for transaction observation

### Sequences
- `uart_packet_sequence.sv.template` - UART packet sequence with CRC calculation

### Verification Components
- `uart_scoreboard.sv.template` - UART scoreboard with transaction checking and statistics
- `uart_env.sv.template` - UART verification environment with agents and scoreboard

## Usage

These templates provide starting points for common UVM components. Customize them for your specific:

- Interface protocols and transactions
- Verification requirements
- Coverage goals
- Test scenarios

## Customization Points

Each template includes comments indicating where to customize:

1. **Transaction Types** - Define specific transaction classes
2. **Interface Signals** - Adapt to your interface protocol
3. **Checking Logic** - Implement specific comparison rules
4. **Coverage** - Add functional coverage points
5. **Statistics** - Track design-specific metrics

## Integration

To use these templates:

1. Copy the template to your project's DV directory
2. Rename to remove `.template` extension
3. Customize for your specific design
4. Add to your UVM environment
5. Connect to your testbench

## Best Practices

See `common/knowledge_base/uart_design_patterns.md` for UVM verification patterns and best practices.