# vcs_regression_debug

## Purpose

This skill debugs VCS compile, elaboration, run, waveform, and regression failures.

It focuses on root-cause analysis from logs, seeds, run directories, UVM reports, scoreboard mismatches, DPI/PLI issues, and waveform availability.

## When to use

Use this skill when:

- `vcs` compile fails.
- Elaboration fails after compilation.
- `simv` fails at runtime.
- UVM reports `UVM_FATAL` or unexpected `UVM_ERROR`.
- Scoreboard mismatch appears.
- Simulation hangs or times out.
- FSDB is not generated or Verdi cannot open waves.
- A random seed fails intermittently.
- A regression summary contains failing tests or seeds.

## Required inputs

- Failing command.
- Compile log and run log.
- Test name and seed.
- Relevant Makefile and filelist snippets.
- Recent RTL/TB changes.

Optional inputs:

- Waveform path.
- Regression summary.
- UVM report server output.
- Scoreboard mismatch transaction dump.
- Reference model logs.
- VCS/Verdi version and environment variables.

## Debug principles

- Start from the first real error, not the last cascading error.
- Preserve failing run directories and seeds.
- Classify failure as flow, compile, elaboration, link, TB, DUT, reference model, scoreboard, environment, or license issue.
- Use the smallest reproducible test and seed.
- Do not change RTL until evidence indicates a DUT issue.
- Do not delete logs, waves, inputs, or golden data while debugging.

## Expected outputs

- Failure classification.
- Most likely root cause.
- Evidence from logs or wave/debug data.
- Recommended fix or next diagnostic command.
- Reproduction command.
- Rerun command after fix.
- Risk notes.
