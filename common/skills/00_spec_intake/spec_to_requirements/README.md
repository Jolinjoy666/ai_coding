# spec_to_requirements

## Purpose

Convert raw user intent, informal specification, protocol notes, and constraints into structured IC design requirements.

This is the first skill in the local AI IC design workflow. It creates a stable requirements baseline that later architecture, micro-architecture, RTL, DV, and signoff work can reference.

## When to use

Use this skill when:

- Starting a new IC design project.
- Receiving an incomplete or ambiguous user spec.
- Converting natural-language requirements into structured requirements.
- Identifying assumptions, open questions, risks, and verification targets.
- Preparing material for architecture exploration.

## Inputs

- Raw user spec or design request.
- Protocol or interface notes.
- Performance, power, area, clock, reset, and technology constraints.
- Existing IP or integration constraints.
- Verification or signoff expectations.

## Outputs

- Structured requirements.
- Clarified scope and non-scope.
- Interface and protocol assumptions.
- Performance/latency/throughput targets.
- Reset, clock, CDC/RDC, memory, and error-handling assumptions.
- Open questions.
- Risk list.
- Initial verification intent.

## Rules

- Do not invent requirements silently.
- Separate confirmed facts, assumptions, and open questions.
- Preserve the original user intent.
- Convert vague words into measurable requirements where possible.
- Mark contradictions explicitly.
- Do not proceed to architecture when blocking requirements are unresolved.
