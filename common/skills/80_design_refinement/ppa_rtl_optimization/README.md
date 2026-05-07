# ppa_rtl_optimization

## Purpose

This skill guides RTL-level performance, power, and area optimization after functional intent is known.

It should be used for constrained optimization, not for speculative broad rewrites.

## When to use

Use this skill when:

- Timing reports show long combinational paths.
- Area reports show expensive muxes, register arrays, duplicated datapath, or inefficient arithmetic.
- Power reports show unnecessary toggling in datapath, memory, or control buses.
- A pipeline, retiming-friendly structure, resource sharing, memory mapping, or clock-enable strategy is needed.
- Optimization must preserve protocol and latency contracts or explicitly update them.

## Optimization areas

- Pipeline insertion and latency management.
- Ready-path and backpressure path breaking.
- Wide mux decomposition.
- Priority encoder or arbiter restructuring.
- High-fanout control replication.
- Arithmetic restructuring and bit-width pruning.
- Resource sharing under proven mutual exclusion.
- Memory macro mapping and banking.
- Operand isolation.
- Clock enable and clock-gating friendly RTL.

## Required evidence

Before recommending changes, collect:

- Functional contract.
- Timing, area, or power report.
- Critical path or hotspot.
- Throughput and latency constraints.
- Verification coverage or regression baseline.
- Equivalence, assertion, or reference model impact.

## Expected outputs

- Optimization diagnosis.
- Candidate options with tradeoffs.
- Recommended RTL change.
- Impact on latency, area, power, timing, and verification.
- Required re-validation steps.
