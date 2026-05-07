# Project Initialization Templates

Templates for creating a new IC design project from a raw user spec.

## Files

- `project.yaml.template`: standard project metadata and path mapping.
- `README.md.template`: project README starter.
- `ai_project_context.md.template`: AI-maintained project context starter.
- `directory_manifest.md`: standard directory structure and purpose.
- `raw_spec.md.template`: raw spec preservation template.

## Usage

When the user provides only a spec:

1. Create a new project directory under `/home/hp/cfy/ai_coding/<project_name>`.
2. Create the standard directory tree from `directory_manifest.md`.
3. Instantiate `project.yaml.template` as `project.yaml`.
4. Instantiate `README.md.template` as `README.md`.
5. Save the raw user spec as `spec/raw_spec.md`.
6. Instantiate `ai_project_context.md.template` as `ai/project_context.md`.
7. Continue with `common/workflows/spec_to_architecture.md`.
