# AttentionCore-SOC 设计规格

## 1. 项目背景

### 1.1 为什么做这个

Transformer 架构已成为 AI 芯片的核心计算负载。从 ChatGPT 到自动驾驶感知，几乎所有前沿 AI 应用都依赖 Transformer 的自注意力机制。然而，标准注意力计算存在两大瓶颈：

1. **计算瓶颈**：Q·K^T 和 Attention·V 两次大规模矩阵乘法
2. **访存瓶颈**：需要将完整的注意力矩阵（seq_len × seq_len）写入/读出片上存储

FlashAttention（Tri Dao, 2022）通过分块计算（tiling）和在线 Softmax 算法解决了第二个瓶颈，但目前主要在 GPU 上实现。本项目的目标是将 FlashAttention 的核心思想硬件化，设计一颗专用的 Transformer 推理 SOC。

### 1.2 设计目标

- 实现基于 FlashAttention 算法的硬件自注意力引擎
- **核心指标是 Attention 性能**：吞吐量（tokens/s）和延迟（ms/token）
- **PPA 导向设计**：在满足性能目标的前提下优化功耗和面积
- RISC-V 控制核设计合理高效，不成为瓶颈
- 数据精度采用 **FP16 半精度浮点**
- 参数化架构，同一 RTL 支持多种模型规模
- 可验证：提供 golden model 对比，端到端推理结果可追溯

### 1.3 核心性能指标

| 指标 | 定义 | 目标（入门版） | 优先级 |
|------|------|---------------|--------|
| **Attention Throughput** | 每秒处理的 token 数 | > 10K tokens/s | P0 |
| **Attention Latency** | 单层注意力的推理延迟 | < 50μs @ 100MHz | P0 |
| **Energy per Token** | 每个 token 的能耗 | < 10μJ/token | P1 |
| **Area Efficiency** | 性能/面积比 | > 1 GOPS/mm² | P1 |
| **MAC Utilization** | 脉动阵列利用率 | > 70% | P0 |
| **SRAM Bandwidth** | 片上存储带宽利用率 | > 80% | P1 |

## 2. 算法背景

### 2.1 标准自注意力

```
输入: X ∈ R^(seq_len × d_model)

线性投影:
  Q = X · W_q    (seq_len × d_model) × (d_model × d_model)
  K = X · W_k
  V = X · W_v

注意力计算:
  Scores = Q · K^T / √d_k     (seq_len × seq_len)
  Attention = softmax(Scores)  (seq_len × seq_len)
  Output = Attention · V       (seq_len × d_model)
```

问题：Scores 矩阵大小为 seq_len × seq_len，当 seq_len=1024 时需要 1M 个元素的中间存储。

### 2.2 FlashAttention 算法

FlashAttention 的核心思想是**分块计算**，避免实例化完整的 seq_len × seq_len 注意力矩阵：

```
将 Q 分成块: Q_1, Q_2, ..., Q_Tb  (每块 B_r 行)
将 K, V 分成块: (K_1,V_1), (K_2,V_2), ..., (K_Tc,V_Tc)  (每块 B_c 列)

对每个 Q 块 Q_i:
  初始化: O_i = 0, m_i = -∞, l_i = 0
  对每个 KV 块 (K_j, V_j):
    计算局部注意力: S_ij = Q_i · K_j^T / √d_k
    更新在线 softmax:
      m_new = max(m_i, rowmax(S_ij))
      P_ij = exp(S_ij - m_new)
      l_new = exp(m_i - m_new) · l_i + rowsum(P_ij)
      O_i = exp(m_i - m_new) · O_i + P_ij · V_j
      m_i = m_new, l_i = l_new
  O_i = O_i / l_i    (最终归一化)
```

关键特性：
- **IO-aware**：SRAM 只需存储当前块，不需要完整注意力矩阵
- **在线 Softmax**：不需要两遍扫描，一遍完成 softmax + matmul
- **精确计算**：结果与标准注意力数学等价（不是近似）
- **SRAM 友好**：中间结果保持在片上 SRAM，减少外部访存

### 2.3 多头注意力

```
MultiHead(Q, K, V) = Concat(head_1, ..., head_h) · W_o
where head_i = Attention(Q·W_qi, K·W_ki, V·W_vi)
```

每个头独立计算，最后拼接投影。硬件上**分时复用**同一组 MAC 阵列。

### 2.4 Transformer Encoder Layer

