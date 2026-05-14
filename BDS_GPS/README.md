# BDS_GPS — 北斗/GPS C/A码捕获与跟踪设计

## 项目概述

本项目实现 BDS/GPS 卫星导航系统 C/A 码的捕获与跟踪，采用时分复用混合架构，支持同时处理 GPS L1 和 BDS B1 信号。项目包含完整的 RTL 设计、Python 分析工具和验证环境。

## 版本记录

| 版本 | 日期 | 状态 | 主要变更 |
|------|------|------|----------|
| v0.1 | 2026-05-08 | completed | 初始版本：完成 spec→需求→架构→微架构→RTL→验证全流程 |

### v0.1 版本特征

- 从原始 PDF 规格启动，经过完整的需求提取和架构探索
- 选定混合时分复用架构（4 种方案中评估选出）
- 生成 8 个 SystemVerilog RTL 模块
- 开发 Python C/A 码分析工具，完成实际解题
- 生成验证报告、设计报告和波形图

## 目录结构

```
BDS_GPS/
├── README.md                          # 本文件（中文，项目跟踪）
├── project.yaml                       # 项目配置元数据
├── SUBMISSION.md                      # 提交清单
├── spec/                              # 设计规格
│   ├── raw_spec.md                    # 原始规格（PDF提取）
│   ├── requirements.md                # 结构化需求文档
│   ├── data_BDS_GPS.txt               # 采样数据文件
│   ├── 数字1更新.md                    # 补充规格
│   └── 数字1更新.pdf                   # 补充规格原始PDF
├── docs/                              # 设计文档
│   ├── architecture/                  # 架构设计
│   │   ├── architecture_options.md    # 4种架构方案评估
│   │   └── selected_arch.md           # 选定架构（时分复用）
│   └── micro_arch/                    # 微架构设计
│       └── micro_architecture.md      # 模块分解、FSM、接口定义
├── rtl/                               # RTL源码
│   └── generated/                     # AI生成的RTL（8个模块）
│       ├── bds_gps_top.sv             # 顶层模块
│       ├── time_slice_scheduler.sv    # 时间片调度器
│       ├── ca_code_generator.sv       # C/A码生成器（GPS+BDS）
│       ├── correlator.sv              # 相关器
│       ├── accumulator.sv             # 累加器
│       ├── acquisition_detector.sv    # 捕获检测器
│       ├── tracking_controller.sv     # 跟踪控制器
│       └── output_interface.sv        # 输出接口
├── dv/                                # 验证环境
│   └── tb/
│       └── tb_bds_gps_top.sv          # 基础测试平台
├── sim/                               # 仿真目录
│   └── Makefile                       # VCS编译仿真脚本
├── tools/                             # 辅助工具
│   ├── analyze_ca_code.py             # C/A码分析脚本（核心解题工具）
│   └── generate_plots.py              # 波形生成脚本
├── reports/                           # 报告
│   └── verification/
│       ├── design_report.md           # 设计报告
│       ├── final_report.md            # 最终报告
│       ├── results.txt                # 分析结果
│       ├── waveforms.png              # 波形截图
│       ├── correlation_peaks.png      # 相关峰截图
│       └── cycle_codes.png            # 循环码截图
└── ai/                                # AI上下文
    └── project_context.md             # 项目状态和操作规则
```

## 设计参数

| 参数 | 值 | 说明 |
|------|-----|------|
| GPS C/A 码周期 | 1023 | GPS L1 C/A 码长度 |
| BDS C/A 码周期 | 2046 | BDS B1 C/A 码长度（截断1位） |
| 采样频率 | 根据采样数据确定 | 4位量化 |
| 捕获阈值 | 自适应（最大值50%） | Python脚本使用 |
| RTL 捕获阈值 | 1000 | RTL中固定值 |

## 验证结果

| 项目 | 结果 |
|------|------|
| GPS 卫星号 | sv_num = 22, 13 |
| BDS 卫星号 | sv_num = 4, 11 |
| 循环码 | 00101, 01010, 00101, 11010 |

## 主要特性

- **时分复用架构**：单相关器硬件复用，降低资源占用
- **双系统支持**：同时支持 GPS L1 和 BDS B1 信号
- **C/A 码生成**：完整的 GPS/BDS 伪随机码生成器
- **二维搜索**：码相位和多普勒频移联合搜索
- **自适应阈值**：基于最大相关的动态捕获判定

## 待改进项

- RTL 代码未从 `rtl/generated/` 提升到 `rtl/src/`（需 review）
- testbench 未使用真实采样数据进行仿真验证
- 缺少 UVM 验证环境
- 缺少 lint/CDC 静态检查
- 捕获阈值参数待优化

## 环境要求

- Synopsys VCS（仿真）
- Python 3.6+（C/A码分析工具）

## 快速开始

```bash
# 运行 C/A 码分析（Python）
cd tools
python analyze_ca_code.py

# 运行 RTL 仿真（需要 VCS）
cd sim
make compile
make sim
```

## 文档

- [原始规格](spec/raw_spec.md)
- [结构化需求](spec/requirements.md)
- [架构选项](docs/architecture/architecture_options.md)
- [选定架构](docs/architecture/selected_arch.md)
- [微架构设计](docs/micro_arch/micro_architecture.md)
- [设计报告](reports/verification/design_report.md)
- [最终报告](reports/verification/final_report.md)

---

版本：v0.1
最后更新：2026年5月8日
