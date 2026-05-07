# VCS RTL/UVM Simulation Workflow

## Purpose

This workflow sets up or reviews a Synopsys VCS RTL/SystemVerilog/UVM simulation flow for a project.

## Inputs

- Project directory.
- Simulation directory.
- RTL filelist or RTL source directory.
- TB top name.
- Simulation mode: RTL-only, SystemVerilog TB, UVM, or gate-level preparation.
- Optional VCS/Verdi/UVM/DPI/PLI requirements.

## Steps

1. Inspect the existing project layout, Makefile, filelists, and scripts.
2. Confirm the simulation top, UVM version, seed policy, wave policy, and expected pass marker.
3. Create or update filelists so include paths, packages, interfaces, TB files, and RTL files compile in dependency order.
4. Create or update Makefile targets: `help`, `compile`, `run`, `sim`, `check`, `regress`, `verdi`, `clean`, and optionally `clean_all`.
5. Ensure compile/elaboration options are separate from runtime plusargs.
6. Ensure base plusargs include test name and seed, while user plusargs are appended separately.
7. Add optional FSDB/Verdi support controlled by `WAVE=1` or `+WAVE`.
8. Add log checking for fatal, error, mismatch, timeout, license failure, and pass marker.
9. Run or provide a smoke simulation command.
10. Run or provide a wave/debug command.
11. Review the final flow using `common/checklists/vcs_flow_review_checklist.md`.

## Recommended commands

Smoke run:

```bash
make run UVM_TEST=smoke_test SEED=1
```

Wave debug run:

```bash
make run UVM_TEST=smoke_test SEED=1 WAVE=1
make verdi UVM_TEST=smoke_test SEED=1
```

Log check:

```bash
make check UVM_TEST=smoke_test SEED=1
```

Clean:

```bash
make clean
```

## Safety rules

- Do not delete source, handwritten golden data, or non-reproducible inputs.
- Do not enable full wave dumping by default in regressions.
- Do not duplicate package compilation across filelists.
- Do not hide required environment assumptions such as VCS, Verdi, license, gcc/g++, DPI, or PLI.
