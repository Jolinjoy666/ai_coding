# End-to-End IC AI Coding Workflow

## Purpose

Run a complete local AI-assisted digital IC design loop from raw user spec to signoff-ready RTL package.

## Entry modes

- If no project exists yet, start with `common/workflows/project_bootstrap_from_spec.md`.
- If a project already exists and has `spec/raw_spec.md`, continue with `common/workflows/spec_to_architecture.md`.

## Flow

1. Use `common/skills/00_spec_intake/project_bootstrap_from_spec/` to initialize the project environment from raw spec when needed.
2. Use `common/skills/00_spec_intake/spec_to_requirements/` to convert raw spec into structured requirements.
3. Use `common/skills/10_architecture_exploration/architecture_option_generation/` to generate and select architecture.
4. Use `common/skills/20_micro_arch_design/micro_arch_design/` to create implementation-ready micro-architecture.
5. Use `common/skills/30_rtl_generation/digital_ic_rtl_design/` to generate or modify synthesizable RTL.
6. Use `common/skills/40_static_checks/rtl_static_check/` and `common/skills/40_static_checks/cdc_rdc_analysis/` for static review.
7. Use `common/skills/50_simulation/rtl_simulation_debug/` or `common/skills/50_simulation/vcs_simulation_flow/` for smoke simulation.
8. Use `common/skills/60_uvm_generation/uvm_env_generation/` to create or update UVM verification.
9. Use `common/skills/70_regression_debug/regression_failure_analysis/` or `common/skills/70_regression_debug/vcs_regression_debug/` for failures.
10. Use `common/skills/80_design_refinement/verification_driven_refinement/` or `common/skills/80_design_refinement/ppa_rtl_optimization/` for refinement.
11. Use `common/skills/90_signoff_package/rtl_signoff_package/` for release packaging.

## Project outputs

- `project.yaml`
- `README.md`
- `ai/project_context.md`
- `spec/raw_spec.md`
- `spec/requirements.md`
- `docs/architecture/options/`
- `docs/architecture/selected_arch.md`
- `docs/micro_arch/`
- `rtl/src/`
- `dv/`
- `sim/`
- `reports/verification/`
- `reports/signoff/`

## Stop conditions

Stop and ask for human review when:

- Project name is ambiguous and could overwrite an existing directory.
- Requirements contradict each other.
- Interface contract is unclear.
- Architecture changes visible behavior.
- CDC/RDC assumptions are not approved.
- Verification failure root cause is unknown.
- Signoff evidence is missing or waived without rationale.
