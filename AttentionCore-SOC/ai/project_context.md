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
golden_matched
```

## Next recommended stage

```text
design_refinement_or_signoff
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

- OQ-001: RISC-V 核心选择 picorv32 还是自建？（P0，微架构阶段需确定）
- OQ-003: SRAM 宏的具体时序参数（P1）

## Resolved questions

- OQ-004: FP16 exp 查表精度已验证——256 条目 LUT（{exp[4:0], man[9:7]} 索引）+ FP16 截断运算，128/128 元素 bit 级精确匹配
- 数据精度：已确定 FP16（IEEE 754 半精度）
- 多 batch：已确定仅支持 batch_size=1
- FlashAttention 分块：已确定 B_r=B_c=4（入门版默认）
- OQ-002: UART 115200 波特率可接受（入门版数据量小，权重下载 ~1.1 秒）
- OQ-005: KV-Cache 管理策略：FIFO，地址递增回绕
- OQ-006: 多头并行：入门版不采用（选项 C 否决），标准版/增强版可考虑
- OQ-007: 不需要 DMA：RISC-V 逐字搬运足够（入门版数据量小）
