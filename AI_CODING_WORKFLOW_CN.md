# AI Coding 工作流说明

## 1. 这套工作流解决什么问题

这套 `ai_coding` 工作流的目标是让 AI agent 能够在本地完成一套较规范的数字 IC 设计流程。

用户后续可以只给一个原始 spec，agent 会根据 `common/` 中的公共资产自动完成：

- 创建项目目录。
- 保存原始 spec。
- 生成项目元数据。
- 提取结构化需求。
- 进行架构探索。
- 生成微架构文档。
- 生成和 review RTL。
- 搭建仿真和 UVM 环境。
- 分析回归失败。
- 根据验证结果迭代 RTL/DV/spec。
- 最后整理 signoff package。

整体思想是：

```text
用户目标
  -> agent 判断当前阶段
  -> 读取对应 workflow
  -> 读取对应 skill
  -> 读取相关 template / standard / checklist / schema / eda_adapter
  -> 修改项目文件
  -> 输出当前阶段结果和下一步建议
```

## 2. 工作区目录分工

当前工作区根目录是：

```text
/home/hp/cfy/ai_coding
```

主要分为两类内容。

### 2.1 `common/`

`common/` 是公共能力库，不属于某一个具体项目。

它包含：

- `skills/`: agent 执行某类任务时的能力定义。
- `workflows/`: 多个 skill 串联起来的阶段流程。
- `templates/`: 创建项目、Makefile、filelist、报告等可复用模板。
- `standards/`: RTL、CDC/RDC、reset/clock、FSM、ready/valid 等规范。
- `checklists/`: 各阶段 review 和 signoff 检查清单。
- `schemas/`: 结构化输出格式，例如 requirements、micro-architecture、debug report。
- `eda_adapters/`: EDA 工具调用约定，例如 VCS。
- `scripts/`: 公共脚本。
- `examples/`: 后续可放参考设计。
- `knowledge_base/`: 项目无关的知识沉淀。

### 2.2 `<project_name>/`

每个具体设计项目是根目录下的一个独立文件夹，例如：

```text
Uart_Controller/
```

项目目录只放和该项目相关的内容，例如：

- `spec/`
- `docs/`
- `rtl/`
- `dv/`
- `sim/`
- `reports/`
- `project.yaml`
- `ai/project_context.md`

公共能力不复制进项目，而是通过 `project.yaml` 指向 `../common`。

## 3. agent 的总体调度逻辑

agent 每次接到任务后，先判断任务属于哪一种入口场景。

### 3.1 用户只给一个原始 spec，还没有项目目录

agent 应先进入项目初始化流程：

```text
common/workflows/project_bootstrap_from_spec.md
common/skills/00_spec_intake/project_bootstrap_from_spec/
```

它会：

1. 读取用户原始 spec。
2. 推导或询问项目名。
3. 检查 `/home/hp/cfy/ai_coding/<project_name>` 是否已存在。
4. 读取项目初始化模板：

```text
common/templates/project_init/
```

5. 创建标准项目目录。
6. 生成 `project.yaml`。
7. 生成项目 `README.md`。
8. 保存原始 spec 到：

```text
<project_name>/spec/raw_spec.md
```

9. 创建：

```text
<project_name>/ai/project_context.md
```

10. 进入下一阶段：

```text
common/skills/00_spec_intake/spec_to_requirements/
```

这个阶段只做项目环境搭建，不生成 RTL，不解释需求，不擅自决定架构。

### 3.2 项目已经存在，且有 `spec/raw_spec.md`

agent 会跳过 bootstrap，直接进入需求提取：

```text
common/workflows/spec_to_requirements.md
common/skills/00_spec_intake/spec_to_requirements/
```

它会先读取：

- 项目 `project.yaml`
- 项目 `ai/project_context.md`
- 项目 `spec/raw_spec.md`
- `spec_to_requirements` skill
- `requirements.schema.yaml`
- `spec_readiness_checklist.md`

然后输出结构化 requirements、assumptions、open questions、verification intent。

### 3.3 用户要求继续设计、生成 RTL、仿真、debug 或 signoff

agent 会根据任务关键词和当前项目状态选择对应阶段：

