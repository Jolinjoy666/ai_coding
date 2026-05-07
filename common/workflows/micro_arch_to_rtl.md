# Micro-Architecture to RTL Workflow

1. Read final micro-architecture and interface contracts.
2. Invoke `digital_ic_rtl_design` to generate or modify RTL.
3. Reference standards under `common/standards/`.
4. Save draft generated RTL under `rtl/generated/` until reviewed.
5. Run RTL self-review using `common/checklists/rtl_review_checklist.md`.
6. Promote reviewed production RTL to `rtl/src/`.
7. Document verification recommendations under `reports/rtl_review/`.
