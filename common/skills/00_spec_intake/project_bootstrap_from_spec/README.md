# project_bootstrap_from_spec

## Purpose

Initialize a new IC design project directory from a user-provided spec.

This skill is the entry point when the user only provides a design idea or raw specification and expects AI to create the project environment, directory structure, metadata files, and initial spec artifacts.

## When to use

Use this skill when:

- Starting a new project under `/home/hp/cfy/ai_coding`.
- The user provides only a raw spec or design request.
- No project directory exists yet.
- The AI needs to create standard folders before running architecture, RTL, DV, simulation, or signoff workflows.

## Inputs

- Raw user spec.
- Desired project name if provided.
- Optional block name, interface type, target simulator, and design style.
- Optional constraints such as clock, reset, latency, throughput, PPA, or protocol.

## Outputs

- New project directory under workspace root.
- Standard IC project directory tree.
- `project.yaml` with paths and common asset references.
- Project `README.md`.
- Raw spec copy under `spec/raw_spec.md`.
- Initial AI context under `ai/project_context.md`.
- Optional initial requirement stub under `spec/requirements.md`.

## Default project directory layout

```text
<project_name>/
  README.md
  project.yaml
  spec/
  docs/
    architecture/
    micro_arch/
  ai/
  rtl/
    src/
    generated/
    include/
    pkg/
  dv/
    tb/
    uvm/
    tests/
  sim/
  lint/
  formal/
  synth/
  tools/
  reports/
    requirements/
    architecture/
    micro_arch/
    rtl_review/
    verification/
    signoff/
  build/
  third_party/
```

## Rules

- Create project folders only under `/home/hp/cfy/ai_coding/<project_name>`.
- Do not overwrite an existing project directory without explicit user approval.
- Preserve the raw user spec exactly in `spec/raw_spec.md`.
- Use safe project names with lowercase letters, digits, and underscores unless the user explicitly requests otherwise.
- If the project name is ambiguous, propose one and ask before creating directories.
- Link the project to `../common` assets in `project.yaml`.
- After bootstrap, invoke `spec_to_requirements` as the next skill.
