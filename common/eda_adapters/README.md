# eda_adapters

Unified wrappers for EDA tool invocation.

The goal is to let project workflows call stable commands such as:

- `make lint`
- `make compile`
- `make sim`
- `make regress`
- `make coverage`

## Available adapters

- `vcs.md`: Synopsys VCS adapter reference for RTL/SystemVerilog/UVM simulation.

## Planned adapters

Adapters can later be added for open-source and commercial tools:

- Verilator
- Verible
- Yosys
- GTKWave
- cocotb
- Questa
- Xcelium
- SpyGlass
