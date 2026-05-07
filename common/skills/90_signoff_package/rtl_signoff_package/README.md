# rtl_signoff_package

## Purpose

Prepare a final RTL signoff package for a digital IC block.

This skill collects final RTL, specs, micro-architecture, verification evidence, static-check evidence, waivers, risks, and release notes into a reviewable package.

## When to use

Use this skill when:

- RTL and DV are believed ready for release.
- UVM/simulation regressions have reached agreed pass criteria.
- Lint/CDC/RDC/static checks have been reviewed.
- Remaining waivers and risks need final disposition.
- A handoff package is needed for integration, synthesis, or broader signoff.

## Inputs

- Final RTL filelist.
- Spec and micro-architecture documents.
- Testplan and verification reports.
- Simulation/regression results.
- Lint/CDC/RDC/static-check reports.
- Coverage data.
- Waivers and known issues.
- Release version or commit ID.

## Outputs

- Signoff summary.
- Release package manifest.
- Evidence checklist.
- Waiver summary.
- Known issue/risk summary.
- Recommended next-stage checks.

## Rules

- Do not claim signoff without evidence.
- Distinguish clean, waived, deferred, and unknown issues.
- Preserve traceability from requirements to verification evidence.
- Identify remaining integration, synthesis, STA, DFT, LEC, or GLS risks.
