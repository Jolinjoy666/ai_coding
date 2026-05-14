# AI Project Context: BDS_GPS

## Bootstrap summary

- **Project name**: `BDS_GPS`
- **Block name**: `ca_code_tracker`
- **Design type**: `digital_ic`
- **Target language**: SystemVerilog
- **Target simulator**: `vcs`
- **Created from**: raw user spec

## Source of truth

- Raw spec: `spec/raw_spec.md`
- Project metadata: `project.yaml`
- Common workflow root: `../common/workflows`
- Common skill root: `../common/skills`

## Current workflow stage

```text
completed
```

## Next recommended stage

```text
signoff_package
```

## AI operating rules for this project

- Preserve raw spec exactly.
- Put generated RTL drafts under `rtl/generated/` until reviewed.
- Put reviewed RTL under `rtl/src/`.
- Keep project-specific scripts under `tools/` or `sim/`.
- Keep reusable assets under `../common`, not inside this project.
- Record major assumptions and decisions in `ai/` or `docs/`.
- Do not overwrite existing source or reports without checking.

## Open questions

- TBD