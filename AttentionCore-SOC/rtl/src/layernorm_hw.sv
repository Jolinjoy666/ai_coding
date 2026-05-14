// LayerNorm Hardware
// Computes LayerNorm(x) = γ * (x - μ) / √(σ² + ε) + β
// Uses FP16 with rsqrt LUT.

module layernorm_hw
  import soc_params_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Control
  input  logic        start_i,
  input  logic        abort_i,
  output logic        done_o,
  output logic        busy_o,

  // Data input
  input  logic [FP16_WIDTH-1:0] data_i,
  input  logic                  valid_i,
  input  logic                  last_i,

  // Data output
  output logic [FP16_WIDTH-1:0] data_o,
  output logic                  valid_o,

  // Gamma/Beta parameters
  input  logic [FP16_WIDTH-1:0] gamma_i,
  input  logic [FP16_WIDTH-1:0] beta_i,

  // Interrupt
  output logic                  irq_o
);

  // FSM states
  typedef enum logic [2:0] {
    ST_IDLE,
    ST_MEAN,
    ST_VARIANCE,
    ST_NORMALIZE,
    ST_AFFINE,
    ST_DONE
  } state_e;

  state_e state_q, state_d;

  // Accumulators
  logic [FP16_WIDTH-1:0] sum_q, sum_d;
  logic [FP16_WIDTH-1:0] sum_sq_q, sum_sq_d;
  logic [FP16_WIDTH-1:0] mean_q, mean_d;
  logic [FP16_WIDTH-1:0] var_q, var_d;
  logic [15:0] cnt_q, cnt_d;

  // Intermediate values
  logic [FP16_WIDTH-1:0] x_minus_mean;
  logic [FP16_WIDTH-1:0] rsqrt_val;
  logic [FP16_WIDTH-1:0] x_norm;

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= ST_IDLE;
    end else begin
      state_q <= state_d;
    end
  end

  // Accumulator registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum_q    <= '0;
      sum_sq_q <= '0;
      mean_q   <= '0;
      var_q    <= '0;
      cnt_q    <= '0;
    end else begin
      sum_q    <= sum_d;
      sum_sq_q <= sum_sq_d;
      mean_q   <= mean_d;
      var_q    <= var_d;
      cnt_q    <= cnt_d;
    end
  end

  // Next-state logic
  always_comb begin
    state_d   = state_q;
    sum_d     = sum_q;
    sum_sq_d  = sum_sq_q;
    mean_d    = mean_q;
    var_d     = var_q;
    cnt_d     = cnt_q;

    done_o    = 1'b0;
    busy_o    = 1'b0;
    irq_o     = 1'b0;
    valid_o   = 1'b0;
    data_o    = '0;

    unique case (state_q)
      ST_IDLE: begin
        if (start_i) begin
          sum_d    = '0;
          sum_sq_d = '0;
          cnt_d    = '0;
          state_d  = ST_MEAN;
        end
      end

      ST_MEAN: begin
        busy_o = 1'b1;
        if (valid_i) begin
          // Accumulate sum
          sum_d = sum_q + data_i;
          cnt_d = cnt_q + 1;

          if (last_i) begin
            // Calculate mean: μ = sum / d_model
            mean_d = sum_q / D_MODEL;
            state_d = ST_VARIANCE;
          end
        end
      end

      ST_VARIANCE: begin
        busy_o = 1'b1;
        if (valid_i) begin
          // Accumulate (x - μ)²
          x_minus_mean = data_i - mean_q;
          sum_sq_d = sum_sq_q + (x_minus_mean * x_minus_mean);

          if (last_i) begin
            // Calculate variance: σ² = sum_sq / d_model
            var_d = sum_sq_q / D_MODEL;
            state_d = ST_NORMALIZE;
          end
        end
      end

      ST_NORMALIZE: begin
        busy_o = 1'b1;
        // rsqrt(σ² + ε) lookup
        // Then: x_norm = (x - μ) * rsqrt
        if (valid_i) begin
          x_minus_mean = data_i - mean_q;
          x_norm = x_minus_mean * rsqrt_val;
          data_o = x_norm;
          valid_o = 1'b1;

          if (last_i) begin
            state_d = ST_AFFINE;
          end
        end
      end

      ST_AFFINE: begin
        busy_o = 1'b1;
        // γ * x_norm + β
        if (valid_i) begin
          data_o = (data_i * gamma_i) + beta_i;
          valid_o = 1'b1;

          if (last_i) begin
            state_d = ST_DONE;
          end
        end
      end

      ST_DONE: begin
        done_o = 1'b1;
        irq_o  = 1'b1;
        if (!start_i) begin
          state_d = ST_IDLE;
        end
      end

      default: begin
        state_d = ST_IDLE;
      end
    endcase

    if (abort_i) begin
      state_d = ST_IDLE;
    end
  end

  // Rsqrt LUT (simplified)
  assign rsqrt_val = 16'h3C00;  // Placeholder: 1.0

endmodule
