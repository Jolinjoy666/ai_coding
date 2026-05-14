# RTL to UVM Workflow

1. Read interface contracts, micro-architecture, RTL ports, and verification intent.
2. Run `uvm_env_generation` to plan agents, env, sequences, tests, scoreboard, reference model, and coverage.
3. Review `common/checklists/uvm_environment_review_checklist.md`.
4. Update UVM filelists and simulation flow.
5. Run smoke UVM test.
6. Add directed, random, assertion, and coverage tests according to testplan.
7. Verify minimum verification depth before declaring verification complete:
   - **Scoreboard must be active**: at least one non-zero match or mismatch count after full_function_test. A scoreboard with all-zero counts indicates no actual checking occurred.
   - **Coverage of primary operations**: each major command/operation defined in the spec must have at least one directed test that exercises it end-to-end.
   - **Both data paths exercised**: if the design has separate TX/RX or request/response paths, both must be stimulated and observed.
   - **Error path coverage**: at least one test must exercise error detection (CRC error, timeout, invalid opcode, etc.) if the spec defines error handling.
   - **APB/register coverage**: if the design has a register interface, at least one test must verify read/write access to key registers.
7. Update `ai/project_context.md`:
    - Set `current_workflow_stage` to `verification_in_progress`.
    - Set `next_recommended_stage` to `regression_failure_analysis` or `rtl_signoff_package`.
    - Record test results summary and coverage status.
