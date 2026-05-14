# AI Coding — 数字IC设计AI辅助工作流

## 概述

这是一套面向数字 IC 设计的 AI 辅助编码工作区。用户只需提供一份原始规格文档，AI agent 即可按照标准化流程自动完成从需求提取到签核打包的完整设计闭环。

## 工作流总览

```
用户原始 spec（文本/PDF/图片）
  │
  ├─ 项目初始化 ─→ 保存 spec、创建目录、生成元数据
  ├─ 需求提取 ───→ 结构化需求、假设、未决问题、验证意图
  ├─ 架构探索 ───→ 多方案评估、权衡矩阵、推荐选型
  ├─ 微架构设计 ─→ 模块分解、FSM、数据通路、接口契约
  ├─ RTL 生成 ───→ 可综合 SystemVerilog 代码
  ├─ 静态检查 ───→ lint、CDC/RDC 分析
  ├─ 仿真验证 ───→ smoke / directed / UVM 回归
  ├─ 设计迭代 ───→ 验证驱动修复、PPA 优化
  └─ 签核打包 ───→ 证据矩阵、waiver 清单、发布清单
```

每个阶段都有明确的输入/输出定义、质量门禁和检查清单，防止跳步或遗漏。

## 目录结构

```
ai_coding/
├── README.md                        # 本文件
├── AI_CODING_WORKFLOW_CN.md          # 工作流详细说明（中文）
├── common/                           # 可复用公共资产
│   ├── skills/                       # AI 能力定义（按阶段分组 00-90）
│   ├── workflows/                    # 阶段流程编排
│   ├── standards/                    # RTL/CDC/FSM 等设计规范
│   ├── templates/                    # 项目、RTL、UVM、仿真模板
│   ├── checklists/                   # 各阶段 review 检查清单
│   ├── schemas/                      # 结构化输出格式约束
│   ├── eda_adapters/                 # EDA 工具调用约定（VCS 等）
│   ├── knowledge_base/               # 设计模式和经验沉淀
│   ├── scripts/                      # 公共脚本
│   └── examples/                     # 参考设计
└── <project_name>/                   # 具体设计项目（每个项目一个目录）
    ├── project.yaml                  # 项目元数据和流程状态
    ├── README.md                     # 项目中文说明（版本跟踪）
    ├── ai/project_context.md         # AI 操作上下文
    ├── spec/                         # 规格和需求
    ├── docs/                         # 架构和微架构文档
    ├── rtl/                          # RTL 源码
    ├── dv/                           # 验证环境（UVM）
    ├── sim/                          # 仿真运行
    ├── reports/                      # 各阶段报告
    └── tools/                        # 项目辅助脚本
```

## 核心设计

### 阶段门禁

每个阶段有强制产出物要求。例如需求阶段必须输出 `spec/requirements.md` 且包含 `confirmed_requirements`、`open_questions`、`verification_intent` 三个非空章节，否则不允许进入架构阶段。

### 状态机

`project.yaml` 中的 `status` 字段驱动阶段推进：

```
initialized → requirements_ready → architecture_selected
→ micro_arch_ready → rtl_in_progress → verification_in_progress
→ signoff_ready
```

每个 workflow 完成后必须更新 `ai/project_context.md` 中的状态，确保跨会话连续性。

### Skill 体系

Skill 按数字前缀分组，对应设计流程阶段：

| 阶段 | 目录 | 职责 |
|------|------|------|
| 00 | spec_intake | 规格摄入、需求提取 |
| 10 | architecture_exploration | 架构方案生成与选型 |
| 20 | micro_arch_design | 微架构设计 |
| 30 | rtl_generation | RTL 代码生成 |
| 40 | static_checks | lint、CDC/RDC 静态分析 |
| 50 | simulation | 仿真调试（通用 + VCS） |
| 60 | uvm_generation | UVM 验证环境生成 |
| 70 | regression_debug | 回归失败分析 |
| 80 | design_refinement | 验证驱动修复、PPA 优化 |
| 90 | signoff_package | 签核打包 |

每个 skill 包含 `skill.yaml`（结构化定义）、`prompt.md`（agent 角色提示）、`README.md`（人读说明）。

### Schema 约束

8 个 YAML schema 约束各阶段的输出格式，确保字段完整性和阶段间契约一致性。

## 快速开始

### 新项目（从 spec 启动）

将原始规格文件放入工作区，告诉 agent：

```
请根据这份 spec 创建一个新项目，并按 ai_coding 工作流推进：
<粘贴 spec 内容或提供文件路径>
```

Agent 会自动：创建项目目录 → 保存 spec → 生成需求 → 探索架构 → ... → 签核。

### 已有项目（继续推进）

```
请继续推进 <project_name> 项目的 <阶段名> 阶段
```

Agent 会读取 `project.yaml` 和 `ai/project_context.md` 判断当前状态，从断点继续。

## 详细文档

- [AI_CODING_WORKFLOW_CN.md](AI_CODING_WORKFLOW_CN.md) — 完整工作流说明、agent 调度逻辑、状态机定义
