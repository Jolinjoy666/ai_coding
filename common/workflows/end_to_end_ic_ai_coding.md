# End-to-End IC AI Coding Workflow

## Purpose

Run a complete local AI-assisted digital IC design loop from raw user spec to signoff-ready RTL package.

## Entry modes

- If no project exists yet, start with `common/workflows/project_bootstrap_from_spec.md`.
- If a project already exists and has `spec/raw_spec.md`, continue with `common/workflows/spec_to_requirements.md`.

## Flow

| Step | Workflow | Skill |
|------|----------|-------|
| 1 | `project_bootstrap_from_spec.md` | `00_spec_intake/project_bootstrap_from_spec/` |
| 2 | `spec_to_requirements.md` | `00_spec_intake/spec_to_requirements/` |
| 3 | `requirements_to_architecture.md` | `10_architecture_exploration/architecture_option_generation/` |
| 4 | `architecture_to_micro_arch.md` | `20_micro_arch_design/micro_arch_design/` |
| 5 | `micro_arch_to_rtl.md` | `30_rtl_generation/digital_ic_rtl_design/` |
| 6 | `rtl_static_check.md` | `40_static_checks/rtl_static_check/` + `cdc_rdc_analysis/` |
| 7 | `rtl_simulation.md` | `50_simulation/rtl_simulation_debug/` or `vcs_simulation_flow/` |
| 8 | `rtl_to_uvm.md` | `60_uvm_generation/uvm_env_generation/` |
| 9 | `regression_debug_loop.md` | `70_regression_debug/regression_failure_analysis/` or `vcs_regression_debug/` |
| 10 | (inline) | `80_design_refinement/verification_driven_refinement/` or `ppa_rtl_optimization/` |
| 11 | `signoff_package.md` | `90_signoff_package/rtl_signoff_package/` |

Each step must update `ai/project_context.md` before proceeding to the next.

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
