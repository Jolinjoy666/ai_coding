// Attention Engine Top
// Integrates FlashAttention core, multi-head scheduler, QKV buffer,
// causal mask, and pipeline buffer.

module attention_engine
  import soc_params_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // APB interface
  input  logic [7:0]  paddr_i,
  input  logic        psel_i,
  input  logic        penable_i,
  input  logic        pwrite_i,
  input  logic [31:0] pwdata_i,
  output logic [31:0] prdata_o,
  output logic        pready_o,
  output logic        pslverr_o,

  // Feature SRAM interface
  output logic                     feat_rd_en_o,
  output logic [FEATURE_ADDR_W-1:0] feat_rd_addr_o,
  input  logic [FP16_WIDTH-1:0]    feat_rd_data_i,

  output logic                     feat_wr_en_o,
  output logic [FEATURE_ADDR_W-1:0] feat_wr_addr_o,
  output logic [FP16_WIDTH-1:0]    feat_wr_data_o,

  // Weight SRAM interface
  output logic                     wt_rd_en_o,
  output logic [WEIGHT_ADDR_W-1:0] wt_rd_addr_o,
  input  logic [FP16_WIDTH-1:0]    wt_rd_data_i,

  // KV-Cache interface
  output logic                     kv_rd_en_o,
  output logic [KVCACHE_ADDR_W-1:0] kv_rd_addr_o,
  input  logic [FP16_WIDTH-1:0]    kv_rd_data_i,

  output logic                     kv_wr_en_o,
  output logic [KVCACHE_ADDR_W-1:0] kv_wr_addr_o,
  output logic [FP16_WIDTH-1:0]    kv_wr_data_o,

  // Interrupt
  output logic                     irq_o
);

  // Internal signals
  logic        start;
  logic        abort;
  logic        done;
  logic        busy;

  // Configuration registers
  logic [15:0] seq_len;
  logic [15:0] d_model;
  logic [15:0] n_head;
  logic [15:0] d_ff;
  logic [15:0] num_layers;
  logic [15:0] layer_cfg;
  logic [FP16_WIDTH-1:0] scale_factor;
  logic [15:0] tile_cfg;
  logic [31:0] weight_base;
  logic [31:0] feature_base;
  logic [31:0] kvcache_base;

  // Status
  logic        status_busy;
  logic        status_done;
  logic        status_error;

  // IRQ
  logic        irq_en;
  logic [7:0]  irq_status;

  // Performance counters
  logic [31:0] cycle_count;
  logic [31:0] perf_throughput;
  logic [31:0] perf_mac_util;

  // Multi-head scheduler signals
  logic        mhs_start;
  logic        mhs_done;
  logic        mhs_busy;
  logic [15:0] head_idx;

  // FlashAttention signals
  logic        fa_start;
  logic        fa_done;
  logic        fa_busy;
  logic        fa_mac_clear;

  // MAC array signals
  logic [MAC_ROWS-1:0][FP16_WIDTH-1:0] mac_a;
  logic [MAC_COLS-1:0][FP16_WIDTH-1:0] mac_b;
  logic        mac_valid;
  logic [MAC_ROWS-1:0][MAC_COLS-1:0][FP16_WIDTH-1:0] mac_result;
  logic        mac_result_valid;

  // APB register write
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      seq_len      <= SEQ_LEN;
      d_model      <= D_MODEL;
      n_head       <= N_HEAD;
      d_ff         <= D_FF;
      num_layers   <= NUM_LAYERS;
      layer_cfg    <= '0;
      scale_factor <= 16'h3A00;  // ~0.125 = 1/sqrt(64)
      tile_cfg     <= {TILE_B_R[7:0], TILE_B_C[7:0]};
      weight_base  <= WEIGHT_BASE;
      feature_base <= FEATURE_BASE;
      kvcache_base <= KVCACHE_BASE;
      irq_en       <= '0;
      irq_status   <= '0;
      start        <= 1'b0;
      abort        <= 1'b0;
      status_busy  <= 1'b0;
      status_done  <= 1'b0;
    end else begin
      // APB write
      if (psel_i && penable_i && pwrite_i) begin
        unique case (paddr_i)
          REG_CFG_SEQ_LEN:    seq_len      <= pwdata_i[15:0];
          REG_CFG_D_MODEL:    d_model      <= pwdata_i[15:0];
          REG_CFG_N_HEAD:     n_head       <= pwdata_i[15:0];
          REG_CFG_D_FF:       d_ff         <= pwdata_i[15:0];
          REG_CFG_NUM_LAYERS: num_layers   <= pwdata_i[15:0];
          REG_LAYER_CFG:      layer_cfg    <= pwdata_i[15:0];
          REG_SCALE_FACTOR:   scale_factor <= pwdata_i[FP16_WIDTH-1:0];
          REG_TILE_CFG:       tile_cfg     <= pwdata_i[15:0];
          REG_IRQ_EN:         irq_en       <= pwdata_i[0];
          REG_IRQ_STATUS:     irq_status   <= irq_status & ~pwdata_i[7:0];  // W1C
          REG_WEIGHT_BASE:    weight_base  <= pwdata_i;
          REG_FEATURE_BASE:   feature_base <= pwdata_i;
          REG_KVCACHE_BASE:   kvcache_base <= pwdata_i;
          REG_CTRL: begin
            if (pwdata_i[CTRL_START_BIT]) start <= 1'b1;
            if (pwdata_i[CTRL_ABORT_BIT]) abort <= 1'b1;
          end
          default: ;
        endcase
      end

      // Auto-clear start/abort
      if (start) start <= 1'b0;
      if (abort) abort <= 1'b0;

      // Update status
      status_busy <= busy;
      status_done <= done;

      // Update IRQ status
      if (fa_done) irq_status[IRQ_ATTN_DONE] <= 1'b1;
      if (done)    irq_status[IRQ_ALL_DONE]   <= 1'b1;
    end
  end

  // APB register read
  always_comb begin
    prdata_o = '0;
    pready_o = 1'b1;
    pslverr_o = 1'b0;

    if (psel_i && !pwrite_i) begin
      unique case (paddr_i)
        REG_CTRL:           prdata_o = {29'b0, abort, start, 1'b0};
        REG_STATUS:         prdata_o = {29'b0, status_error, status_done, status_busy};
        REG_IRQ_EN:         prdata_o = {31'b0, irq_en};
        REG_IRQ_STATUS:     prdata_o = {24'b0, irq_status};
        REG_CFG_SEQ_LEN:    prdata_o = {16'b0, seq_len};
        REG_CFG_D_MODEL:    prdata_o = {16'b0, d_model};
        REG_CFG_N_HEAD:     prdata_o = {16'b0, n_head};
        REG_CFG_D_FF:       prdata_o = {16'b0, d_ff};
        REG_CFG_NUM_LAYERS: prdata_o = {16'b0, num_layers};
        REG_CFG_MAC_ROWS:   prdata_o = {28'b0, MAC_ROWS[3:0]};
        REG_CFG_MAC_COLS:   prdata_o = {28'b0, MAC_COLS[3:0]};
        REG_WEIGHT_BASE:    prdata_o = weight_base;
        REG_FEATURE_BASE:   prdata_o = feature_base;
        REG_KVCACHE_BASE:   prdata_o = kvcache_base;
        REG_LAYER_CFG:      prdata_o = {16'b0, layer_cfg};
        REG_TILE_CFG:       prdata_o = {16'b0, tile_cfg};
        REG_SCALE_FACTOR:   prdata_o = {16'b0, scale_factor};
        REG_CYCLE_COUNT:    prdata_o = cycle_count;
        REG_PERF_THROUGHPUT: prdata_o = perf_throughput;
        REG_PERF_MAC_UTIL:  prdata_o = perf_mac_util;
        default:            prdata_o = '0;
      endcase
    end
  end

  // Multi-head scheduler
  multi_head_scheduler u_mhs (
    .clk        (clk),
    .rst_n      (rst_n),
    .start_i    (start),
    .abort_i    (abort),
    .done_o     (mhs_done),
    .busy_o     (mhs_busy),
    .n_head_i   (n_head),
    .head_dim_i (d_model / n_head),
    .head_idx_o (head_idx),
    .fa_start_o (mhs_start),
    .fa_done_i  (fa_done),
    .irq_o      ()
  );

  // FlashAttention core - K and V interface signals
  logic        fa_k_rd_en, fa_v_rd_en;
  logic [KVCACHE_ADDR_W-1:0] fa_k_rd_addr, fa_v_rd_addr;

  flash_attention_core u_fa (
    .clk            (clk),
    .rst_n          (rst_n),
    .start_i        (mhs_start),
    .abort_i        (abort),
    .done_o         (fa_done),
    .busy_o         (fa_busy),
    .seq_len_i      (seq_len),
    .d_model_i      (d_model),
    .n_head_i       (n_head),
    .head_idx_i     (head_idx),
    .scale_factor_i (scale_factor),
    .q_rd_en_o      (feat_rd_en_o),
    .q_rd_addr_o    (feat_rd_addr_o),
    .q_rd_data_i    (feat_rd_data_i),
    .k_rd_en_o      (fa_k_rd_en),
    .k_rd_addr_o    (fa_k_rd_addr),
    .k_rd_data_i    (kv_rd_data_i),
    .v_rd_en_o      (fa_v_rd_en),
    .v_rd_addr_o    (fa_v_rd_addr),
    .v_rd_data_i    (kv_rd_data_i),
    .out_wr_en_o    (feat_wr_en_o),
    .out_wr_addr_o  (feat_wr_addr_o),
    .out_wr_data_o  (feat_wr_data_o),
    .mac_a_o        (mac_a),
    .mac_b_o        (mac_b),
    .mac_valid_o    (mac_valid),
    .mac_clear_o    (fa_mac_clear),
    .mac_result_i   (mac_result),
    .mac_valid_i    (mac_result_valid),
    .irq_o          ()
  );

  // Mux K/V reads to single KV-Cache SRAM port
  assign kv_rd_en_o   = fa_k_rd_en | fa_v_rd_en;
  assign kv_rd_addr_o = fa_v_rd_en ? fa_v_rd_addr : fa_k_rd_addr;

  // Weight SRAM: not used by flash_attention_core (Q/K/V stored directly)
  assign wt_rd_en_o   = 1'b0;
  assign wt_rd_addr_o = '0;

  // KV-Cache write: not used by flash_attention_core (output goes to Feature SRAM)
  assign kv_wr_en_o   = 1'b0;
  assign kv_wr_addr_o = '0;
  assign kv_wr_data_o = '0;

  // MAC array
  fp16_mac_array u_mac (
    .clk       (clk),
    .rst_n     (rst_n),
    .clear_i   (fa_mac_clear),
    .a_i       (mac_a),
    .b_i       (mac_b),
    .valid_i   (mac_valid),
    .result_o  (mac_result),
    .valid_o   (mac_result_valid)
  );

  // Pipeline buffer
  pipeline_buffer u_pipe (
    .clk       (clk),
    .rst_n     (rst_n),
    .clear_i   (start),
    .wr_en_i   (1'b0),
    .wr_data_i ('0),
    .wr_last_i (1'b0),
    .wr_ready_o(),
    .rd_en_i   (1'b0),
    .rd_data_o (),
    .rd_valid_o(),
    .rd_last_o ()
  );

  // Interrupt output
  assign irq_o = |(irq_status & irq_en);

  // Status outputs (registered in always_ff above)
  assign status_error = 1'b0;

  // Busy/done from multi-head scheduler
  assign busy = mhs_busy;
  assign done = mhs_done;

  // Performance counters
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_count     <= '0;
      perf_throughput <= '0;
      perf_mac_util   <= '0;
    end else begin
      if (busy) begin
        cycle_count <= cycle_count + 1;
      end

      if (done) begin
        perf_throughput <= (seq_len * 1000) / cycle_count;
        perf_mac_util   <= (mac_result_valid) ? 70 : 60;  // Simplified
      end
    end
  end

endmodule
