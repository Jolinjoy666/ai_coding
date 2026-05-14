# Spec to Requirements Workflow

## Purpose

Convert raw user spec into structured, reviewable requirements before any architecture or RTL work.

## Steps

1. Read the raw spec from `spec/raw_spec.md`.
2. Run `spec_to_requirements` skill to create structured requirements.
3. Ensure the output contains all required sections:
   - `confirmed_requirements` — facts extracted directly from the spec.
   - `assumptions` — decisions made where the spec was silent.
   - `open_questions` — ambiguities or missing information that need user input.
   - `constraints` — interface, protocol, clock, reset, storage, PPA, and integration constraints.
   - `verification_intent` — how each requirement will be verified.
   - `risks` — technical risks and mitigation ideas.
4. Review `common/checklists/spec_readiness_checklist.md`.
5. Resolve blocking questions or document assumptions with rationale.
6. Save structured requirements to `spec/requirements.md`.
7. Save requirements report to `reports/requirements/`.
8. Update `ai/project_context.md`:
   - Set `current_workflow_stage` to `requirements_ready`.
   - Set `next_recommended_stage` to `architecture_option_generation`.
   - Sync unresolved questions from `spec/requirements.md` to `open_questions`.

## Gate

Do not proceed to architecture until:
- All three sections (confirmed_requirements, open_questions, verification_intent) are non-empty.
- Blocking questions are either resolved or explicitly marked as assumptions with rationale.

## Next workflow

`common/workflows/requirements_to_architecture.md`