```
输入 x
  ↓
LayerNorm(x)
  ↓
MultiHead Attention (self-attention)
  ↓
Residual Add: x + Attention_output
  ↓
LayerNorm(x)
  ↓
MLP: FC1 → GELU → FC2
  ↓
Residual Add: x + MLP_output
  ↓
输出
```

### 2.5 FP16 浮点格式

采用 IEEE 754 半精度浮点（FP16）：

```
┌───┬─────────┬──────────────┐
│ S │ Exponent│   Mantissa   │
│1b│  5 bits │   10 bits    │
└───┴─────────┴──────────────┘

范围: ±65504
精度: ~3.3 位十进制有效数字
动态范围: 2^(-24) ~ 2^15

优势:
- 相比 INT8 精度损失更小，适合注意力中的 exp/softmax
- 相比 FP32 面积和功耗减半
- 现代 AI 芯片的主流推理精度（A100、H100 的推理模式）
```

FP16 运算单元：
- FP16 加法器：1 级流水线
- FP16 乘法器：2 级流水线
- FP16 MAC（乘累加）：3 级流水线
- FP16 比较器：组合逻辑
- FP16→INT 转换：1 级流水线

## 3. SOC 架构

### 3.1 顶层框图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         AttentionCore-SOC                               │
│                                                                         │
│  ┌──────────┐        ┌────────────────────────────────────────────┐     │
│  │ RISC-V   │◄──────►│           Attention Engine                │     │
│  │ RV32IMF  │  APB   │                                           │     │
│  │ Core     │        │  ┌──────────┐  ┌───────────────────────┐  │     │
│  │          │        │  │ QKV      │  │ FlashAttention Core   │  │     │
│  │ (控制核) │        │  │ Linear   │  │                       │  │     │
│  └────┬─────┘        │  │ Project  │  │  ┌─────┐ ┌─────────┐  │  │     │
│       │              │  │          │  │  │Tile │ │Online   │  │  │     │
│       │              │  │ FP16 MAC │──►→ │MatMul│→│Softmax  │  │  │     │
│  ┌────┴─────┐        │  │ Array    │  │  │(FP16)│ │(FP16)   │  │  │     │
│  │ APB Bus  │◄──────►│  │ (4x4)    │  │  └─────┘ └─────────┘  │  │     │
│  │ Intercon │        │  └──────────┘  │                       │  │     │
│  └──┬──┬──┬─┘        │                │  ┌─────┐ ┌─────────┐  │  │     │
│     │  │  │          │  ┌──────────┐  │  │Accum│ │Scale +  │  │  │     │
│     │  │  │          │  │ MLP      │  │  │Buffer│ │Mask     │  │  │     │
│  ┌──┴──┴──┴──┐       │  │ Engine   │  │  │(FP16)│ │(FP16)   │  │  │     │
│  │ UART      │       │  │          │  │  └─────┘ └─────────┘  │  │     │
│  │ GPIO      │       │  │ FC1+GELU │  └───────────────────────┘  │     │
│  │ Timer     │       │  │ FC2      │                             │     │
│  └───────────┘       │  │(FP16 MAC)│  ┌──────────┐              │     │
│                      │  └──────────┘  │LayerNorm │              │     │
│  ┌───────────┐       │                │(FP16 HW) │              │     │
│  │ Weight    │◄─────►│                └──────────┘              │     │
│  │ SRAM      │       │                                           │     │
│  │ (16KB)    │       │  ┌──────────┐  ┌──────────┐              │     │
│  ├───────────┤       │  │ KV-Cache │  │ Ctrl     │              │     │
│  │ Feature   │◄─────►│  │ SRAM     │  │ Regs     │◄── APB      │     │
│  │ SRAM      │       │  │ (8KB)    │  │ (APB)    │              │     │
│  │ (16KB)    │       │  └──────────┘  └──────────┘              │     │
│  └───────────┘       └────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 RISC-V 核心定位：控制而非计算

RISC-V 核心的职责是**控制和协调**，不是参与计算：

```
RISC-V 做的事（合理且高效）:
  ✓ 配置加速器寄存器（APB 写）
  ✓ 触发计算启动（APB 写 CTRL 寄存器）
  ✓ 等待中断（WFI 指令，低功耗）
  ✓ UART 数据收发（搬运权重和输入到 SRAM）
  ✓ 结果读取和回传
  ✓ 错误处理和状态管理

RISC-V 不做的事:
  ✗ 矩阵乘法（交给 MAC 阵列）
  ✗ Softmax/LayerNorm（交给硬件加速器）
  ✗ 注意力计算（交给 FlashAttention Core）
  ✗ 大规模数据搬运（用 DMA 或 SRAM 直接映射）
```

