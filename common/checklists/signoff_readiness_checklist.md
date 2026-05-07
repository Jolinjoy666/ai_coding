# Signoff Readiness Checklist

## Specification and design intent

- **Spec traceability**: Final RTL behavior maps to approved requirements.
- **Architecture approval**: Selected architecture and micro-architecture are documented.
- **Interface contract**: Protocol, latency, backpressure, reset, error, and memory behavior are stable.
- **Open assumptions**: Assumptions are tracked and approved or resolved.

## RTL quality

- **Coding standard**: RTL follows project SystemVerilog coding standard.
- **Review complete**: RTL review checklist is complete.
- **No known functional ambiguity**: Ambiguous behavior is resolved or documented.
- **No broad unreviewed changes**: Final diff is scoped and understood.

## Verification

- **Directed tests**: Basic and boundary behavior are covered.
- **Random tests**: Legal randomized scenarios are covered where relevant.
- **Assertions**: Local protocol and invariant assertions are passing.
- **Coverage**: Functional and code coverage targets are reviewed.
- **Reference model**: Reference model matches final RTL semantics.
- **Regression**: Regression status is clean or exceptions are approved.

## Static and signoff checks

- **Lint**: Fatal and high-severity lint issues are resolved.
- **Compile/elaboration**: Clean under target simulator/toolchain.
- **CDC**: CDC issues are resolved or waived with proof.
- **RDC**: Reset crossing issues are resolved or waived with proof.
- **Synthesis**: Basic synthesis or mapping sanity is reviewed.
- **STA assumptions**: Clocks, generated clocks, false paths, multicycle paths, and I/O delays are defined.
- **LEC**: Equivalence flow impact is understood where applicable.
- **DFT**: Test mode, scan, clock gating, reset, and memory wrapper needs are considered.

## PPA

- **Timing risk**: Known timing hotspots are documented.
- **Area risk**: Large memories, muxes, arithmetic, and flop arrays are reviewed.
- **Power risk**: High-toggle datapath and memory activity are reviewed.
- **Tradeoff record**: PPA decisions and tradeoffs are documented.

## Release package

- **RTL filelist**: Source filelist is complete.
- **Constraints**: Relevant constraints are included or referenced.
- **Reports**: Lint, simulation, coverage, CDC/RDC, synthesis, and review reports are collected.
- **Waivers**: Waivers include owner, reason, proof, and review condition.
- **Known issues**: Remaining risks are documented with disposition.
- **Versioning**: Release tag or commit ID is recorded.
