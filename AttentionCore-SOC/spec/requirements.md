# AttentionCore-SOC 结构化需求

## 设计名称

AttentionCore-SOC — Transformer 自注意力推理加速 SOC

## 概述

基于 FlashAttention 算法的 Transformer 推理 SOC，采用 FP16 精度，RISC-V 控制核 + 专用注意力加速器架构。核心目标是高能效的 Attention 计算性能。

---

## 1. 确认需求 (confirmed_requirements)

### 1.1 核心架构

| ID | 需求 | 来源 |
|----|------|------|
| CR-001 | 采用 RISC-V RV32IMF 作为控制核心，不参与计算 | §3.2 |
| CR-002 | RISC-V 核心采用 2 级流水线（IF+EX），无缓存，无 MMU | §3.2 |
| CR-003 | RISC-V 核心通过 APB 总线访问所有外设和加速器 | §3.2, §3.4 |
| CR-004 | 加速器完成计算后通过中断通知 RISC-V | §3.3 |
| CR-005 | RISC-V 在等待加速器时使用 WFI 指令进入低功耗状态 | §3.2 |

### 1.2 Attention 引擎

| ID | 需求 | 来源 |
|----|------|------|
| CR-010 | 实现 FlashAttention 算法（分块计算 + 在线 Softmax） | §2.2, §4.5.2 |
| CR-011 | FP16 MAC 阵列，入门版 4×4 规模（参数可配） | §4.5.1 |
| CR-012 | 每个 PE 包含 FP16 乘法器（2 级流水线）、FP16 加法器（1 级）、FP32 累加器 | §4.5.1 |
| CR-013 | 峰值性能 1.6 GMAC/s = 3.2 GFLOPS @ 100MHz | §4.5.1 |
| CR-014 | FlashAttention 分块参数 B_r, B_c 可配（默认均为 4） | §4.5.2 |
| CR-015 | 在线 Softmax 使用 FP16 查表（256 条目 LUT）+ 线性插值 | §4.5.2 |
| CR-016 | FP16 迭代除法器，4 周期完成 | §4.5.2 |
| CR-017 | 因果掩码：对 i < j 位置设为 FP16 负无穷 | §4.5.3 |
| CR-018 | 多头注意力通过分时复用同一组 MAC 阵列实现 | §4.5.4 |

### 1.3 MLP 引擎

| ID | 需求 | 来源 |
|----|------|------|
| CR-020 | FC 层复用 MAC 阵列做矩阵乘 | §4.6.1 |
| CR-021 | GELU 激活函数使用 FP16 分段线性近似（32 段） | §4.6.2 |
| CR-022 | GELU 查表 32×32b，x > 4 输出 x，x < -4 输出 0 | §4.6.2 |

### 1.4 LayerNorm 与残差

| ID | 需求 | 来源 |
|----|------|------|
| CR-030 | LayerNorm 硬件实现：μ, σ² 计算 → rsqrt 查表 → γ·x_norm + β | §4.7 |
| CR-031 | rsqrt 查表 256 条目 | §4.7 |
| CR-032 | γ, β 参数存储在寄存器堆（d_model × 2 × FP16） | §4.7 |
| CR-033 | 残差加法：d_model 个 FP16 并行加法器 | §4.8 |

### 1.5 存储子系统

| ID | 需求 | 来源 |
|----|------|------|
| CR-040 | Weight SRAM：入门版 16KB，双端口 | §4.9 |
| CR-041 | Feature SRAM：入门版 16KB，双端口 | §4.9 |
| CR-042 | KV-Cache SRAM：入门版 8KB，双端口 | §4.9 |
| CR-043 | 指令 SRAM：16KB（RISC-V 程序存储） | §3.4 |
| CR-044 | 数据 SRAM：16KB（RISC-V 数据存储） | §3.4 |

### 1.6 外设

| ID | 需求 | 来源 |
|----|------|------|
| CR-050 | UART：115200 波特率，8N1，收发 FIFO 深度 16 | §4.3 |
| CR-051 | GPIO：8 位输出（LED），4 位输入（按键） | §4.4 |
| CR-052 | APB 互联：10 个从设备端口，高位地址解码，单主设备 | §4.2 |

### 1.7 控制寄存器

| ID | 需求 | 来源 |
|----|------|------|
| CR-060 | CTRL 寄存器：start/reset/abort 位 | §4.10 |
| CR-061 | STATUS 寄存器：busy/done/error 位 | §4.10 |
| CR-062 | 中断使能和状态寄存器（IRQ_EN, IRQ_STATUS） | §4.10 |
| CR-063 | 模型配置寄存器：seq_len, d_model, n_head, d_ff, num_layers | §4.10 |
| CR-064 | 存储基地址寄存器：weight, feature, kvcache | §4.10 |
| CR-065 | 性能计数器：cycle_count, throughput, mac_util | §4.10 |
| CR-066 | 总计 20 个 APB 寄存器，地址 0x00-0x4C | §4.10 |

