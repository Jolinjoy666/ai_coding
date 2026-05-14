# skills

Reusable AI skills for local IC design automation.

## Skill categories

- `00_spec_intake/`: bootstrap projects, convert user intent and raw specification into structured requirements.
- `10_architecture_exploration/`: generate and compare architecture options.
- `20_micro_arch_design/`: create module partitioning, FSM, datapath, timing, and interface details.
- `30_rtl_generation/`: generate production-oriented SystemVerilog RTL drafts.
- `40_static_checks/`: run and analyze lint, formatting, compile, CDC, and structural checks.
- `50_simulation/`: run smoke simulation, directed tests, and waveform-oriented debug.
- `60_uvm_generation/`: create or update UVM agents, env, tests, sequences, scoreboard, and coverage.
- `70_regression_debug/`: analyze regression failures and propose root-cause fixes.
- `80_design_refinement/`: modify RTL, testbench, or spec based on verification feedback.
- `90_signoff_package/`: collect final RTL, verification evidence, reports, and release notes.

## Available skills

- `00_spec_intake/project_bootstrap_from_spec/`: initialize a new project directory from raw user spec.
- `00_spec_intake/spec_to_requirements/`: convert raw user spec into structured requirements.
- `00_spec_intake/doc_to_markdown/`: extract text from images or PDFs and convert to Markdown format.
- `10_architecture_exploration/architecture_option_generation/`: generate and compare architecture options.
- `20_micro_arch_design/micro_arch_design/`: create RTL-ready micro-architecture.
- `30_rtl_generation/digital_ic_rtl_design/`: generate, modify, and review synthesizable digital IC RTL.
- `40_static_checks/rtl_static_check/`: analyze RTL lint, compile, and static-check results.
- `40_static_checks/cdc_rdc_analysis/`: analyze CDC/RDC structures, reports, constraints, and waivers.
- `50_simulation/rtl_simulation_debug/`: plan and debug simulator-agnostic RTL smoke and directed simulation.
- `50_simulation/vcs_simulation_flow/`: create and maintain VCS RTL/SystemVerilog/UVM simulation flows.
- `60_uvm_generation/uvm_env_generation/`: create and update UVM env, agents, sequences, tests, scoreboard, and coverage.
- `70_regression_debug/regression_failure_analysis/`: cluster and triage simulator-independent regression failures.
- `70_regression_debug/vcs_regression_debug/`: debug VCS compile, elaboration, runtime, waveform, mismatch, timeout, and regression failures.
- `80_design_refinement/verification_driven_refinement/`: refine RTL/DV/spec from verification evidence.
- `80_design_refinement/ppa_rtl_optimization/`: optimize RTL for performance, power, and area.
- `90_signoff_package/rtl_signoff_package/`: prepare final RTL signoff package and evidence matrix.

## Recommended skill content

Each skill should eventually contain:

- `README.md`
- `skill.yaml`
- `prompt.md`
- `inputs/`
- `outputs/`
- `scripts/`
- `examples/`
- `tests/`