RISC-V 核心选择：**RV32IMF**
- RV32I：基础整数指令集（控制逻辑）
- M：乘除法指令（固件中的地址计算、索引）
- F：单精度浮点（配置 FP16 参数时的格式转换，不用于推理计算）

核心微架构：**2 级流水线**（取指 + 执行），足够高效，不浪费面积：
- 单周期执行大多数指令
- 分支预测：静态（向后跳转预测为 taken）
- 不需要缓存（指令和数据都在 SRAM 中）
- 不需要 MMU（无虚拟内存需求）

### 3.3 数据流

**推理流程（固件视角）**：

```
Phase 1: 权重加载
  Host → UART → RISC-V → APB → Weight SRAM
  (W_q, W_k, W_v, W_o, W_fc1, W_fc2 均为 FP16)

Phase 2: 输入加载
  Host → UART → RISC-V → APB → Feature SRAM
  (输入 token embedding 序列，FP16)

Phase 3: 逐层推理（硬件自动执行，固件配置触发）
  对每一层:
    3.1 配置 Attention Engine（seq_len, d_model, n_head）
    3.2 触发 QKV 投影 → 等待中断
    3.3 触发 FlashAttention → 等待中断
    3.4 触发残差加法 + LayerNorm → 等待中断
    3.5 触发 MLP（FC1→GELU→FC2）→ 等待中断
    3.6 触发残差加法 + LayerNorm → 等待中断

Phase 4: 结果回传
  Feature SRAM → APB → RISC-V → UART → Host
```

### 3.4 APB 地址映射

| 地址空间 | 设备 | 大小 |
|----------|------|------|
| 0x0000_0000 - 0x0000_3FFF | 指令 SRAM | 16KB |
| 0x0000_4000 - 0x0000_7FFF | 数据 SRAM | 16KB |
| 0x1000_0000 - 0x1000_0FFF | UART | 4KB |
| 0x1000_1000 - 0x1000_1FFF | GPIO | 4KB |
| 0x1000_2000 - 0x1000_2FFF | Timer | 4KB |
| 0x2000_0000 - 0x2000_0FFF | Attention Engine Ctrl | 4KB |
| 0x2000_1000 - 0x2000_1FFF | MLP Engine Ctrl | 4KB |
| 0x3000_0000 - 0x3000_FFFF | Weight SRAM | 64KB |
| 0x3001_0000 - 0x3001_FFFF | Feature SRAM | 64KB |
| 0x3002_0000 - 0x3002_7FFF | KV-Cache SRAM | 32KB |

## 4. 模块规格

### 4.1 RISC-V Core（riscv_core）

- 指令集：RV32IMF
- 流水线：2 级（IF + EX），简洁高效
- 寄存器堆：32×32b 通用寄存器
- 乘法器：单周期 32b 乘法，多周期除法
- 浮点：FP32 单精度（用于 FP16 参数转换，不参与推理）
- 中断：支持外部中断（加速器完成、UART 收发）
- 总线接口：APB Master
- 功耗优化：WFI 指令进入低功耗等待状态

**面积估算**：~15K gates（不含 SRAM）

### 4.2 APB 总线互联（apb_interconnect）

- 10 个从设备端口
- 地址解码：高位匹配
- 无仲裁（单主设备）
- 0 等周期访问（SRAM）或可配置等待（外设）

**面积估算**：~2K gates

### 4.3 UART（uart_top）

- 波特率：115200（可配置）
- 数据位：8，停止位：1，无校验
- 收发 FIFO：深度 16
- 中断支持：收发完成

**面积估算**：~3K gates

### 4.4 GPIO（gpio_top）

- 8 位输出（LED：idle/computing/done/error）
- 4 位输入（按键：start/reset/mode）

**面积估算**：~1K gates

### 4.5 Attention Engine（attention_engine）

核心计算模块，实现 FlashAttention 算法。

#### 4.5.1 FP16 MAC 阵列（fp16_mac_array）

