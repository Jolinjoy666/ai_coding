# AttentionCore-SOC 微架构设计

## 1. 模块分解

### 1.1 顶层模块

```
attentioncore_soc_top
├── riscv_core              # RISC-V 控制核 (RV32IMF)
├── apb_interconnect        # APB 总线互联
├── uart_top                # UART 外设
├── gpio_top                # GPIO 外设
├── timer_top               # Timer 外设
├── attention_engine        # Attention 引擎顶层
│   ├── fp16_mac_array      # FP16 4×4 MAC 阵列
│   ├── flash_attention_core # FlashAttention 核心
│   ├── causal_mask         # 因果掩码
│   ├── multi_head_scheduler # 多头调度器
│   ├── qkv_buffer          # QKV 缓冲区
│   ├── pipeline_buffer     # 流水线 ping-pong 缓冲区
│   └── attn_ctrl_fsm       # Attention 控制 FSM
├── mlp_engine              # MLP 引擎
│   ├── gelu_hw             # GELU 硬件
│   └── mlp_ctrl_fsm        # MLP 控制 FSM
├── layernorm_hw            # LayerNorm 硬件
├── residual_add            # 残差加法
├── ctrl_regs               # APB 控制寄存器
├── sram_weight             # Weight SRAM
├── sram_feature            # Feature SRAM (A/B bank)
├── sram_kvcache            # KV-Cache SRAM
├── sram_inst               # 指令 SRAM
└── sram_data               # 数据 SRAM
```

### 1.2 模块职责

| 模块 | 职责 | 接口 |
|------|------|------|
| riscv_core | 控制和协调，不参与计算 | APB Master |
| apb_interconnect | 地址解码，单主多从路由 | APB Slave × 10 |
| fp16_mac_array | FP16 矩阵乘法核心 | 自定义流式接口 |
| flash_attention_core | 分块注意力计算，在线 Softmax | 自定义流式接口 |
| attn_ctrl_fsm | Attention 流水线控制 | APB Slave + IRQ |
| mlp_engine | MLP 计算（FC1+GELU+FC2） | APB Slave + IRQ |
| layernorm_hw | LayerNorm 计算 | 自定义流式接口 |
| residual_add | 残差加法 | 自定义流式接口 |
| ctrl_regs | APB 寄存器文件 | APB Slave |

---

## 2. 接口契约

### 2.1 顶层端口

```systemverilog
module attentioncore_soc_top (
  // 时钟与复位
  input  logic        clk,          // 100 MHz 主时钟
  input  logic        rst_n,        // 低有效异步复位

  // UART
  input  logic        uart_rx,      // UART 接收
  output logic        uart_tx,      // UART 发送

  // GPIO
  output logic [7:0]  gpio_out,     // LED 输出
  input  logic [3:0]  gpio_in,      // 按键输入

  // 中断
  output logic        irq           // 中断输出
);
```

### 2.2 APB 接口

```systemverilog
interface apb_if;
  logic [31:0] paddr;      // 地址
  logic        psel;       // 从设备选择
  logic        penable;    // 使能
  logic        pwrite;     // 写使能
  logic [31:0] pwdata;     // 写数据
  logic [31:0] prdata;     // 读数据
  logic        pready;     // 就绪（可插入等待）
  logic        pslverr;    // 从设备错误

  modport master (output paddr, psel, penable, pwrite, pwdata,
                  input  prdata, pready, pslverr);
  modport slave  (input  paddr, psel, penable, pwrite, pwdata,
                  output prdata, pready, pslverr);
endinterface
```

### 2.3 MAC 阵列流式接口

```systemverilog
interface mac_stream_if;
  logic        valid;       // 数据有效
  logic        ready;       // 下游就绪
  logic [15:0] a_data;     // A 矩阵数据 (FP16)
  logic        a_last;     // A 矩阵行/列结束
  logic [15:0] b_data;     // B 矩阵数据 (FP16)
  logic        b_last;     // B 矩阵行/列结束
  logic [15:0] result;     // 结果 (FP16)
  logic        result_valid;

  modport producer (output valid, a_data, a_last, b_data, b_last,
                    input  ready, result, result_valid);
  modport consumer (input  valid, a_data, a_last, b_data, b_last,
                    output ready, result, result_valid);
endinterface
```

