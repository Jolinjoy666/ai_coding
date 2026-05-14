# AI Project Context: AttentionCore-SOC

## Bootstrap summary

- **Project name**: `AttentionCore-SOC`
- **Block name**: `attention_core`
- **Design type**: `digital_ic`
- **Target language**: SystemVerilog
- **Target simulator**: `vcs`
- **Created from**: raw user spec

## Source of truth

- Raw spec: `spec/raw_spec.md`
- Project metadata: `project.yaml`
- Common workflow root: `../common/workflows`
- Common skill root: `../common/skills`

## Current workflow stage

```text
project_bootstrap_from_spec
```

## Next recommended stage

```text
spec_to_requirements
```

## AI operating rules for this project

- Preserve raw spec exactly.
- Put generated RTL drafts under `rtl/generated/` until reviewed.
- Put reviewed RTL under `rtl/src/`.
- Keep project-specific scripts under `tools/` or `sim/`.
- Keep reusable assets under `../common`, not inside this project.
- Record major assumptions and decisions in `ai/` or `docs/`.
- Do not overwrite existing source or reports without checking.
- All parameters must be centralized in a SystemVerilog package for easy scaling.
- RTL must be parameterizable: changing model size (D_MODEL, N_HEAD, SEQ_LEN, etc.) should not require architectural changes.

## Open questions

- FlashAttention 的 tile 大小如何选择？（与 SRAM 容量和 MAC 阵列规模相关）
- 数据精度用 INT8 定点还是 FP16 半精度？还是两者都支持？
- RISC-V 核心是自建还是用开源 IP（如 picorv32）？
- 是否需要支持多 batch 推理？
- KV-Cache 管理策略：固定大小还是动态分配？
