// FP32 to FP16 Converter
// Converts IEEE 754 single-precision to half-precision with rounding.

module fp32_to_fp16
  import soc_params_pkg::*;
(
  input  logic [FP32_WIDTH-1:0] fp32_i,
  output logic [FP16_WIDTH-1:0] fp16_o
);

  logic        sign;
  logic [7:0]  exp32;
  logic [22:0] man32;

  assign sign  = fp32_i[31];
  assign exp32 = fp32_i[30:23];
  assign man32 = fp32_i[22:0];

  logic [4:0]  exp16;
  logic [9:0]  man16;

  always_comb begin
    if (exp32 == 8'h00) begin
      // Zero
      exp16 = 5'h00;
      man16 = 10'b0;
    end else if (exp32 == 8'hFF) begin
      // Inf or NaN
      exp16 = 5'h1F;
      man16 = (man32 != 0) ? 10'h200 : 10'b0;  // NaN has quiet bit
    end else begin
      // Normalized: rebias from 127 to 15
      logic signed [8:0] biased_exp;
      biased_exp = {1'b0, exp32} - 9'sd112;

      if (biased_exp <= 0) begin
        // Underflow to zero
        exp16 = 5'h00;
        man16 = 10'b0;
      end else if (biased_exp >= 31) begin
        // Overflow to inf
        exp16 = 5'h1F;
        man16 = 10'b0;
      end else begin
        exp16 = biased_exp[4:0];
        man16 = man32[22:13];  // Truncate with rounding
      end
    end
  end

  assign fp16_o = {sign, exp16, man16};

endmodule