- 需求不清楚：进入 spec intake。
- 需要比较方案：进入 architecture exploration。
- 需要模块设计：进入 micro-architecture。
- 需要写 RTL：进入 RTL generation。
- 需要静态检查：进入 static checks。
- 需要仿真：进入 simulation。
- 需要 UVM：进入 UVM generation。
- 回归失败：进入 regression debug。
- 需要修 bug 或优化：进入 design refinement。
- 需要交付：进入 signoff package。

## 4. workflow、skill、template、checklist 的关系

### 4.1 workflow 是“流程编排”

`workflow` 回答的是：

```text
这个阶段先做什么，再做什么，完成标准是什么？
```

例如：

```text
common/workflows/end_to_end_ic_ai_coding.md
common/workflows/spec_to_requirements.md
common/workflows/requirements_to_architecture.md
common/workflows/micro_arch_to_rtl.md
common/workflows/regression_debug_loop.md
```

agent 在进入一个阶段前，会先读相关 workflow，确认当前阶段的顺序和停止条件。

### 4.2 skill 是“角色和能力定义”

`skill` 回答的是：

```text
agent 在这个任务中应该扮演什么角色？需要哪些输入？输出什么？有什么质量门禁和禁止事项？
```

每个 skill 通常包括：

```text
README.md
skill.yaml
prompt.md
```

其中：

- `README.md`: 给人看的说明，说明何时使用、输入输出和规则。
- `skill.yaml`: 给 agent 调度看的结构化定义，包括 inputs、outputs、references、quality_gates、guardrails。
- `prompt.md`: 给 agent 执行任务时使用的角色提示和操作流程。

agent 在真正执行某项任务前，应读取对应 skill。

### 4.3 template 是“可实例化文件模板”

`template` 用来生成实际项目文件。

例如项目初始化阶段会读取：

```text
common/templates/project_init/project.yaml.template
common/templates/project_init/README.md.template
common/templates/project_init/ai_project_context.md.template
common/templates/project_init/raw_spec.md.template
```

VCS 仿真阶段会读取：

```text
common/templates/simulation/vcs/Makefile
common/templates/simulation/vcs/filelists/dv.f
common/templates/simulation/vcs/scripts/check_sim_log.py
```

### 4.4 checklist 是“阶段门禁”

`checklist` 用来防止 agent 跳步、遗漏关键风险，或在证据不足时继续推进。

例如：

- 初始化项目后，用 `project_bootstrap_checklist.md`。
- 需求提取后，用 `spec_readiness_checklist.md`。
- 架构选择后，用 `architecture_review_checklist.md`。
- 微架构完成后，用 `micro_arch_review_checklist.md`。
- RTL review 时，用 `rtl_review_checklist.md`。
- UVM 环境完成后，用 `uvm_environment_review_checklist.md`。
- 回归关闭前，用 `regression_closure_checklist.md`。
- 交付前，用 `signoff_readiness_checklist.md`。

### 4.5 schema 是“结构化输出约束”

`schema` 用来约束某类输出应该包含哪些字段。

例如：

```text
common/schemas/project.schema.yaml
common/schemas/requirements.schema.yaml
common/schemas/architecture_option.schema.yaml
common/schemas/micro_arch.schema.yaml
common/schemas/testplan.schema.yaml
common/schemas/debug_report.schema.yaml
common/schemas/signoff_report.schema.yaml
```

agent 在生成结构化文档或报告时，应参考对应 schema。

### 4.6 standard 是“设计规范”

`standard` 用来约束 RTL 和验证设计风格。

例如 RTL 生成时会读取：

```text
common/standards/systemverilog_rtl_coding.md
common/standards/reset_and_clocking.md
common/standards/fsm_design.md
common/standards/ready_valid_protocol.md
common/standards/cdc_rdc_guidelines.md
```

### 4.7 eda_adapter 是“工具调用约定”

`eda_adapter` 不描述完整设计流程，只描述工具怎么调用。

例如 VCS 相关工具信息在：

```text
common/eda_adapters/vcs.md
```

VCS 详细流程则在：

```text
common/skills/50_simulation/vcs_simulation_flow/
common/skills/70_regression_debug/vcs_regression_debug/
common/templates/simulation/vcs/
```

