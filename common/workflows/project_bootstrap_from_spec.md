# Project Bootstrap From Spec Workflow

## Purpose

Create a new IC design project environment when the user provides only a raw spec or design idea.

This workflow runs before `spec_to_architecture.md` and before any RTL or DV generation.

## Inputs

- Raw user spec.
- Optional desired project name.
- Optional block name.
- Optional target simulator, such as VCS.
- Optional target language, default SystemVerilog.

## Steps

1. Preserve the raw user spec exactly.
2. Infer a short project name from the spec if the user did not provide one.
3. Normalize the project name for filesystem safety.
4. Check whether `/home/hp/cfy/ai_coding/<project_name>` already exists.
5. If the path exists, stop and ask the user whether to choose another name or reuse the existing project.
6. Create the standard directory tree from `common/templates/project_init/directory_manifest.md`.
7. Instantiate `common/templates/project_init/project.yaml.template` as `<project_name>/project.yaml`.
8. Instantiate `common/templates/project_init/README.md.template` as `<project_name>/README.md`.
9. Save the raw spec as `<project_name>/spec/raw_spec.md` using `common/templates/project_init/raw_spec.md.template`.
10. Instantiate `common/templates/project_init/ai_project_context.md.template` as `<project_name>/ai/project_context.md`.
11. Confirm that `project.yaml` links to `../common` assets.
12. Recommend `common/workflows/spec_to_architecture.md` as the next workflow.

## Standard directory tree

```text
<project_name>/
  README.md
  project.yaml
  spec/
  docs/architecture/
  docs/micro_arch/
  ai/
  rtl/src/
  rtl/generated/
  rtl/include/
  rtl/pkg/
  dv/tb/
  dv/uvm/
  dv/tests/
  sim/
  lint/
  formal/
  synth/
  tools/
  reports/requirements/
  reports/architecture/
  reports/micro_arch/
  reports/rtl_review/
  reports/verification/
  reports/signoff/
  build/
  third_party/
```

## Done definition

- Project root exists under `/home/hp/cfy/ai_coding`.
- `project.yaml` exists and references `../common`.
- `README.md` exists.
- `spec/raw_spec.md` preserves the user spec.
- `ai/project_context.md` exists.
- Next workflow is documented.

## Safety rules

- Do not overwrite an existing project directory.
- Do not interpret raw spec as approved requirements during bootstrap.
- Do not generate RTL during bootstrap.
- Do not place project-specific files under `common/`.