### 1.8 固件

| ID | 需求 | 来源 |
|----|------|------|
| CR-070 | 3 层架构：HAL → 设备驱动 → 推理应用 | §7.1 |
| CR-071 | 推理流程：权重加载 → 输入加载 → 逐层推理（配置触发等待中断）→ 结果回传 | §3.3, §7.3 |
| CR-072 | 固件代码量约 1000 行 C，指令 SRAM 约 4KB | §7.2 |

### 1.9 参数化

| ID | 需求 | 来源 |
|----|------|------|
| CR-080 | 统一参数包 soc_params_pkg，包含所有模型和硬件参数 | §6.1 |
| CR-081 | 入门版：D_MODEL=16, N_HEAD=2, LAYERS=2, SEQ_LEN=8, D_FF=64 | §6.2 |
| CR-082 | 标准版：D_MODEL=32, N_HEAD=4, LAYERS=4, SEQ_LEN=32, D_FF=128 | §6.2 |
| CR-083 | 增强版：D_MODEL=64, N_HEAD=8, LAYERS=8, SEQ_LEN=64, D_FF=256 | §6.2 |
| CR-084 | 扩展只需改参数值，核心 RTL 不需重写 | §6.2 |

### 1.10 接口

| ID | 需求 | 来源 |
|----|------|------|
| CR-090 | 顶层端口：clk, rst_n, uart_rx, uart_tx, gpio_out[7:0], gpio_in[3:0], irq | §9.1 |
| CR-091 | APB 接口：paddr, psel, penable, pwrite, pwdata, prdata, pready, pslverr | §9.2 |

### 1.11 设计约束

| ID | 需求 | 来源 |
|----|------|------|
| CR-100 | 目标频率 100 MHz | §10.1 |
| CR-101 | 数据精度 FP16（IEEE 754 半精度） | §10.1 |
| CR-102 | 仅支持 Encoder（不支持 Decoder 交叉注意力） | §10.2 |
| CR-103 | 仅支持单 batch（batch_size = 1） | §10.2 |
| CR-104 | 不支持训练，仅推理 | §10.2 |

---

## 2. 假设 (assumptions)

| ID | 假设 | 理由 |
|----|------|------|
| AS-001 | 权重已预训练，通过 UART 下载到 SRAM | SOC 不含训练硬件 |
| AS-002 | 输入已完成 token化 和 embedding | SOC 仅做 Transformer 推理 |
| AS-003 | RISC-V 核心使用 picorv32 开源 IP 或简化版自建 | 降低开发复杂度 |
| AS-004 | SRAM 使用工艺厂商标准 SRAM 宏 | 假设 28nm 工艺 |
| AS-005 | FP16 精度足够覆盖目标应用场景（时序异常检测） | 现代 AI 芯片推理主流精度 |
| AS-006 | UART 115200 波特率足够用于权重下载和结果回传 | 入门版数据量小 |
| AS-007 | 单 batch 推理满足实时推理场景需求 | 控制复杂度 |
| AS-008 | FlashAttention 分块大小 B_r=B_c=4 对入门版参数足够 | d_model=16, seq_len=8 |

---

## 3. 开放问题 (open_questions)

| ID | 问题 | 影响 | 优先级 |
|----|------|------|--------|
| OQ-001 | RISC-V 核心选择 picorv32 还是自建？picorv32 不支持 F 扩展 | 需要评估 picorv32 + FPU 的集成方案 | P0 |
| OQ-002 | UART 波特率 115200 下载 16KB 权重需要 ~1.1 秒，是否可接受？ | 影响用户体验，考虑提高波特率或增加 SPI 接口 | P1 |
| SRAM 宏的具体时序参数（访问延迟、建立保持时间） | 影响时序收敛 | P1 |
| OQ-004 | FP16 exp 查表精度是否满足 FlashAttention 数学等价要求？ | 可能需要增加 LUT 条目或插值精度 | P0 |
| OQ-005 | KV-Cache 管理策略：FIFO 还是 LRU？seq_len 超过 SRAM 容量时如何处理？ | 影响推理质量和 SRAM 利用率 | P1 |
| OQ-006 | 多头并行计算（§5.4 提到条件允许时 2 头并行）的具体条件是什么？ | 需要额外的 SRAM 端口和控制逻辑 | P2 |
| OQ-007 | 是否需要 DMA 引擎来加速权重/数据搬运？ | RISC-V 逐字搬运效率低 | P1 |

---

## 4. 约束 (constraints)

### 4.1 时钟与复位

- 目标频率：100 MHz
- 复位：低有效异步复位（rst_n）
- 单时钟域设计（入门版）

### 4.2 接口协议

- APB 3.0 协议
- UART 8N1
- GPIO 无协议，直接电平

### 4.3 存储

- Weight SRAM：16KB 双端口（入门版）
- Feature SRAM：16KB 双端口（入门版）
- KV-Cache SRAM：8KB 双端口（入门版）
- 指令 SRAM：16KB
- 数据 SRAM：16KB

