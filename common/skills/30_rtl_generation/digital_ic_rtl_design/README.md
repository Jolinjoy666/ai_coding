# digital_ic_rtl_design

## Purpose

This skill guides AI-assisted generation, modification, and review of synthesizable digital IC RTL for ASIC and FPGA projects.

It focuses on production-oriented Verilog/SystemVerilog RTL that is functionally correct, synthesizable, timing-aware, verification-friendly, PPA-conscious, and maintainable.

## When to use

Use this skill when working on:

- New RTL modules such as datapath, control path, FIFO, arbiter, crossbar, DMA, register file, SRAM wrapper, protocol adapter, or pipeline block.
- Functional RTL changes involving FSMs, counters, handshake protocols, data formats, memory behavior, or pipeline latency.
- RTL review before lint, simulation, synthesis, CDC/RDC, or integration.
- Mismatch debug where RTL behavior differs from spec, reference model, simulation, synthesis result, FPGA bring-up, or silicon observation.
- Early signoff preparation where RTL must be checked with lint, CDC/RDC, STA assumptions, DFT, LEC, coverage, and verification closure in mind.

## Priority order

1. Functional correctness against architecture spec, protocol spec, and reference model.
2. Synthesizability with mainstream ASIC/FPGA tools.
3. Timing convergence through clear register boundaries and bounded combinational paths.
4. Verification reproducibility with tests, assertions, formal targets, and coverage intent.
5. PPA optimization after correctness is preserved.
6. Engineering maintainability with clear interface contracts, naming, parameterization, and traceable changes.

## Required inputs

The skill should request or infer the following before changing RTL:

- User spec or structured requirements.
- Selected architecture and micro-architecture documents.
- Interface contract including clock/reset domain, protocol, latency, backpressure, sideband, and error behavior.
- Parameters such as width, depth, ID count, burst length, pipeline stage count, and target throughput.
- Reset strategy and CDC/RDC assumptions.
- Memory behavior including read/write latency, collision behavior, byte enable, and initialization policy.
- Existing RTL and testbench context when modifying a design.

## Expected outputs

The skill should produce or update:

- Synthesizable SystemVerilog RTL.
- Notes on interface contract, latency, reset, CDC/RDC, and memory assumptions.
- Assertions or assertion recommendations for protocol and boundary conditions.
- Verification recommendations covering directed tests, random tests, assertions, formal checks, coverage, lint, CDC/RDC, and simulation.
- RTL review summary using the common review checklist.

## Required references

Before generating or modifying RTL, reference these shared documents when relevant:

- `common/standards/systemverilog_rtl_coding.md`
- `common/standards/reset_and_clocking.md`
- `common/standards/fsm_design.md`
- `common/standards/ready_valid_protocol.md`
- `common/standards/pipeline_timing.md`
- `common/standards/cdc_rdc_guidelines.md`
- `common/standards/memory_register_file.md`
- `common/standards/rtl_arithmetic_fixed_point.md`
- `common/standards/assertion_verification_guidelines.md`
- `common/checklists/rtl_review_checklist.md`

## Execution rules

- Confirm the design contract before implementation.
- Do not perform unrelated refactoring.
- Prefer explicit synthesizable hardware structure over clever or ambiguous code.
- Use `always_ff` for sequential logic and `always_comb` for combinational logic.
- Use nonblocking assignments in sequential logic and blocking assignments in combinational logic.
- Give all combinational outputs default assignments.
- Use explicit bit widths and signed casts for arithmetic.
- Keep control, data, valid, address, and sideband latency aligned.
- Treat any latency change as an interface change that must be documented and verified.
- Make CDC/RDC structures explicit; do not rely on assumptions.
- Do not reset large memories through flop-style reset loops unless the spec explicitly requires it.
- If numerical behavior changes, require reference model updates.
- After implementation, state which checks should be run.

## Done definition

An RTL task using this skill is complete only when:

- The implemented behavior is traceable to spec or micro-architecture requirements.
- Interface assumptions are documented.
- Reset, CDC/RDC, latency, memory, and arithmetic semantics are explicit.
- RTL passes self-review against the checklist.
- Verification and static-check next steps are provided.
