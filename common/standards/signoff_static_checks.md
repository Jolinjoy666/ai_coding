# Signoff-Oriented Static Checks

## Scope

This document summarizes front-end static checks that influence RTL signoff readiness.

## Lint focus

Check for:

- Inferred latch.
- Multiple drivers.
- Undriven signal.
- Unused signal with suspicious intent.
- Uninitialized register.
- Width mismatch.
- Signed/unsigned mismatch.
- Incomplete case.
- Unreachable state.
- Combinational loop.
- Blocking/nonblocking misuse.
- Non-synthesizable construct.
- Reset or clocking ambiguity.

## CDC focus

Check for:

- Unsynchronized crossing.
- Multi-bit crossing risk.
- Pulse loss risk.
- Reconvergence risk.
- Async FIFO pointer correctness.
- Reset crossing.
- Generated or gated clock crossing.
- Missing constraints or attributes.

## RDC focus

Check for:

- Async reset release into active logic.
- Reset domain ordering assumptions.
- State consumed while producer is reset.
- Isolation missing between reset domains.
- Reset synchronizer constraints and attributes.

## STA focus

Check for:

- Clock definitions.
- Generated clocks.
- Input and output delays.
- False paths.
- Multicycle paths.
- Clock groups.
- Reset paths.
- High-fanout nets.
- Max transition and max capacitance.
- Memory macro timing arcs.

## LEC focus

Check for:

- Uninitialized flop handling.
- Retiming impact.
- Clock-gating insertion.
- Memory mapping.
- Scan insertion.
- Boundary optimization.
- Black-box and wrapper equivalence.

## Waiver policy

A waiver should include:

- Tool message ID.
- Affected file and signal.
- Reason the warning is safe.
- Design intent or proof.
- Owner and date.
- Expiration or review condition.

Do not waive functional ambiguity, CDC/RDC uncertainty, or reset hazards without proof.
