# Signoff Package Workflow

1. Confirm release scope and version.
2. Collect final RTL, filelists, specs, micro-architecture, testplan, reports, coverage, and waivers.
3. Review `common/checklists/signoff_readiness_checklist.md`.
4. Run `rtl_signoff_package` to create signoff summary, manifest, evidence matrix, waiver summary, and known risks.
5. Save output under `reports/signoff/`.
6. Record next-stage synthesis, STA, DFT, LEC, GLS, and integration recommendations.
7. Update `ai/project_context.md`:
    - Set `current_workflow_stage` to `signoff_ready`.
    - Set `next_recommended_stage` to `null` or next-phase tool (synthesis/STA/DFT).
    - Record final known risks and waivers.
