// Control Registers
// APB register file for SOC control and status.

module ctrl_regs
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

  // Control outputs
  output logic        start_o,
  output logic        reset_o,
  output logic        abort_o,

  // Status inputs
  input  logic        busy_i,
  input  logic        done_i,
  input  logic        error_i,

  // Configuration outputs
  output logic [15:0] seq_len_o,
  output logic [15:0] d_model_o,
  output logic [15:0] n_head_o,
  output logic [15:0] d_ff_o,
  output logic [15:0] num_layers_o,
  output logic [15:0] layer_cfg_o,
  output logic [15:0] tile_cfg_o,
  output logic [FP16_WIDTH-1:0] scale_factor_o,
  output logic [31:0] weight_base_o,
  output logic [31:0] feature_base_o,
  output logic [31:0] kvcache_base_o,

  // Performance inputs
  input  logic [31:0] cycle_count_i,
  input  logic [31:0] perf_throughput_i,
  input  logic [31:0] perf_mac_util_i,

  // IRQ
  output logic        irq_o
);

  // Register storage
  logic [31:0] ctrl_reg;
  logic [31:0] irq_en_reg;
  logic [31:0] irq_status_reg;
  logic [31:0] cfg_seq_len;
  logic [31:0] cfg_d_model;
  logic [31:0] cfg_n_head;
  logic [31:0] cfg_d_ff;
  logic [31:0] cfg_num_layers;
  logic [31:0] layer_cfg;
  logic [31:0] tile_cfg;
  logic [31:0] scale_factor;
  logic [31:0] weight_base;
  logic [31:0] feature_base;
  logic [31:0] kvcache_base;

  // Write logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ctrl_reg       <= '0;
      irq_en_reg     <= '0;
      irq_status_reg <= '0;
      cfg_seq_len    <= SEQ_LEN;
      cfg_d_model    <= D_MODEL;
      cfg_n_head     <= N_HEAD;
      cfg_d_ff       <= D_FF;
      cfg_num_layers <= NUM_LAYERS;
      layer_cfg      <= '0;
      tile_cfg       <= {TILE_B_R[15:0], TILE_B_C[15:0]};
      scale_factor   <= 16'h3A00;
      weight_base    <= WEIGHT_BASE;
      feature_base   <= FEATURE_BASE;
      kvcache_base   <= KVCACHE_BASE;
    end else begin
      // Auto-clear start/reset/abort
      ctrl_reg[CTRL_START_BIT] <= 1'b0;
      ctrl_reg[CTRL_RESET_BIT] <= 1'b0;
      ctrl_reg[CTRL_ABORT_BIT] <= 1'b0;

      // APB write
      if (psel_i && penable_i && pwrite_i) begin
        unique case (paddr_i)
          REG_CTRL:           ctrl_reg       <= pwdata_i;
          REG_IRQ_EN:         irq_en_reg     <= pwdata_i;
          REG_IRQ_STATUS:     irq_status_reg <= irq_status_reg & ~pwdata_i;  // W1C
          REG_CFG_SEQ_LEN:    cfg_seq_len    <= pwdata_i;
          REG_CFG_D_MODEL:    cfg_d_model    <= pwdata_i;
          REG_CFG_N_HEAD:     cfg_n_head     <= pwdata_i;
          REG_CFG_D_FF:       cfg_d_ff       <= pwdata_i;
          REG_CFG_NUM_LAYERS: cfg_num_layers <= pwdata_i;
          REG_LAYER_CFG:      layer_cfg      <= pwdata_i;
          REG_TILE_CFG:       tile_cfg       <= pwdata_i;
          REG_SCALE_FACTOR:   scale_factor   <= pwdata_i;
          REG_WEIGHT_BASE:    weight_base    <= pwdata_i;
          REG_FEATURE_BASE:   feature_base   <= pwdata_i;
          REG_KVCACHE_BASE:   kvcache_base   <= pwdata_i;
          default: ;
        endcase
      end

      // Update IRQ status from inputs
      if (done_i)  irq_status_reg[STATUS_DONE_BIT]  <= 1'b1;
      if (error_i) irq_status_reg[STATUS_ERROR_BIT] <= 1'b1;
    end
  end

  // Read logic
  always_comb begin
    prdata_o = '0;
    pready_o = 1'b1;
    pslverr_o = 1'b0;

    if (psel_i && !pwrite_i) begin
      unique case (paddr_i)
        REG_CTRL:            prdata_o = ctrl_reg;
        REG_STATUS:          prdata_o = {29'b0, error_i, done_i, busy_i};
        REG_IRQ_EN:          prdata_o = irq_en_reg;
        REG_IRQ_STATUS:      prdata_o = irq_status_reg;
        REG_CFG_SEQ_LEN:     prdata_o = cfg_seq_len;
        REG_CFG_D_MODEL:     prdata_o = cfg_d_model;
        REG_CFG_N_HEAD:      prdata_o = cfg_n_head;
        REG_CFG_D_FF:        prdata_o = cfg_d_ff;
        REG_CFG_NUM_LAYERS:  prdata_o = cfg_num_layers;
        REG_CFG_MAC_ROWS:    prdata_o = {28'b0, MAC_ROWS[3:0]};
        REG_CFG_MAC_COLS:    prdata_o = {28'b0, MAC_COLS[3:0]};
        REG_WEIGHT_BASE:     prdata_o = weight_base;
        REG_FEATURE_BASE:    prdata_o = feature_base;
        REG_KVCACHE_BASE:    prdata_o = kvcache_base;
        REG_LAYER_CFG:       prdata_o = layer_cfg;
        REG_TILE_CFG:        prdata_o = tile_cfg;
        REG_SCALE_FACTOR:    prdata_o = scale_factor;
        REG_CYCLE_COUNT:     prdata_o = cycle_count_i;
        REG_PERF_THROUGHPUT: prdata_o = perf_throughput_i;
        REG_PERF_MAC_UTIL:   prdata_o = perf_mac_util_i;
        default:             prdata_o = '0;
      endcase
    end
  end

  // Output assignments
  assign start_o         = ctrl_reg[CTRL_START_BIT];
  assign reset_o         = ctrl_reg[CTRL_RESET_BIT];
  assign abort_o         = ctrl_reg[CTRL_ABORT_BIT];
  assign seq_len_o       = cfg_seq_len[15:0];
  assign d_model_o       = cfg_d_model[15:0];
  assign n_head_o        = cfg_n_head[15:0];
  assign d_ff_o          = cfg_d_ff[15:0];
  assign num_layers_o    = cfg_num_layers[15:0];
  assign layer_cfg_o     = layer_cfg[15:0];
  assign tile_cfg_o      = tile_cfg[15:0];
  assign scale_factor_o  = scale_factor[FP16_WIDTH-1:0];
  assign weight_base_o   = weight_base;
  assign feature_base_o  = feature_base;
  assign kvcache_base_o  = kvcache_base;

  // IRQ output
  assign irq_o = |(irq_status_reg & irq_en_reg);

endmodule
