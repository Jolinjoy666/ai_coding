---
name: vcs
type: eda_adapter
tool: Synopsys VCS
description: Synopsys VCS adapter reference for RTL/SystemVerilog/UVM simulation flows.
---

# VCS EDA Adapter

## Purpose

This document is the tool-specific adapter entry for Synopsys VCS in the local IC AI coding workspace.

It should stay focused on VCS tool invocation assumptions, stable command shapes, environment variables, and links to reusable skills, templates, checklists, and workflows.

Detailed simulation-flow behavior is intentionally split into dedicated assets:

- `common/skills/50_simulation/vcs_simulation_flow/`
- `common/skills/70_regression_debug/vcs_regression_debug/`
- `common/templates/simulation/vcs/`
- `common/checklists/vcs_flow_review_checklist.md`
- `common/workflows/vcs_rtl_uvm_simulation.md`

## Tool scope

VCS is used for:

- Verilog/SystemVerilog RTL compile and elaboration.
- SystemVerilog testbench simulation.
- UVM simulation with `-ntb_opts uvm-1.2` or project-selected UVM version.
- FSDB/VPD/VCD waveform generation when configured.
- DPI/PLI-linked simulation.
- RTL and gate-level simulation preparation.

## Environment variables

Common variables:

- `VCS_HOME`
- `VERDI_HOME`
- `SNPSLMD_LICENSE_FILE` or `LM_LICENSE_FILE`
- `PATH`
- `LD_LIBRARY_PATH`

Basic checks:

```bash
which vcs
vcs -ID
which verdi
verdi -version
```

## Compile command shape

Basic SystemVerilog compile/elaboration:

```bash
vcs -full64 \
    -sverilog \
    -timescale=1ns/1ps \
    -f filelists/rtl.f \
    -f filelists/tb.f \
    -top tb_top \
    -o simv \
    -l compile.log
```

UVM compile/elaboration:

```bash
vcs -full64 \
    -sverilog \
    -ntb_opts uvm-1.2 \
    -timescale=1ns/1ps \
    -debug_access+all \
    -f filelists/dv.f \
    -top tb_top \
    -o simv \
    -l compile.log
```

Compatibility flags for older link flows:

```bash
-cc gcc -cpp g++ -LDFLAGS -Wl,-no-as-needed
```

Use them when C/C++ link errors, DPI link errors, or older VCS runtime link issues appear.

## Runtime command shape

Basic run:

```bash
./simv -l sim.log
```

UVM run:

```bash
./simv \
    +UVM_TESTNAME=smoke_test \
    +ntb_random_seed=1 \
    -l sim.log
```

Common runtime plusargs:

- `+UVM_TESTNAME=<test_name>`
- `+ntb_random_seed=<seed>`
- `+UVM_VERBOSITY=UVM_LOW|UVM_MEDIUM|UVM_HIGH|UVM_DEBUG`
- `+UVM_TIMEOUT=<time>,YES`
- `+UVM_NO_RELNOTES`
- `+WAVE`

## FSDB and Verdi notes

When FSDB is required, link Verdi PLI during compile:

```bash
-fsdb -P $VERDI_HOME/share/PLI/VCS/LINUXAMD64/novas.tab \
      $VERDI_HOME/share/PLI/VCS/LINUXAMD64/pli.a
```

Open wave:

```bash
verdi -sv -f filelists/dv.f -top tb_top -ssf run/<test>_<seed>/wave.fsdb &
```

Default policy:

- Keep waves off for normal runs.
- Enable waves only with `WAVE=1` or `+WAVE`.
- Keep large regression waves limited to failing or debug runs.

## Filelist expectations

- Put `+incdir+` entries before source files.
- Compile packages before import users.
- Compile interfaces before drivers, monitors, env, tests, and top users.
- Avoid duplicate package compilation.
- Keep filelist paths stable relative to the Makefile execution directory.

## Required Make targets

Recommended project targets:

- `help`
- `compile`
- `run`
- `sim`
- `check`
- `regress`
- `verdi`
- `clean`
- `clean_all` when needed

The reusable Makefile template is:

```text
common/templates/simulation/vcs/Makefile
```

## Log failure patterns

Compile logs should be checked for:

- `Error-`
- `Syntax error`
- `Undefined module`
- `Cannot find file`
- `Package not found`
- `Multiple definition`
- `undefined reference`
- `collect2: error`

Run logs should be checked for:

- `UVM_FATAL`
- `UVM_ERROR`
- `Fatal:`
- `Error:`
- `Mismatch`
- `Bit-True Errors`
- `timeout`
- `segmentation fault`
- `License checkout failed`

Use the shared template checker:

```text
common/templates/simulation/vcs/scripts/check_sim_log.py
```

## Related reusable assets

- **Simulation skill**: `common/skills/50_simulation/vcs_simulation_flow/`
- **Regression debug skill**: `common/skills/70_regression_debug/vcs_regression_debug/`
- **Templates**: `common/templates/simulation/vcs/`
- **Checklist**: `common/checklists/vcs_flow_review_checklist.md`
- **Workflow**: `common/workflows/vcs_rtl_uvm_simulation.md`

## Guardrails

- Read existing Makefile and filelists before editing.
- Keep compile options separate from runtime plusargs.
- Keep base plusargs separate from user `PLUSARGS`.
- Do not enable wave dumping by default for regressions.
- Do not let `clean` delete source, handwritten golden data, or non-reproducible inputs.
- Preserve failing test name, seed, command, logs, and run directory during debug.
