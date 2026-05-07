# PPA Review Checklist

## Performance and timing

- **Critical path known**: The optimization target is backed by timing report or structural evidence.
- **Pipeline opportunity**: Long arithmetic, mux, memory, or encoder paths are evaluated for staging.
- **Ready path bounded**: Backpressure logic does not span too many modules or form loops.
- **Fanout controlled**: High-fanout enables, resets, and control signals are considered for replication or hierarchy changes.
- **Memory output timing**: SRAM/BRAM outputs are registered when needed.
- **Multicycle proof**: Any multicycle path has protocol proof and constraint alignment.

## Area

- **Memory mapping**: Large arrays are mapped to memory resources instead of flops.
- **Mux structure**: Wide muxes are decomposed when appropriate.
- **Arithmetic sharing**: Shared arithmetic resources have proven mutual exclusion.
- **Parameter sizing**: Width and depth parameters are not over-provisioned unnecessarily.
- **State encoding**: FSM encoding matches timing/area goals.

## Power

- **Unnecessary toggling**: Invalid-cycle datapath toggling is reviewed.
- **Operand isolation**: Expensive datapath units are isolated when beneficial.
- **Memory enables**: RAM read/write enables avoid unnecessary activity.
- **Clock enables**: Register enable patterns allow clock-gating inference where methodology supports it.
- **Side effects**: Isolation and gating do not change valid data or debug behavior.

## Functional safety

- **Equivalence**: Optimization preserves behavior or documents approved changes.
- **Latency impact**: Pipeline changes update interface contract and verification.
- **Sideband alignment**: ID, last, user, error, and mask fields remain aligned.
- **Reset behavior**: Added registers have correct reset or masking.
- **CDC/RDC impact**: Optimization does not create unsafe crossings.

## Validation

- **Regression**: Existing tests are rerun.
- **Assertions**: Protocol assertions still pass or are updated.
- **Reference model**: Numerical or latency changes are reflected.
- **Static checks**: Lint, compile, synthesis, STA, CDC/RDC, and LEC implications are reviewed.
- **Coverage**: Optimization does not remove coverage visibility for important scenarios.
