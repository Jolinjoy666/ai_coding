# Standard IC Project Directory Manifest

## Root files

- `README.md`: project overview and current status.
- `project.yaml`: project metadata, paths, and common asset links.

## Required directories

- `spec/`: raw spec, structured requirements, assumptions, and open questions.
- `docs/architecture/`: architecture options, tradeoff matrix, and selected architecture.
- `docs/micro_arch/`: module decomposition, interface contracts, FSMs, datapath, memory, reset, CDC/RDC, and latency.
- `ai/`: AI-maintained project context, decisions, task state, and prompt notes.
- `rtl/src/`: reviewed production RTL.
- `rtl/generated/`: AI-generated draft RTL before review.
- `rtl/include/`: include files and shared defines.
- `rtl/pkg/`: SystemVerilog packages.
- `dv/tb/`: basic testbench top, interfaces, and harness files.
- `dv/uvm/`: UVM agents, env, sequences, tests, scoreboard, reference models, and coverage.
- `dv/tests/`: non-UVM directed tests or testcase data.
- `sim/`: simulator Makefiles, filelists, logs, waves, run directories, and local scripts.
- `lint/`: lint/static-check setup and reports.
- `formal/`: formal verification setup and reports.
- `synth/`: synthesis setup and reports.
- `tools/`: project-specific scripts and wrappers.
- `reports/requirements/`: requirements extraction and review output.
- `reports/architecture/`: architecture analysis and decision output.
- `reports/micro_arch/`: micro-architecture review output.
- `reports/rtl_review/`: RTL review and static-check summaries.
- `reports/verification/`: simulation, UVM, regression, coverage, and debug reports.
- `reports/signoff/`: final release package and evidence matrix.
- `build/`: generated build outputs.
- `third_party/`: external IP, models, libraries, or vendor material.

## Creation policy

- Create this structure before architecture or RTL work starts.
- Keep `common/` reusable and project-independent.
- Keep project-specific generated files inside the project directory.
- Do not delete user-provided spec or non-reproducible input data.
