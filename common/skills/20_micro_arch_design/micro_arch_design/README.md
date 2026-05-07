# micro_arch_design

## Purpose

Convert a selected architecture into implementable micro-architecture documentation for RTL and verification.

This skill defines module boundaries, interfaces, parameters, FSMs, datapath, memory behavior, pipeline, latency, reset, CDC/RDC, assertions, and test intent.

## When to use

Use this skill after architecture selection and before RTL generation.

## Inputs

- Selected architecture.
- Structured requirements.
- Interface and integration constraints.
- PPA and timing targets.
- Verification expectations.

## Outputs

- Module decomposition.
- Interface contracts.
- Parameter definitions.
- FSM descriptions.
- Datapath and pipeline descriptions.
- Memory/register behavior.
- Reset and CDC/RDC strategy.
- Latency and throughput contract.
- Assertion and testplan seed.

## Rules

- Micro-architecture must be specific enough to implement RTL.
- Every externally visible behavior must be documented.
- Latency, backpressure, reset, memory collision, and error semantics must be explicit.
- Verification implications must be captured before RTL starts.