```
功能: FP16 矩阵乘法核心
规模: 4×4（参数可配: MAC_ROWS × MAC_COLS）
数据流: 输出固定（output stationary）

每个 PE（处理单元）:
  result_fp16 += a_fp16 × b_fp16

  FP16 乘法器: 2 级流水线
  FP16 加法器: 1 级流水线
  FP16 累加器: 32b 寄存器（FP32 精度累加，最后转回 FP16）

时序:
  - 4×4 阵列: 每周期 16 个 MAC 操作
  - 峰值性能: 16 MAC × 100MHz = 1.6 GMAC/s = 3.2 GFLOPS（FP16）

面积估算（单个 PE）:
  FP16 乘法器: ~1.5K gates
  FP16 加法器: ~1K gates
  累加寄存器: ~200 gates
  控制逻辑: ~300 gates
  合计: ~3K gates/PE

总面积: 4×4 × 3K = 48K gates
```

#### 4.5.2 FlashAttention Core（flash_attention_core）

```
功能: 分块计算注意力，在线 Softmax

分块参数:
  B_r: Q 的行分块大小（默认 4）
  B_c: K/V 的列分块大小（默认 4）

对每个 Q 块 (B_r 行):
  初始化: O = 0(FP16), m = -inf(FP16), l = 0(FP16)
  对每个 KV 块 (B_c 列):
    1. S = Q_tile × K_tile^T / sqrt(d_k)     -- 复用 mac_array
    2. m_new = max(m, rowmax(S))             -- FP16 比较树
    3. P = exp(S - m_new)                    -- FP16 exp 查表
    4. l_new = exp(m - m_new) * l + rowsum(P) -- FP16 乘加
    5. O = exp(m - m_new) * O + P × V_tile   -- 复用 mac_array
    6. m = m_new, l = l_new
  O = O / l                                  -- FP16 除法

硬件单元:
  - rowmax: B_r 个 FP16 比较器（树形结构）
  - exp(): FP16 查表 + 线性插值，256 条目 LUT
  - rowsum: B_r 个 FP16 加法树
  - 累加缓冲区: B_r × d_model × FP16 寄存器
  - 除法器: FP16 迭代除法（4 周期）

面积估算:
  比较器/加法树: ~2K gates
  exp LUT (256×16b): ~4K gates
  除法器: ~3K gates
  累加缓冲区 (4×16×16b): ~1K gates
  控制 FSM: ~2K gates
  合计: ~12K gates
```

#### 4.5.3 因果掩码（causal_mask）

```
功能: 自回归推理时的下三角掩码
实现: 对 S 矩阵中 i < j 的位置设为 FP16 负无穷

面积估算: ~500 gates
```

#### 4.5.4 多头调度（multi_head_scheduler）

```
功能: 分时复用硬件计算多头注意力

策略:
  对 head_i = 0 到 n_head-1:
    1. 从 QKV 缓冲区取出第 i 头数据
    2. 调用 FlashAttention Core
    3. 写入输出缓冲区
  拼接 → 输出投影 W_o

面积估算: ~2K gates（控制逻辑 + 地址生成）
```

#### 4.5.5 Attention Engine 总面积

| 子模块 | 面积（gates） |
|--------|-------------|
| FP16 MAC 阵列 (4×4) | 48K |
| FlashAttention Core | 12K |
| 因果掩码 | 0.5K |
| 多头调度 | 2K |
| QKV 缓冲区 | 4K |
| 控制寄存器 | 2K |
| **合计** | **~68.5K gates** |

### 4.6 MLP Engine（mlp_engine）

#### 4.6.1 全连接层（fc_layer）

```
功能: Y = X · W + b (FP16)
实现: 复用 mac_array 做矩阵乘
FC1: (seq_len × d_model) × (d_model × d_ff) → (seq_len × d_ff)
FC2: (seq_len × d_ff) × (d_ff × d_model) → (seq_len × d_model)
```

#### 4.6.2 GELU 激活函数（gelu_hw）

```
功能: GELU(x) ≈ 0.5x(1 + tanh(√(2/π)(x + 0.044715x³)))

实现: FP16 分段线性近似
  - 输入范围 [-4, 4] 分成 32 段
  - 每段 y = ax + b（a, b 为 FP16 常数）
  - 查表获取 a, b
  - x > 4: output = x
  - x < -4: output = 0

面积估算:
  LUT (32×32b): ~1K gates
  乘法器+加法器: ~2.5K gates
  控制: ~500 gates
  合计: ~4K gates
```

#### 4.6.3 MLP Engine 总面积

