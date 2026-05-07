# architecture_option_generation

## Purpose

Generate and compare candidate architectures for a digital IC block based on structured requirements.

This skill explores tradeoffs before committing to micro-architecture or RTL.

## When to use

Use this skill when:

- Requirements are available but architecture is not selected.
- Multiple implementations are possible.
- PPA, latency, throughput, complexity, reuse, or verification tradeoffs matter.
- The project needs a decision record before micro-architecture design.

## Inputs

- Structured requirements.
- Constraints and assumptions.
- Performance, power, area, latency, throughput, and clock targets.
- Integration or interface constraints.
- Reuse/IP availability.

## Outputs

- Architecture options.
- Tradeoff matrix.
- Recommended architecture.
- Decision rationale.
- Risks and mitigations.
- Impact on RTL, verification, CDC/RDC, memory, and signoff.

## Rules

- Generate meaningfully different options, not cosmetic variants.
- Compare options against requirements.
- State what each option optimizes and sacrifices.
- Do not select an option without exposing risks and assumptions.
