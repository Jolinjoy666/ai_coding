// APB Interconnect
// Routes APB transactions from master to appropriate slave based on address.
// 10 slave ports, single master, no arbitration needed.

module apb_interconnect
  import soc_params_pkg::*;
(
  // Master interface (from RISC-V)
  input  logic [31:0] m_paddr_i,
  input  logic        m_psel_i,
  input  logic        m_penable_i,
  input  logic        m_pwrite_i,
  input  logic [31:0] m_pwdata_i,
  output logic [31:0] m_prdata_o,
  output logic        m_pready_o,
  output logic        m_pslverr_o,

  // Slave 0: Instruction SRAM
  output logic [31:0] s0_paddr_o,
  output logic        s0_psel_o,
  output logic        s0_penable_o,
  output logic        s0_pwrite_o,
  output logic [31:0] s0_pwdata_o,
  input  logic [31:0] s0_prdata_i,
  input  logic        s0_pready_i,
  input  logic        s0_pslverr_i,

  // Slave 1: Data SRAM
  output logic [31:0] s1_paddr_o,
  output logic        s1_psel_o,
  output logic        s1_penable_o,
  output logic        s1_pwrite_o,
  output logic [31:0] s1_pwdata_o,
  input  logic [31:0] s1_prdata_i,
  input  logic        s1_pready_i,
  input  logic        s1_pslverr_i,

  // Slave 2: UART
  output logic [31:0] s2_paddr_o,
  output logic        s2_psel_o,
  output logic        s2_penable_o,
  output logic        s2_pwrite_o,
  output logic [31:0] s2_pwdata_o,
  input  logic [31:0] s2_prdata_i,
  input  logic        s2_pready_i,
  input  logic        s2_pslverr_i,

  // Slave 3: GPIO
  output logic [31:0] s3_paddr_o,
  output logic        s3_psel_o,
  output logic        s3_penable_o,
  output logic        s3_pwrite_o,
  output logic [31:0] s3_pwdata_o,
  input  logic [31:0] s3_prdata_i,
  input  logic        s3_pready_i,
  input  logic        s3_pslverr_i,

  // Slave 4: Timer
  output logic [31:0] s4_paddr_o,
  output logic        s4_psel_o,
  output logic        s4_penable_o,
  output logic        s4_pwrite_o,
  output logic [31:0] s4_pwdata_o,
  input  logic [31:0] s4_prdata_i,
  input  logic        s4_pready_i,
  input  logic        s4_pslverr_i,

  // Slave 5: Attention Engine
  output logic [31:0] s5_paddr_o,
  output logic        s5_psel_o,
  output logic        s5_penable_o,
  output logic        s5_pwrite_o,
  output logic [31:0] s5_pwdata_o,
  input  logic [31:0] s5_prdata_i,
  input  logic        s5_pready_i,
  input  logic        s5_pslverr_i,

  // Slave 6: MLP Engine
  output logic [31:0] s6_paddr_o,
  output logic        s6_psel_o,
  output logic        s6_penable_o,
  output logic        s6_pwrite_o,
  output logic [31:0] s6_pwdata_o,
  input  logic [31:0] s6_prdata_i,
  input  logic        s6_pready_i,
  input  logic        s6_pslverr_i,

  // Slave 7: Weight SRAM
  output logic [31:0] s7_paddr_o,
  output logic        s7_psel_o,
  output logic        s7_penable_o,
  output logic        s7_pwrite_o,
  output logic [31:0] s7_pwdata_o,
  input  logic [31:0] s7_prdata_i,
  input  logic        s7_pready_i,
  input  logic        s7_pslverr_i,

  // Slave 8: Feature SRAM
  output logic [31:0] s8_paddr_o,
  output logic        s8_psel_o,
  output logic        s8_penable_o,
  output logic        s8_pwrite_o,
  output logic [31:0] s8_pwdata_o,
  input  logic [31:0] s8_prdata_i,
  input  logic        s8_pready_i,
  input  logic        s8_pslverr_i,

  // Slave 9: KV-Cache SRAM
  output logic [31:0] s9_paddr_o,
  output logic        s9_psel_o,
  output logic        s9_penable_o,
  output logic        s9_pwrite_o,
  output logic [31:0] s9_pwdata_o,
  input  logic [31:0] s9_prdata_i,
  input  logic        s9_pready_i,
  input  logic        s9_pslverr_i
);

  // Address decode
  logic sel_inst, sel_data, sel_uart, sel_gpio, sel_timer;
  logic sel_attn, sel_mlp, sel_weight, sel_feature, sel_kvcache;

  assign sel_inst    = (m_paddr_i & INST_MASK)    == INST_BASE;
  assign sel_data    = (m_paddr_i & DATA_MASK)    == DATA_BASE;
  assign sel_uart    = (m_paddr_i & UART_MASK)    == UART_BASE;
  assign sel_gpio    = (m_paddr_i & GPIO_MASK)    == GPIO_BASE;
  assign sel_timer   = (m_paddr_i & TIMER_MASK)   == TIMER_BASE;
  assign sel_attn    = (m_paddr_i & ATTN_MASK)    == ATTN_BASE;
  assign sel_mlp     = (m_paddr_i & MLP_MASK)     == MLP_BASE;
  assign sel_weight  = (m_paddr_i & WEIGHT_MASK)  == WEIGHT_BASE;
  assign sel_feature = (m_paddr_i & FEATURE_MASK) == FEATURE_BASE;
  assign sel_kvcache = (m_paddr_i & KVCACHE_MASK) == KVCACHE_BASE;

  // Route to slaves
  always_comb begin
    // Default: no slave selected
    s0_psel_o = 1'b0; s1_psel_o = 1'b0; s2_psel_o = 1'b0;
    s3_psel_o = 1'b0; s4_psel_o = 1'b0; s5_psel_o = 1'b0;
    s6_psel_o = 1'b0; s7_psel_o = 1'b0; s8_psel_o = 1'b0;
    s9_psel_o = 1'b0;

    m_prdata_o = '0;
    m_pready_o = 1'b1;
    m_pslverr_o = 1'b0;

    // Address passthrough
    s0_paddr_o = m_paddr_i; s1_paddr_o = m_paddr_i;
    s2_paddr_o = m_paddr_i; s3_paddr_o = m_paddr_i;
    s4_paddr_o = m_paddr_i; s5_paddr_o = m_paddr_i;
    s6_paddr_o = m_paddr_i; s7_paddr_o = m_paddr_i;
    s8_paddr_o = m_paddr_i; s9_paddr_o = m_paddr_i;

    // Control passthrough
    s0_penable_o = m_penable_i; s1_penable_o = m_penable_i;
    s2_penable_o = m_penable_i; s3_penable_o = m_penable_i;
    s4_penable_o = m_penable_i; s5_penable_o = m_penable_i;
    s6_penable_o = m_penable_i; s7_penable_o = m_penable_i;
    s8_penable_o = m_penable_i; s9_penable_o = m_penable_i;

    s0_pwrite_o = m_pwrite_i; s1_pwrite_o = m_pwrite_i;
    s2_pwrite_o = m_pwrite_i; s3_pwrite_o = m_pwrite_i;
    s4_pwrite_o = m_pwrite_i; s5_pwrite_o = m_pwrite_i;
    s6_pwrite_o = m_pwrite_i; s7_pwrite_o = m_pwrite_i;
    s8_pwrite_o = m_pwrite_i; s9_pwrite_o = m_pwrite_i;

    s0_pwdata_o = m_pwdata_i; s1_pwdata_o = m_pwdata_i;
    s2_pwdata_o = m_pwdata_i; s3_pwdata_o = m_pwdata_i;
    s4_pwdata_o = m_pwdata_i; s5_pwdata_o = m_pwdata_i;
    s6_pwdata_o = m_pwdata_i; s7_pwdata_o = m_pwdata_i;
    s8_pwdata_o = m_pwdata_i; s9_pwdata_o = m_pwdata_i;

    // Route based on address
    unique case (1'b1)
      sel_inst: begin
        s0_psel_o   = m_psel_i;
        m_prdata_o  = s0_prdata_i;
        m_pready_o  = s0_pready_i;
        m_pslverr_o = s0_pslverr_i;
      end
      sel_data: begin
        s1_psel_o   = m_psel_i;
        m_prdata_o  = s1_prdata_i;
        m_pready_o  = s1_pready_i;
        m_pslverr_o = s1_pslverr_i;
      end
      sel_uart: begin
        s2_psel_o   = m_psel_i;
        m_prdata_o  = s2_prdata_i;
        m_pready_o  = s2_pready_i;
        m_pslverr_o = s2_pslverr_i;
      end
      sel_gpio: begin
        s3_psel_o   = m_psel_i;
        m_prdata_o  = s3_prdata_i;
        m_pready_o  = s3_pready_i;
        m_pslverr_o = s3_pslverr_i;
      end
      sel_timer: begin
        s4_psel_o   = m_psel_i;
        m_prdata_o  = s4_prdata_i;
        m_pready_o  = s4_pready_i;
        m_pslverr_o = s4_pslverr_i;
      end
      sel_attn: begin
        s5_psel_o   = m_psel_i;
        m_prdata_o  = s5_prdata_i;
        m_pready_o  = s5_pready_i;
        m_pslverr_o = s5_pslverr_i;
      end
      sel_mlp: begin
        s6_psel_o   = m_psel_i;
        m_prdata_o  = s6_prdata_i;
        m_pready_o  = s6_pready_i;
        m_pslverr_o = s6_pslverr_i;
      end
      sel_weight: begin
        s7_psel_o   = m_psel_i;
        m_prdata_o  = s7_prdata_i;
        m_pready_o  = s7_pready_i;
        m_pslverr_o = s7_pslverr_i;
      end
      sel_feature: begin
        s8_psel_o   = m_psel_i;
        m_prdata_o  = s8_prdata_i;
        m_pready_o  = s8_pready_i;
        m_pslverr_o = s8_pslverr_i;
      end
      sel_kvcache: begin
        s9_psel_o   = m_psel_i;
        m_prdata_o  = s9_prdata_i;
        m_pready_o  = s9_pready_i;
        m_pslverr_o = s9_pslverr_i;
      end
      default: begin
        m_pslverr_o = m_psel_i;  // Error if no slave selected
      end
    endcase
  end

endmodule
