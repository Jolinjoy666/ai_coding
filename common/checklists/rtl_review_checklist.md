# RTL Review Checklist

## Interface

- **Protocol clarity**: Valid-ready, req-ack, credit, AXI/APB/AHB, or custom protocol semantics are documented.
- **Clock domain clarity**: Every input and output has a known clock domain.
- **Reset domain clarity**: Every state element has a known reset domain or documented no-reset reason.
- **Latency clarity**: Input-to-output latency is documented as fixed, variable, or backpressure-dependent.
- **Backpressure clarity**: The module behavior when downstream cannot accept data is defined.
- **Payload stability**: Payload remains stable when valid is asserted and ready is deasserted.
- **Sideband alignment**: ID, last, user, error, mask, and address sidebands travel with the correct data beat.

## Sequential logic

- **Single driver**: Each register is assigned in exactly one sequential block.
- **Nonblocking assignment**: Flop updates use nonblocking assignments.
- **Reset values**: Control and visible state have deterministic reset values.
- **Datapath reset policy**: Unreset datapath is safely masked by valid or initialization protocol.
- **No mixed responsibilities**: Sequential blocks have clear purpose and avoid unnecessary complex reset logic.

## Combinational logic

- **Default assignments**: Outputs and next-state variables have defaults.
- **No unintended latch**: Every combinational path assigns all required outputs.
- **No combinational loop**: Especially ready, grant, ack, valid, and mux-select paths.
- **Case completeness**: Case statements have safe defaults or formal proof of completeness.
- **Priority intent**: `unique`, `unique0`, or `priority` is used only when the intent is true.

## FSM

- **State coverage**: All legal states are handled.
- **Illegal recovery**: Default or explicit recovery path exists.
- **Reset state**: Reset state is valid and safe.
- **Transition correctness**: Start, done, clear, error, flush, and timeout transitions are checked.
- **Output safety**: Outputs do not glitch into unsafe external behavior.

## Counters and control

- **Boundary correctness**: Zero, one, maximum, wrap, and off-by-one cases are checked.
- **Enable behavior**: Counter updates occur only under the correct fire/enable condition.
- **Flush and clear**: Flush or clear behavior is defined when relevant.
- **Deadlock freedom**: Wait states have defined exit conditions or assumptions.
- **Starvation risk**: Arbitration fairness or fixed-priority starvation risk is understood.

## Datapath

- **Width explicitness**: Addition, subtraction, multiplication, shift, concat, and slice widths are explicit.
- **Signedness explicitness**: Signed operations use explicit signed declarations or casts.
- **Overflow semantics**: Wrap, saturate, error, or illegal overflow behavior is defined.
- **Rounding/truncation**: Fixed-point conversion behavior is defined.
- **Pipeline alignment**: Data, valid, control, address, and sideband stages are aligned.

## Memory

- **Mapping intent**: Flop array, LUTRAM, BRAM, or SRAM macro intent is clear.
- **Read latency**: Read latency is documented.
- **Write behavior**: Write enable, byte enable, and mask behavior are clear.
- **Collision semantics**: Same-address read/write behavior is defined.
- **Reset/init**: Memory reset and initialization behavior is appropriate.
- **Wrapper use**: Large or implementation-specific memory is wrapped.

## CDC/RDC

- **Crossing identification**: All clock and reset crossings are identified.
- **Safe structure**: Each crossing uses an appropriate synchronizer, handshake, or async FIFO.
- **Multi-bit safety**: Multi-bit crossings are not independently double-flopped without protocol proof.
- **Reset release**: Async reset release is synchronized per destination domain.
- **Constraints**: Required CDC/RDC constraints, attributes, or waivers are documented.

## PPA

- **Critical path awareness**: Wide arithmetic, muxes, encoders, ready paths, and memory outputs are reviewed.
- **Fanout awareness**: High-fanout control and reset nets are considered.
- **Memory efficiency**: Large memory is not accidentally implemented as flops.
- **Power awareness**: Unnecessary toggling in invalid cycles is considered.
- **Resource sharing**: Shared resources are protected by proven mutual exclusion.

## Verification readiness

- **Directed tests**: Basic, boundary, and error scenarios are identified.
- **Random/backpressure tests**: Stall and interleaving behavior are covered when relevant.
- **Assertions**: Local protocol and invariant assertions are suggested.
- **Reference model impact**: Numerical or visible behavior changes are reflected in the model.
- **Coverage intent**: State, transition, boundary, and error coverage targets are identified.

## Review result categories

Use these result labels:

- **PASS**: Requirement is satisfied.
- **FIX_REQUIRED**: RTL or spec must be changed.
- **ASSUMPTION_REQUIRED**: Design intent must be documented.
- **WAIVER_CANDIDATE**: Warning may be waived with proof.
- **NOT_APPLICABLE**: Item does not apply to this module.
