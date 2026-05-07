# Assertion and Verification Guidelines

## Scope

This document defines RTL-oriented assertion and verification recommendations.

## RTL assertion policy

Assertions in RTL should be guarded from synthesis unless the project has a specific assertion synthesis methodology.

Recommended style:

```systemverilog
`ifndef SYNTHESIS
assert property (@(posedge clk) disable iff (!rst_n)
    in_valid && !in_ready |-> $stable(in_data)
);
`endif
```

## Good RTL assertion targets

- Ready/valid payload stability.
- FIFO overflow and underflow.
- Buffer full/empty consistency.
- One-hot or one-hot0 controls.
- FSM illegal state recovery.
- Request eventually acknowledge under defined assumptions.
- Memory illegal conflict prevention.
- Credit counter bounds.
- Address range bounds.
- Numeric overflow when overflow is illegal.

## Verification layers

Use multiple layers:

- Directed tests for basic function and boundary cases.
- Random tests for combinations and backpressure.
- Assertions for protocol and local invariants.
- Formal checks for FIFO, arbiter, handshake, CDC protocol, and bounded control properties.
- Coverage for state, transition, boundary, error, and protocol scenarios.
- Gate-level simulation when reset, X-prop, scan, or timing annotation must be validated.
- LEC to ensure synthesis transformations preserve behavior.

## Testbench impact of RTL changes

Update verification assets when changing:

- Visible function.
- Pipeline latency.
- Error behavior.
- Reset behavior.
- Memory collision semantics.
- Numeric rounding, truncation, saturation, or overflow behavior.
- Protocol timing or backpressure.

## Coverage guidance

Coverage should track:

- FSM states and transitions.
- Counter boundaries.
- FIFO empty/full/almost states.
- Backpressure combinations.
- Error and recovery paths.
- Memory collision or illegal access cases.
- Numeric min/max/overflow/saturation cases.
