# VCS Flow Review Checklist

## Environment

- **VCS available**: `vcs` is in `PATH` and version is known.
- **License available**: Compile and run license requirements are understood.
- **Verdi available**: `verdi` and `VERDI_HOME` are configured when FSDB is required.
- **Compiler compatibility**: gcc/g++ compatibility is known for the VCS version.
- **UVM version**: UVM version is explicit, such as `-ntb_opts uvm-1.2`.

## Directory and reproducibility

- **Run directory**: Run path includes test name and seed.
- **Logs saved**: Compile and run logs are saved under the run directory.
- **Command traceability**: Test name, seed, plusargs, and build options are recoverable.
- **No source pollution**: Generated artifacts are separated from source files.

## Filelist

- **Include paths complete**: All include files can be found.
- **Package order correct**: Packages appear before users.
- **Interface order correct**: Interfaces appear before drivers, monitors, env, and top users.
- **RTL/TB split clear**: RTL, TB, and DV filelists are layered clearly.
- **No duplicate packages**: Package source is not compiled more than once.
- **Path stability**: Paths are valid from the Makefile execution directory.

## Compile and elaboration

- **Base flags complete**: `-full64`, `-sverilog`, timescale, top, output, and log are defined.
- **UVM flags complete**: UVM option is present for UVM flows.
- **Debug flags controllable**: Heavy debug options are configurable.
- **DPI/PLI linked**: DPI C files and Verdi PLI are linked when required.
- **Compatibility flags**: `-cc gcc -cpp g++ -LDFLAGS -Wl,-no-as-needed` are available for older-link issues.

## Run

- **Test name protected**: `+UVM_TESTNAME` is set by base plusargs and not accidentally overridden.
- **Seed reproducible**: `+ntb_random_seed` is explicit.
- **Plusargs layered**: Required plusargs and user `PLUSARGS` are separate.
- **Timeout configured**: UVM timeout or project timeout exists for regression safety.
- **Exit status checked**: Failed `simv` exit status fails the make target.

## Wave and Verdi

- **Wave default off**: FSDB/VPD/VCD dumping is disabled by default.
- **Wave switch clear**: `WAVE=1` or `+WAVE` enables dump.
- **FSDB PLI correct**: Verdi PLI path is correct when using FSDB.
- **Wave moved safely**: Generated wave files are placed under run directory.
- **Verdi target works**: `make verdi` opens the correct filelist, top, and wave.

## Log checking

- **Compile patterns checked**: Syntax, undefined module, missing file, missing package, duplicate definition, and link errors are detected.
- **Run patterns checked**: `UVM_FATAL`, `UVM_ERROR`, mismatch, timeout, segfault, and license errors are detected.
- **Pass marker checked**: A required pass marker is used when available.
- **Summary readable**: Regression summary reports pass/fail by test and seed.

## Clean safety

- **Generated-only clean**: `clean` deletes only generated simulation artifacts.
- **No golden deletion**: Source, handwritten golden data, and non-reproducible inputs are not removed.
- **Boundary clear**: `clean_all` is separate if more aggressive cleanup is needed.

## Debug readiness

- **First-error workflow**: Compile debug starts from first real error.
- **Seed preservation**: Failing seed and command are preserved.
- **Mismatch evidence**: Scoreboard prints enough transaction context.
- **Wave availability**: Failed cases can be rerun with waves.
- **DUT/TB separation**: Debug flow distinguishes DUT, TB, scoreboard, reference model, and flow issues.
