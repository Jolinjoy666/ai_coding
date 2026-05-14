# AttentionCore-SOC 设计规格

## 1. 项目背景

### 1.1 为什么做这个

Transformer 架构已成为 AI 芯片的核心计算负载。从 ChatGPT 到自动驾驶感知，几乎所有前沿 AI 应用都依赖 Transformer 的自注意力机制。然而，标准注意力计算存在两大瓶颈：

1. **计算瓶颈**：Q·K^T 和 Attention·V 两次大规模矩阵乘法
2. **访存瓶颈**：需要将完整的注意力矩阵（seq_len × seq_len）写入/读出片上存储

FlashAttention（Tri Dao, 2022）通过分块计算（tiling）和在线 Softmax 算法解决了第二个瓶颈，但目前主要在 GPU 上实现。本项目的目标是将 FlashAttention 的核心思想硬件化，设计一颗专用的 Transformer 推理 SOC。

### 1.2 设计目标

- 实现基于 FlashAttention 算法的硬件自注意力引擎
- 支持参数化模型规模，同一架构覆盖多种应用场景
- RISC-V 固件驱动，支持软件配置和数据搬运
- 可验证：提供 golden model 对比，端到端推理结果可追溯

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

### 2.3 多头注意力

```
MultiHead(Q, K, V) = Concat(head_1, ..., head_h) · W_o
where head_i = Attention(Q·W_qi, K·W_ki, V·W_vi)
```

每个头独立计算，最后拼接投影。硬件上可以**分时复用**同一组 MAC 阵列。

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

## 3. SOC 架构

### 3.1 顶层框图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         AttentionCore-SOC                               │
│                                                                         │
│  ┌──────────┐        ┌────────────────────────────────────────────┐     │
│  │ RISC-V   │◄──────►│           Attention Engine                │     │
│  │ RV32I    │  APB   │                                           │     │
│  │ Core     │        │  ┌──────────┐  ┌───────────────────────┐  │     │
│  └────┬─────┘        │  │ QKV      │  │ FlashAttention Core   │  │     │
│       │              │  │ Linear   │  │                       │  │     │
│       │              │  │ Project  │  │  ┌─────┐ ┌─────────┐  │  │     │
│  ┌────┴─────┐        │  │          │  │  │Tile │ │Online   │  │  │     │
│  │ APB Bus  │◄──────►│  │ MAC Array│──►→ │MatMul│→│Softmax  │  │  │     │
│  │ Intercon │        │  │ (4x4)    │  │  └─────┘ └─────────┘  │  │     │
│  └──┬──┬──┬─┘        │  └──────────┘  │                       │  │     │
│     │  │  │          │                │  ┌─────┐ ┌─────────┐  │  │     │
│     │  │  │          │  ┌──────────┐  │  │Accum│ │Scale +  │  │  │     │
│  ┌──┴──┴──┴──┐       │  │ MLP      │  │  │Buffer│ │Mask     │  │  │     │
│  │ UART      │       │  │ Engine   │  │  └─────┘ └─────────┘  │  │     │
│  │ GPIO      │       │  │          │  └───────────────────────┘  │     │
│  │ Timer     │       │  │ FC1+GELU │                             │     │
│  └───────────┘       │  │ FC2      │  ┌──────────┐              │     │
│                      │  └──────────┘  │LayerNorm │              │     │
│  ┌───────────┐       │                │(HW)      │              │     │
│  │ Weight    │◄─────►│                └──────────┘              │     │
│  │ SRAM      │       │                                           │     │
│  │ (16KB)    │       │  ┌──────────┐  ┌──────────┐              │     │
│  ├───────────┤       │  │ KV-Cache │  │ Ctrl     │              │     │
│  │ Feature   │◄─────►│  │ SRAM     │  │ Regs     │◄── APB      │     │
│  │ SRAM      │       │  │ (8KB)    │  │ (APB)    │              │     │
│  │ (16KB)    │       │  └──────────┘  └──────────┘              │     │
│  └───────────┘       └────────────────────────────────────────────┘     │
│                                                                         │
│  ┌───────────┐                                                          │
│  │ Debug     │  ◄── JTAG（可选）                                        │
│  └───────────┘                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 数据流

**推理流程（固件视角）**：

