// AttentionCore-SOC Top Module
// Integrates RISC-V core, APB interconnect, attention engine,
// MLP engine, LayerNorm, residual add, UART, GPIO, timer, and SRAMs.

module attentioncore_soc_top
  import soc_params_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // UART
  input  logic        uart_rx,
  output logic        uart_tx,

  // GPIO
  output logic [7:0]  gpio_out,
  input  logic [3:0]  gpio_in,

  // Interrupt
  output logic        irq,

  // Test mode: bypass RISC-V, drive APB directly
  input  logic        test_mode_i,
  input  logic [31:0] test_paddr_i,
  input  logic        test_psel_i,
  input  logic        test_penable_i,
  input  logic        test_pwrite_i,
  input  logic [31:0] test_pwdata_i,
  output logic [31:0] test_prdata_o,
  output logic        test_pready_o,
  output logic        test_pslverr_o
);

  // ---- Internal Signals ----

  // RISC-V to APB master
  logic [31:0] rv_inst_addr;
  logic        rv_inst_re;
  logic [31:0] rv_inst_rdata;
  logic        rv_inst_ready;

  logic [31:0] rv_data_addr;
  logic        rv_data_re;
  logic        rv_data_we;
  logic [31:0] rv_data_wdata;
  logic [31:0] rv_data_rdata;
  logic        rv_data_ready;

  // APB master signals
  logic [31:0] apb_paddr;
  logic        apb_psel;
  logic        apb_penable;
  logic        apb_pwrite;
  logic [31:0] apb_pwdata;
  logic [31:0] apb_prdata;
  logic        apb_pready;
  logic        apb_pslverr;

  // APB slave signals (10 slaves)
  logic [31:0] s_paddr [0:9];
  logic [9:0]  s_psel;
  logic [9:0]  s_penable;
  logic [9:0]  s_pwrite;
  logic [31:0] s_pwdata [0:9];
  logic [31:0] s_prdata [0:9];
  logic [9:0]  s_pready;
  logic [9:0]  s_pslverr;

  // SRAM signals
  logic        inst_cs, inst_we;
  logic [INST_ADDR_W-1:0] inst_addr;
  logic [31:0] inst_wdata, inst_rdata;

  logic        data_cs, data_we;
  logic [DATA_ADDR_W-1:0] data_addr;
  logic [31:0] data_wdata, data_rdata;

  // Weight SRAM
  logic        wt_cs, wt_we;
  logic [WEIGHT_ADDR_W-1:0] wt_addr;
  logic [FP16_WIDTH-1:0] wt_wdata, wt_rdata;

  // Feature SRAM
  logic        feat_cs, feat_we;
  logic [FEATURE_ADDR_W-1:0] feat_addr;
  logic [FP16_WIDTH-1:0] feat_wdata, feat_rdata;

  // KV-Cache SRAM
  logic        kv_cs, kv_we;
  logic [KVCACHE_ADDR_W-1:0] kv_addr;
  logic [FP16_WIDTH-1:0] kv_wdata, kv_rdata;

  // Interrupt signals
  logic        attn_irq, mlp_irq, uart_irq, gpio_irq, timer_irq;

  // Control signals
  logic        start, reset, abort;
  logic        busy, done, error;

  // Configuration
  logic [15:0] seq_len, d_model, n_head, d_ff, num_layers;
  logic [15:0] layer_cfg, tile_cfg;
  logic [FP16_WIDTH-1:0] scale_factor;
  logic [31:0] weight_base, feature_base, kvcache_base;

  // Performance
  logic [31:0] cycle_count, perf_throughput, perf_mac_util;

  // Debug
  logic [31:0] rv_pc, rv_instr;

  // ---- RISC-V Core ----
  riscv_core u_rv (
    .clk          (clk),
    .rst_n        (rst_n),
    .inst_addr_o  (rv_inst_addr),
    .inst_re_o    (rv_inst_re),
    .inst_rdata_i (rv_inst_rdata),
    .inst_ready_i (rv_inst_ready),
    .data_addr_o  (rv_data_addr),
    .data_re_o    (rv_data_re),
    .data_we_o    (rv_data_we),
    .data_wdata_o (rv_data_wdata),
    .data_rdata_i (rv_data_rdata),
    .data_ready_i (rv_data_ready),
    .irq_i        (irq),
    .pc_o         (rv_pc),
    .instr_o      (rv_instr)
  );

  // ---- APB Master Bridge ----
  // Mux between RISC-V and test APB master
  assign apb_paddr   = test_mode_i ? test_paddr_i   : rv_data_addr;
  assign apb_psel    = test_mode_i ? test_psel_i     : (rv_data_re || rv_data_we);
  assign apb_penable = test_mode_i ? test_penable_i  : apb_psel;
  assign apb_pwrite  = test_mode_i ? test_pwrite_i   : rv_data_we;
  assign apb_pwdata  = test_mode_i ? test_pwdata_i   : rv_data_wdata;

  assign rv_data_rdata = apb_prdata;
  assign rv_data_ready = apb_pready;

  // Test APB response
  assign test_prdata_o  = apb_prdata;
  assign test_pready_o  = apb_pready;
  assign test_pslverr_o = apb_pslverr;

  // ---- APB Interconnect ----
  apb_interconnect u_apb (
    .m_paddr_i   (apb_paddr),
    .m_psel_i    (apb_psel),
    .m_penable_i (apb_penable),
    .m_pwrite_i  (apb_pwrite),
    .m_pwdata_i  (apb_pwdata),
    .m_prdata_o  (apb_prdata),
    .m_pready_o  (apb_pready),
    .m_pslverr_o (apb_pslverr),

    // Slave 0: Instruction SRAM
    .s0_paddr_o  (s_paddr[0]),
    .s0_psel_o   (s_psel[0]),
    .s0_penable_o(s_penable[0]),
    .s0_pwrite_o (s_pwrite[0]),
    .s0_pwdata_o (s_pwdata[0]),
    .s0_prdata_i (s_prdata[0]),
    .s0_pready_i (s_pready[0]),
    .s0_pslverr_i(s_pslverr[0]),

    // Slave 1: Data SRAM
    .s1_paddr_o  (s_paddr[1]),
    .s1_psel_o   (s_psel[1]),
    .s1_penable_o(s_penable[1]),
    .s1_pwrite_o (s_pwrite[1]),
    .s1_pwdata_o (s_pwdata[1]),
    .s1_prdata_i (s_prdata[1]),
    .s1_pready_i (s_pready[1]),
    .s1_pslverr_i(s_pslverr[1]),

    // Slave 2: UART
    .s2_paddr_o  (s_paddr[2]),
    .s2_psel_o   (s_psel[2]),
    .s2_penable_o(s_penable[2]),
    .s2_pwrite_o (s_pwrite[2]),
    .s2_pwdata_o (s_pwdata[2]),
    .s2_prdata_i (s_prdata[2]),
    .s2_pready_i (s_pready[2]),
    .s2_pslverr_i(s_pslverr[2]),

    // Slave 3: GPIO
    .s3_paddr_o  (s_paddr[3]),
    .s3_psel_o   (s_psel[3]),
    .s3_penable_o(s_penable[3]),
    .s3_pwrite_o (s_pwrite[3]),
    .s3_pwdata_o (s_pwdata[3]),
    .s3_prdata_i (s_prdata[3]),
    .s3_pready_i (s_pready[3]),
    .s3_pslverr_i(s_pslverr[3]),

    // Slave 4: Timer
    .s4_paddr_o  (s_paddr[4]),
    .s4_psel_o   (s_psel[4]),
    .s4_penable_o(s_penable[4]),
    .s4_pwrite_o (s_pwrite[4]),
    .s4_pwdata_o (s_pwdata[4]),
    .s4_prdata_i (s_prdata[4]),
    .s4_pready_i (s_pready[4]),
    .s4_pslverr_i(s_pslverr[4]),

    // Slave 5: Attention Engine
    .s5_paddr_o  (s_paddr[5]),
    .s5_psel_o   (s_psel[5]),
    .s5_penable_o(s_penable[5]),
    .s5_pwrite_o (s_pwrite[5]),
    .s5_pwdata_o (s_pwdata[5]),
    .s5_prdata_i (s_prdata[5]),
    .s5_pready_i (s_pready[5]),
    .s5_pslverr_i(s_pslverr[5]),

    // Slave 6: MLP Engine
    .s6_paddr_o  (s_paddr[6]),
    .s6_psel_o   (s_psel[6]),
    .s6_penable_o(s_penable[6]),
    .s6_pwrite_o (s_pwrite[6]),
    .s6_pwdata_o (s_pwdata[6]),
    .s6_prdata_i (s_prdata[6]),
    .s6_pready_i (s_pready[6]),
    .s6_pslverr_i(s_pslverr[6]),

    // Slave 7: Weight SRAM
    .s7_paddr_o  (s_paddr[7]),
    .s7_psel_o   (s_psel[7]),
    .s7_penable_o(s_penable[7]),
    .s7_pwrite_o (s_pwrite[7]),
    .s7_pwdata_o (s_pwdata[7]),
    .s7_prdata_i (s_prdata[7]),
    .s7_pready_i (s_pready[7]),
    .s7_pslverr_i(s_pslverr[7]),

    // Slave 8: Feature SRAM
    .s8_paddr_o  (s_paddr[8]),
    .s8_psel_o   (s_psel[8]),
    .s8_penable_o(s_penable[8]),
    .s8_pwrite_o (s_pwrite[8]),
    .s8_pwdata_o (s_pwdata[8]),
    .s8_prdata_i (s_prdata[8]),
    .s8_pready_i (s_pready[8]),
    .s8_pslverr_i(s_pslverr[8]),

    // Slave 9: KV-Cache SRAM
    .s9_paddr_o  (s_paddr[9]),
    .s9_psel_o   (s_psel[9]),
    .s9_penable_o(s_penable[9]),
    .s9_pwrite_o (s_pwrite[9]),
    .s9_pwdata_o (s_pwdata[9]),
    .s9_prdata_i (s_prdata[9]),
    .s9_pready_i (s_pready[9]),
    .s9_pslverr_i(s_pslverr[9])
  );

  // ---- Instruction SRAM ----
  assign inst_cs    = s_psel[0];
  assign inst_we    = s_pwrite[0];
  assign inst_addr  = s_paddr[0][INST_ADDR_W+1:2];
  assign inst_wdata = s_pwdata[0];

  sram_single_port #(
    .WORDS (INST_WORDS),
    .WIDTH (32)
  ) u_inst_sram (
    .clk    (clk),
    .cs_i   (inst_cs),
    .we_i   (inst_we),
    .addr_i (inst_addr),
    .wdata_i(inst_wdata),
    .rdata_o(inst_rdata)
  );

  assign s_prdata[0]  = inst_rdata;
  assign s_pready[0]  = 1'b1;
  assign s_pslverr[0] = 1'b0;

  // ---- Data SRAM ----
  assign data_cs    = s_psel[1];
  assign data_we    = s_pwrite[1];
  assign data_addr  = s_paddr[1][DATA_ADDR_W+1:2];
  assign data_wdata = s_pwdata[1];

  sram_single_port #(
    .WORDS (DATA_WORDS),
    .WIDTH (32)
  ) u_data_sram (
    .clk    (clk),
    .cs_i   (data_cs),
    .we_i   (data_we),
    .addr_i (data_addr),
    .wdata_i(data_wdata),
    .rdata_o(data_rdata)
  );

  assign s_prdata[1]  = data_rdata;
  assign s_pready[1]  = 1'b1;
  assign s_pslverr[1] = 1'b0;

  // ---- UART ----
  uart_top u_uart (
    .clk      (clk),
    .rst_n    (rst_n),
    .paddr_i  (s_paddr[2]),
    .psel_i   (s_psel[2]),
    .penable_i(s_penable[2]),
    .pwrite_i (s_pwrite[2]),
    .pwdata_i (s_pwdata[2]),
    .prdata_o (s_prdata[2]),
    .pready_o (s_pready[2]),
    .pslverr_o(s_pslverr[2]),
    .rx_i     (uart_rx),
    .tx_o     (uart_tx),
    .irq_o    (uart_irq)
  );

  // ---- GPIO ----
  gpio_top u_gpio (
    .clk      (clk),
    .rst_n    (rst_n),
    .paddr_i  (s_paddr[3]),
    .psel_i   (s_psel[3]),
    .penable_i(s_penable[3]),
    .pwrite_i (s_pwrite[3]),
    .pwdata_i (s_pwdata[3]),
    .prdata_o (s_prdata[3]),
    .pready_o (s_pready[3]),
    .pslverr_o(s_pslverr[3]),
    .gpio_out_o(gpio_out),
    .gpio_in_i (gpio_in),
    .irq_o    (gpio_irq)
  );

  // ---- Timer ----
  timer_top u_timer (
    .clk      (clk),
    .rst_n    (rst_n),
    .paddr_i  (s_paddr[4]),
    .psel_i   (s_psel[4]),
    .penable_i(s_penable[4]),
    .pwrite_i (s_pwrite[4]),
    .pwdata_i (s_pwdata[4]),
    .prdata_o (s_prdata[4]),
    .pready_o (s_pready[4]),
    .pslverr_o(s_pslverr[4]),
    .irq_o    (timer_irq)
  );

  // ---- Attention Engine ----
  attention_engine u_attn (
    .clk           (clk),
    .rst_n         (rst_n),
    .paddr_i       (s_paddr[5][7:0]),
    .psel_i        (s_psel[5]),
    .penable_i     (s_penable[5]),
    .pwrite_i      (s_pwrite[5]),
    .pwdata_i      (s_pwdata[5]),
    .prdata_o      (s_prdata[5]),
    .pready_o      (s_pready[5]),
    .pslverr_o     (s_pslverr[5]),
    .feat_rd_en_o  (),
    .feat_rd_addr_o(),
    .feat_rd_data_i('0),
    .feat_wr_en_o  (),
    .feat_wr_addr_o(),
    .feat_wr_data_o(),
    .wt_rd_en_o    (),
    .wt_rd_addr_o  (),
    .wt_rd_data_i  ('0),
    .kv_rd_en_o    (),
    .kv_rd_addr_o  (),
    .kv_rd_data_i  ('0),
    .kv_wr_en_o    (),
    .kv_wr_addr_o  (),
    .kv_wr_data_o  (),
    .irq_o         (attn_irq)
  );

  // ---- MLP Engine ----
  mlp_engine u_mlp (
    .clk           (clk),
    .rst_n         (rst_n),
    .paddr_i       (s_paddr[6][7:0]),
    .psel_i        (s_psel[6]),
    .penable_i     (s_penable[6]),
    .pwrite_i      (s_pwrite[6]),
    .pwdata_i      (s_pwdata[6]),
    .prdata_o      (s_prdata[6]),
    .pready_o      (s_pready[6]),
    .pslverr_o     (s_pslverr[6]),
    .feat_rd_en_o  (),
    .feat_rd_addr_o(),
    .feat_rd_data_i('0),
    .feat_wr_en_o  (),
    .feat_wr_addr_o(),
    .feat_wr_data_o(),
    .wt_rd_en_o    (),
    .wt_rd_addr_o  (),
    .wt_rd_data_i  ('0),
    .irq_o         (mlp_irq)
  );

  // ---- Weight SRAM ----
  assign wt_cs    = s_psel[7];
  assign wt_we    = s_pwrite[7];
  assign wt_addr  = s_paddr[7][WEIGHT_ADDR_W:1];
  assign wt_wdata = s_pwdata[7][FP16_WIDTH-1:0];

  sram_single_port #(
    .WORDS (WEIGHT_WORDS),
    .WIDTH (FP16_WIDTH)
  ) u_weight_sram (
    .clk    (clk),
    .cs_i   (wt_cs),
    .we_i   (wt_we),
    .addr_i (wt_addr),
    .wdata_i(wt_wdata),
    .rdata_o(wt_rdata)
  );

  assign s_prdata[7]  = {16'b0, wt_rdata};
  assign s_pready[7]  = 1'b1;
  assign s_pslverr[7] = 1'b0;

  // ---- Feature SRAM ----
  assign feat_cs    = s_psel[8];
  assign feat_we    = s_pwrite[8];
  assign feat_addr  = s_paddr[8][FEATURE_ADDR_W:1];
  assign feat_wdata = s_pwdata[8][FP16_WIDTH-1:0];

  sram_dual_port #(
    .WORDS (FEATURE_WORDS),
    .WIDTH (FP16_WIDTH)
  ) u_feature_sram (
    .clk     (clk),
    .a_cs_i  (feat_cs),
    .a_we_i  (feat_we),
    .a_addr_i(feat_addr),
    .a_wdata_i(feat_wdata),
    .a_rdata_o(feat_rdata),
    .b_cs_i  (1'b0),
    .b_we_i  (1'b0),
    .b_addr_i('0),
    .b_wdata_i('0),
    .b_rdata_o()
  );

  assign s_prdata[8]  = {16'b0, feat_rdata};
  assign s_pready[8]  = 1'b1;
  assign s_pslverr[8] = 1'b0;

  // ---- KV-Cache SRAM ----
  assign kv_cs    = s_psel[9];
  assign kv_we    = s_pwrite[9];
  assign kv_addr  = s_paddr[9][KVCACHE_ADDR_W:1];
  assign kv_wdata = s_pwdata[9][FP16_WIDTH-1:0];

  sram_single_port #(
    .WORDS (KVCACHE_WORDS),
    .WIDTH (FP16_WIDTH)
  ) u_kvcache_sram (
    .clk    (clk),
    .cs_i   (kv_cs),
    .we_i   (kv_we),
    .addr_i (kv_addr),
    .wdata_i(kv_wdata),
    .rdata_o(kv_rdata)
  );

  assign s_prdata[9]  = {16'b0, kv_rdata};
  assign s_pready[9]  = 1'b1;
  assign s_pslverr[9] = 1'b0;

  // ---- Interrupt Aggregation ----
  assign irq = attn_irq | mlp_irq | uart_irq | gpio_irq | timer_irq;

endmodule