### 2.4 SRAM 接口

```systemverilog
interface sram_if #(parameter int WORDS = 8192, parameter int WIDTH = 16);
  logic [$clog2(WORDS)-1:0] addr;
  logic                     cs;       // 片选
  logic                     we;       // 写使能
  logic [WIDTH-1:0]         wdata;    // 写数据
  logic [WIDTH-1:0]         rdata;    // 读数据

  modport master (output addr, cs, we, wdata, input rdata);
  modport slave  (input  addr, cs, we, wdata, output rdata);
endinterface
```

### 2.5 流水线握手协议

```
valid/ready 握手规则:
  - 数据传输当且仅当 valid && ready 同时为高
  - producer 在 valid 为高后不能取消数据
  - consumer 在 ready 为高后不能拒绝已握手的数据
  - valid 不能依赖于 ready（防止组合环路）
```

---

## 3. 参数定义

### 3.1 统一参数包

```systemverilog
package soc_params_pkg;

  // ---- 模型架构参数 ----
  parameter int D_MODEL     = 16;       // 模型维度
  parameter int N_HEAD      = 2;        // 注意力头数
  parameter int HEAD_DIM    = D_MODEL / N_HEAD;  // 每头维度 = 8
  parameter int NUM_LAYERS  = 2;        // Encoder 层数
  parameter int SEQ_LEN     = 8;        // 序列长度
  parameter int D_FF        = 64;       // FFN 中间维度

  // ---- 数据精度 ----
  parameter int FP16_WIDTH  = 16;
  parameter int FP32_WIDTH  = 32;

  // ---- 硬件资源 ----
  parameter int MAC_ROWS    = 4;
  parameter int MAC_COLS    = 4;
  parameter int MAC_PE_COUNT = MAC_ROWS * MAC_COLS;  // 16

  // ---- 存储容量（FP16 字数）----
  parameter int WEIGHT_WORDS   = 8192;   // 16KB / 2B
  parameter int FEATURE_WORDS  = 8192;
  parameter int KVCACHE_WORDS  = 4096;
  parameter int INST_WORDS     = 8192;   // 16KB
  parameter int DATA_WORDS     = 8192;   // 16KB

  // ---- FlashAttention 分块 ----
  parameter int TILE_B_R   = 4;
  parameter int TILE_B_C   = 4;

  // ---- 流水线缓冲 ----
  parameter int PIPELINE_BUF_DEPTH = 2;  // ping-pong

  // ---- 地址映射 ----
  parameter bit [31:0] INST_BASE     = 32'h0000_0000;
  parameter bit [31:0] DATA_BASE     = 32'h0000_4000;
  parameter bit [31:0] UART_BASE     = 32'h1000_0000;
  parameter bit [31:0] GPIO_BASE     = 32'h1000_1000;
  parameter bit [31:0] TIMER_BASE    = 32'h1000_2000;
  parameter bit [31:0] ATTN_BASE     = 32'h2000_0000;
  parameter bit [31:0] MLP_BASE      = 32'h2000_1000;
  parameter bit [31:0] WEIGHT_BASE   = 32'h3000_0000;
  parameter bit [31:0] FEATURE_BASE  = 32'h3001_0000;
  parameter bit [31:0] KVCACHE_BASE  = 32'h3002_0000;

endpackage
```

### 3.2 参数合法范围

| 参数 | 最小值 | 默认值 | 最大值 | 约束 |
|------|--------|--------|--------|------|
| D_MODEL | 8 | 16 | 128 | 必须是 N_HEAD 的倍数 |
| N_HEAD | 1 | 2 | 16 | 必须整除 D_MODEL |
| NUM_LAYERS | 1 | 2 | 16 | 无 |
| SEQ_LEN | 1 | 8 | 128 | 无 |
| D_FF | 32 | 64 | 512 | 通常 4×D_MODEL |
| MAC_ROWS | 2 | 4 | 8 | 无 |
| MAC_COLS | 2 | 4 | 8 | 无 |
| TILE_B_R | 1 | 4 | MAC_ROWS | 无 |
| TILE_B_C | 1 | 4 | MAC_COLS | 无 |

---