```
Phase 1: 权重加载
  Host → UART → RISC-V → APB → Weight SRAM
  (W_q, W_k, W_v, W_o, W_fc1, W_fc2)

Phase 2: 输入加载
  Host → UART → RISC-V → APB → Feature SRAM
  (输入 token embedding 序列)

Phase 3: 逐层推理（硬件自动执行，固件配置触发）
  对每一层:
    3.1 配置 Attention Engine 参数（seq_len, d_model, n_head）
    3.2 触发 QKV 投影：Feature SRAM × Weight → Q,K,V
    3.3 触发 FlashAttention：Q,K,V → Attention Output
    3.4 触发残差加法 + LayerNorm
    3.5 触发 MLP：FC1 → GELU → FC2
    3.6 触发残差加法 + LayerNorm
    3.7 结果写回 Feature SRAM

Phase 4: 结果回传
  Feature SRAM → APB → RISC-V → UART → Host
```

## 4. 模块规格

### 4.1 RISC-V Core（riscv_core）

- 指令集：RV32I（基础整数指令集）
- 流水线：单周期或 2 级流水线
- 中断：支持外部中断（加速器完成、UART 收发）
- 总线接口：APB Master

### 4.2 APB 总线互联（apb_interconnect）

- 从设备地址映射：

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

### 4.3 UART（uart_top）

复用已有 UART IP，参数：
- 波特率：115200
- 数据位：8
- 停止位：1
- 校验：无
- 收发 FIFO 深度：16

### 4.4 GPIO（gpio_top）

- 8 位输出：LED 指示推理状态（idle/computing/done/error）
- 4 位输入：按键控制（start/reset/mode_select）

### 4.5 Attention Engine（attention_engine）

这是核心模块，实现 FlashAttention 算法。

#### 4.5.1 QKV 线性投影（qkv_projection）

```
功能: Q = X · W_q, K = X · W_k, V = X · W_v
输入: Feature SRAM (输入序列 X), Weight SRAM (W_q, W_k, W_v)
输出: Q, K, V 缓冲区

实现:
  - 复用 MAC 阵列做矩阵乘
  - Q/K/V 三次投影可分时复用同一硬件
  - 每次投影: (seq_len × d_model) × (d_model × d_model)
```

#### 4.5.2 脉动阵列（mac_array）

```
功能: 矩阵乘法核心计算单元
规模: ROWS × COLS（默认 4×4，参数可配）
数据流: 输出固定（output stationary）

每个 PE:
  result += a × b
  传递 a 向右，b 向下

时序:
  - 4×4 阵列: 每周期计算 4 个部分积
  - 完成一次 (4×4)×(4×1) 需要 4 周期
  - 完成一次 (seq_len×d_model)×(d_model×d_model) 需要复用多次
```

#### 4.5.3 FlashAttention 计算核心（flash_attention_core）

```
功能: 分块计算注意力，避免实例化完整 seq_len×seq_len 矩阵

分块参数:
  B_r: Q 的行分块大小（默认 4）
  B_c: K/V 的列分块大小（默认 4）

对每个 Q 块 (B_r 行):
  初始化: O = 0, m = -inf, l = 0
  对每个 KV 块 (B_c 列):
    1. S = Q_tile × K_tile^T / sqrt(d_k)     -- Tile MatMul
    2. m_new = max(m, rowmax(S))             -- 在线更新最大值
    3. P = exp(S - m_new)                    -- 指数运算
    4. l_new = exp(m - m_new) * l + rowsum(P) -- 更新归一化因子
    5. O = exp(m - m_new) * O + P × V_tile   -- 累加输出
    6. m = m_new, l = l_new
  O = O / l                                  -- 最终归一化

硬件单元:
  - Tile MatMul: 复用 mac_array
  - rowmax: 比较树，B_r 个并行比较器
  - exp(): 查表 + 线性插值（LUT-based）
  - rowsum: 加法树
  - 累加缓冲区: B_r × d_model 个寄存器
```

#### 4.5.4 因果掩码（causal_mask）

```
功能: 自回归推理时的下三角掩码
实现: 对 S 矩阵中 i < j 的位置设为 -inf

掩码生成:
  mask[i][j] = (i >= j) ? 0 : -inf

在 Softmax 之前应用:
  S_masked = S + mask
```

#### 4.5.5 多头调度（multi_head_scheduler）

```
功能: 将多头注意力的计算调度到同一硬件上分时执行

策略:
  对 head_i = 0 到 n_head-1:
    1. 从 QKV 缓冲区取出第 i 头的 Q_i, K_i, V_i
    2. 调用 FlashAttention Core 计算
    3. 将结果写入输出缓冲区第 i 头位置
  拼接所有头的输出
  执行输出投影: Output = Concat(heads) · W_o
```

### 4.6 MLP Engine（mlp_engine）

#### 4.6.1 全连接层（fc_layer）

