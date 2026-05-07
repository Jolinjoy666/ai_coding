# rtl_simulation_debug

## Purpose

Create and debug simulator-agnostic RTL/SystemVerilog smoke and directed simulations.

This skill focuses on quickly proving basic RTL behavior before full UVM closure.

## When to use

Use this skill when:

- A new RTL module needs a smoke test.
- A directed SystemVerilog testbench is enough for early validation.
- A failure needs quick waveform or log triage.
- The project has not yet built a full UVM environment.

## Inputs

- RTL source or module description.
- Interface contract and micro-architecture.
- Existing testbench if any.
- Simulator adapter such as VCS, Verilator, Questa, or Xcelium.
- Expected pass/fail behavior.

## Outputs

- Simulation plan.
- Directed test scenarios.
- Simple TB or TB patch suggestions.
- Compile/run commands.
- Wave/log debug plan.
- Failure classification and next action.

## Rules

- Start with the smallest reproducible scenario.
- Check reset, clock, handshake, latency, and expected outputs first.
- Do not assume every mismatch is a DUT bug.
- Preserve logs, seed, command, and wave evidence.
