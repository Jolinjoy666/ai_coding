# VCS Simulation Templates

Reusable templates for Synopsys VCS RTL/SystemVerilog/UVM simulation flows.

## Files

- `Makefile`: default VCS simulation Makefile template.
- `filelists/rtl.f`: RTL filelist placeholder.
- `filelists/tb.f`: simple testbench filelist placeholder.
- `filelists/dv.f`: UVM/DV filelist placeholder.
- `scripts/check_sim_log.py`: basic compile/run log checker.

## Usage

Copy this directory into a project simulation area, then edit:

- `TOP`
- filelist paths
- UVM test names
- pass marker
- project-specific plusargs
- FSDB/Verdi options