```
功能: Y = X · W + b
实现: 复用 mac_array 做矩阵乘，加偏置
FC1: (seq_len × d_model) × (d_model × d_ff) → (seq_len × d_ff)
FC2: (seq_len × d_ff) × (d_ff × d_model) → (seq_len × d_model)
```

#### 4.6.2 GELU 激活函数（gelu_hw）

```
功能: GELU(x) = x · Φ(x) ≈ 0.5x(1 + tanh(√(2/π)(x + 0.044715x³)))

实现: 分段线性近似
  - 将输入范围 [-4, 4] 分成 16 段
  - 每段用 y = ax + b 近似
  - 查表获取 a, b 参数
  - x > 4: GELU(x) ≈ x
  - x < -4: GELU(x) ≈ 0
```

### 4.7 LayerNorm 硬件（layernorm_hw）

```
功能: LayerNorm(x) = γ · (x - μ) / √(σ² + ε) + β

计算步骤:
  1. μ = mean(x)          -- 求均值
  2. σ² = var(x)          -- 求方差
  3. x_norm = (x - μ) / √(σ² + ε)  -- 归一化
  4. output = γ · x_norm + β        -- 仿射变换

硬件实现:
  - 均值: 加法树 + 除法器（或乘倒数）
  - 方差: 减均值 → 平方 → 求和 → 除法
  - 归一化: 乘法器 + rsqrt 查表
  - γ, β: 存在寄存器或小 SRAM 中
```

### 4.8 残差加法（residual_add）

```
功能: output = x + residual
实现: 逐元素加法器，seq_len × d_model 个并行加法
时序: 1 周期完成（组合逻辑）
```

### 4.9 存储子系统

| 存储 | 容量 | 用途 | 接口 |
|------|------|------|------|
| Weight SRAM | 16KB（入门版）| QKV/MLP/Output 权重 | 双端口 SRAM |
| Feature SRAM | 16KB（入门版）| 输入序列、中间激活、输出 | 双端口 SRAM |
| KV-Cache SRAM | 8KB（入门版）| K/V 缓存，自回归推理用 | 双端口 SRAM |
| RegFile | 256B | LayerNorm 的 γ/β 参数 | 寄存器堆 |

扩展配置：

| 配置 | Weight SRAM | Feature SRAM | KV-Cache |
|------|-------------|--------------|----------|
| 入门版 | 16KB | 16KB | 8KB |
| 标准版 | 64KB | 64KB | 32KB |
| 增强版 | 256KB | 256KB | 128KB |

### 4.10 控制寄存器（ctrl_regs）

通过 APB 访问，固件配置加速器的工作参数：

| 偏移 | 名称 | 读/写 | 说明 |
|------|------|-------|------|
| 0x00 | CTRL | R/W | bit0: start, bit1: reset |
| 0x04 | STATUS | R | bit0: busy, bit1: done, bit2: error |
| 0x08 | IRQ_EN | R/W | 中断使能 |
| 0x0C | IRQ_STATUS | R/W1C | 中断状态 |
| 0x10 | CFG_SEQ_LEN | R/W | 序列长度 |
| 0x14 | CFG_D_MODEL | R/W | 模型维度 |
| 0x18 | CFG_N_HEAD | R/W | 注意力头数 |
| 0x1C | CFG_D_FF | R/W | FFN 中间维度 |
| 0x20 | CFG_NUM_LAYERS | R/W | Encoder 层数 |
| 0x24 | CFG_DATA_WIDTH | R/W | 数据位宽（8/16） |
| 0x28 | CFG_MAC_ROWS | R | MAC 阵列行数（只读） |
| 0x2C | CFG_MAC_COLS | R | MAC 阵列列数（只读） |
| 0x30 | WEIGHT_BASE | R/W | 权重 SRAM 基地址 |
| 0x34 | FEATURE_BASE | R/W | 特征 SRAM 基地址 |
| 0x38 | KVCACHE_BASE | R/W | KV-Cache 基地址 |
| 0x3C | LAYER_CFG | R/W | 当前层配置（layer_id 等） |
| 0x40 | TILE_CFG | R/W | 分块参数（B_r, B_c） |
| 0x44 | SCALE_FACTOR | R/W | 1/√d_k 定点值 |
| 0x48 | CYCLE_COUNT | R | 推理周期计数（性能统计） |

## 5. 参数化设计

### 5.1 统一参数包

所有可配置参数集中在 `rtl/pkg/soc_params_pkg.sv`：