### 4.4 PPA 目标

| 指标 | 目标 |
|------|------|
| 总面积 | ~176K gates (~0.07mm² @ 28nm) |
| 动态功耗 | ~28 mW @ 100MHz |
| 总功耗 | ~29.3 mW |
| 峰值算力 | 3.2 GFLOPS (FP16) |
| MAC 利用率 | > 70% |
| 单层延迟 | < 50 μs |
| 吞吐量 | > 10K tokens/s |
| 能效 | < 10 μJ/token |

### 4.5 面积预算

| 模块 | 预算 (K gates) |
|------|---------------|
| RISC-V Core | 15 |
| APB Interconnect | 2 |
| UART | 3 |
| GPIO | 1 |
| Timer | 2 |
| Attention Engine | 68.5 |
| MLP Engine | 7 |
| LayerNorm HW | 8.5 |
| 残差加法 | 16 |
| 控制寄存器 | 2 |
| SRAM | ~50 |
| 其他 | 3 |

---

## 5. 验证意图 (verification_intent)

### 5.1 验证层级

| 层级 | 内容 | 通过标准 | 方法 |
|------|------|----------|------|
| L0 | FP16 MAC 阵列 | 与 PyTorch FP16 逐比特一致 | UVM + golden model |
| L1 | FP16 Softmax | 误差 < 0.5% | UVM + golden model |
| L2 | FP16 LayerNorm | 误差 < 0.5% | UVM + golden model |
| L3 | FP16 GELU | 误差 < 1% | UVM + golden model |
| L4 | QKV 投影 | 与 PyTorch 对比 | UVM + golden model |
| L5 | FlashAttention | 与标准注意力误差 < 1% | UVM + golden model |
| L6 | 单层 Encoder | 与 PyTorch 误差 < 2% | UVM + golden model |
| L7 | 2 层推理 | 端到端输出对比 | UVM + golden model |
| L8 | SOC 集成 | 固件+加速器+UART 全链路 | 系统级仿真 |
| L9 | 性能验证 | MAC 利用率 > 70%, 吞吐量达标 | 性能仿真 |
| L10 | PPA 验证 | 面积/功耗在目标范围内 | 静态分析 |
| L11 | 应用验证 | 时序异常检测端到端通过 | 系统级验证 |

### 5.2 Golden Model

- 使用 PyTorch `nn.TransformerEncoder` 作为参考模型
- FP16 精度（`.half()`）
- 输入：随机 FP16 张量 (1, 8, 16)
- 对比方法：逐层对比输出值

### 5.3 应用验证场景

**时序异常检测**：
- 输入：8 个时间步 × 3 个传感器（温度、振动、电流）→ FP16 embedding → 8 token 序列
- 输出：异常概率（0~1）
- 测试集：100 组正常 + 100 组异常
- 通过标准：
  - 100% 测试向量 FP16 误差 < 2%
  - 分类准确率差异 < 3%
  - 推理延迟 < 100μs（2 层）

### 5.4 功能覆盖点

- 所有 APB 寄存器读写
- 所有中断源触发和响应
- FlashAttention 分块边界条件（seq_len 非整数倍 B_r/B_c）
- 因果掩码正确性
- 多头调度完整性
- WFI 低功耗状态进入/退出
- UART 收发完整链路
- GPIO 输入输出

### 5.5 随机验证

- 随机化输入数据（FP16 范围内）
- 随机化模型参数（在参数包允许范围内）
- 随机化 APB 访问时序

---

## 6. 风险 (risks)

| ID | 风险 | 影响 | 缓解措施 |
|----|------|------|----------|
| RK-001 | FP16 exp 查表精度不足 | FlashAttention 输出偏差 | 增加 LUT 条目或使用更高精度插值 |
| RK-002 | RISC-V F 扩展集成复杂 | 开发周期延长 | 评估是否可省略 F 扩展，用软件模拟 |
| RK-003 | MAC 阵列利用率低于 70% | 性能不达标 | 优化数据流和 SRAM 访问模式 |
| RK-004 | SRAM 访存冲突 | 流水线停顿 | 分 bank 设计，增加缓冲 |
| RK-005 | 单时钟域 100MHz 时序紧张 | 需要降频 | 流水线切割，关键路径优化 |
| RK-006 | UART 权重下载速度慢 | 用户体验差 | 提高波特率或增加 SPI 接口 |
| RK-007 | FP16 动态范围不足（2^-24 ~ 2^15） | Softmax 溢出/下溢 | 增加数值稳定化逻辑 |
| RK-008 | 参数扩展后面积超出预算 | 需要重新评估架构 | 预留面积余量，优先优化关键路径 |

---

## 7. 范围外 (out_of_scope)

- Decoder 架构（交叉注意力）
- 训练功能
- 多 batch 推理
- FP32/INT8 精度
- 虚拟内存 / MMU
- 片外存储接口（DDR）
- 网络接口
- 动态电压频率调节（DVFS）
