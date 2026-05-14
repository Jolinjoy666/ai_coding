# AttentionCore-SOC — Transformer 自注意力推理加速 SOC

## 项目概述

基于 FlashAttention 算法的 Transformer 推理加速 SOC，采用 RISC-V 控制核 + 专用注意力引擎架构。核心创新在于将 FlashAttention 的分块计算和在线 Softmax 算法硬件化，实现 IO-aware 的高效注意力推理。支持参数化配置，同一架构可覆盖从边缘关键词检测到小型 LLM 推理的多种场景。

## 版本记录

| 版本 | 日期 | 状态 | 主要变更 |
|------|------|------|----------|
| v0.1 | 2026-05-14 | initialized | 初始版本：项目创建，编写初版设计规格 |
| v0.2 | 2026-05-14 | rtl_in_progress | RTL生成：完成全部31个SystemVerilog源文件 |

### v0.1 版本特征

- 从用户讨论启动，确定 Transformer 自注意力加速方向
- 参考 FlashAttention 算法设计硬件加速架构
- 定义参数化模型规模体系（入门版→标准版→增强版→高性能版）
- 规划 6 大应用场景（关键词检测、时序异常检测、文本分类、ViT、DNA 分析、手势识别）

### v0.2 版本特征

- 完成结构化需求提取（42条确认需求、8条假设、7条开放问题）
- 完成架构选型：流水线重叠架构（MAC利用率72%，吞吐量19.9K tokens/s）
- 完成微架构设计：模块分解、接口契约、FSM、数据通路
- 生成31个SystemVerilog源文件，覆盖全部模块
- FP16运算单元：adder、multiplier、MAC(3级流水线)、阵列(4×4)
- FlashAttention核心：分块计算、在线Softmax、因果掩码
- 加速器：attention_engine、mlp_engine、layernorm_hw、residual_add、gelu_hw
- 总线：apb_interconnect(10从设备)、ctrl_regs(20个APB寄存器)
- 外设：uart_top(115200 8N1)、gpio_top(8out/4in)、timer_top
- 处理器：riscv_core(RV32IMF 2级流水线)
- 存储：sram_single_port、sram_dual_port

## 目录结构

```
AttentionCore-SOC/
├── README.md                          # 本文件（中文，项目跟踪）
├── project.yaml                       # 项目配置元数据
├── spec/                              # 设计规格
│   └── raw_spec.md                    # 原始设计规格
├── docs/                              # 设计文档
│   ├── architecture/                  # 架构设计
│   └── micro_arch/                    # 微架构设计
├── rtl/                               # RTL源码
│   ├── src/                           # review后的产品级RTL
│   ├── generated/                     # AI生成的RTL草稿
│   ├── include/                       # 头文件和宏定义
│   └── pkg/                           # SystemVerilog 参数包
├── dv/                                # 验证环境
│   ├── tb/                            # 测试平台
│   ├── uvm/                           # UVM组件
│   └── tests/                         # 定向测试
├── sim/                               # 仿真目录
├── lint/                              # 静态检查
├── formal/                            # 形式验证
├── synth/                             # 综合
├── tools/                             # 辅助工具
├── reports/                           # 各阶段报告
│   ├── requirements/
│   ├── architecture/
│   ├── micro_arch/
│   ├── rtl_review/
│   ├── verification/
│   └── signoff/
├── build/                             # 构建产物
├── third_party/                       # 外部IP
└── ai/                                # AI上下文
    └── project_context.md
```

## 设计参数（入门版）

| 参数 | 值 | 说明 |
|------|-----|------|
| D_MODEL | 16 | 模型维度 |
| N_HEAD | 2 | 注意力头数 |
| HEAD_DIM | 8 | 每头维度 (D_MODEL/N_HEAD) |
| NUM_LAYERS | 2 | Transformer Encoder 层数 |
| SEQ_LEN | 8 | 输入序列长度 |
| D_FF | 64 | FFN 中间层维度 |
| DATA_WIDTH | 16 | 数据位宽（INT8/FP16 可选） |
| MAC 阵列 | 4x4 | 脉动阵列规模 |

## 主要特性

- **FlashAttention 硬件化**：分块计算 + 在线 Softmax，最小化 SRAM 访存
- **脉动阵列 MatMul**：参数化 4x4 脉动阵列，支持 QKV 投影和注意力计算
- **硬件 Softmax/LayerNorm/GELU**：非线性函数硬件加速，避免软件瓶颈
- **KV-Cache 管理**：硬件 KV-Cache SRAM，支持自回归推理
- **参数化架构**：修改参数即可扩展模型规模，无需改 RTL 结构
- **APB 寄存器配置**：固件通过 APB 运行时配置模型参数

## 应用场景

| 应用 | 输入 | 输出 | 典型场景 |
|------|------|------|----------|
| 关键词检测 | 音频 MFCC 序列 | 关键词 ID | 唤醒词检测 |
| 时序异常检测 | 传感器序列 | 异常概率 | 工业预测维护 |
| 文本分类 | 短文本 token | 类别标签 | 嵌入式 NLU |
| Vision Transformer | 图像 Patch 序列 | 图像分类 | 嵌入式视觉 |
| DNA 序列分析 | 碱基 token 序列 | 突变预测 | 基因组分析 |
| 手势识别 | IMU 数据序列 | 手势 ID | 可穿戴设备 |

## 环境要求

- Synopsys VCS（仿真）
- Python 3.6+（Golden Model 对比）
- PyTorch（参考模型生成）

## 快速开始

```bash
# 生成 golden model 数据
cd tools && python generate_golden.py

# 编译仿真
cd sim && make compile

# 运行注意力单元验证
make run UVM_TEST=attention_unit_test SEED=1

# 运行全芯片推理验证
make run UVM_TEST=soc_inference_test SEED=1
```

## 文档

- [原始规格](spec/raw_spec.md)
- （后续阶段完成后补充）

---

版本：v0.2
最后更新：2026年5月14日