```systemverilog
package soc_params_pkg;

  // ---- 模型架构参数 ----
  parameter int D_MODEL     = 16;    // 模型维度
  parameter int N_HEAD      = 2;     // 注意力头数
  parameter int HEAD_DIM    = D_MODEL / N_HEAD;
  parameter int NUM_LAYERS  = 2;     // Encoder 层数
  parameter int SEQ_LEN     = 8;     // 最大序列长度
  parameter int D_FF        = 64;    // FFN 中间维度

  // ---- 数据精度 ----
  parameter int DATA_WIDTH  = 16;    // 数据位宽
  parameter int ACC_WIDTH   = 32;    // 累加器位宽
  parameter int FRAC_BITS   = 8;     // 定点小数位数

  // ---- 硬件资源 ----
  parameter int MAC_ROWS    = 4;     // 脉动阵列行数
  parameter int MAC_COLS    = 4;     // 脉动阵列列数

  // ---- 存储容量（字数）----
  parameter int WEIGHT_WORDS   = 8192;   // 16KB / 2B
  parameter int FEATURE_WORDS  = 8192;
  parameter int KVCACHE_WORDS  = 4096;

  // ---- FlashAttention 分块 ----
  parameter int TILE_B_R   = 4;     // Q 行分块
  parameter int TILE_B_C   = 4;     // KV 列分块

endpackage
```

### 5.2 扩展指南

扩展模型规模时，只需修改参数包中的值：

| 从入门版到标准版 | 修改项 |
|-----------------|--------|
| D_MODEL: 16→32 | 改参数 |
| N_HEAD: 2→4 | 改参数 |
| SEQ_LEN: 8→32 | 改参数 |
| D_FF: 64→128 | 改参数 |
| MAC: 4×4→8×8 | 改参数（阵列自动扩展）|
| SRAM: 16KB→64KB | 改参数（存储自动扩展）|

不需要修改的：
- 计算引擎的控制 FSM 结构
- APB 总线互联逻辑
- 固件的推理流程代码（运行时配置）
- FlashAttention 算法逻辑

## 6. 固件设计

### 6.1 固件架构

```
┌──────────────────────────────────┐
│          Application Layer       │
│  ┌────────────────────────────┐  │
│  │ 模型配置表                  │  │
│  │ (d_model, n_head, layers)  │  │
│  └────────────────────────────┘  │
│  ┌────────────────────────────┐  │
│  │ 推理调度器                  │  │
│  │ (逐层触发加速器)           │  │
│  └────────────────────────────┘  │
├──────────────────────────────────┤
│          Driver Layer            │
│  ┌──────────┐ ┌──────────────┐  │
│  │ UART     │ │ Accelerator  │  │
│  │ Driver   │ │ Driver       │  │
│  └──────────┘ └──────────────┘  │
│  ┌──────────┐ ┌──────────────┐  │
│  │ GPIO     │ │ Timer        │  │
│  │ Driver   │ │ Driver       │  │
│  └──────────┘ └──────────────┘  │
├──────────────────────────────────┤
│          HAL Layer               │
│  ┌────────────────────────────┐  │
│  │ APB 读写函数               │  │
│  │ reg_read / reg_write       │  │
│  └────────────────────────────┘  │
└──────────────────────────────────┘
```

### 6.2 推理流程伪代码

```c
void transformer_inference(model_config_t *cfg) {
    // 1. 配置加速器
    write_reg(CFG_SEQ_LEN, cfg->seq_len);
    write_reg(CFG_D_MODEL, cfg->d_model);
    write_reg(CFG_N_HEAD, cfg->n_head);
    write_reg(CFG_D_FF, cfg->d_ff);

    // 2. 逐层推理
    for (int layer = 0; layer < cfg->num_layers; layer++) {
        // 2.1 QKV 投影
        load_weights_to_sram(cfg->w_qkv_offset[layer]);
        write_reg(CFG_LAYER_CFG, layer);
        write_reg(CTRL, CTRL_START_QKV);
        wait_irq(IRQ_QKV_DONE);

        // 2.2 FlashAttention
        write_reg(TILE_CFG, (cfg->tile_br << 16) | cfg->tile_bc);
        write_reg(SCALE_FACTOR, cfg->scale_1_sqrt_dk);
        write_reg(CTRL, CTRL_START_ATTN);
        wait_irq(IRQ_ATTN_DONE);

        // 2.3 残差 + LayerNorm
        write_reg(CTRL, CTRL_START_RESIDUAL_LN);
        wait_irq(IRQ_LN_DONE);

        // 2.4 MLP
        load_weights_to_sram(cfg->w_mlp_offset[layer]);
        write_reg(CTRL, CTRL_START_MLP);
        wait_irq(IRQ_MLP_DONE);

        // 2.5 残差 + LayerNorm
        write_reg(CTRL, CTRL_START_RESIDUAL_LN);
        wait_irq(IRQ_LN_DONE);
    }

    // 3. 读取结果
    read_output_from_sram(output_buffer);
}
```

