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
requirements_ready
```

## Next recommended stage

```text
architecture_option_generation
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

- OQ-001: RISC-V 核心选择 picorv32 还是自建？picorv32 不支持 F 扩展（P0）
- OQ-002: UART 115200 波特率下载 16KB 权重需 ~1.1 秒，是否可接受？（P1）
- OQ-003: SRAM 宏的具体时序参数（P1）
- OQ-004: FP16 exp 查表精度是否满足 FlashAttention 数学等价要求？（P0）
- OQ-005: KV-Cache 管理策略：FIFO 还是 LRU？（P1）
- OQ-006: 多头并行计算的具体条件（P2）
- OQ-007: 是否需要 DMA 引擎加速数据搬运？（P1）

## Resolved questions

- 数据精度：已确定 FP16（IEEE 754 半精度）
- 多 batch：已确定仅支持 batch_size=1
- FlashAttention 分块：已确定 B_r=B_c=4（入门版默认）
