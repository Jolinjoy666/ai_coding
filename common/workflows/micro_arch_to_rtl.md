# Micro-Architecture to RTL Workflow

1. Read final micro-architecture and interface contracts.
2. Invoke `digital_ic_rtl_design` to generate or modify RTL.
3. Reference standards under `common/standards/`.
4. Save draft generated RTL under `rtl/generated/` until reviewed.
5. Run RTL self-review using `common/checklists/rtl_review_checklist.md`.
6. Verify all promotion conditions below before moving files from `rtl/generated/` to `rtl/src/`:
   - **No fatal lint errors**: syntax errors, elaboration failures, multi-driver conflicts, combinational loops, or non-synthesizable constructs must be zero.
   - **No high lint warnings unresolved**: latch inference, width mismatch, signed/unsigned mismatch, reset ambiguity must be fixed or explicitly waived.
   - **Interface matches micro-architecture**: port names, widths, directions, and protocols match the micro-architecture document.
   - **Reset strategy implemented**: all registers have explicit reset values matching the micro-architecture spec.
   - **No multi-driver signals**: each signal has exactly one driver; internal muxes are explicit.
   - **Data path matches spec**: FIFO integration, CRC, command routing match the design specification.
7. Promote reviewed production RTL to `rtl/src/`. Only promote files that pass all conditions above.
7. Document verification recommendations under `reports/rtl_review/`.
8. Update `ai/project_context.md`:
    - Set `current_workflow_stage` to `rtl_in_progress`.
    - Set `next_recommended_stage` to `rtl_static_check` or `rtl_simulation_debug`.
    - List any design assumptions made during RTL generation.
