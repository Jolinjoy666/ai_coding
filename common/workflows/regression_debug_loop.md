# Regression Debug Loop Workflow

1. Collect regression summary, failing logs, seeds, commands, and waves.
2. Use `regression_failure_analysis` to cluster failures.
3. Use simulator-specific debug skill such as `vcs_regression_debug` when relevant.
4. Determine whether root cause is RTL, TB, scoreboard, reference model, flow, spec, or environment.
5. Use `verification_driven_refinement` for scoped fixes.
6. Rerun targeted tests.
7. Rerun broader regression after targeted fixes pass.
8. Review `common/checklists/regression_closure_checklist.md`.
