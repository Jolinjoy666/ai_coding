# CDC/RDC Guidelines

## Scope

This document defines common Clock Domain Crossing and Reset Domain Crossing rules for RTL design and review.

## CDC principles

Every crossing between unrelated or asynchronous clock domains must use an explicit safe structure.

Common safe structures:

- Single-bit level signal: two-flop or multi-flop synchronizer.
- Single-bit pulse: pulse toggle synchronizer or request/ack handshake.
- Multi-bit data: async FIFO, handshake with stable data, or protocol-specific capture.
- Configuration register: stable-before-sample protocol or request/ack handshake.
- High-throughput stream: async FIFO.

## CDC prohibitions

Do not use:

- Independent two-flop synchronizers for a multi-bit bus without protocol proof.
- Pulse synchronization without pulse-width or toggle guarantee.
- Combinational CDC path.
- Unconstrained async crossing.
- Reconvergent synchronized signals without analysis.
- Source-domain assumption not documented in constraints or verification.

## Async FIFO guidance

Async FIFO requires:

- Separate read and write clocks.
- Gray-code pointer crossing.
- Full and empty logic proven safe.
- Correct pointer synchronization depth.
- Reset behavior in each domain.
- Assertions or formal checks for overflow, underflow, full, empty, and pointer monotonicity.

## RDC principles

Reset Domain Crossing must be reviewed when state under one reset can be observed by logic under another reset.

Rules:

- Async reset release must be synchronized into the target clock domain.
- Reset ordering assumptions must be explicit.
- State crossing between reset domains may require isolation or reset handshake.
- Consumers must not observe half-reset state.
- Reset synchronizers need attributes and timing exceptions according to methodology.

## Constraints and attributes

CDC/RDC implementation may require:

- async-reg attributes on synchronizer flops.
- false path constraints for asynchronous reset assertion paths.
- clock group definitions.
- CDC waiver with explicit crossing type, structure, and proof.
- reset release timing constraints or assumptions.

## Verification recommendations

- Add assertions for pulse preservation, handshake completion, FIFO safety, and reset sequencing.
- Use formal for small CDC protocols such as async FIFO, toggle sync, and request/ack.
- Simulate reset sequencing with different domain release orders.
- Review CDC/RDC reports after synthesis if the flow supports it.

## Common bugs

- Multi-bit CDC bus double-flopped bit by bit.
- Reset release not synchronized.
- Pulse lost because destination clock is slower.
- Async FIFO full/empty off by one.
- Source and destination assumptions missing from constraints.
- Waiver hides an actual reconvergence risk.