## 4. FSM 与控制

### 4.1 顶层控制 FSM (attn_ctrl_fsm)

```
                    ┌──────────┐
                    │  IDLE    │
                    └────┬─────┘
                         │ start
                    ┌────▼─────┐
             ┌──────│ CONFIG   │ 配置参数
             │      └────┬─────┘
             │           │
        abort│      ┌────▼─────┐
             │      │ QKV_PROJ │ QKV 投影
             │      └────┬─────┘
             │           │ qkv_done
             │      ┌────▼─────┐
             │      │ ATTENTION│ FlashAttention
             │      └────┬─────┘
             │           │ attn_done
             │      ┌────▼─────┐
             │      │RESIDUAL_1│ 残差 + LayerNorm
             │      └────┬─────┘
             │           │ ln1_done
             │      ┌────▼─────┐
             │      │   MLP    │ FC1 + GELU + FC2
             │      └────┬─────┘
             │           │ mlp_done
             │      ┌────▼─────┐
             │      │RESIDUAL_2│ 残差 + LayerNorm
             │      └────┬─────┘
             │           │ ln2_done
             │      ┌────▼─────┐
             │      │LAYER_CHK │ 检查是否还有层
             │      └────┬─────┘
             │           │
             │    ┌──────┴──────┐
             │    │             │
             │  more层       最后一层
             │    │             │
             │    └──►QKV_PROJ  │
             │                  │
             │             ┌────▼─────┐
             └────────────►│  DONE    │ 中断 + 等待
                           └──────────┘
```

**状态编码**:

| 状态 | 编码 | 说明 |
|------|------|------|
| IDLE | 4'h0 | 空闲，等待 start |
| CONFIG | 4'h1 | 从寄存器读取配置 |
| QKV_PROJ | 4'h2 | QKV 线性投影 |
| ATTENTION | 4'h3 | FlashAttention 计算 |
| RESIDUAL_1 | 4'h4 | 第一次残差 + LayerNorm |
| MLP | 4'h5 | MLP 计算 |
| RESIDUAL_2 | 4'h6 | 第二次残差 + LayerNorm |
| LAYER_CHK | 4'h7 | 检查层数 |
| DONE | 4'h8 | 完成，产生中断 |
| ERROR | 4'hF | 错误状态 |

### 4.2 MAC 阵列控制 FSM

```
IDLE → LOAD_A → LOAD_B → COMPUTE → DRAIN → DONE
```

- LOAD_A: 从 SRAM 读取 A 矩阵到内部缓冲
- LOAD_B: 从 SRAM 读取 B 矩阵到内部缓冲
- COMPUTE: 流水线计算，每周期 16 个 MAC
- DRAIN: 排空流水线，收集最后结果
- DONE: 产生完成信号

### 4.3 FlashAttention Core FSM

```
IDLE → INIT → OUTER_LOOP → INNER_LOOP → TILE_COMPUTE →
SOFTMAX_UPDATE → ACCUM_UPDATE → INNER_CHECK → OUTER_CHECK → NORMALIZE → DONE
```

详细状态：
1. INIT: O=0, m=-inf, l=0
2. OUTER_LOOP: 取 Q 块 (B_r 行)
3. INNER_LOOP: 取 KV 块 (B_c 列)
4. TILE_COMPUTE: S = Q_tile × K_tile^T / sqrt(d_k)
5. SOFTMAX_UPDATE: m_new, P = exp(S - m_new), l_new
6. ACCUM_UPDATE: O = exp(m-m_new)×O + P×V_tile
7. INNER_CHECK: 是否还有 KV 块
8. OUTER_CHECK: 是否还有 Q 块
9. NORMALIZE: O = O / l
10. DONE: 产生完成信号

---

## 5. 数据通路

### 5.1 QKV 投影数据通路

```
Feature SRAM → [seq_len × d_model]
                    ↓
            ┌───────────────┐
            │   MAC 阵列    │ ← Weight SRAM [d_model × d_model]
            │   4×4 FP16    │
            └───────┬───────┘
                    ↓
            QKV Buffer [3 × seq_len × d_model]
```

时序：
- 每次加载 4×4 块到 MAC 阵列
- 总计算量：3 × 16 × 16 × 8 = 6144 MAC
- 周期数：6144 / 16 = 384 cycles

