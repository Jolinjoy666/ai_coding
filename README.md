# ai_coding

This workspace is organized for local AI-assisted IC design projects.

## 中文说明

- `AI_CODING_WORKFLOW_CN.md`: 中文说明这套 AI Coding 工作流、agent 调度逻辑、skill 读取时机、项目 bootstrap 方式和端到端设计闭环。

## Layout

- `common/`: reusable IC design skills, workflows, prompts, standards, templates, scripts, schemas, examples, checklists, and knowledge base.
- `.windsurf/workflows/`: IDE-level workflows that can be invoked by Cascade/Windsurf.
- `<project_name>/`: one folder per IC design project.

## Recommended project flow

1. Bootstrap project from raw spec when no project exists.
2. Capture and preserve user specification.
3. Convert specification into structured requirements.
4. Explore architecture options.
5. Select architecture and define micro-architecture.
6. Generate and review RTL.
7. Run lint, compile, simulation, and regression.
8. Generate or update UVM verification environment.
9. Analyze failures and coverage.
10. Refine design until the RTL passes the agreed verification plan.
11. Create signoff package.