| 子模块 | 面积（gates） |
|--------|-------------|
| GELU 硬件 | 4K |
| 偏置加法器 | 1K |
| 控制逻辑 | 2K |
| **合计** | **~7K gates** |

（FC 层复用 MAC 阵列，不额外增加面积）

### 4.7 LayerNorm 硬件（layernorm_hw）

```
功能: LayerNorm(x) = γ · (x - μ) / √(σ² + ε) + β (FP16)

计算步骤:
  1. μ = mean(x)                    -- FP16 加法树 + 乘倒数
  2. σ² = var(x)                    -- 减均值 → 平方 → 求和 → 乘倒数
  3. x_norm = (x - μ) × rsqrt(σ² + ε)  -- rsqrt 查表
  4. output = γ × x_norm + β        -- 乘加

硬件实现:
  - 加法树: d_model 个 FP16 加法器
  - rsqrt 查表: 256 条目，输入 FP16 → 输出 FP16
  - 乘法器: FP16 × FP16
  - γ, β: 存在寄存器堆（d_model × 2 × FP16）

面积估算:
  加法树: ~2K gates
  rsqrt LUT: ~3K gates
  乘法器: ~1.5K gates
  γ/β 寄存器: ~1K gates
  控制: ~1K gates
  合计: ~8.5K gates
```

### 4.8 残差加法（residual_add）

```
功能: output = x + residual (FP16)
实现: d_model 个 FP16 并行加法器

面积估算: d_model × 1K gates = 16K gates
```

### 4.9 存储子系统

| 存储 | 入门版容量 | 用途 | 类型 |
|------|-----------|------|------|
| Weight SRAM | 16KB | QKV/MLP/Output 权重 (FP16) | 双端口 SRAM |
| Feature SRAM | 16KB | 输入序列、中间激活、输出 (FP16) | 双端口 SRAM |
| KV-Cache SRAM | 8KB | K/V 缓存 (FP16) | 双端口 SRAM |
| γ/β RegFile | 64B | LayerNorm 参数 | 寄存器堆 |

FP16 存储计算：
- FP16 = 2 字节
- 16KB = 8192 个 FP16 值
- 入门版 d_model=16, seq_len=8: 单层权重 ≈ 4×16×16×2B = 2KB，8 层 ≈ 16KB

扩展配置：

| 配置 | Weight | Feature | KV-Cache | 适用场景 |
|------|--------|---------|----------|----------|
| 入门版 | 16KB | 16KB | 8KB | 功能验证 |
| 标准版 | 64KB | 64KB | 32KB | 关键词检测 |
| 增强版 | 256KB | 256KB | 128KB | 文本分类/ViT |

### 4.10 控制寄存器（ctrl_regs）

| 偏移 | 名称 | 读/写 | 说明 |
|------|------|-------|------|
| 0x00 | CTRL | R/W | bit0: start, bit1: reset, bit2: abort |
| 0x04 | STATUS | R | bit0: busy, bit1: done, bit2: error |
| 0x08 | IRQ_EN | R/W | 中断使能 |
| 0x0C | IRQ_STATUS | R/W1C | 中断状态 |
| 0x10 | CFG_SEQ_LEN | R/W | 序列长度 |
| 0x14 | CFG_D_MODEL | R/W | 模型维度 |
| 0x18 | CFG_N_HEAD | R/W | 注意力头数 |
| 0x1C | CFG_D_FF | R/W | FFN 中间维度 |
| 0x20 | CFG_NUM_LAYERS | R/W | Encoder 层数 |
| 0x24 | CFG_MAC_ROWS | R | MAC 阵列行数（只读） |
| 0x28 | CFG_MAC_COLS | R | MAC 阵列列数（只读） |
| 0x2C | WEIGHT_BASE | R/W | 权重 SRAM 基地址 |
| 0x30 | FEATURE_BASE | R/W | 特征 SRAM 基地址 |
| 0x34 | KVCACHE_BASE | R/W | KV-Cache 基地址 |
| 0x38 | LAYER_CFG | R/W | 当前层配置 |
| 0x3C | TILE_CFG | R/W | 分块参数（B_r, B_c） |
| 0x40 | SCALE_FACTOR | R/W | 1/√d_k（FP16 值） |
| 0x44 | CYCLE_COUNT | R | 推理周期计数 |
| 0x48 | PERF_ATTN_THROUGHPUT | R | Attention 吞吐量（tokens/cycle）|
| 0x4C | PERF_MAC_UTIL | R | MAC 阵列利用率（%）|

