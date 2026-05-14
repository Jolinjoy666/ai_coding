// Causal Mask
// Applies lower-triangular mask for autoregressive inference.
// Sets S[i][j] = -inf for i < j.

module causal_mask
  import soc_params_pkg::*;
(
  input  logic [FP16_WIDTH-1:0] data_i,
  input  logic [15:0]           row_i,
  input  logic [15:0]           col_i,
  input  logic                  valid_i,
  output logic [FP16_WIDTH-1:0] data_o,
  output logic                  valid_o
);

  // FP16 negative infinity
  localparam logic [FP16_WIDTH-1:0] FP16_NEG_INF = 16'hFC00;

  // Apply mask
  always_comb begin
    if (row_i < col_i) begin
      data_o = FP16_NEG_INF;
    end else begin
      data_o = data_i;
    end
    valid_o = valid_i;
  end

endmodule