## 7. 验证策略

### 7.1 Golden Model

使用 PyTorch 实现参考模型，生成测试向量：

```python
import torch
import torch.nn as nn

class AttentionCoreGoldenModel(nn.Module):
    def __init__(self, d_model=16, nhead=2, num_layers=2, d_ff=64):
        super().__init__()
        self.encoder_layer = nn.TransformerEncoderLayer(
            d_model=d_model, nhead=nhead,
            dim_feedforward=d_ff, batch_first=True
        )
        self.encoder = nn.TransformerEncoder(
            self.encoder_layer, num_layers=num_layers
        )

    def forward(self, x):
        return self.encoder(x)

# 生成测试向量
model = AttentionCoreGoldenModel()
x = torch.randn(1, 8, 16)  # (batch=1, seq_len=8, d_model=16)
output = model(x)
# 保存 input, weights, output 用于 RTL 验证
```

### 7.2 验证层级

| 层级 | 测试内容 | 通过标准 |
|------|----------|----------|
| MAC 阵列 | 4×4 矩阵乘 | 与 Python 结果逐比特一致 |
| Softmax | 定点 exp + 归一化 | 与 float 误差 < 1% |
| LayerNorm | 均值+方差+归一化 | 与 float 误差 < 1% |
| GELU | 分段线性近似 | 与 float 误差 < 2% |
| QKV 投影 | 矩阵乘+偏置 | 与 PyTorch 对比 |
| FlashAttention | 分块+在线softmax | 与标准注意力误差 < 1% |
| 单层 Encoder | Attn+MLP+LN+残差 | 与 PyTorch 误差 < 2% |
| 多层推理 | 2层 Encoder | 端到端输出对比 |
| SOC 集成 | 固件+加速器+UART | Host 发数据→推理→读结果 |
| 应用验证 | 关键词/分类任务 | 准确率与软件模型一致 |

### 7.3 测试数据

- **随机向量**：用于单元级测试（MAC、Softmax、LayerNorm）
- **固定序列**：用于集成测试（已知输入→已知输出）
- **MNIST 子集**：用于应用验证（10 类手写数字，每类 10 张）

## 8. 接口定义

### 8.1 顶层接口

```systemverilog
module attentioncore_soc_top (
  // 时钟和复位
  input  logic        clk,
  input  logic        rst_n,

  // UART
  input  logic        uart_rx,
  output logic        uart_tx,

  // GPIO
  output logic [7:0]  gpio_out,     // LED
  input  logic [3:0]  gpio_in,      // 按键

  // 中断
  output logic        irq           // 加速器完成中断
);
```

### 8.2 APB 接口（内部）

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

## 9. 性能目标

### 9.1 入门版（D_MODEL=16, SEQ_LEN=8, LAYERS=2）

| 指标 | 目标值 |
|------|--------|
| 推理延迟 | < 100K 时钟周期 |
| 时钟频率 | 100 MHz |
| 推理时间 | < 1 ms |
| 吞吐量 | > 1K tokens/s |
| 功耗 | < 50 mW（估算） |

### 9.2 时钟周期估算（单层）

| 操作 | 周期数（估算） |
|------|---------------|
| QKV 投影（3次 MatMul）| 3 × (8×16×16) / 16 ≈ 384 |
| FlashAttention（2头）| 2 × (8/4)×(8/4)×(4×4×4) ≈ 512 |
| LayerNorm × 2 | 2 × 8 × 16 ≈ 256 |
| MLP（FC1+GELU+FC2）| (8×16×64 + 8×64 + 8×64×16) / 16 ≈ 1024 |
| **单层合计** | **~2176** |
| **2层合计** | **~4352** |

## 10. 约束和限制

### 10.1 设计约束

- 目标工艺：不限（RTL 可综合即可）
- 时钟频率：100 MHz（入门版目标）
- 面积：不限（验证为主）
- 功耗：不限（验证为主）

### 10.2 功能限制

- 仅支持 Encoder（不支持 Decoder 的交叉注意力）
- 仅支持单 batch 推理（不支持 batch > 1）
- 不支持动态序列长度（运行时可配，但不超过 SEQ_LEN 上限）
- 不支持训练（仅推理）

### 10.3 已知假设

- 权重已预训练，通过 UART 下载到 SRAM
- 输入数据已 token化 和 embedding，通过 UART 下载
- 使用定点运算（INT8 或 FP16），精度损失可接受
- RISC-V 核心使用开源 IP（picorv32）或简化版自建