## 5. 端到端执行顺序

完整执行链路如下。

### 阶段 0：任务入口判断

agent 先判断：

- 是新项目还是已有项目？
- 是否只有 spec？
- 是否已有 `project.yaml`？
- 是否已有 `ai/project_context.md`？
- 当前任务是设计、仿真、debug、优化还是 signoff？

如果没有项目，进入阶段 1。

如果已有项目，读取项目上下文后跳到对应阶段。

### 阶段 1：项目初始化

读取：

```text
common/workflows/project_bootstrap_from_spec.md
common/skills/00_spec_intake/project_bootstrap_from_spec/
common/templates/project_init/
common/schemas/project.schema.yaml
common/checklists/project_bootstrap_checklist.md
```

输出：

```text
<project_name>/project.yaml
<project_name>/README.md
<project_name>/spec/raw_spec.md
<project_name>/ai/project_context.md
```

### 阶段 2：需求提取

读取：

```text
common/skills/00_spec_intake/spec_to_requirements/
common/schemas/requirements.schema.yaml
common/checklists/spec_readiness_checklist.md
```

输出：

```text
spec/requirements.md
reports/requirements/
```

重点是区分：

- 已确认需求。
- 假设。
- 未决问题。
- 约束。
- 验证意图。

### 阶段 3：架构探索

读取：

```text
common/workflows/spec_to_architecture.md
common/skills/10_architecture_exploration/architecture_option_generation/
common/schemas/architecture_option.schema.yaml
common/checklists/architecture_review_checklist.md
```

输出：

```text
docs/architecture/options/
docs/architecture/selected_arch.md
reports/architecture/
```

agent 会生成多个架构方案，比较 PPA、复杂度、验证难度、风险，然后推荐一个。

### 阶段 4：微架构设计

读取：

```text
common/workflows/architecture_to_micro_arch.md
common/skills/20_micro_arch_design/micro_arch_design/
common/schemas/micro_arch.schema.yaml
common/checklists/micro_arch_review_checklist.md
```

输出：

```text
docs/micro_arch/
reports/micro_arch/
```

agent 会明确：

- 模块划分。
- 端口和接口协议。
- 参数。
- FSM。
- datapath。
- pipeline。
- memory 行为。
- reset/clock/CDC/RDC。
- latency 和 backpressure。
- assertion 和 testplan 种子。

### 阶段 5：RTL 生成和 review

读取：

```text
common/workflows/micro_arch_to_rtl.md
common/skills/30_rtl_generation/digital_ic_rtl_design/
common/standards/systemverilog_rtl_coding.md
common/standards/reset_and_clocking.md
common/standards/fsm_design.md
common/checklists/rtl_review_checklist.md
```

输出：

```text
rtl/generated/
rtl/src/
reports/rtl_review/
```

调度规则：

- AI 初版 RTL 先放 `rtl/generated/`。
- 经 review 后再进入 `rtl/src/`。
- 修改 RTL 前必须读取 micro-architecture 和相关 standard。
- 不应在需求或微架构不清楚时直接写 RTL。

### 阶段 6：静态检查

读取：

```text
common/workflows/rtl_static_check.md
common/skills/40_static_checks/rtl_static_check/
common/skills/40_static_checks/cdc_rdc_analysis/
common/checklists/cdc_rdc_review_checklist.md
```

输出：

```text
lint/
reports/rtl_review/
```

agent 会分析 lint、compile、CDC/RDC、潜在综合问题和 waiver 风险。

### 阶段 7：仿真

如果是通用 RTL 仿真，读取：

```text
common/workflows/rtl_simulation.md
common/skills/50_simulation/rtl_simulation_debug/
```

如果使用 VCS，进一步读取：

```text
common/eda_adapters/vcs.md
common/skills/50_simulation/vcs_simulation_flow/
common/templates/simulation/vcs/
common/checklists/vcs_flow_review_checklist.md
```

输出：

```text
sim/
reports/verification/
```

agent 会搭建或修改 Makefile、filelist、log checker，并运行 smoke/directed simulation。

### 阶段 8：UVM 环境生成

读取：

```text
common/workflows/rtl_to_uvm.md
common/skills/60_uvm_generation/uvm_env_generation/
common/schemas/testplan.schema.yaml
common/checklists/uvm_environment_review_checklist.md
```