## 5. PPA 分析

### 5.1 面积估算（入门版）

| 模块 | 面积（K gates） | 占比 |
|------|----------------|------|
| RISC-V Core (RV32IMF) | 15 | 8.5% |
| APB Interconnect | 2 | 1.1% |
| UART | 3 | 1.7% |
| GPIO | 1 | 0.6% |
| Timer | 2 | 1.1% |
| **Attention Engine** | **68.5** | **38.9%** |
| MLP Engine | 7 | 4.0% |
| LayerNorm HW | 8.5 | 4.8% |
| 残差加法 | 16 | 9.1% |
| 控制寄存器 | 2 | 1.1% |
| SRAM（16+16+8 KB）| ~50 | 28.4% |
| 其他（连线、IO）| 3 | 1.7% |
| **总计** | **~176K gates** | 100% |

等效面积（28nm 工艺）：
- 176K gates × 1.5 μm²/gate ≈ 0.026 mm²（纯逻辑）
- 40KB SRAM ≈ 0.04 mm²
- **总面积 ≈ 0.07 mm²**

### 5.2 功耗估算（入门版 @ 100MHz）

| 模块 | 动态功耗（mW） | 静态功耗（mW） |
|------|---------------|---------------|
| Attention Engine | 15 | 0.5 |
| MLP Engine | 3 | 0.2 |
| LayerNorm | 2 | 0.1 |
| RISC-V Core | 2 | 0.1 |
| SRAM 访问 | 5 | 0.3 |
| 其他 | 1 | 0.1 |
| **总计** | **~28 mW** | **~1.3 mW** |
| **合计** | **~29.3 mW** | |

### 5.3 性能分析（入门版）

#### 5.3.1 Attention 性能核心指标

```
单层 Attention 计算量:
  QKV 投影: 3 × 2 × seq_len × d_model × d_model = 3 × 2 × 8 × 16 × 16 = 12,288 FLOPs
  QK^T MatMul: 2 × seq_len × seq_len × d_k = 2 × 8 × 8 × 8 = 1,024 FLOPs
  P×V MatMul: 2 × seq_len × seq_len × d_v = 2 × 8 × 8 × 8 = 1,024 FLOPs
  输出投影: 2 × seq_len × d_model × d_model = 2 × 8 × 16 × 16 = 4,096 FLOPs
  Softmax: ~4 × seq_len × seq_len = 256 FLOPs
  合计: ~18,688 FLOPs

单层 MLP 计算量:
  FC1: 2 × seq_len × d_model × d_ff = 2 × 8 × 16 × 64 = 16,384 FLOPs
  FC2: 2 × seq_len × d_ff × d_model = 2 × 8 × 64 × 16 = 16,384 FLOPs
  合计: ~32,768 FLOPs

单层总计算量: ~51,456 FLOPs

MAC 阵列峰值: 4×4 × 2 = 32 FLOPs/cycle
@ 100MHz: 3.2 GFLOPS

理论单层延迟:
  Attention: 18,688 / 32 = 584 cycles
  MLP: 32,768 / 32 = 1,024 cycles
  LayerNorm + 残差: ~200 cycles
  合计: ~1,808 cycles

实际延迟（考虑利用率 70%）:
  ~1,808 / 0.7 ≈ 2,583 cycles ≈ 25.8μs @ 100MHz
```

#### 5.3.2 性能总结

| 指标 | 入门版 |
|------|--------|
| 峰值算力 | 3.2 GFLOPS (FP16) |
| MAC 利用率 | ~70%（目标） |
| 有效算力 | ~2.24 GFLOPS |
| 单层延迟 | ~25.8 μs |
| 2 层推理延迟 | ~51.6 μs |
| 吞吐量（2层） | ~19.4K tokens/s |
| 能效 | ~29.3mW / 19.4K = 1.5 μJ/token |

### 5.4 PPA 优化策略

| 策略 | 措施 | 效果 |
|------|------|------|
| 时钟门控 | 加速器空闲时关闭时钟 | 静态功耗降低 60% |
| SRAM 分bank | 权重/特征/缓存独立 bank | 避免访存冲突 |
| 流水线重叠 | QKV 投影与 FlashAttention 流水 | 延迟降低 15% |
| 多头并行 | 条件允许时 2 头并行计算 | 吞吐量提升 80% |
| 定点转 FP16 | rsqrt/exp 用查表替代精确计算 | 面积降低 30% |

