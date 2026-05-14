// AttentionCore-SOC Parameter Package
// All model and hardware parameters centralized here for easy scaling.

package soc_params_pkg;

  // ---- Model Architecture Parameters ----
  parameter int D_MODEL     = 16;       // Model dimension
  parameter int N_HEAD      = 2;        // Number of attention heads
  parameter int HEAD_DIM    = D_MODEL / N_HEAD;  // Per-head dimension = 8
  parameter int NUM_LAYERS  = 2;        // Number of encoder layers
  parameter int SEQ_LEN     = 8;        // Sequence length
  parameter int D_FF        = 64;       // FFN intermediate dimension

  // ---- Data Precision ----
  parameter int FP16_WIDTH  = 16;
  parameter int FP32_WIDTH  = 32;

  // ---- Hardware Resources ----
  parameter int MAC_ROWS    = 4;
  parameter int MAC_COLS    = 4;
  parameter int MAC_PE_COUNT = MAC_ROWS * MAC_COLS;  // 16

  // ---- Storage Capacity (FP16 words) ----
  parameter int WEIGHT_WORDS   = 8192;   // 16KB / 2B
  parameter int FEATURE_WORDS  = 8192;
  parameter int KVCACHE_WORDS  = 4096;
  parameter int INST_WORDS     = 8192;   // 16KB
  parameter int DATA_WORDS     = 8192;   // 16KB

  // ---- Address Widths ----
  localparam int WEIGHT_ADDR_W  = $clog2(WEIGHT_WORDS);
  localparam int FEATURE_ADDR_W = $clog2(FEATURE_WORDS);
  localparam int KVCACHE_ADDR_W = $clog2(KVCACHE_WORDS);
  localparam int INST_ADDR_W    = $clog2(INST_WORDS);
  localparam int DATA_ADDR_W    = $clog2(DATA_WORDS);

  // ---- FlashAttention Tiling ----
  parameter int TILE_B_R   = 4;
  parameter int TILE_B_C   = 4;

  // ---- Pipeline Buffer ----
  parameter int PIPELINE_BUF_DEPTH = 2;  // ping-pong

  // ---- APB Address Map ----
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

  // ---- APB Address Masks ----
  parameter bit [31:0] INST_MASK     = 32'hFFFF_C000;
  parameter bit [31:0] DATA_MASK     = 32'hFFFF_C000;
  parameter bit [31:0] UART_MASK     = 32'hFFFF_F000;
  parameter bit [31:0] GPIO_MASK     = 32'hFFFF_F000;
  parameter bit [31:0] TIMER_MASK    = 32'hFFFF_F000;
  parameter bit [31:0] ATTN_MASK     = 32'hFFFF_F000;
  parameter bit [31:0] MLP_MASK      = 32'hFFFF_F000;
  parameter bit [31:0] WEIGHT_MASK   = 32'hFFFF_0000;
  parameter bit [31:0] FEATURE_MASK  = 32'hFFFF_0000;
  parameter bit [31:0] KVCACHE_MASK  = 32'hFFFF_8000;

  // ---- Control Register Offsets ----
  parameter bit [7:0] REG_CTRL           = 8'h00;
  parameter bit [7:0] REG_STATUS          = 8'h04;
  parameter bit [7:0] REG_IRQ_EN         = 8'h08;
  parameter bit [7:0] REG_IRQ_STATUS     = 8'h0C;
  parameter bit [7:0] REG_CFG_SEQ_LEN    = 8'h10;
  parameter bit [7:0] REG_CFG_D_MODEL    = 8'h14;
  parameter bit [7:0] REG_CFG_N_HEAD     = 8'h18;
  parameter bit [7:0] REG_CFG_D_FF       = 8'h1C;
  parameter bit [7:0] REG_CFG_NUM_LAYERS = 8'h20;
  parameter bit [7:0] REG_CFG_MAC_ROWS   = 8'h24;
  parameter bit [7:0] REG_CFG_MAC_COLS   = 8'h28;
  parameter bit [7:0] REG_WEIGHT_BASE    = 8'h2C;
  parameter bit [7:0] REG_FEATURE_BASE   = 8'h30;
  parameter bit [7:0] REG_KVCACHE_BASE   = 8'h34;
  parameter bit [7:0] REG_LAYER_CFG      = 8'h38;
  parameter bit [7:0] REG_TILE_CFG       = 8'h3C;
  parameter bit [7:0] REG_SCALE_FACTOR   = 8'h40;
  parameter bit [7:0] REG_CYCLE_COUNT    = 8'h44;
  parameter bit [7:0] REG_PERF_THROUGHPUT = 8'h48;
  parameter bit [7:0] REG_PERF_MAC_UTIL  = 8'h4C;

  // ---- CTRL Register Bits ----
  parameter int CTRL_START_BIT  = 0;
  parameter int CTRL_RESET_BIT  = 1;
  parameter int CTRL_ABORT_BIT  = 2;

  // ---- STATUS Register Bits ----
  parameter int STATUS_BUSY_BIT  = 0;
  parameter int STATUS_DONE_BIT  = 1;
  parameter int STATUS_ERROR_BIT = 2;

  // ---- IRQ Bits ----
  parameter int IRQ_QKV_DONE   = 0;
  parameter int IRQ_ATTN_DONE  = 1;
  parameter int IRQ_LN1_DONE   = 2;
  parameter int IRQ_MLP_DONE   = 3;
  parameter int IRQ_LN2_DONE   = 4;
  parameter int IRQ_LAYER_DONE = 5;
  parameter int IRQ_ALL_DONE   = 6;
  parameter int IRQ_ERROR      = 7;

  // ---- GELU Parameters ----
  parameter int GELU_SEGMENTS  = 32;
  parameter int GELU_LUT_DEPTH = 32;

  // ---- Exp LUT Parameters ----
  parameter int EXP_LUT_DEPTH  = 256;

  // ---- Rsqrt LUT Parameters ----
  parameter int RSQRT_LUT_DEPTH = 256;

endpackage