输出：

```text
dv/
sim/
reports/verification/
```

agent 会规划或生成：

- interface。
- agent。
- driver。
- monitor。
- sequencer。
- env。
- sequence。
- test。
- scoreboard。
- reference model。
- coverage。

### 阶段 9：回归失败分析

如果 regression 失败，读取：

```text
common/workflows/regression_debug_loop.md
common/skills/70_regression_debug/regression_failure_analysis/
common/schemas/debug_report.schema.yaml
common/checklists/regression_closure_checklist.md
```

如果是 VCS 失败，进一步读取：

```text
common/skills/70_regression_debug/vcs_regression_debug/
common/eda_adapters/vcs.md
```

agent 会优先保存和分析：

- test name。
- seed。
- failing command。
- compile log。
- sim log。
- wave。
- scoreboard mismatch。
- recent changes。

然后判断失败属于：

- flow 问题。
- 编译问题。
- elaboration/link 问题。
- TB 问题。
- scoreboard 问题。
- reference model 问题。
- DUT RTL 问题。
- spec 不明确问题。

### 阶段 10：验证驱动修改和 PPA 优化

读取：

```text
common/skills/80_design_refinement/verification_driven_refinement/
common/skills/80_design_refinement/ppa_rtl_optimization/
```

agent 根据 debug 证据进行最小范围修改。

调度原则：

- 有证据才改 RTL。
- 可能是 TB、scoreboard、reference model 的问题时，不直接归咎 DUT。
- 行为改变时同步更新 spec、micro-architecture、testplan、coverage。
- 每次修改后给出 rerun plan。

### 阶段 11：signoff package

读取：

```text
common/workflows/signoff_package.md
common/skills/90_signoff_package/rtl_signoff_package/
common/schemas/signoff_report.schema.yaml
common/checklists/signoff_readiness_checklist.md
```

输出：

```text
reports/signoff/
```

agent 会整理：

- release manifest。
- final RTL filelist。
- verification evidence。
- regression summary。
- coverage summary。
- lint/CDC/RDC 状态。
- waivers。
- known risks。
- next-stage recommendations。

## 6. agent 什么时候读取 skill

agent 不是每次都读取所有 skill，而是按当前阶段读取最小必要集合。

### 6.1 进入新阶段时读取 skill

例如从 micro-architecture 进入 RTL 生成时，agent 读取：

```text
common/skills/30_rtl_generation/digital_ic_rtl_design/
```

因为角色、输入输出、guardrails 都发生了变化。

### 6.2 遇到工具相关任务时读取 EDA adapter

例如用户要求 VCS 仿真，agent 读取：

```text
common/eda_adapters/vcs.md
```

同时读取：

```text
common/skills/50_simulation/vcs_simulation_flow/
```

### 6.3 需要生成文件结构时读取 template

例如创建项目时读取：

```text
common/templates/project_init/
```

创建 VCS 仿真环境时读取：

```text
common/templates/simulation/vcs/
```

### 6.4 需要判断是否完成时读取 checklist

每个阶段结束前，agent 应读取对应 checklist 进行自检。

### 6.5 需要结构化输出时读取 schema

例如写 requirements 或 debug report 时，agent 应参考 schema，避免输出遗漏关键字段。

## 7. 调度优先级

agent 的调度优先级如下。

### 7.1 先保护用户输入

原始 spec、失败日志、波形、seed、golden data 不应被覆盖或删除。

### 7.2 先判断阶段，不盲目写代码

如果 spec、架构、微架构不清楚，agent 不应该直接写 RTL。

### 7.3 先读取项目上下文

已有项目中，agent 应优先读取：

```text
project.yaml
ai/project_context.md
spec/raw_spec.md
```

然后再读对应 workflow 和 skill。

### 7.4 先公共规则，后项目实现

agent 执行任务时，先读取 `common/` 的通用规则，再修改具体项目文件。

### 7.5 先最小改动，后扩大范围

debug 和 refinement 阶段应先定位 root cause，再进行最小必要修改。

### 7.6 每个阶段都要给出下一步

agent 完成当前阶段后，需要说明：