## 6. 参数化设计

### 6.1 统一参数包

```systemverilog
package soc_params_pkg;

  // ---- 模型架构参数 ----
  parameter int D_MODEL     = 16;
  parameter int N_HEAD      = 2;
  parameter int HEAD_DIM    = D_MODEL / N_HEAD;
  parameter int NUM_LAYERS  = 2;
  parameter int SEQ_LEN     = 8;
  parameter int D_FF        = 64;

  // ---- 数据精度 ----
  parameter int FP16_WIDTH  = 16;
  parameter int FP32_WIDTH  = 32;

  // ---- 硬件资源 ----
  parameter int MAC_ROWS    = 4;
  parameter int MAC_COLS    = 4;

  // ---- 存储容量（FP16 字数）----
  parameter int WEIGHT_WORDS   = 8192;   // 16KB / 2B
  parameter int FEATURE_WORDS  = 8192;
  parameter int KVCACHE_WORDS  = 4096;

  // ---- FlashAttention 分块 ----
  parameter int TILE_B_R   = 4;
  parameter int TILE_B_C   = 4;

endpackage
```

### 6.2 扩展路径

```
入门版 ──改参数──→ 标准版 ──改参数+扩存储──→ 增强版
D_MODEL=16        D_MODEL=32          D_MODEL=64
N_HEAD=2          N_HEAD=4            N_HEAD=8
SEQ_LEN=8         SEQ_LEN=32          SEQ_LEN=64
MAC 4×4           MAC 4×4             MAC 8×8
SRAM 40KB         SRAM 160KB          SRAM 640KB

每一步只需修改 soc_params_pkg.sv 中的参数值
核心 RTL（FSM、数据通路、控制逻辑）不需要重写
```

## 7. 固件设计

### 7.1 架构

```
┌──────────────────────────────────┐
│       Inference Application      │
│  模型配置表 + 推理调度器          │
├──────────────────────────────────┤
│       Device Drivers             │
│  UART / GPIO / Accelerator       │
├──────────────────────────────────┤
│       HAL                        │
│  reg_read / reg_write / delay    │
└──────────────────────────────────┘
```

### 7.2 RISC-V 固件代码量估算

| 模块 | 代码量 | 说明 |
|------|--------|------|
| HAL 层 | ~100 行 | APB 读写函数 |
| UART 驱动 | ~200 行 | 收发 + FIFO |
| GPIO 驱动 | ~50 行 | LED/按键 |
| 加速器驱动 | ~300 行 | 配置 + 触发 + 等待 |
| 推理调度 | ~200 行 | 逐层循环 |
| 主程序 | ~150 行 | 初始化 + 数据收发 |
| **合计** | **~1000 行 C** | 指令 SRAM ~4KB |

### 7.3 推理流程

```c
void transformer_inference(model_config_t *cfg) {
    // 配置加速器
    write_reg(CFG_SEQ_LEN, cfg->seq_len);
    write_reg(CFG_D_MODEL, cfg->d_model);
    write_reg(CFG_N_HEAD, cfg->n_head);
    write_reg(CFG_D_FF, cfg->d_ff);
    write_reg(SCALE_FACTOR, fp16_encode(1.0f / sqrt(cfg->d_model / cfg->n_head)));

    for (int layer = 0; layer < cfg->num_layers; layer++) {
        // QKV 投影
        load_weights(cfg->w_qkv_offset[layer]);
        write_reg(CFG_LAYER_CFG, layer);
        write_reg(CTRL, CTRL_START_QKV);
        wait_irq(IRQ_QKV_DONE);

        // FlashAttention
        write_reg(TILE_CFG, (cfg->tile_br << 16) | cfg->tile_bc);
        write_reg(CTRL, CTRL_START_ATTN);
        wait_irq(IRQ_ATTN_DONE);

        // 残差 + LayerNorm
        write_reg(CTRL, CTRL_START_RESIDUAL_LN);
        wait_irq(IRQ_LN_DONE);

        // MLP
        load_weights(cfg->w_mlp_offset[layer]);
        write_reg(CTRL, CTRL_START_MLP);
        wait_irq(IRQ_MLP_DONE);

        // 残差 + LayerNorm
        write_reg(CTRL, CTRL_START_RESIDUAL_LN);
        wait_irq(IRQ_LN_DONE);
    }

    read_output(cfg->output_offset);
}
```

