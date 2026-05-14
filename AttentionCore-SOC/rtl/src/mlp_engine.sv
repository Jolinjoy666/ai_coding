// MLP Engine
// Implements FC1 → GELU → FC2 pipeline.
// Reuses MAC array for matrix multiplication.

module mlp_engine
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

  // Interrupt
  output logic                     irq_o
);

  // FSM states
  typedef enum logic [2:0] {
    ST_IDLE,
    ST_FC1_LOAD,
    ST_FC1_COMPUTE,
    ST_GELU,
    ST_FC2_LOAD,
    ST_FC2_COMPUTE,
    ST_DONE
  } state_e;

  state_e state_q, state_d;

  // Control signals
  logic start, abort;
  logic done, busy;

  // GELU signals
  logic [FP16_WIDTH-1:0] gelu_in, gelu_out;
  logic gelu_valid_in, gelu_valid_out;

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= ST_IDLE;
    end else begin
      state_q <= state_d;
    end
  end

  // Next-state logic
  always_comb begin
    state_d = state_q;
    done    = 1'b0;
    busy    = 1'b0;
    irq_o   = 1'b0;

    feat_rd_en_o   = 1'b0;
    feat_rd_addr_o = '0;
    feat_wr_en_o   = 1'b0;
    feat_wr_addr_o = '0;
    feat_wr_data_o = '0;
    wt_rd_en_o     = 1'b0;
    wt_rd_addr_o   = '0;

    gelu_in      = '0;
    gelu_valid_in = 1'b0;

    unique case (state_q)
      ST_IDLE: begin
        if (start) begin
          state_d = ST_FC1_LOAD;
        end
      end

      ST_FC1_LOAD: begin
        busy = 1'b1;
        // Load FC1 weights and input
        state_d = ST_FC1_COMPUTE;
      end

      ST_FC1_COMPUTE: begin
        busy = 1'b1;
        // FC1: Y = X * W_fc1 + b
        // Use MAC array (simplified)
        state_d = ST_GELU;
      end

      ST_GELU: begin
        busy = 1'b1;
        gelu_valid_in = 1'b1;
        if (gelu_valid_out) begin
          state_d = ST_FC2_LOAD;
        end
      end

      ST_FC2_LOAD: begin
        busy = 1'b1;
        state_d = ST_FC2_COMPUTE;
      end

      ST_FC2_COMPUTE: begin
        busy = 1'b1;
        // FC2: Y = GELU_output * W_fc2 + b
        state_d = ST_DONE;
      end

      ST_DONE: begin
        done  = 1'b1;
        irq_o = 1'b1;
        if (!start) begin
          state_d = ST_IDLE;
        end
      end

      default: begin
        state_d = ST_IDLE;
      end
    endcase

    if (abort) begin
      state_d = ST_IDLE;
    end
  end

  // GELU instance
  gelu_hw u_gelu (
    .clk     (clk),
    .rst_n   (rst_n),
    .x_i     (gelu_in),
    .valid_i (gelu_valid_in),
    .y_o     (gelu_out),
    .valid_o (gelu_valid_out)
  );

  // APB register interface (simplified)
  always_comb begin
    prdata_o = '0;
    pready_o = 1'b1;
    pslverr_o = 1'b0;

    if (psel_i && !pwrite_i) begin
      prdata_o = {30'b0, done, busy};
    end

    if (psel_i && penable_i && pwrite_i) begin
      if (paddr_i == REG_CTRL) begin
        if (pwdata_i[CTRL_START_BIT]) start = 1'b1;
        if (pwdata_i[CTRL_ABORT_BIT]) abort = 1'b1;
      end
    end
  end

endmodule
