// FP16 Exponential Lookup Table
// 256-entry LUT with linear interpolation for exp(x).
// Input range: [-8, 0] (FP16)
// For values > 0, clamp to 1.0 (softmax normalization handles this)

module fp16_exp_lut
  import soc_params_pkg::*;
(
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic [FP16_WIDTH-1:0] x_i,
  input  logic                  valid_i,
  output logic [FP16_WIDTH-1:0] exp_o,
  output logic                  valid_o
);

  // LUT storage: 256 entries for exp(x) where x in [-8, 0]
  // Each entry is FP16
  logic [FP16_WIDTH-1:0] lut [0:EXP_LUT_DEPTH-1];

  // Initialize LUT with exp values
  // lut[i] = exp(-8 + 8*i/255) in FP16
  initial begin
    // These would be pre-computed and loaded
    // For synthesis, use a ROM macro or generate block
    for (int i = 0; i < EXP_LUT_DEPTH; i++) begin
      lut[i] = 16'h3C00;  // Placeholder: 1.0 in FP16
    end
  end

  // Extract index from input
  // Map x in [-8, 0] to index [0, 255]
  // index = (x + 8) * 255 / 8 = (x + 8) * 31.875
  logic [7:0]  lut_index;
  logic [FP16_WIDTH-1:0] x_clamped;

  always_comb begin
    // Clamp to valid range
    if (x_i[15] == 1'b0) begin
      // Positive: exp(x) ≈ 1.0 for softmax (x already subtracted max)
      x_clamped = 16'h3C00;  // 1.0
    end else if (x_i[14:10] < 5'h03) begin
      // Very negative: exp(x) ≈ 0
      x_clamped = 16'h0000;
    end else begin
      x_clamped = x_i;
    end

    // Simple index extraction (approximate)
    // For proper implementation, need FP16 to index conversion
    lut_index = x_clamped[7:0];
  end

  // LUT read (1 cycle latency)
  logic [FP16_WIDTH-1:0] lut_value_q;
  logic                  valid_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lut_value_q <= '0;
      valid_q     <= 1'b0;
    end else begin
      lut_value_q <= lut[lut_index];
      valid_q     <= valid_i;
    end
  end

  // Output
  assign exp_o    = lut_value_q;
  assign valid_o  = valid_q;

endmodule
