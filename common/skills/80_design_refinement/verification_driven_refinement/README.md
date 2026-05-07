# verification_driven_refinement

## Purpose

Modify RTL, micro-architecture, testbench, reference model, assertions, or documentation based on verification feedback.

This skill closes the loop from simulation/regression results back to design and DV updates.

## When to use

Use this skill when:

- A test or regression failure has a classified root cause.
- RTL must be fixed based on verified evidence.
- Testbench, scoreboard, reference model, or coverage must be updated.
- A spec or micro-architecture ambiguity is discovered during verification.

## Inputs

- Failure analysis or debug report.
- Relevant RTL/DV/reference model files.
- Spec and micro-architecture context.
- Logs, waves, assertions, or mismatch evidence.

## Outputs

- Scoped change plan.
- RTL/DV/spec patch recommendation or implementation.
- Updated assumptions and documentation notes.
- Required rerun tests and static checks.
- Regression risk summary.

## Rules

- Fix root cause, not symptoms.
- Keep changes scoped.
- Do not change visible behavior without updating spec, reference model, tests, and coverage.
- Always provide rerun commands after refinement.