### 5.2 FlashAttention 数据通路

```
QKV Buffer ──→ ┌──────────────────────────────────────┐
  Q[i:i+B_r]   │           FlashAttention Core         │
               │  ┌─────────┐    ┌─────────────────┐  │
               │  │MAC 阵列 │───→│ Softmax 更新    │  │
               │  │4×4 FP16 │    │ rowmax + exp +  │  │
               │  └─────────┘    │ rowsum + scale  │  │
               │       ↑         └────────┬────────┘  │
               │       │                  │           │
               │  ┌────┴────┐    ┌────────▼────────┐  │
               │  │K_tile   │    │ 累加缓冲区      │  │
               │  │V_tile   │    │ O[0:B_r, :]     │  │
               │  └─────────┘    └─────────────────┘  │
               └──────────────────────────────────────┘
                            ↓
                    Pipeline Buffer
```

### 5.3 MLP 数据通路

```
Feature SRAM → MAC 阵列 (FC1) → GELU HW → MAC 阵列 (FC2) → Feature SRAM
                  ↑                              ↑
            Weight SRAM (W_fc1)           Weight SRAM (W_fc2)
```

### 5.4 LayerNorm 数据通路

```
输入 x[0:d_model]
    ↓
┌───┴───┐
│ μ 计算 │ mean(x) = sum(x) / d_model
└───┬───┘
    ↓
┌───┴───┐
│ σ² 计算│ var(x) = mean((x-μ)²)
└───┬───┘
    ↓
┌───┴───┐
│ rsqrt │ 1/√(σ²+ε) 查表
└───┬───┘
    ↓
┌───┴───┐
│ 归一化 │ x_norm = (x-μ) × rsqrt
└───┬───┘
    ↓
┌───┴───┐
│ 仿射  │ γ × x_norm + β
└───┬───┘
    ↓
输出
```

### 5.5 流水线重叠数据通路

```
时间 →
QKV_PROJ:    [====]
ATTENTION:        [====]
RESIDUAL_1:            [==]
MLP:                      [========]
RESIDUAL_2:                      [==]

流水线缓冲区 (ping-pong):
  buf[0]: QKV_PROJ → ATTENTION (Q 数据)
  buf[1]: ATTENTION → RESIDUAL_1 (注意力输出)
```

---

## 6. 存储设计

### 6.1 SRAM 分配

| SRAM | 容量 | 端口 | Bank | 用途 |
|------|------|------|------|------|
| Weight | 16KB | 双端口 | 1 | 权重存储 |
| Feature | 16KB | 双端口 | 2 (A/B) | 输入/中间/输出 |
| KV-Cache | 8KB | 双端口 | 1 | K/V 缓存 |
| Inst | 16KB | 单端口 | 1 | RISC-V 指令 |
| Data | 16KB | 单端口 | 1 | RISC-V 数据 |

### 6.2 Feature SRAM Bank 交替

```
Layer N:
  读: Feature SRAM Bank A (输入)
  写: Feature SRAM Bank B (输出)

Layer N+1:
  读: Feature SRAM Bank B (输入)
  写: Feature SRAM Bank A (输出)
```

避免读写冲突，无需额外仲裁。

### 6.3 SRAM 访问时序

- 单端口 SRAM：1 周期读延迟
- 双端口 SRAM：1 周期读延迟，支持同时读写不同地址
- 写操作：1 周期（写地址在时钟上升沿锁存）

### 6.4 KV-Cache 管理

- FIFO 策略：当 seq_len 超过 SRAM 容量时，覆盖最旧的 K/V
- 地址递增，到达末尾后回绕
- 每个 head 独立的地址区域

---

## 7. 流水线设计

### 7.1 流水线阶段

```
Stage 1: QKV_PROJ (384 cycles)
Stage 2: ATTENTION (200 cycles)
Stage 3: RESIDUAL_1 (100 cycles)
Stage 4: MLP (1024 cycles)
Stage 5: RESIDUAL_2 (100 cycles)
```

### 7.2 重叠规则

