// FP16 Reciprocal (1/x)
// Computes 1/x using LUT + exponent manipulation.
// Latency: 1 cycle (registered output)
// Method: 1/(1.m * 2^e) = (1/(1.m)) * 2^(-e)
//   - LUT indexed by mantissa[9:4] (64 entries) gives 1/(1.m)
//   - Exponent: new_exp = 30 - old_exp (bias flip)

module fp16_reciprocal
  import soc_params_pkg::*;
(
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic [FP16_WIDTH-1:0] x_i,
  input  logic                  valid_i,
  output logic [FP16_WIDTH-1:0] recip_o,
  output logic                  valid_o
);

  // Reciprocal LUT: 1/(1 + i/64) for i = 0..63
  logic [FP16_WIDTH-1:0] lut [0:63];

  initial begin
      lut[ 0] = 16'h3C00; lut[ 1] = 16'h3BE0; lut[ 2] = 16'h3BC2; lut[ 3] = 16'h3BA4;
      lut[ 4] = 16'h3B88; lut[ 5] = 16'h3B6C; lut[ 6] = 16'h3B50; lut[ 7] = 16'h3B36;
      lut[ 8] = 16'h3B1C; lut[ 9] = 16'h3B04; lut[10] = 16'h3AEB; lut[11] = 16'h3AD4;
      lut[12] = 16'h3ABD; lut[13] = 16'h3AA6; lut[14] = 16'h3A90; lut[15] = 16'h3A7B;
      lut[16] = 16'h3A66; lut[17] = 16'h3A52; lut[18] = 16'h3A3E; lut[19] = 16'h3A2B;
      lut[20] = 16'h3A18; lut[21] = 16'h3A06; lut[22] = 16'h39F4; lut[23] = 16'h39E3;
      lut[24] = 16'h39D1; lut[25] = 16'h39C1; lut[26] = 16'h39B0; lut[27] = 16'h39A0;
      lut[28] = 16'h3991; lut[29] = 16'h3981; lut[30] = 16'h3972; lut[31] = 16'h3964;
      lut[32] = 16'h3955; lut[33] = 16'h3947; lut[34] = 16'h3939; lut[35] = 16'h392C;
      lut[36] = 16'h391F; lut[37] = 16'h3912; lut[38] = 16'h3905; lut[39] = 16'h38F9;
      lut[40] = 16'h38EC; lut[41] = 16'h38E0; lut[42] = 16'h38D5; lut[43] = 16'h38C9;
      lut[44] = 16'h38BE; lut[45] = 16'h38B2; lut[46] = 16'h38A8; lut[47] = 16'h389D;
      lut[48] = 16'h3892; lut[49] = 16'h3888; lut[50] = 16'h387E; lut[51] = 16'h3874;
      lut[52] = 16'h386A; lut[53] = 16'h3860; lut[54] = 16'h3857; lut[55] = 16'h384D;
      lut[56] = 16'h3844; lut[57] = 16'h383B; lut[58] = 16'h3832; lut[59] = 16'h382A;
      lut[60] = 16'h3821; lut[61] = 16'h3819; lut[62] = 16'h3810; lut[63] = 16'h3808;
  end

  // Unpack input
  logic        sign;
  logic [4:0]  exp;
  logic [9:0]  man;

  assign sign = x_i[15];
  assign exp  = x_i[14:10];
  assign man  = x_i[9:0];

  // Is zero?
  logic is_zero;
  assign is_zero = (exp == 5'b0) && (man == 10'b0);

  // LUT index: top 6 bits of mantissa
  logic [5:0] lut_idx;
  assign lut_idx = man[9:4];

  // Compute reciprocal exponent: 30 - exp
  // For exp=15 (value=1.0): new_exp = 15 (recip = 1.0) ✓
  // For exp=16 (value=2.0): new_exp = 14 (recip = 0.5) ✓
  logic [5:0] recip_exp;
  assign recip_exp = 6'd30 - {1'b0, exp};

  // LUT read + output assembly (registered)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      recip_o <= '0;
      valid_o <= 1'b0;
    end else begin
      if (valid_i) begin
        if (is_zero) begin
          recip_o <= {sign, 5'h1F, 10'b0};
        end else if (recip_exp[5]) begin
          recip_o <= {sign, 5'b0, 10'b0};
        end else if (recip_exp[4:0] == 5'h1F) begin
          recip_o <= {sign, 5'h1F, 10'b0};
        end else begin
          recip_o <= {sign, recip_exp[4:0], lut[lut_idx][9:0]};
        end
      end
      valid_o <= valid_i;
    end
  end

endmodule
