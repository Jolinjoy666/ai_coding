# rtl_static_check

## Purpose

This skill analyzes RTL static-check results and prepares RTL for lint, compile, CDC/RDC, basic synthesis, and signoff-oriented review.

It does not replace EDA tools. Its role is to classify reports, identify likely root causes, recommend fixes, and connect static-check findings back to RTL design intent.

## When to use

Use this skill when:

- Running lint or compile checks on RTL.
- Reviewing errors or warnings from Verilator, Verible, VCS, Questa, Xcelium, SpyGlass, or other tools.
- Checking synthesizability issues before simulation or integration.
- Preparing RTL for CDC, RDC, STA, DFT, LEC, or synthesis.
- Triaging warnings that may require waiver, RTL fix, constraint update, or design clarification.

## Main check categories

- Latch inference.
- Multiple drivers.
- Undriven or unused signals.
- Uninitialized registers.
- Width mismatch.
- Signed/unsigned mismatch.
- Incomplete case or unreachable state.
- Combinational loop.
- Blocking/nonblocking misuse.
- Non-synthesizable constructs.
- Reset and clocking hazards.
- CDC/RDC structural risks.
- Memory modeling risks.
- Tool-specific warning patterns.

## Required inputs

- RTL source files or relevant snippets.
- Filelist and compile options when available.
- Tool name and version when available.
- Lint, compile, CDC/RDC, or synthesis report.
- Known design intent and acceptable waivers.

## Expected outputs

- Issue classification by severity.
- Root-cause hypothesis for each important finding.
- Recommended RTL fix, constraint fix, test update, or waiver rationale.
- Risk summary.
- Suggested next checks.

## Guardrails

- Do not suppress warnings without a technical rationale.
- Do not recommend waivers for functional ambiguity.
- Do not treat lint-clean as equivalent to functionally verified.
- Prefer RTL fixes over waivers when the warning indicates real ambiguity.
- Escalate CDC/RDC and reset-related warnings when intent is unclear.