- Stage 1 和 Stage 2 可重叠（QKV 输出直接流入 FA 输入）
- Stage 2 和 Stage 3 可重叠（FA 输出直接流入残差加法）
- Stage 4 和 Stage 5 可重叠（MLP 输出直接流入残差加法）
- Stage 3 和 Stage 4 不可重叠（需要完整 LayerNorm 结果）

### 7.3 缓冲区设计

**ping-pong 缓冲区**:
- 大小：B_r × d_model × FP16 = 4 × 16 × 16 = 1024 bits = 128 bytes
- 两个缓冲区交替使用
- 写入端：上游模块
- 读出端：下游模块

**握手协议**:
```
producer: valid = 1 when data ready
consumer: ready = 1 when can accept
transfer: happens when valid && ready
```

### 7.4 反压处理

- 如果下游模块忙（ready=0），上游模块保持数据（valid=1 不变）
- MAC 阵列：如果输出缓冲满，暂停输入加载
- SRAM：如果正在写，读请求等待 1 周期

---

## 8. 复位、CDC、RDC

### 8.1 复位策略

- **异步复位，同步释放**：rst_n 异步置位所有寄存器，同步释放避免亚稳态
- 复位值：
  - 所有 FSM 回到 IDLE
  - 所有计数器清零
  - 所有使能信号禁用
  - SRAM 内容不定（需要软件初始化）

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    counter <= '0;
    enable <= 1'b0;
  end else begin
    state <= next_state;
    counter <= next_counter;
    enable <= next_enable;
  end
end
```

### 8.2 CDC 策略

- **单时钟域设计**：所有逻辑使用同一 100MHz 时钟
- 无时钟域交叉（入门版）
- UART 收发使用 16× 过采样（100MHz / 115200 ≈ 868 倍，足够）

### 8.3 RDC 策略

- 单一复位信号 rst_n
- 所有模块使用同一复位源
- 无复位域交叉

---

## 9. 验证播种

### 9.1 断言候选

| 断言 | 位置 | 说明 |
|------|------|------|
| `assert(valid && ready → data stable)` | mac_stream_if | 数据在握手期间稳定 |
| `assert(state != ERROR → no timeout)` | attn_ctrl_fsm | 正常状态无超时 |
| `assert(addr < WEIGHT_WORDS)` | sram_weight | 地址不越界 |
| `assert(psel → pready within 4 cycles)` | apb_slave | APB 等待不超过 4 周期 |
| `assert(mac_util >= 70)` | 性能监控 | MAC 利用率不低于 70% |
| `assert(irq → (status.done \|\| status.error))` | ctrl_regs | 中断有对应状态 |

### 9.2 覆盖点候选

| 覆盖点 | 说明 |
|--------|------|
| `cp_fsm_states` | 所有 FSM 状态被访问 |
| `cp_apb_all_regs` | 所有 20 个 APB 寄存器被读写 |
| `cp_irq_sources` | 所有中断源被触发 |
| `cp_mac_overflow` | FP16 累加器溢出场景 |
| `cp_softmax_boundary` | Softmax 极端输入（全 0、全 inf） |
| `cp_layer_count` | 不同层数配置 |
| `cp_seq_len_boundary` | seq_len 非整数倍 B_r/B_c |
| `cp_pipeline_hazard` | 流水线反压场景 |

### 9.3 测试场景

| 测试 | 层级 | 说明 |
|------|------|------|
| mac_array_basic | L0 | 单个 MAC 操作正确性 |
| mac_array_full | L0 | 4×4 矩阵乘正确性 |
| softmax_basic | L1 | 标准输入 Softmax |
| softmax_edge | L1 | 极端输入（inf, -inf, 0） |
| layernorm_basic | L2 | 标准输入 LayerNorm |
| gelu_basic | L3 | 标准输入 GELU |
| gelu_boundary | L3 | x > 4, x < -4 边界 |
| qkv_projection | L4 | QKV 投影与 PyTorch 对比 |
| flash_attention | L5 | FlashAttention 与标准注意力对比 |
| single_layer | L6 | 单层 Encoder 端到端 |
| two_layer | L7 | 2 层推理端到端 |
| soc_integration | L8 | 固件+加速器+UART 全链路 |
| perf_utilization | L9 | MAC 利用率验证 |
| perf_throughput | L9 | 吞吐量验证 |
