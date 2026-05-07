# common

Reusable assets for AI-assisted IC design workflows.

## Start from only a spec

When the user provides only a raw spec and expects AI to create the project environment, use:

- `workflows/project_bootstrap_from_spec.md`
- `skills/00_spec_intake/project_bootstrap_from_spec/`
- `templates/project_init/`
- `schemas/project.schema.yaml`
- `checklists/project_bootstrap_checklist.md`

Default flow:

```text
raw user spec
  -> project_bootstrap_from_spec
  -> spec_to_requirements
  -> spec_to_architecture
  -> end_to_end_ic_ai_coding
```

New project directories should be created under:

```text
/home/hp/cfy/ai_coding/<project_name>
```

Project-specific files belong inside the project directory. Reusable skills, templates, standards, checklists, schemas, workflows, and EDA adapters stay under `common/`.

## Directory purpose

- `skills/`: reusable AI skills for project bootstrap, spec intake, architecture, RTL generation, simulation, UVM generation, debug, and signoff.
- `workflows/`: end-to-end IC design workflow descriptions.
- `prompts/`: prompt templates for recurring AI tasks.
- `standards/`: coding, verification, lint, reset, clock, CDC, and signoff guidelines.
- `templates/`: reusable project, RTL, UVM, script, report, and filelist templates.
- `eda_adapters/`: wrappers and configuration for EDA tools.
- `scripts/`: common utility scripts.
- `schemas/`: structured input/output schemas.
- `examples/`: small reference designs and verification examples.
- `checklists/`: review and signoff checklists.
- `knowledge_base/`: local IC design knowledge and project-independent notes.
