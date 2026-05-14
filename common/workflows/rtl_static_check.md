# RTL Static Check Workflow

1. Identify RTL filelist and target tool flow.
2. Run or prepare lint/compile/static checks.
3. Use `rtl_static_check` to classify warnings and errors.
4. Use `cdc_rdc_analysis` for clock/reset crossing issues.
5. Fix real RTL ambiguity before considering waivers.
6. Record results under `lint/reports/` or `reports/rtl_review/`.
7. Update `ai/project_context.md`:
    - Set `next_recommended_stage` to `rtl_simulation_debug`.
    - Record static check pass/fail status and any outstanding waivers.
