# regression_failure_analysis

## Purpose

Analyze regression failures independent of a specific simulator.

This skill triages failures across tests, seeds, logs, waves, coverage, assertions, scoreboards, and recent changes.

## When to use

Use this skill when:

- A regression has one or more failing tests or seeds.
- Failures need classification before modifying RTL or DV.
- A failure may be DUT, TB, reference model, flow, environment, or test issue.
- Coverage or pass-rate trends need interpretation.

## Inputs

- Regression summary.
- Failing logs.
- Test names and seeds.
- Recent RTL/DV changes.
- Known waivers or expected failures.
- Waveform or transaction dumps when available.

## Outputs

- Failure clustering.
- Root-cause hypotheses.
- Reproduction commands.
- Debug priority order.
- Recommended owner area: RTL, TB, reference model, flow, or spec.
- Fix and rerun plan.

## Rules

- Cluster by root cause, not just by test name.
- Preserve failing seeds and logs.
- Do not modify design before classifying failure evidence.
- Separate real failures from infrastructure noise.
