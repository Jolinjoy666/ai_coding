# Architecture to Micro-Architecture Workflow

1. Read structured requirements and selected architecture.
2. Run `micro_arch_design` to define modules, interfaces, parameters, FSMs, datapath, memory, reset, CDC/RDC, and latency.
3. Review `common/checklists/micro_arch_review_checklist.md`.
4. Resolve open behavior such as reset, collision, overflow, latency, backpressure, and errors.
5. Save final micro-architecture under `docs/micro_arch/`.
