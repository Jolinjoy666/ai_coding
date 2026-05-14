# Spec to Architecture Workflow (Combined Reference)

This workflow is split into two sub-workflows for clarity. Use them in order:

1. `common/workflows/spec_to_requirements.md` — Convert raw spec to structured requirements.
2. `common/workflows/requirements_to_architecture.md` — Generate and select architecture from requirements.

## When to use this combined flow

Use this file as a quick reference when running the full spec-to-architecture pipeline in one session. For detailed steps, gates, and outputs, read the individual workflow files above.

## Quick sequence

1. Read `spec/raw_spec.md`.
2. Run `spec_to_requirements` → save `spec/requirements.md`.
3. Review `common/checklists/spec_readiness_checklist.md`.
4. Run `architecture_option_generation` → save `docs/architecture/selected_arch.md`.
5. Review `common/checklists/architecture_review_checklist.md`.
6. Update `ai/project_context.md` at each stage boundary.
