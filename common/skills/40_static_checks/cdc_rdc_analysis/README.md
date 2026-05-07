# cdc_rdc_analysis

## Purpose

This skill reviews Clock Domain Crossing and Reset Domain Crossing risks in RTL designs.

It focuses on whether crossings are explicitly implemented with safe structures, whether reset release is controlled, and whether constraints or waivers are technically justified.

## When to use

Use this skill when:

- A design has multiple clocks or resets.
- Signals cross between unrelated or asynchronous clock domains.
- Reset release timing may affect visible state.
- CDC/RDC reports contain violations or waivers.
- Adding async FIFO, pulse synchronizer, level synchronizer, request/ack handshake, or reset synchronizer.

## Supported crossing patterns

- Single-bit level synchronizer.
- Pulse toggle synchronizer.
- Request/ack handshake.
- Stable configuration bus sampling.
- Async FIFO with gray-code pointers.
- Reset synchronizer for async assert and sync release.
- Isolation or reset handshake between reset domains.

## High-risk patterns

- Multi-bit bus synchronized with independent two-flop chains.
- Pulse synchronized without width guarantee.
- Combinational CDC path.
- Reset release consumed by another active domain without synchronization.
- Reconvergent synchronized signals without protocol proof.
- Async FIFO pointer logic without gray-code and full/empty proof.

## Expected outputs

- Clock/reset domain map.
- Crossing classification.
- Risk assessment.
- Recommended synchronizer or protocol.
- Constraint and attribute notes.
- Verification or formal check suggestions.
