# vcs_simulation_flow

## Purpose

This skill builds and maintains Synopsys VCS-based RTL/SystemVerilog/UVM simulation flows.

It focuses on project-level simulation automation: filelists, compile/elaboration, run commands, plusargs, waves, log checking, regression entry points, and reproducible Makefile targets.

## When to use

Use this skill when:

- Creating a VCS simulation environment for RTL or UVM verification.
- Adding or fixing Makefile targets such as `compile`, `run`, `sim`, `regress`, `check`, `verdi`, and `clean`.
- Maintaining RTL/TB/UVM filelists and include paths.
- Adding FSDB/Verdi wave support.
- Defining UVM test name, seed, timeout, verbosity, and user plusarg handling.
- Standardizing run directory layout and log naming.
- Preparing a smoke simulation or small regression flow.

## Inputs

Required inputs:

- Project simulation directory.
- RTL filelist or RTL source location.
- Testbench top name.
- Target mode: RTL-only, SystemVerilog TB, UVM, or gate-level preparation.

Optional inputs:

- Existing Makefile.
- Existing filelists.
- Existing scripts.
- VCS version.
- Verdi/FSDB requirement.
- UVM version.
- DPI/PLI requirement.
- Regression test list.
- Expected pass marker.

## Outputs

Expected outputs:

- VCS Makefile or Makefile patch.
- Filelist structure.
- Log-check integration.
- Run directory convention.
- Smoke-run command.
- Wave/debug command.
- Regression command.
- Notes on environment assumptions and tool options.

## Core rules

- Keep compile/elaboration and runtime plusargs conceptually separated.
- Use filelists as the source of truth for RTL/TB/package ordering.
- Compile packages, interfaces, classes, modules, and top in dependency order.
- Keep required plusargs separate from user-supplied `PLUSARGS`.
- Save compile and run logs for every run.
- Default wave dumping off; enable by `WAVE=1` or `+WAVE` only for debug.
- Keep seed, test name, plusargs, and run directory reproducible.
- Make `clean` remove only generated simulation artifacts.
- After flow edits, provide at least one smoke command and one wave/debug command.

## References

- `common/eda_adapters/vcs.md`
- `common/templates/simulation/vcs/Makefile`
- `common/templates/simulation/vcs/filelists/dv.f`
- `common/templates/simulation/vcs/scripts/check_sim_log.py`
- `common/checklists/vcs_flow_review_checklist.md`
- `common/workflows/vcs_rtl_uvm_simulation.md`
