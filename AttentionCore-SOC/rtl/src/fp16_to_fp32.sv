// FP16 to FP32 Converter
// Converts IEEE 754 half-precision to single-precision.

module fp16_to_fp32
  import soc_params_pkg::*;
(
  input  logic [FP16_WIDTH-1:0] fp16_i,
  output logic [FP32_WIDTH-1:0] fp32_o
);

  logic        sign;
  logic [4:0]  exp16;
  logic [9:0]  man16;

  assign sign  = fp16_i[15];
  assign exp16 = fp16_i[14:10];
  assign man16 = fp16_i[9:0];

  logic [7:0]  exp32;
  logic [22:0] man32;

  always_comb begin
    if (exp16 == 5'h00) begin
      // Zero or denormalized
      exp32 = 8'h00;
      man32 = {man16, 13'b0};
    end else if (exp16 == 5'h1F) begin
      // Infinity or NaN
      exp32 = 8'hFF;
      man32 = {man16, 13'b0};
    end else begin
      // Normalized: rebias from 15 to 127
      exp32 = {3'b0, exp16} + 8'd112;
      man32 = {man16, 13'b0};
    end
  end

  assign fp32_o = {sign, exp32, man32};

endmodule