- 已生成什么。
- 当前有哪些假设和风险。
- 是否有 blocking question。
- 下一步应该进入哪个 workflow/skill。

## 8. 针对 `Uart_Controller` 项目的理解

`Uart_Controller` 是一个已经用这套工作流完成的项目。它应该被视为一个具体项目目录，而不是公共能力的一部分。

后续复用规则是：

- `Uart_Controller/` 中的内容属于该项目。
- 可复用的流程、规范、模板应该沉淀到 `common/`。
- 如果 `Uart_Controller` 中发现可复用经验，可以整理到 `common/examples/` 或 `common/knowledge_base/`。

## 9. 后续使用方式

之后你可以直接给 agent 一个新 spec，例如：

```text
请根据下面这个 spec 创建一个新项目，并按 ai_coding 工作流推进：
...
```

agent 应按如下方式调度：

```text
1. 判断是否已有项目名。
2. 如果没有，推导项目名并请求确认。
3. 读取 project_bootstrap_from_spec workflow 和 skill。
4. 创建项目目录和初始化文件。
5. 保存 raw spec。
6. 读取 spec_to_requirements skill。
7. 提取 requirements。
8. 根据 readiness checklist 判断是否能进入架构阶段。
9. 继续 architecture -> micro-architecture -> RTL -> static check -> simulation -> UVM -> regression -> refinement -> signoff。
```

这就是当前 `ai_coding` 环境的 agent 调度模型。

## 10. 项目状态机定义

`project.yaml` 中的 `project.status` 字段是一个状态机，agent 必须按以下规则推进。

### 10.1 状态枚举

```text
initialized
  → requirements_ready
    → architecture_selected
      → micro_arch_ready
        → rtl_in_progress
          → verification_in_progress
            → signoff_ready
```

### 10.2 状态转换规则

| 当前状态 | 转换条件 | 下一状态 | 负责方 |
|----------|----------|----------|--------|
| (无) | project_bootstrap 完成 | initialized | bootstrap workflow |
| initialized | `spec/requirements.md` 存在且通过 spec_readiness_checklist | requirements_ready | spec_to_requirements workflow |
| requirements_ready | `docs/architecture/selected_arch.md` 存在且通过 architecture_review_checklist | architecture_selected | requirements_to_architecture workflow |
| architecture_selected | `docs/micro_arch/micro_architecture.md` 存在且通过 micro_arch_review_checklist | micro_arch_ready | architecture_to_micro_arch workflow |
| micro_arch_ready | 至少一个文件从 `rtl/generated/` 提升到 `rtl/src/` 且通过 rtl_review_checklist | rtl_in_progress | micro_arch_to_rtl workflow |
| rtl_in_progress | 首次仿真通过（smoke test 或 directed test） | verification_in_progress | rtl_simulation 或 rtl_to_uvm workflow |
| verification_in_progress | 所有回归测试通过且 signoff checklist 通过 | signoff_ready | signoff_package workflow |

### 10.3 状态同步职责

- **谁更新状态**：每个 workflow 的最后一步必须更新 `ai/project_context.md` 中的 `current_workflow_stage`。
- **何时更新**：在该 workflow 的所有质量门禁通过后、推荐下一步之前。
- **降级规则**：如果后续阶段发现上游问题（如 RTL bug 需要改微架构），状态可以降级，但必须记录降级原因。
- **跳步禁止**：agent 不得跳过中间状态。例如不能从 `initialized` 直接到 `rtl_in_progress`。

### 10.4 agent 入口判断流程

```text
1. 读取 project.yaml 的 status 字段。
2. 如果 status 不存在 → 新项目，进入 bootstrap。
3. 如果 status == initialized → 检查 spec/requirements.md 是否存在。
   - 存在且完整 → 推进到 requirements_ready。
   - 不存在 → 进入 spec_to_requirements。
4. 如果 status == requirements_ready → 检查 docs/architecture/selected_arch.md 是否存在。
   - 存在 → 推进到 architecture_selected。
   - 不存在 → 进入 requirements_to_architecture。
5. 以此类推，按状态机推进。
6. 如果用户要求跳到特定阶段，检查前置状态是否满足，不满足则拒绝并说明原因。
```
