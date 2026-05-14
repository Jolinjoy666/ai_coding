# Requirements to Architecture Workflow

## Purpose

Generate architecture options from structured requirements, evaluate trade-offs, and select a recommended architecture.

## Prerequisites

- `spec/requirements.md` exists with non-empty `confirmed_requirements` and `open_questions`.
- `project.yaml` status is `requirements_ready` or later.

## Steps

1. Read structured requirements from `spec/requirements.md`.
2. Run `architecture_option_generation` to create 2-4 architecture options.
3. Ensure each option includes: data path, control strategy, memory approach, interface impact, latency/throughput estimates, PPA trade-offs, verification impact, and risks.
4. Evaluate options using a trade-off matrix (explicit weighting, not just narrative).
5. Select and justify the recommended architecture.
6. Review `common/checklists/architecture_review_checklist.md`.
7. Save options under `docs/architecture/options/`.
8. Save selected decision under `docs/architecture/selected_arch.md`.
9. Save architecture report to `reports/architecture/`.
10. Update `ai/project_context.md`:
    - Set `current_workflow_stage` to `architecture_selected`.
    - Set `next_recommended_stage` to `micro_arch_design`.

## Gate

Do not proceed to micro-architecture until:
- At least 2 architecture options with substantive differences exist.
- Trade-off matrix is explicit (not just prose).
- Recommended architecture maps back to specific requirements.
- Risks and assumptions are documented.

## Next workflow

`common/workflows/architecture_to_micro_arch.md`
