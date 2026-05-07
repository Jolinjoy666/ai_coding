# Project Bootstrap Checklist

- **Project name chosen**: Project name is explicit or safely inferred from the spec.
- **Path checked**: `/home/hp/cfy/ai_coding/<project_name>` does not already exist, or reuse is explicitly approved.
- **Raw spec preserved**: Original user spec is saved under `spec/raw_spec.md`.
- **Standard directories created**: Required IC design directories are present.
- **Project metadata created**: `project.yaml` exists and follows `common/schemas/project.schema.yaml`.
- **Common assets linked**: `project.yaml` points to `../common` skills, workflows, standards, templates, checklists, schemas, and EDA adapters.
- **README created**: Project `README.md` documents purpose, layout, and next step.
- **AI context created**: `ai/project_context.md` records bootstrap metadata and AI operating rules.
- **No RTL generated yet**: Bootstrap does not create design implementation files.
- **Next workflow clear**: `spec_to_requirements` or `spec_to_architecture.md` is identified as next step.
