// FP16 Exponential Lookup Table
// 256-entry LUT for exp(x) where x is negative FP16.
// Index mapping: {exponent, mantissa[9:7]} → 8-bit index
// Input range: [-16, 0] (FP16 negative numbers)
// For x >= 0: output clamps to 1.0 (softmax use case: inputs always <= 0)

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

  // LUT storage: 256 entries for exp(x)
  // Index = {exponent[4:0], mantissa[9:7]} = 8 bits
  logic [FP16_WIDTH-1:0] lut [0:EXP_LUT_DEPTH-1];

  // Pre-computed exp values using Python:
  // For index i: exp = i//8, man_top3 = i%8
  // magnitude = (1 + (man_top3<<7)/1024) * 2^(exp-15)
  // lut[i] = exp(-magnitude) in FP16
  initial begin
      lut[  0] = 16'h3C00; lut[  1] = 16'h3C00; lut[  2] = 16'h3C00; lut[  3] = 16'h3C00;
      lut[  4] = 16'h3C00; lut[  5] = 16'h3C00; lut[  6] = 16'h3C00; lut[  7] = 16'h3C00;
      lut[  8] = 16'h3C00; lut[  9] = 16'h3C00; lut[ 10] = 16'h3C00; lut[ 11] = 16'h3C00;
      lut[ 12] = 16'h3C00; lut[ 13] = 16'h3C00; lut[ 14] = 16'h3C00; lut[ 15] = 16'h3C00;
      lut[ 16] = 16'h3C00; lut[ 17] = 16'h3C00; lut[ 18] = 16'h3C00; lut[ 19] = 16'h3C00;
      lut[ 20] = 16'h3C00; lut[ 21] = 16'h3C00; lut[ 22] = 16'h3C00; lut[ 23] = 16'h3C00;
      lut[ 24] = 16'h3C00; lut[ 25] = 16'h3BFF; lut[ 26] = 16'h3BFF; lut[ 27] = 16'h3BFF;
      lut[ 28] = 16'h3BFF; lut[ 29] = 16'h3BFF; lut[ 30] = 16'h3BFF; lut[ 31] = 16'h3BFF;
      lut[ 32] = 16'h3BFF; lut[ 33] = 16'h3BFF; lut[ 34] = 16'h3BFF; lut[ 35] = 16'h3BFF;
      lut[ 36] = 16'h3BFF; lut[ 37] = 16'h3BFE; lut[ 38] = 16'h3BFE; lut[ 39] = 16'h3BFE;
      lut[ 40] = 16'h3BFE; lut[ 41] = 16'h3BFE; lut[ 42] = 16'h3BFE; lut[ 43] = 16'h3BFD;
      lut[ 44] = 16'h3BFD; lut[ 45] = 16'h3BFD; lut[ 46] = 16'h3BFD; lut[ 47] = 16'h3BFC;
      lut[ 48] = 16'h3BFC; lut[ 49] = 16'h3BFC; lut[ 50] = 16'h3BFB; lut[ 51] = 16'h3BFB;
      lut[ 52] = 16'h3BFA; lut[ 53] = 16'h3BFA; lut[ 54] = 16'h3BF9; lut[ 55] = 16'h3BF9;
      lut[ 56] = 16'h3BF8; lut[ 57] = 16'h3BF7; lut[ 58] = 16'h3BF6; lut[ 59] = 16'h3BF5;
      lut[ 60] = 16'h3BF4; lut[ 61] = 16'h3BF3; lut[ 62] = 16'h3BF2; lut[ 63] = 16'h3BF1;
      lut[ 64] = 16'h3BF0; lut[ 65] = 16'h3BEE; lut[ 66] = 16'h3BEC; lut[ 67] = 16'h3BEA;
      lut[ 68] = 16'h3BE8; lut[ 69] = 16'h3BE6; lut[ 70] = 16'h3BE4; lut[ 71] = 16'h3BE2;
      lut[ 72] = 16'h3BE0; lut[ 73] = 16'h3BDC; lut[ 74] = 16'h3BD8; lut[ 75] = 16'h3BD4;
      lut[ 76] = 16'h3BD1; lut[ 77] = 16'h3BCD; lut[ 78] = 16'h3BC9; lut[ 79] = 16'h3BC5;
      lut[ 80] = 16'h3BC1; lut[ 81] = 16'h3BB9; lut[ 82] = 16'h3BB2; lut[ 83] = 16'h3BAA;
      lut[ 84] = 16'h3BA2; lut[ 85] = 16'h3B9B; lut[ 86] = 16'h3B93; lut[ 87] = 16'h3B8B;
      lut[ 88] = 16'h3B84; lut[ 89] = 16'h3B75; lut[ 90] = 16'h3B66; lut[ 91] = 16'h3B57;
      lut[ 92] = 16'h3B49; lut[ 93] = 16'h3B3A; lut[ 94] = 16'h3B2C; lut[ 95] = 16'h3B1E;
      lut[ 96] = 16'h3B0F; lut[ 97] = 16'h3AF3; lut[ 98] = 16'h3AD8; lut[ 99] = 16'h3ABD;
      lut[100] = 16'h3AA2; lut[101] = 16'h3A88; lut[102] = 16'h3A6E; lut[103] = 16'h3A54;
      lut[104] = 16'h3A3B; lut[105] = 16'h3A0A; lut[106] = 16'h39DA; lut[107] = 16'h39AC;
      lut[108] = 16'h3980; lut[109] = 16'h3954; lut[110] = 16'h392A; lut[111] = 16'h3902;
      lut[112] = 16'h38DA; lut[113] = 16'h388F; lut[114] = 16'h3848; lut[115] = 16'h3806;
      lut[116] = 16'h378F; lut[117] = 16'h371A; lut[118] = 16'h36AB; lut[119] = 16'h3644;
      lut[120] = 16'h35E3; lut[121] = 16'h3532; lut[122] = 16'h3496; lut[123] = 16'h340C;
      lut[124] = 16'h3324; lut[125] = 16'h324D; lut[126] = 16'h3190; lut[127] = 16'h30E8;
      lut[128] = 16'h3055; lut[129] = 16'h2EBF; lut[130] = 16'h2D41; lut[131] = 16'h2C17;
      lut[132] = 16'h2A5F; lut[133] = 16'h28F7; lut[134] = 16'h27BB; lut[135] = 16'h2605;
      lut[136] = 16'h24B0; lut[137] = 16'h21B0; lut[138] = 16'h1EE6; lut[139] = 16'h1C2F;
      lut[140] = 16'h1914; lut[141] = 16'h1628; lut[142] = 16'h1378; lut[143] = 16'h1088;
      lut[144] = 16'h0D7F; lut[145] = 16'h0000; lut[146] = 16'h0000; lut[147] = 16'h0000;
      lut[148] = 16'h0000; lut[149] = 16'h0000; lut[150] = 16'h0000; lut[151] = 16'h0000;
      lut[152] = 16'h0000; lut[153] = 16'h0000; lut[154] = 16'h0000; lut[155] = 16'h0000;
      lut[156] = 16'h0000; lut[157] = 16'h0000; lut[158] = 16'h0000; lut[159] = 16'h0000;
      lut[160] = 16'h0000; lut[161] = 16'h0000; lut[162] = 16'h0000; lut[163] = 16'h0000;
      lut[164] = 16'h0000; lut[165] = 16'h0000; lut[166] = 16'h0000; lut[167] = 16'h0000;
      lut[168] = 16'h0000; lut[169] = 16'h0000; lut[170] = 16'h0000; lut[171] = 16'h0000;
      lut[172] = 16'h0000; lut[173] = 16'h0000; lut[174] = 16'h0000; lut[175] = 16'h0000;
      lut[176] = 16'h0000; lut[177] = 16'h0000; lut[178] = 16'h0000; lut[179] = 16'h0000;
      lut[180] = 16'h0000; lut[181] = 16'h0000; lut[182] = 16'h0000; lut[183] = 16'h0000;
      lut[184] = 16'h0000; lut[185] = 16'h0000; lut[186] = 16'h0000; lut[187] = 16'h0000;
      lut[188] = 16'h0000; lut[189] = 16'h0000; lut[190] = 16'h0000; lut[191] = 16'h0000;
      lut[192] = 16'h0000; lut[193] = 16'h0000; lut[194] = 16'h0000; lut[195] = 16'h0000;
      lut[196] = 16'h0000; lut[197] = 16'h0000; lut[198] = 16'h0000; lut[199] = 16'h0000;
      lut[200] = 16'h0000; lut[201] = 16'h0000; lut[202] = 16'h0000; lut[203] = 16'h0000;
      lut[204] = 16'h0000; lut[205] = 16'h0000; lut[206] = 16'h0000; lut[207] = 16'h0000;
      lut[208] = 16'h0000; lut[209] = 16'h0000; lut[210] = 16'h0000; lut[211] = 16'h0000;
      lut[212] = 16'h0000; lut[213] = 16'h0000; lut[214] = 16'h0000; lut[215] = 16'h0000;
      lut[216] = 16'h0000; lut[217] = 16'h0000; lut[218] = 16'h0000; lut[219] = 16'h0000;
      lut[220] = 16'h0000; lut[221] = 16'h0000; lut[222] = 16'h0000; lut[223] = 16'h0000;
      lut[224] = 16'h0000; lut[225] = 16'h0000; lut[226] = 16'h0000; lut[227] = 16'h0000;
      lut[228] = 16'h0000; lut[229] = 16'h0000; lut[230] = 16'h0000; lut[231] = 16'h0000;
      lut[232] = 16'h0000; lut[233] = 16'h0000; lut[234] = 16'h0000; lut[235] = 16'h0000;
      lut[236] = 16'h0000; lut[237] = 16'h0000; lut[238] = 16'h0000; lut[239] = 16'h0000;
      lut[240] = 16'h0000; lut[241] = 16'h0000; lut[242] = 16'h0000; lut[243] = 16'h0000;
      lut[244] = 16'h0000; lut[245] = 16'h0000; lut[246] = 16'h0000; lut[247] = 16'h0000;
      lut[248] = 16'h0000; lut[249] = 16'h0000; lut[250] = 16'h0000; lut[251] = 16'h0000;
      lut[252] = 16'h0000; lut[253] = 16'h0000; lut[254] = 16'h0000; lut[255] = 16'h0000;
  end

  // Index extraction: {exponent[4:0], mantissa[9:7]}
  logic [7:0] lut_index;
  logic is_negative;

  assign is_negative = x_i[15];

  always_comb begin
    if (!is_negative || x_i[14:10] == 5'b0) begin
      // Positive or zero: exp(x) ≈ 1.0 for softmax
      lut_index = 8'd0;
    end else begin
      // Negative: index = {exponent, mantissa[9:7]}
      lut_index = {x_i[14:10], x_i[9:7]};
    end
  end

  // LUT read (1 cycle latency)
  logic [FP16_WIDTH-1:0] lut_value_q;
  logic                  valid_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lut_value_q <= '0;
      valid_q     <= 1'b0;
    end else begin
      if (!is_negative || x_i[14:10] == 5'b0) begin
        // Positive or zero: output 1.0
        lut_value_q <= 16'h3C00;
      end else begin
        lut_value_q <= lut[lut_index];
      end
      valid_q <= valid_i;
    end
  end

  // Output
  assign exp_o    = lut_value_q;
  assign valid_o  = valid_q;

endmodule
