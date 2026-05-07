# Pipeline and Timing Standard

## Scope

This standard defines RTL-level practices for timing-convergent pipelines and critical-path management.

## Pipeline principles

- Split long combinational paths into bounded stages.
- Keep valid, control, data, address, and sideband aligned across all stages.
- Document every externally visible latency change.
- Treat pipeline insertion as both a micro-architecture and verification change.
- Reset control and valid bits; payload registers may remain unreset if masked by valid.

## Common critical paths

- Wide adders or adder chains.
- Multiplier output into adder or comparator.
- Priority encoder and arbiter logic.
- Wide mux trees.
- RAM read data into complex datapath.
- High-fanout enable or control signals.
- Cross-module combinational ready paths.
- Signed compare plus mux plus arithmetic chain.

## Timing optimization methods

- Insert pipeline registers.
- Register SRAM outputs.
- Split wide muxes into smaller stages.
- Predecode control signals.
- Replicate high-fanout control registers when justified.
- Use one-hot control where decode timing dominates.
- Move address calculation earlier.
- Use carry-save or staged adder trees.
- Use skid buffers to break ready paths.
- Use multicycle paths only when protocol proof and STA constraints are valid.

## Latency documentation

For each pipeline:

- Define input-to-output latency.
- Define whether latency is fixed or variable.
- Define how stalls affect latency.
- Define which sideband fields travel with data.
- Define reset/flush behavior.
- Define how errors are pipelined.

## Review questions

- Are all control and data signals aligned?
- Does valid represent the same pipeline stage as payload?
- Does backpressure stop all affected state consistently?
- Is the ready path bounded and loop-free?
- Is the latency change reflected in testbench and reference model?
- Does the optimization require new assertions or coverage?