## 8. 验证策略

### 8.1 Golden Model

```python
import torch
import torch.nn as nn

class AttentionCoreGoldenModel(nn.Module):
    def __init__(self, d_model=16, nhead=2, num_layers=2, d_ff=64):
        super().__init__()
        self.encoder = nn.TransformerEncoder(
            nn.TransformerEncoderLayer(d_model, nhead, d_ff, batch_first=True),
            num_layers
        )
    def forward(self, x):
        return self.encoder(x)

# FP16 精度验证
model = AttentionCoreGoldenModel().half()
x = torch.randn(1, 8, 16, dtype=torch.float16)
output = model(x)
```

### 8.2 验证层级

| 层级 | 内容 | 通过标准 |
|------|------|----------|
| L0 | FP16 MAC 阵列 | 与 PyTorch FP16 逐比特一致 |
| L1 | FP16 Softmax | 与 PyTorch 误差 < 0.5% |
| L2 | FP16 LayerNorm | 与 PyTorch 误差 < 0.5% |
| L3 | FP16 GELU | 与 PyTorch 误差 < 1% |
| L4 | QKV 投影 | 与 PyTorch 对比 |
| L5 | FlashAttention | 与标准注意力误差 < 1% |
| L6 | 单层 Encoder | 与 PyTorch 误差 < 2% |
| L7 | 2层推理 | 端到端输出对比 |
| L8 | SOC 集成 | 固件+加速器+UART 全链路 |
| L9 | 性能验证 | MAC利用率>70%, 吞吐量达标 |
| L10 | PPA 验证 | 面积/功耗在目标范围内 |
| L11 | 应用验证 | 简单应用场景端到端通过 |

### 8.3 应用验证方案（L11）

完成基础验证后，用一个简单应用场景做端到端验证：

**场景：时序异常检测**

```
输入: 8 个时间步的传感器数据（温度、振动、电流）
      → FP16 embedding → 8 token 序列
输出: 异常概率（0~1）

验证方法:
  1. Python 生成测试数据集（100 组正常 + 100 组异常）
  2. PyTorch 训练一个 2 层 Transformer Encoder 分类器
  3. 导出权重到 FP16
  4. 通过 UART 下载到 SOC
  5. 逐条推理，对比 Python 输出
  6. 统计准确率差异（应 < 2%，因 FP16 精度损失）

通过标准:
  - 100% 测试向量 FP16 误差 < 2%
  - 分类准确率与 Python 模型差异 < 3%
  - 推理延迟 < 100μs（2层）
```

## 9. 接口定义

### 9.1 顶层接口

```systemverilog
module attentioncore_soc_top (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        uart_rx,
  output logic        uart_tx,
  output logic [7:0]  gpio_out,
  input  logic [3:0]  gpio_in,
  output logic        irq
);
```

### 9.2 APB 接口

```systemverilog
interface apb_if;
  logic [31:0] paddr;
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;
endinterface
```

## 10. 约束和限制

### 10.1 设计约束

- 目标频率：100 MHz
- 数据精度：FP16（IEEE 754 半精度）
- 验证优先：功能正确性 > PPA 优化
- 参数化：所有模型参数集中在参数包

### 10.2 功能限制

- 仅支持 Encoder（不支持 Decoder 交叉注意力）
- 仅支持单 batch（batch_size = 1）
- 不支持动态序列长度（运行时可配，不超过 SEQ_LEN 上限）
- 不支持训练（仅推理）
- FP16 精度，不适合需要 FP32 精度的场景

### 10.3 已知假设

- 权重已预训练，通过 UART 下载到 SRAM
- 输入已 token化 和 embedding
- RISC-V 核心使用开源 IP（picorv32）或简化版自建
- SRAM 使用工艺厂商提供的标准 SRAM 宏

## 11. 开发路线

```
Phase 1（当前）: 入门版功能验证
  → D_MODEL=16, N_HEAD=2, LAYERS=2, SEQ=8
  → 跑通全部验证层级 L0-L8
  → 性能验证 L9-L10

Phase 2: 应用验证
  → 时序异常检测端到端验证 L11
  → 确认 FP16 精度满足应用需求

Phase 3: merge to main
  → 所有验证通过后合并到主分支

Phase 4: 参数扩展（后续）
  → 标准版/增强版参数
  → 更多应用场景验证
```
